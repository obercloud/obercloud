use crate::{client::Client, output, Result};
use clap::Subcommand;
use serde_json::json;

#[derive(Subcommand)]
pub enum ProjectsCommand {
    List,
    Create {
        name: String,
        slug: String,
        org_id: String,
    },
    Delete {
        id: String,
    },
}

pub async fn run(cmd: ProjectsCommand) -> Result<()> {
    let client = Client::from_config()?;
    match cmd {
        ProjectsCommand::List => {
            let resp: serde_json::Value = client.get("/api/projects").await?;
            for p in resp["data"].as_array().unwrap_or(&vec![]) {
                println!(
                    "{}  {}",
                    p["id"].as_str().unwrap_or(""),
                    p["attributes"]["name"].as_str().unwrap_or("")
                );
            }
        }
        ProjectsCommand::Create { name, slug, org_id } => {
            let body = json!({
                "data": {
                    "type": "project",
                    "attributes": {"name": name, "slug": slug, "org_id": org_id}
                }
            });
            let resp: serde_json::Value = client.post("/api/projects", &body).await?;
            output::success(&format!(
                "created project {}",
                resp["data"]["id"].as_str().unwrap_or("?")
            ));
        }
        ProjectsCommand::Delete { id } => {
            client.delete(&format!("/api/projects/{}", id)).await?;
            output::success(&format!("deleted project {}", id));
        }
    }
    Ok(())
}
