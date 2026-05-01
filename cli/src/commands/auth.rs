use clap::Subcommand;
use crate::Result;

#[derive(Subcommand)]
pub enum AuthCommand {
    #[command(hide = true)]
    Stub,
}

pub async fn run(_cmd: AuthCommand) -> Result<()> {
    todo!("implemented in Task 29+")
}
