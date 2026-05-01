use thiserror::Error;

#[derive(Error, Debug)]
pub enum CliError {
    #[error("config error: {0}")]
    Config(String),
    #[error("no active context — run `obercloud context use <name>` first")]
    NoActiveContext,
    #[error("HTTP error: {0}")]
    Http(#[from] reqwest::Error),
    #[error("API error ({status}): {message}")]
    Api { status: u16, message: String },
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("TOML parse error: {0}")]
    TomlDe(#[from] toml::de::Error),
    #[error("TOML serialize error: {0}")]
    TomlSer(#[from] toml::ser::Error),
    #[error("OpenTofu error: {0}")]
    Tofu(String),
    #[error("validation error: {0}")]
    Validation(String),
}

pub type Result<T> = std::result::Result<T, CliError>;
