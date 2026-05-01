use clap::Subcommand;
use crate::Result;

#[derive(Subcommand)]
pub enum OrgsCommand {
    #[command(hide = true)]
    Stub,
}

pub async fn run(_cmd: OrgsCommand) -> Result<()> {
    todo!("implemented in Task 29+")
}
