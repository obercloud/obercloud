use super::tofu;
use crate::{config::Config, output, Result};
use clap::Args as ClapArgs;

#[derive(ClapArgs)]
pub struct Args {}

pub async fn run(_args: Args) -> Result<()> {
    let cfg_dir = Config::path().parent().unwrap().join("default");
    output::info("running tofu destroy");
    tofu::run(&cfg_dir, &["destroy", "-auto-approve", "-no-color"])?;
    output::success("control plane destroyed");
    Ok(())
}
