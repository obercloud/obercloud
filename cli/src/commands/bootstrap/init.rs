use super::tofu;
use crate::{
    config::{Config, Context},
    output, CliError, Result,
};
use clap::{Args as ClapArgs, ValueEnum};
use dialoguer::Password;
use std::{fs, path::PathBuf};

#[derive(Copy, Clone, Debug, PartialEq, Eq, ValueEnum)]
pub enum Provider {
    Vultr,
    Hetzner,
}

impl Provider {
    fn as_str(&self) -> &'static str {
        match self {
            Provider::Vultr => "vultr",
            Provider::Hetzner => "hetzner",
        }
    }

    fn token_var_name(&self) -> &'static str {
        match self {
            Provider::Vultr => "vultr_token",
            Provider::Hetzner => "hetzner_token",
        }
    }

    fn token_prompt(&self) -> &'static str {
        match self {
            Provider::Vultr => "Vultr API key",
            Provider::Hetzner => "Hetzner API token",
        }
    }

    fn default_region(&self) -> &'static str {
        match self {
            Provider::Vultr => "ewr",
            Provider::Hetzner => "nbg1",
        }
    }

    fn default_server_type(&self) -> &'static str {
        match self {
            Provider::Vultr => "vc2-2c-4gb",
            Provider::Hetzner => "cx21",
        }
    }

    fn single_node_template(&self) -> &'static str {
        match self {
            Provider::Vultr => include_str!("templates/vultr_single_node.tf"),
            Provider::Hetzner => include_str!("templates/single_node.tf"),
        }
    }

    fn multi_node_template(&self) -> &'static str {
        match self {
            Provider::Vultr => include_str!("templates/vultr_multi_node.tf"),
            Provider::Hetzner => include_str!("templates/multi_node.tf"),
        }
    }
}

#[derive(ClapArgs)]
pub struct Args {
    /// Cloud provider to bootstrap on. Defaults to vultr.
    #[arg(long, value_enum, default_value_t = Provider::Vultr)]
    pub provider: Provider,

    /// Provider API token. Prompted interactively if not provided.
    #[arg(long)]
    pub token: Option<String>,

    /// Provider region. Vultr default: ewr (New Jersey).
    /// Hetzner default: nbg1 (Nuremberg).
    #[arg(long)]
    pub region: Option<String>,

    /// Number of control plane nodes (1 = indie dev, 3 = HA).
    #[arg(long, default_value_t = 1)]
    pub nodes: u8,

    /// Provider instance type. Vultr default: vc2-2c-4gb.
    /// Hetzner default: cx21.
    #[arg(long)]
    pub server_type: Option<String>,

    /// Logical name for this control plane installation. Used as the
    /// VM hostname prefix and as the CLI context name.
    #[arg(long, default_value = "obercloud")]
    pub name: String,

    /// Path to an SSH public key file to upload. When omitted, the CLI
    /// searches ~/.ssh/id_ed25519.pub, ~/.ssh/id_ed25519_sk.pub,
    /// ~/.ssh/id_ecdsa.pub, and ~/.ssh/id_rsa.pub in that order.
    #[arg(long, value_name = "PATH")]
    pub ssh_pubkey: Option<PathBuf>,
}

pub async fn run(args: Args) -> Result<()> {
    let region = args
        .region
        .unwrap_or_else(|| args.provider.default_region().to_string());
    let server_type = args
        .server_type
        .unwrap_or_else(|| args.provider.default_server_type().to_string());

    output::info(&format!(
        "OberCloud bootstrap ({}): {} {}-node cluster in {} on {}",
        args.provider.as_str(),
        args.name,
        args.nodes,
        region,
        server_type
    ));

    let token = match args.token {
        Some(t) => t,
        None => Password::new()
            .with_prompt(args.provider.token_prompt())
            .interact()
            .map_err(|e| CliError::Validation(e.to_string()))?,
    };

    let nodes = args.nodes;
    if nodes != 1 && nodes != 3 {
        return Err(CliError::Validation("nodes must be 1 or 3".into()));
    }

    let template = if nodes == 1 {
        args.provider.single_node_template()
    } else {
        args.provider.multi_node_template()
    };
    let cloud_init = include_str!("templates/cloud_init.yaml");

    let workdir = tempfile::tempdir()?;
    fs::write(workdir.path().join("main.tf"), template)?;
    fs::write(workdir.path().join("cloud_init.yaml"), cloud_init)?;

    let ssh_pubkey = read_ssh_pubkey(args.ssh_pubkey.as_deref())?;
    fs::write(
        workdir.path().join("terraform.tfvars"),
        format!(
            "{} = \"{}\"\n\
             region = \"{}\"\n\
             server_type = \"{}\"\n\
             ssh_pubkey = \"{}\"\n\
             cluster_name = \"{}\"\n",
            args.provider.token_var_name(),
            token,
            region,
            server_type,
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

fn read_ssh_pubkey(explicit: Option<&std::path::Path>) -> Result<String> {
    if let Some(path) = explicit {
        return fs::read_to_string(path).map_err(|e| {
            CliError::Validation(format!(
                "cannot read SSH public key at {}: {}",
                path.display(),
                e
            ))
        });
    }

    let home = dirs::home_dir().unwrap();
    let candidates = [
        home.join(".ssh/id_ed25519.pub"),
        home.join(".ssh/id_ed25519_sk.pub"),
        home.join(".ssh/id_ecdsa.pub"),
        home.join(".ssh/id_rsa.pub"),
    ];

    for path in &candidates {
        match fs::read_to_string(path) {
            Ok(key) => return Ok(key),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => continue,
            Err(e) => {
                return Err(CliError::Validation(format!(
                    "cannot read SSH public key at {}: {}",
                    path.display(),
                    e
                )))
            }
        }
    }

    let paths = candidates
        .iter()
        .map(|p| p.display().to_string())
        .collect::<Vec<_>>()
        .join(", ");
    Err(CliError::Validation(format!(
        "no SSH public key found — tried: {paths}\n\
         generate one with `ssh-keygen -t ed25519` or pass --ssh-pubkey <PATH>"
    )))
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
