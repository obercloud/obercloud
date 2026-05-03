use crate::{client::Client, Result};
use clap::Subcommand;

#[derive(Subcommand)]
pub enum NodesCommand {
    List,
    Status,
}

pub async fn run(cmd: NodesCommand) -> Result<()> {
    let client = Client::from_config()?;
    match cmd {
        NodesCommand::List | NodesCommand::Status => {
            let resp: serde_json::Value = client.get("/api/nodes").await?;
            for n in resp["data"].as_array().unwrap_or(&vec![]) {
                let attrs = &n["attributes"];
                println!(
                    "{}  {}  {}  {}  {}",
                    n["id"].as_str().unwrap_or(""),
                    attrs["provider"].as_str().unwrap_or(""),
                    attrs["role"].as_str().unwrap_or(""),
                    attrs["status"].as_str().unwrap_or(""),
                    attrs["ip_address"].as_str().unwrap_or("-"),
                );
            }
        }
    }
    Ok(())
}
