use clap::Subcommand;
use crate::Result;

#[derive(Subcommand)]
pub enum ProjectsCommand {
    #[command(hide = true)]
    Stub,
}

pub async fn run(_cmd: ProjectsCommand) -> Result<()> {
    todo!("implemented in Task 29+")
}
