use clap::{Parser, Subcommand};
use obercloud::commands;
use obercloud::Result;

#[derive(Parser)]
#[command(name = "obercloud", version, about = "OberCloud control plane CLI")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Bootstrap a new OberCloud installation
    Init(commands::bootstrap::init::Args),
    /// Tear down an OberCloud installation
    Destroy(commands::bootstrap::destroy::Args),
    /// Upgrade an existing OberCloud installation
    Upgrade(commands::bootstrap::upgrade::Args),
    #[command(subcommand)]
    Context(commands::context::ContextCommand),
    #[command(subcommand)]
    Auth(commands::auth::AuthCommand),
    #[command(subcommand)]
    Orgs(commands::orgs::OrgsCommand),
    #[command(subcommand)]
    Users(commands::users::UsersCommand),
    #[command(subcommand)]
    Projects(commands::projects::ProjectsCommand),
    #[command(subcommand)]
    Nodes(commands::nodes::NodesCommand),
    #[command(subcommand)]
    Apikeys(commands::apikeys::ApikeysCommand),
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();
    match cli.command {
        Command::Init(a) => commands::bootstrap::init::run(a).await,
        Command::Destroy(a) => commands::bootstrap::destroy::run(a).await,
        Command::Upgrade(a) => commands::bootstrap::upgrade::run(a).await,
        Command::Context(c) => commands::context::run(c).await,
        Command::Auth(c) => commands::auth::run(c).await,
        Command::Orgs(c) => commands::orgs::run(c).await,
        Command::Users(c) => commands::users::run(c).await,
        Command::Projects(c) => commands::projects::run(c).await,
        Command::Nodes(c) => commands::nodes::run(c).await,
        Command::Apikeys(c) => commands::apikeys::run(c).await,
    }
}
