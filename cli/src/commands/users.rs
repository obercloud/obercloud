use crate::{output, CliError, Result};
use clap::Subcommand;

#[derive(Subcommand)]
pub enum UsersCommand {
    /// List users (not exposed via REST API in P0 — use the web UI)
    List,
    /// Invite a user (deferred — P1+ feature)
    Invite {
        email: String,
        org_id: String,
        #[arg(default_value = "org:member")]
        role: String,
    },
    /// Remove a membership
    Remove { user_id: String, org_id: String },
}

pub async fn run(cmd: UsersCommand) -> Result<()> {
    match cmd {
        UsersCommand::List | UsersCommand::Invite { .. } | UsersCommand::Remove { .. } => {
            output::error("user management via CLI is not available in P0");
            Err(CliError::Validation(
                "user management is deferred to P1; use the web UI to manage memberships".into(),
            ))
        }
    }
}
