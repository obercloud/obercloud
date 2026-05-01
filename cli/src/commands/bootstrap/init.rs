use clap::Args as ClapArgs;
use crate::Result;

#[derive(ClapArgs)]
pub struct Args {}

pub async fn run(_args: Args) -> Result<()> {
    todo!("implemented in Task 31")
}
