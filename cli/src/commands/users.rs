use clap::Subcommand;
use crate::Result;

#[derive(Subcommand)]
pub enum UsersCommand {
    #[command(hide = true)]
    Stub,
}

pub async fn run(_cmd: UsersCommand) -> Result<()> {
    todo!("implemented in Task 29+")
}
