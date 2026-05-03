use crate::{
    config::{Config, Context},
    output, CliError, Result,
};
use clap::Subcommand;

#[derive(Subcommand)]
pub enum ContextCommand {
    /// Add a new server context
    Add { name: String, url: String },
    /// Set the active context
    Use { name: String },
    /// List all contexts
    List,
}

pub async fn run(cmd: ContextCommand) -> Result<()> {
    let mut cfg = Config::load()?;
    match cmd {
        ContextCommand::Add { name, url } => {
            cfg.contexts
                .insert(name.clone(), Context { url, api_key: None });
            if cfg.active_context.is_none() {
                cfg.active_context = Some(name.clone());
            }
            cfg.save()?;
            output::success(&format!("added context '{}'", name));
        }
        ContextCommand::Use { name } => {
            if !cfg.contexts.contains_key(&name) {
                return Err(CliError::Config(format!("no such context '{}'", name)));
            }
            cfg.active_context = Some(name.clone());
            cfg.save()?;
            output::success(&format!("active context: {}", name));
        }
        ContextCommand::List => {
            for (name, ctx) in &cfg.contexts {
                let m = if cfg.active_context.as_deref() == Some(name) {
                    "*"
                } else {
                    " "
                };
                println!("{} {} ({})", m, name, ctx.url);
            }
        }
    }
    Ok(())
}
