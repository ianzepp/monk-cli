use clap::Parser;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let cli = monk_cli::cli::Cli::parse();
    monk_cli::commands::run(cli).await
}
