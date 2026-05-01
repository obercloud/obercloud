use clap::Subcommand;
use crate::Result;

#[derive(Subcommand)]
pub enum ContextCommand {
    #[command(hide = true)]
    Stub,
}

pub async fn run(_cmd: ContextCommand) -> Result<()> {
    todo!("implemented in Task 29+")
}
