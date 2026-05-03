use crate::{client::Client, output, Result};
use clap::Subcommand;
use serde_json::json;

#[derive(Subcommand)]
pub enum OrgsCommand {
    /// List organizations visible to the current API key
    List,
    /// Create a new organization
    Create { name: String, slug: String },
    /// Delete an organization by id
    Delete { id: String },
}

pub async fn run(cmd: OrgsCommand) -> Result<()> {
    let client = Client::from_config()?;
    match cmd {
        OrgsCommand::List => {
            let resp: serde_json::Value = client.get("/api/orgs").await?;
            for org in resp["data"].as_array().unwrap_or(&vec![]) {
                println!(
                    "{}  {}",
                    org["id"].as_str().unwrap_or(""),
                    org["attributes"]["name"].as_str().unwrap_or("")
                );
            }
        }
        OrgsCommand::Create { name, slug } => {
            let body = json!({
                "data": {"type": "org", "attributes": {"name": name, "slug": slug}}
            });
            let resp: serde_json::Value = client.post("/api/orgs", &body).await?;
            output::success(&format!(
                "created org {}",
                resp["data"]["id"].as_str().unwrap_or("?")
            ));
        }
        OrgsCommand::Delete { id } => {
            client.delete(&format!("/api/orgs/{}", id)).await?;
            output::success(&format!("deleted org {}", id));
        }
    }
    Ok(())
}
