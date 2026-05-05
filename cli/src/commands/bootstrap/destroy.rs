use super::tofu;
use crate::{config::Config, output, CliError, Result};
use clap::Args as ClapArgs;

#[derive(ClapArgs)]
pub struct Args {
    /// Cluster name (matches `obercloud init --name <name>`).
    /// Defaults to the active context.
    #[arg(long)]
    pub name: Option<String>,
}

pub async fn run(args: Args) -> Result<()> {
    let cfg = Config::load()?;
    let name = args
        .name
        .or_else(|| cfg.active_context.clone())
        .ok_or(CliError::NoActiveContext)?;

    let cfg_dir = Config::path().parent().unwrap().join(&name);
    if !cfg_dir.exists() {
        return Err(CliError::Config(format!(
            "no persisted Tofu state at {}.\n\n\
             If `obercloud init` was interrupted, the VM may still be running on\n\
             your provider. Sign in to your provider's console and look for\n\
             instances tagged `obercloud` and `{name}`:\n\
             \x20 • Vultr:   https://my.vultr.com/   (filter by tag)\n\
             \x20 • Hetzner: https://console.hetzner.cloud/   (filter by label)\n\n\
             Older versions of `obercloud init` only persisted state at the very\n\
             end of bootstrap, after the health check. The current version\n\
             persists state right after `tofu apply` so this can't happen again.",
            cfg_dir.display(),
        )));
    }

    output::info(&format!("running tofu init for cluster '{}'", name));
    tofu::run(&cfg_dir, &["init", "-no-color"])?;

    output::info(&format!("running tofu destroy on cluster '{}'", name));
    tofu::run(&cfg_dir, &["destroy", "-auto-approve", "-no-color"])?;
    output::success(&format!("control plane '{}' destroyed", name));
    Ok(())
}
