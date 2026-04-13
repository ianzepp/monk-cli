use std::io::{self, IsTerminal, Read};

use reqwest::Method;
use serde_json::{json, Value};

use crate::{
    api::{ApiClient, LoginRequest, RefreshRequest, RegisterRequest},
    cli::{
        AclsCommand, AggregateCommand, AppCommand, AuthCommand, BulkCommand, Cli, Command,
        CronCommand, DataCommand, DescribeCommand, DocsCommand, FindCommand, FsCommand,
        PublicCommand, StatCommand, TrackedCommand, TrashedCommand, UserCommand,
    },
    config::MonkConfig,
};

pub async fn run(cli: Cli) -> anyhow::Result<()> {
    let mut config = MonkConfig::load_effective()?;

    if let Some(base_url) = cli.globals.base_url {
        config.base_url = base_url;
    }
    if let Some(token) = cli.globals.token {
        config.token = Some(token);
    }
    if let Some(format) = cli.globals.format {
        config.output_format = crate::config::OutputFormat::from_str(&format).unwrap_or_default();
    }

    let client = ApiClient::new(config.clone())?;

    match cli.command {
        Command::Public(command) => public(command, &client).await?,
        Command::Auth(command) => {
            auth(command, &mut config, &client).await?;
            if config.token.is_some() {
                config.save()?;
            }
        }
        Command::Health => print_json(&client.health().await?)?,
        Command::Docs(command) => docs(command, &client).await?,
        Command::Describe(command) => describe(command, &client).await?,
        Command::Data(command) => data(command, &client).await?,
        Command::Find(command) => find(command, &client).await?,
        Command::Aggregate(command) => aggregate(command, &client).await?,
        Command::Bulk(command) => bulk(command, &client).await?,
        Command::Acls(command) => acls(command, &client).await?,
        Command::Stat(command) => stat(command, &client).await?,
        Command::Tracked(command) => tracked(command, &client).await?,
        Command::Trashed(command) => trashed(command, &client).await?,
        Command::User(command) => user(command, &client).await?,
        Command::Cron(command) => cron(command, &client).await?,
        Command::Fs(command) => fs(command, &client).await?,
        Command::App(command) => app(command, &client).await?,
    }

    Ok(())
}

async fn public(command: PublicCommand, client: &ApiClient) -> anyhow::Result<()> {
    match command.command {
        crate::cli::PublicSubcommand::Root => print_text(&client.get_text("/").await?)?,
        crate::cli::PublicSubcommand::Llms => print_text(&client.get_text("/llms.txt").await?)?,
    }
    Ok(())
}

async fn auth(
    command: AuthCommand,
    config: &mut MonkConfig,
    client: &ApiClient,
) -> anyhow::Result<()> {
    match command.command {
        crate::cli::AuthSubcommand::Login(args) => {
            let response = client
                .auth_login(&LoginRequest {
                    tenant: args.tenant,
                    tenant_id: args.tenant_id,
                    username: args.username,
                    format: args.format,
                })
                .await?;
            let token = response
                .data
                .as_ref()
                .map(|data| data.token.clone())
                .unwrap_or_default();
            if !token.is_empty() {
                config.token = Some(token.clone());
                config.save()?;
            }
            print_json(&response)?;
        }
        crate::cli::AuthSubcommand::Register(args) => {
            let response = client
                .auth_register(&RegisterRequest {
                    tenant: args.tenant,
                    username: args.username,
                    database: args.database,
                    description: args.description,
                    adapter: args.adapter,
                })
                .await?;
            if let Some(token) = response.data.as_ref().map(|data| data.token.clone()) {
                config.token = Some(token);
                config.save()?;
            }
            print_json(&response)?;
        }
        crate::cli::AuthSubcommand::Refresh(args) => {
            let token = args
                .token
                .or_else(|| config.token.clone())
                .ok_or_else(|| anyhow::anyhow!("refresh requires a token or saved config token"))?;
            let response = client.auth_refresh(&RefreshRequest { token }).await?;
            if let Some(next_token) = response.data.as_ref().map(|data| data.token.clone()) {
                config.token = Some(next_token);
                config.save()?;
            }
            print_json(&response)?;
        }
        crate::cli::AuthSubcommand::Tenants => {
            print_json(&client.auth_tenants().await?)?;
        }
    }
    Ok(())
}

async fn docs(command: DocsCommand, client: &ApiClient) -> anyhow::Result<()> {
    match command.command {
        crate::cli::DocsSubcommand::Root => print_text(&client.get_text("/docs").await?)?,
        crate::cli::DocsSubcommand::Path { path } => {
            let path = path.unwrap_or_else(|| "/docs".to_string());
            print_text(&client.get_text(&path).await?)?;
        }
    }
    Ok(())
}

async fn describe(command: DescribeCommand, client: &ApiClient) -> anyhow::Result<()> {
    match command.command {
        crate::cli::DescribeSubcommand::List => {
            print_json(&client.get_json::<Value>("/api/describe").await?)?
        }
        crate::cli::DescribeSubcommand::Get(arg) => print_json(
            &client
                .get_json::<Value>(&format!("/api/describe/{}", arg.model))
                .await?,
        )?,
        crate::cli::DescribeSubcommand::Create(arg) => print_json(
            &client
                .post_json::<_, Value>(
                    &format!("/api/describe/{}", arg.model),
                    &read_json_body_or_default(json!({}))?,
                )
                .await?,
        )?,
        crate::cli::DescribeSubcommand::Update(arg) => print_json(
            &client
                .put_json::<_, Value>(
                    &format!("/api/describe/{}", arg.model),
                    &read_json_body_or_default(json!({}))?,
                )
                .await?,
        )?,
        crate::cli::DescribeSubcommand::Delete(arg) => print_json(
            &client
                .delete_json::<Value>(&format!("/api/describe/{}", arg.model))
                .await?,
        )?,
        crate::cli::DescribeSubcommand::Fields(fields) => describe_fields(fields, client).await?,
    }
    Ok(())
}

async fn describe_fields(
    command: crate::cli::DescribeFieldsCommand,
    client: &ApiClient,
) -> anyhow::Result<()> {
    match command.command {
        crate::cli::DescribeFieldsSubcommand::List(arg) => print_json(
            &client
                .get_json::<Value>(&format!("/api/describe/{}/fields", arg.model))
                .await?,
        )?,
        crate::cli::DescribeFieldsSubcommand::BulkCreate(arg) => print_json(
            &client
                .post_json::<_, Value>(
                    &format!("/api/describe/{}/fields", arg.model),
                    &read_json_body_or_default(json!([]))?,
                )
                .await?,
        )?,
        crate::cli::DescribeFieldsSubcommand::BulkUpdate(arg) => print_json(
            &client
                .put_json::<_, Value>(
                    &format!("/api/describe/{}/fields", arg.model),
                    &read_json_body_or_default(json!([]))?,
                )
                .await?,
        )?,
        crate::cli::DescribeFieldsSubcommand::Get(arg) => print_json(
            &client
                .get_json::<Value>(&format!("/api/describe/{}/fields/{}", arg.model, arg.field))
                .await?,
        )?,
        crate::cli::DescribeFieldsSubcommand::Create(arg) => print_json(
            &client
                .post_json::<_, Value>(
                    &format!("/api/describe/{}/fields/{}", arg.model, arg.field),
                    &read_json_body_or_default(json!({}))?,
                )
                .await?,
        )?,
        crate::cli::DescribeFieldsSubcommand::Update(arg) => print_json(
            &client
                .put_json::<_, Value>(
                    &format!("/api/describe/{}/fields/{}", arg.model, arg.field),
                    &read_json_body_or_default(json!({}))?,
                )
                .await?,
        )?,
        crate::cli::DescribeFieldsSubcommand::Delete(arg) => print_json(
            &client
                .delete_json::<Value>(&format!("/api/describe/{}/fields/{}", arg.model, arg.field))
                .await?,
        )?,
    }
    Ok(())
}

async fn data(command: DataCommand, client: &ApiClient) -> anyhow::Result<()> {
    match command.command {
        crate::cli::DataSubcommand::List(arg) => print_json(
            &client
                .get_json::<Value>(&format!("/api/data/{}", arg.model))
                .await?,
        )?,
        crate::cli::DataSubcommand::Create(arg) => print_json(
            &client
                .post_json::<_, Value>(
                    &format!("/api/data/{}", arg.model),
                    &read_json_body_or_default(json!([]))?,
                )
                .await?,
        )?,
        crate::cli::DataSubcommand::Update(arg) => print_json(
            &client
                .put_json::<_, Value>(
                    &format!("/api/data/{}", arg.model),
                    &read_json_body_or_default(json!([]))?,
                )
                .await?,
        )?,
        crate::cli::DataSubcommand::Patch(arg) => print_json(
            &client
                .patch_json::<_, Value>(
                    &format!("/api/data/{}", arg.model),
                    &read_json_body_or_default(json!({}))?,
                )
                .await?,
        )?,
        crate::cli::DataSubcommand::Delete(arg) => print_json(
            &client
                .delete_json::<Value>(&format!("/api/data/{}", arg.model))
                .await?,
        )?,
        crate::cli::DataSubcommand::Get(arg) => print_json(
            &client
                .get_json::<Value>(&format!("/api/data/{}/{}", arg.model, arg.id))
                .await?,
        )?,
        crate::cli::DataSubcommand::Put(arg) => print_json(
            &client
                .put_json::<_, Value>(
                    &format!("/api/data/{}/{}", arg.model, arg.id),
                    &read_json_body_or_default(json!({}))?,
                )
                .await?,
        )?,
        crate::cli::DataSubcommand::DeleteRecord(arg) => print_json(
            &client
                .delete_json::<Value>(&format!("/api/data/{}/{}", arg.model, arg.id))
                .await?,
        )?,
        crate::cli::DataSubcommand::Relationship(arg) => relationship(arg, client).await?,
    }
    Ok(())
}

async fn relationship(
    command: crate::cli::RelationshipArg,
    client: &ApiClient,
) -> anyhow::Result<()> {
    let base = format!(
        "/api/data/{}/{}/{}",
        command.model, command.id, command.relationship
    );
    match command.command {
        crate::cli::RelationshipSubcommand::Get => {
            print_json(&client.get_json::<Value>(&base).await?)?
        }
        crate::cli::RelationshipSubcommand::Create => print_json(
            &client
                .post_json::<_, Value>(&base, &read_json_body_or_default(json!({}))?)
                .await?,
        )?,
        crate::cli::RelationshipSubcommand::Update => print_json(
            &client
                .put_json::<_, Value>(&base, &read_json_body_or_default(json!({}))?)
                .await?,
        )?,
        crate::cli::RelationshipSubcommand::Delete => {
            print_json(&client.delete_json::<Value>(&base).await?)?
        }
        crate::cli::RelationshipSubcommand::Child(child) => {
            let path = format!("{}/{}", base, child.child);
            print_json(&client.get_json::<Value>(&path).await?)?;
        }
    }
    Ok(())
}

async fn find(command: FindCommand, client: &ApiClient) -> anyhow::Result<()> {
    match command.command {
        crate::cli::FindSubcommand::Query(arg) => print_json(
            &client
                .post_json::<_, Value>(
                    &format!("/api/find/{}", arg.model),
                    &read_json_body_or_default(json!({}))?,
                )
                .await?,
        )?,
        crate::cli::FindSubcommand::Saved(arg) => print_json(
            &client
                .get_json::<Value>(&format!("/api/find/{}/{}", arg.model, arg.target))
                .await?,
        )?,
    }
    Ok(())
}

async fn aggregate(command: AggregateCommand, client: &ApiClient) -> anyhow::Result<()> {
    match command.command {
        crate::cli::AggregateSubcommand::Get(arg) => print_json(
            &client
                .get_json::<Value>(&format!("/api/aggregate/{}", arg.model))
                .await?,
        )?,
        crate::cli::AggregateSubcommand::Run(arg) => print_json(
            &client
                .post_json::<_, Value>(
                    &format!("/api/aggregate/{}", arg.model),
                    &read_json_body_or_default(json!({}))?,
                )
                .await?,
        )?,
    }
    Ok(())
}

async fn bulk(command: BulkCommand, client: &ApiClient) -> anyhow::Result<()> {
    match command.command {
        crate::cli::BulkSubcommand::Run => print_json(
            &client
                .post_json::<_, Value>(
                    "/api/bulk",
                    &read_json_body_or_default(json!({"operations": []}))?,
                )
                .await?,
        )?,
        crate::cli::BulkSubcommand::Export => print_json(
            &client
                .post_json::<_, Value>("/api/bulk/export", &read_json_body_or_default(json!({}))?)
                .await?,
        )?,
        crate::cli::BulkSubcommand::Import => print_json(
            &client
                .post_json::<_, Value>("/api/bulk/import", &read_json_body_or_default(json!({}))?)
                .await?,
        )?,
    }
    Ok(())
}

async fn acls(command: AclsCommand, client: &ApiClient) -> anyhow::Result<()> {
    match command.command {
        crate::cli::AclsSubcommand::Get(arg) => print_json(
            &client
                .get_json::<Value>(&format!("/api/acls/{}/{}", arg.model, arg.id))
                .await?,
        )?,
        crate::cli::AclsSubcommand::Create(arg) => print_json(
            &client
                .post_json::<_, Value>(
                    &format!("/api/acls/{}/{}", arg.model, arg.id),
                    &read_json_body_or_default(json!({}))?,
                )
                .await?,
        )?,
        crate::cli::AclsSubcommand::Update(arg) => print_json(
            &client
                .put_json::<_, Value>(
                    &format!("/api/acls/{}/{}", arg.model, arg.id),
                    &read_json_body_or_default(json!({}))?,
                )
                .await?,
        )?,
        crate::cli::AclsSubcommand::Delete(arg) => print_json(
            &client
                .delete_json::<Value>(&format!("/api/acls/{}/{}", arg.model, arg.id))
                .await?,
        )?,
    }
    Ok(())
}

async fn stat(command: StatCommand, client: &ApiClient) -> anyhow::Result<()> {
    match command.command {
        crate::cli::StatSubcommand::Get(arg) => print_json(
            &client
                .get_json::<Value>(&format!("/api/stat/{}/{}", arg.model, arg.id))
                .await?,
        )?,
    }
    Ok(())
}

async fn tracked(command: TrackedCommand, client: &ApiClient) -> anyhow::Result<()> {
    match command.command {
        crate::cli::TrackedSubcommand::List(arg) => print_json(
            &client
                .get_json::<Value>(&format!("/api/tracked/{}/{}", arg.model, arg.id))
                .await?,
        )?,
        crate::cli::TrackedSubcommand::Get(arg) => print_json(
            &client
                .get_json::<Value>(&format!(
                    "/api/tracked/{}/{}/{}",
                    arg.model, arg.id, arg.change
                ))
                .await?,
        )?,
    }
    Ok(())
}

async fn trashed(command: TrashedCommand, client: &ApiClient) -> anyhow::Result<()> {
    match command.command {
        crate::cli::TrashedSubcommand::List => {
            print_json(&client.get_json::<Value>("/api/trashed").await?)?
        }
        crate::cli::TrashedSubcommand::Model(arg) => print_json(
            &client
                .get_json::<Value>(&format!("/api/trashed/{}", arg.model))
                .await?,
        )?,
        crate::cli::TrashedSubcommand::Record(arg) => print_json(
            &client
                .get_json::<Value>(&format!("/api/trashed/{}/{}", arg.model, arg.id))
                .await?,
        )?,
    }
    Ok(())
}

async fn user(command: UserCommand, client: &ApiClient) -> anyhow::Result<()> {
    match command.command {
        crate::cli::UserSubcommand::Me => {
            print_json(&client.get_json::<Value>("/api/user/me").await?)?
        }
        crate::cli::UserSubcommand::List => {
            print_json(&client.get_json::<Value>("/api/user").await?)?
        }
        crate::cli::UserSubcommand::Create => print_json(
            &client
                .post_json::<_, Value>("/api/user", &read_json_body_or_default(json!({}))?)
                .await?,
        )?,
        crate::cli::UserSubcommand::Get(arg) => print_json(
            &client
                .get_json::<Value>(&format!("/api/user/{}", arg.id))
                .await?,
        )?,
        crate::cli::UserSubcommand::Update(arg) => print_json(
            &client
                .put_json::<_, Value>(
                    &format!("/api/user/{}", arg.id),
                    &read_json_body_or_default(json!({}))?,
                )
                .await?,
        )?,
        crate::cli::UserSubcommand::Delete(arg) => print_json(
            &client
                .delete_json::<Value>(&format!("/api/user/{}", arg.id))
                .await?,
        )?,
        crate::cli::UserSubcommand::Password(arg) => print_json(
            &client
                .post_json::<_, Value>(
                    &format!("/api/user/{}/password", arg.id),
                    &read_json_body_or_default(json!({}))?,
                )
                .await?,
        )?,
        crate::cli::UserSubcommand::Keys(arg) => print_json(
            &client
                .post_json::<_, Value>(
                    &format!("/api/user/{}/keys", arg.id),
                    &read_json_body_or_default(json!({}))?,
                )
                .await?,
        )?,
        crate::cli::UserSubcommand::Sudo => print_json(&client.auth_sudo(None).await?)?,
        crate::cli::UserSubcommand::Fake => print_json(
            &client
                .post_json::<_, Value>("/api/user/fake", &read_json_body_or_default(json!({}))?)
                .await?,
        )?,
    }
    Ok(())
}

async fn cron(command: CronCommand, client: &ApiClient) -> anyhow::Result<()> {
    match command.command {
        crate::cli::CronSubcommand::List => {
            print_json(&client.get_json::<Value>("/api/cron").await?)?
        }
        crate::cli::CronSubcommand::Create => print_json(
            &client
                .post_json::<_, Value>("/api/cron", &read_json_body_or_default(json!({}))?)
                .await?,
        )?,
        crate::cli::CronSubcommand::Get(arg) => print_json(
            &client
                .get_json::<Value>(&format!("/api/cron/{}", arg.pid))
                .await?,
        )?,
        crate::cli::CronSubcommand::Update(arg) => print_json(
            &client
                .patch_json::<_, Value>(
                    &format!("/api/cron/{}", arg.pid),
                    &read_json_body_or_default(json!({}))?,
                )
                .await?,
        )?,
        crate::cli::CronSubcommand::Delete(arg) => print_json(
            &client
                .delete_json::<Value>(&format!("/api/cron/{}", arg.pid))
                .await?,
        )?,
        crate::cli::CronSubcommand::Enable(arg) => print_json(
            &client
                .post_json::<_, Value>(
                    &format!("/api/cron/{}/enable", arg.pid),
                    &read_json_body_or_default(json!({}))?,
                )
                .await?,
        )?,
        crate::cli::CronSubcommand::Disable(arg) => print_json(
            &client
                .post_json::<_, Value>(
                    &format!("/api/cron/{}/disable", arg.pid),
                    &read_json_body_or_default(json!({}))?,
                )
                .await?,
        )?,
    }
    Ok(())
}

async fn fs(command: FsCommand, client: &ApiClient) -> anyhow::Result<()> {
    match command.command {
        crate::cli::FsSubcommand::Get(arg) => {
            print_text(&client.get_text(&format!("/fs/{}", arg.path)).await?)?
        }
        crate::cli::FsSubcommand::Put(arg) => {
            let content = read_stdin_or_empty()?;
            print_text(
                &client
                    .request_text(Method::PUT, &format!("/fs/{}", arg.path), Some(&content))
                    .await?,
            )?;
        }
        crate::cli::FsSubcommand::Delete(arg) => print_json(
            &client
                .delete_json::<Value>(&format!("/fs/{}", arg.path))
                .await?,
        )?,
    }
    Ok(())
}

async fn app(command: AppCommand, client: &ApiClient) -> anyhow::Result<()> {
    let path = command.path.unwrap_or_else(|| "".to_string());
    let full_path = if path.is_empty() {
        format!("/app/{}", command.app_name)
    } else {
        format!("/app/{}/{}", command.app_name, path.trim_start_matches('/'))
    };
    print_text(&client.get_text(&full_path).await?)?;
    Ok(())
}

fn print_json<T: serde::Serialize>(value: &T) -> anyhow::Result<()> {
    let text = serde_json::to_string_pretty(value)?;
    println!("{text}");
    Ok(())
}

fn print_text(value: &str) -> anyhow::Result<()> {
    println!("{value}");
    Ok(())
}

fn read_stdin_or_empty() -> anyhow::Result<String> {
    if io::stdin().is_terminal() {
        return Ok(String::new());
    }

    let mut buffer = String::new();
    let mut stdin = io::stdin();
    if stdin.read_to_string(&mut buffer).is_ok() && !buffer.trim().is_empty() {
        return Ok(buffer);
    }
    Ok(String::new())
}

fn read_json_body_or_default(default: Value) -> anyhow::Result<Value> {
    let raw = read_stdin_or_empty()?;
    if raw.trim().is_empty() {
        return Ok(default);
    }

    Ok(serde_json::from_str(&raw)?)
}
