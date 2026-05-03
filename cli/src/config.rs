use crate::{CliError, Result};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::path::PathBuf;

#[derive(Debug, Default, Serialize, Deserialize)]
pub struct Config {
    pub active_context: Option<String>,
    #[serde(default)]
    pub contexts: BTreeMap<String, Context>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Context {
    pub url: String,
    pub api_key: Option<String>,
}

impl Config {
    pub fn path() -> PathBuf {
        dirs::config_dir()
            .expect("no config dir")
            .join("obercloud")
            .join("config.toml")
    }

    pub fn load() -> Result<Self> {
        let p = Self::path();
        if !p.exists() {
            return Ok(Self::default());
        }
        Ok(toml::from_str(&std::fs::read_to_string(&p)?)?)
    }

    pub fn save(&self) -> Result<()> {
        let p = Self::path();
        if let Some(parent) = p.parent() {
            std::fs::create_dir_all(parent)?;
        }
        std::fs::write(&p, toml::to_string_pretty(self)?)?;
        Ok(())
    }

    pub fn active(&self) -> Result<&Context> {
        let n = self
            .active_context
            .as_ref()
            .ok_or(CliError::NoActiveContext)?;
        self.contexts.get(n).ok_or(CliError::NoActiveContext)
    }
}
