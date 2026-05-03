use crate::{client::Client, config::Config, output, CliError, Result};
use clap::Subcommand;
use dialoguer::{Input, Password};
use serde_json::json;

#[derive(Subcommand)]
pub enum AuthCommand {
    /// Sign in to the active context with email and password.
    /// Stores the returned token as the active context's api_key.
    Login,
}

pub async fn run(cmd: AuthCommand) -> Result<()> {
    match cmd {
        AuthCommand::Login => {
            let mut cfg = Config::load()?;
            let active_name = cfg
                .active_context
                .clone()
                .ok_or(CliError::NoActiveContext)?;
            let url = cfg
                .contexts
                .get(&active_name)
                .ok_or(CliError::NoActiveContext)?
                .url
                .clone();

            let email: String = Input::new()
                .with_prompt("Email")
                .interact_text()
                .map_err(|e| CliError::Validation(e.to_string()))?;
            let password = Password::new()
                .with_prompt("Password")
                .interact()
                .map_err(|e| CliError::Validation(e.to_string()))?;

            let body = json!({
                "data": {
                    "type": "user",
                    "attributes": {"email": email, "password": password}
                }
            });

            // unauthenticated POST — use a client with empty key
            let client = Client::new_for_test(&url, "");
            let resp: serde_json::Value =
                client.post("/auth/user/password/sign_in", &body).await?;
            let token = resp["data"]["attributes"]["token"]
                .as_str()
                .ok_or_else(|| CliError::Validation("no token in response".into()))?;

            cfg.contexts.get_mut(&active_name).unwrap().api_key = Some(token.to_string());
            cfg.save()?;
            output::success("authenticated");
        }
    }
    Ok(())
}
