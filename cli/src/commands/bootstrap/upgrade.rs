use super::tofu;
use crate::{config::Config, output, Result};
use clap::Args as ClapArgs;

#[derive(ClapArgs)]
pub struct Args {
    #[arg(long, default_value = "latest")]
    pub version: String,
}

pub async fn run(args: Args) -> Result<()> {
    let cfg_dir = Config::path().parent().unwrap().join("default");
    output::info(&format!("upgrading to obercloud {}", args.version));
    tofu::run(&cfg_dir, &["apply", "-auto-approve", "-no-color"])?;
    output::success("upgrade complete");
    Ok(())
}
