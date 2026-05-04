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
            "no persisted Tofu state at {} — was this cluster bootstrapped via `obercloud init`?",
            cfg_dir.display()
        )));
    }

    output::info(&format!("running tofu destroy on cluster '{}'", name));
    tofu::run(&cfg_dir, &["destroy", "-auto-approve", "-no-color"])?;
    output::success(&format!("control plane '{}' destroyed", name));
    Ok(())
}
