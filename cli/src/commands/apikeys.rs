use crate::{client::Client, output, Result};
use clap::Subcommand;
use serde_json::json;

#[derive(Subcommand)]
pub enum ApikeysCommand {
    List,
    Create {
        name: String,
        org_id: String,
        #[arg(default_value = "org:admin")]
        role: String,
    },
    Revoke {
        id: String,
    },
}

pub async fn run(cmd: ApikeysCommand) -> Result<()> {
    let client = Client::from_config()?;
    match cmd {
        ApikeysCommand::List => {
            let resp: serde_json::Value = client.get("/api/api_keys").await?;
            for k in resp["data"].as_array().unwrap_or(&vec![]) {
                let a = &k["attributes"];
                println!(
                    "{}  {}  {}  {}",
                    k["id"].as_str().unwrap_or(""),
                    a["name"].as_str().unwrap_or(""),
                    a["role"].as_str().unwrap_or(""),
                    a["key_prefix"].as_str().unwrap_or(""),
                );
            }
        }
        ApikeysCommand::Create {
            name,
            org_id,
            role,
        } => {
            let body = json!({
                "data": {
                    "type": "api_key",
                    "attributes": {"name": name, "role": role, "org_id": org_id}
                }
            });
            let resp: serde_json::Value = client.post("/api/api_keys", &body).await?;
            output::success(&format!(
                "created api key {}",
                resp["data"]["id"].as_str().unwrap_or("?")
            ));
        }
        ApikeysCommand::Revoke { id } => {
            client.delete(&format!("/api/api_keys/{}", id)).await?;
            output::success(&format!("revoked api key {}", id));
        }
    }
    Ok(())
}
