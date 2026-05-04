use super::tofu;
use crate::{
    config::{Config, Context},
    output, CliError, Result,
};
use clap::Args as ClapArgs;
use dialoguer::{Password, Select};
use std::fs;

#[derive(ClapArgs)]
pub struct Args {
    /// Hetzner Cloud API token (project-scoped, read+write).
    /// Prompted interactively if not provided.
    #[arg(long)]
    pub token: Option<String>,

    /// Hetzner region (e.g. nbg1, fsn1, hel1).
    #[arg(long, default_value = "nbg1")]
    pub region: String,

    /// Number of control plane nodes (1 = indie dev, 3 = HA).
    #[arg(long, default_value_t = 1)]
    pub nodes: u8,

    /// Hetzner server type for each node (e.g. cx21, cx31, cpx21).
    /// cx21 = 2 vCPU, 4 GB RAM (~€5/month).
    #[arg(long, default_value = "cx21")]
    pub server_type: String,

    /// Logical name for this control plane installation. Used as the
    /// VM hostname prefix and as the CLI context name.
    #[arg(long, default_value = "obercloud")]
    pub name: String,
}

pub async fn run(args: Args) -> Result<()> {
    output::info(&format!(
        "OberCloud bootstrap (Hetzner): {} {}-node cluster in {} on {}",
        args.name, args.nodes, args.region, args.server_type
    ));

    let token = match args.token {
        Some(t) => t,
        None => Password::new()
            .with_prompt("Hetzner API token")
            .interact()
            .map_err(|e| CliError::Validation(e.to_string()))?,
    };

    // Provider picker (Hetzner only in P0)
    Select::new()
        .with_prompt("Provider")
        .items(&["Hetzner"])
        .default(0)
        .interact()
        .ok();

    let nodes = args.nodes;
    if nodes != 1 && nodes != 3 {
        return Err(CliError::Validation("nodes must be 1 or 3".into()));
    }

    let template = if nodes == 1 {
        include_str!("templates/single_node.tf")
    } else {
        include_str!("templates/multi_node.tf")
    };
    let cloud_init = include_str!("templates/cloud_init.yaml");

    let workdir = tempfile::tempdir()?;
    fs::write(workdir.path().join("main.tf"), template)?;
    fs::write(workdir.path().join("cloud_init.yaml"), cloud_init)?;

    let ssh_pubkey = read_ssh_pubkey()?;
    fs::write(
        workdir.path().join("terraform.tfvars"),
        format!(
            "hetzner_token = \"{}\"\n\
             region = \"{}\"\n\
             server_type = \"{}\"\n\
             ssh_pubkey = \"{}\"\n\
             cluster_name = \"{}\"\n",
            token,
            args.region,
            args.server_type,
            ssh_pubkey.trim(),
            args.name,
        ),
    )?;

    output::info("running tofu init");
    tofu::run(workdir.path(), &["init", "-no-color"])?;

    output::info("running tofu apply");
    tofu::run(workdir.path(), &["apply", "-auto-approve", "-no-color"])?;

    let out_json = tofu::run(workdir.path(), &["output", "-json"])?;
    let outputs: serde_json::Value =
        serde_json::from_str(&out_json).map_err(|e| CliError::Tofu(e.to_string()))?;

    let url = outputs["url"]["value"].as_str().unwrap_or("").to_string();
    let admin_password = outputs["admin_password"]["value"]
        .as_str()
        .unwrap_or("")
        .to_string();

    output::info(&format!("waiting for {} to come up", url));
    wait_for_health(&url).await?;

    let mut cfg = Config::load()?;
    cfg.contexts.insert(
        args.name.clone(),
        Context {
            url: url.clone(),
            api_key: None,
        },
    );
    cfg.active_context = Some(args.name.clone());
    cfg.save()?;

    // Persist tfvars + state to a per-cluster directory so destroy/upgrade
    // can find them later. Each cluster name gets its own subdirectory.
    let cfg_dir = Config::path().parent().unwrap().join(&args.name);
    fs::create_dir_all(&cfg_dir)?;
    fs::write(cfg_dir.join("main.tf"), template)?;
    fs::write(cfg_dir.join("cloud_init.yaml"), cloud_init)?;
    fs::copy(
        workdir.path().join("terraform.tfvars"),
        cfg_dir.join("terraform.tfvars"),
    )?;
    let tfstate = workdir.path().join("terraform.tfstate");
    if tfstate.exists() {
        fs::copy(&tfstate, cfg_dir.join("terraform.tfstate"))?;
    }

    output::success(&format!("OberCloud '{}' is running at {}", args.name, url));
    output::success(&format!("admin password: {}", admin_password));
    output::info(&format!(
        "OpenTofu state lives at {} — back this up before tearing down",
        cfg_dir.display()
    ));
    output::info("run `obercloud auth login` to sign in");
    Ok(())
}

fn read_ssh_pubkey() -> Result<String> {
    let home = dirs::home_dir().unwrap();
    fs::read_to_string(home.join(".ssh/id_ed25519.pub"))
        .or_else(|_| fs::read_to_string(home.join(".ssh/id_rsa.pub")))
        .map_err(CliError::from)
}

async fn wait_for_health(url: &str) -> Result<()> {
    let client = reqwest::Client::new();
    for _ in 0..60 {
        if let Ok(r) = client.get(format!("{}/health", url)).send().await {
            if r.status().is_success() {
                return Ok(());
            }
        }
        tokio::time::sleep(std::time::Duration::from_secs(5)).await;
    }
    Err(CliError::Tofu("control plane never became healthy".into()))
}
