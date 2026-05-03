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
    #[arg(long)]
    pub token: Option<String>,
    #[arg(long, default_value = "nbg1")]
    pub region: String,
    #[arg(long, default_value_t = 1)]
    pub nodes: u8,
}

pub async fn run(args: Args) -> Result<()> {
    output::info("OberCloud bootstrap (Hetzner)");

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
            "hetzner_token = \"{}\"\nregion = \"{}\"\nssh_pubkey = \"{}\"\n",
            token,
            args.region,
            ssh_pubkey.trim()
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
        "default".into(),
        Context {
            url: url.clone(),
            api_key: None,
        },
    );
    cfg.active_context = Some("default".into());
    cfg.save()?;

    // Persist tfvars + state for destroy/upgrade later
    let cfg_dir = Config::path().parent().unwrap().join("default");
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

    output::success(&format!("OberCloud is running at {}", url));
    output::success(&format!("admin password: {}", admin_password));
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
