use clap::Subcommand;
use crate::Result;

#[derive(Subcommand)]
pub enum ApikeysCommand {
    #[command(hide = true)]
    Stub,
}

pub async fn run(_cmd: ApikeysCommand) -> Result<()> {
    todo!("implemented in Task 29+")
}
