use clap::Subcommand;
use crate::Result;

#[derive(Subcommand)]
pub enum NodesCommand {
    #[command(hide = true)]
    Stub,
}

pub async fn run(_cmd: NodesCommand) -> Result<()> {
    todo!("implemented in Task 29+")
}
