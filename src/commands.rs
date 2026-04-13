use std::io::{self, IsTerminal, Read};

use reqwest::Method;
use serde_json::{json, Map, Value};

use crate::{
    api::{ApiClient, LoginRequest, RefreshRequest, RegisterRequest},
    cli::{
        AclsCommand, AggregateCommand, AppCommand, AuthCommand, BulkCommand, Cli, Command,
        CronCommand, DataCommand, DescribeCommand, DocsCommand, FindCommand, FsCommand,
        PublicCommand, StatCommand, TrackedCommand, TrashedCommand, UserCommand,
        UserCreateCommand, UserKeysCommand, UserKeysCreateCommand, UserKeysSubcommand,
        UserListCommand, UserPasswordCommand, UserSubcommand,
    },
    config::MonkConfig,
    data,
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
                .get_json_with_query::<_, Value>(
                    &format!("/api/data/{}", arg.model),
                    &data::query_pairs(&command.options),
                )
                .await?,
        )?,
        crate::cli::DataSubcommand::Create(arg) => print_json(
            &client
                .post_json_with_query::<_, _, Value>(
                    &format!("/api/data/{}", arg.model),
                    &data::query_pairs(&command.options),
                    &read_json_body_or_default(json!([]))?,
                )
                .await?,
        )?,
        crate::cli::DataSubcommand::Update(arg) => print_json(
            &client
                .put_json_with_query::<_, _, Value>(
                    &format!("/api/data/{}", arg.model),
                    &data::query_pairs(&command.options),
                    &read_json_body_or_default(json!([]))?,
                )
                .await?,
        )?,
        crate::cli::DataSubcommand::Patch(arg) => print_json(
            &client
                .patch_json_with_query::<_, _, Value>(
                    &format!("/api/data/{}", arg.model),
                    &data::query_pairs(&command.options),
                    &read_json_body_or_default(json!({}))?,
                )
                .await?,
        )?,
        crate::cli::DataSubcommand::Delete(arg) => print_json(
            &client
                .delete_json_with_query::<_, Value>(
                    &format!("/api/data/{}", arg.model),
                    &data::query_pairs(&command.options),
                )
                .await?,
        )?,
        crate::cli::DataSubcommand::Get(arg) => print_json(
            &client
                .get_json_with_query::<_, Value>(
                    &format!("/api/data/{}/{}", arg.model, arg.id),
                    &data::query_pairs(&command.options),
                )
                .await?,
        )?,
        crate::cli::DataSubcommand::Put(arg) => print_json(
            &client
                .put_json_with_query::<_, _, Value>(
                    &format!("/api/data/{}/{}", arg.model, arg.id),
                    &data::query_pairs(&command.options),
                    &read_json_body_or_default(json!({}))?,
                )
                .await?,
        )?,
        crate::cli::DataSubcommand::PatchRecord(arg) => print_json(
            &client
                .patch_json_with_query::<_, _, Value>(
                    &format!("/api/data/{}/{}", arg.model, arg.id),
                    &data::query_pairs(&command.options),
                    &read_json_body_or_default(json!({}))?,
                )
                .await?,
        )?,
        crate::cli::DataSubcommand::DeleteRecord(arg) => print_json(
            &client
                .delete_json_with_query::<_, Value>(
                    &format!("/api/data/{}/{}", arg.model, arg.id),
                    &data::query_pairs(&command.options),
                )
                .await?,
        )?,
        crate::cli::DataSubcommand::Relationship(arg) => {
            relationship(arg, client, &command.options).await?
        }
    }
    Ok(())
}

async fn relationship(
    command: crate::cli::RelationshipArg,
    client: &ApiClient,
    options: &crate::cli::DataOptions,
) -> anyhow::Result<()> {
    let base = format!(
        "/api/data/{}/{}/{}",
        command.model, command.id, command.relationship
    );
    match command.command {
        crate::cli::RelationshipSubcommand::Get => print_json::<Value>(
            &client
                .get_json_with_query::<_, Value>(&base, &data::query_pairs(options))
                .await?,
        )?,
        crate::cli::RelationshipSubcommand::Create => print_json(
            &client
                .post_json_with_query::<_, _, Value>(
                    &base,
                    &data::query_pairs(options),
                    &read_json_body_or_default(json!({}))?,
                )
                .await?,
        )?,
        crate::cli::RelationshipSubcommand::Update => print_json(
            &client
                .put_json_with_query::<_, _, Value>(
                    &base,
                    &data::query_pairs(options),
                    &read_json_body_or_default(json!({}))?,
                )
                .await?,
        )?,
        crate::cli::RelationshipSubcommand::Delete => print_json::<Value>(
            &client
                .delete_json_with_query::<_, Value>(&base, &data::query_pairs(options))
                .await?,
        )?,
        crate::cli::RelationshipSubcommand::Child(child) => {
            let path = format!("{}/{}", base, child.child);
            match child.command {
                crate::cli::RelationshipChildSubcommand::Get => {
                    print_json::<Value>(
                        &client
                            .get_json_with_query::<_, Value>(&path, &data::query_pairs(options))
                            .await?,
                    )?;
                }
                crate::cli::RelationshipChildSubcommand::Put => {
                    print_json::<Value>(
                        &client
                            .put_json_with_query::<_, _, Value>(
                                &path,
                                &data::query_pairs(options),
                                &read_json_body_or_default(json!({}))?,
                            )
                            .await?,
                    )?;
                }
                crate::cli::RelationshipChildSubcommand::Patch => {
                    print_json::<Value>(
                        &client
                            .patch_json_with_query::<_, _, Value>(
                                &path,
                                &data::query_pairs(options),
                                &read_json_body_or_default(json!({}))?,
                            )
                            .await?,
                    )?;
                }
                crate::cli::RelationshipChildSubcommand::Delete => {
                    print_json::<Value>(
                        &client
                            .delete_json_with_query::<_, Value>(&path, &data::query_pairs(options))
                            .await?,
                    )?;
                }
            }
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
        UserSubcommand::Me => {
            print_json(&client.get_json::<Value>("/api/user/me").await?)?
        }
        UserSubcommand::List(args) => {
            let query = user_list_query(&args);
            print_json(&client.get_json_with_query::<_, Value>("/api/user", &query).await?)?
        }
        UserSubcommand::Create(args) => {
            let body = user_create_body(args)?;
            print_json(&client.post_json::<_, Value>("/api/user", &body).await?)?
        }
        UserSubcommand::Get(arg) => print_json(
            &client
                .get_json::<Value>(&format!("/api/user/{}", arg.id))
                .await?,
        )?,
        UserSubcommand::Update(arg) => print_json(
            &client
                .put_json::<_, Value>(
                    &format!("/api/user/{}", arg.id),
                    &read_json_body_or_default(json!({}))?,
                )
                .await?,
        )?,
        UserSubcommand::Delete(args) => {
            let body = json!({
                "confirm": args.confirm,
                "reason": args.reason,
            });
            print_json::<Value>(
                &client
                    .request_json(Method::DELETE, &format!("/api/user/{}", args.id), Some(&body))
                    .await?,
            )?;
        }
        UserSubcommand::Password(args) => {
            let body = user_password_body(args)?;
            print_json::<Value>(
                &client
                    .post_json::<_, Value>(&format!("/api/user/{}/password", body.id), &body.body)
                    .await?,
            )?;
        }
        UserSubcommand::Keys(command) => user_keys(command, client).await?,
        UserSubcommand::Sudo(args) => print_json(&client.auth_sudo(args.reason.as_deref()).await?)?,
        UserSubcommand::Fake(args) => {
            let body = json!({
                "user_id": args.user_id,
                "username": args.username,
            });
            print_json::<Value>(&client.post_json::<_, Value>("/api/user/fake", &body).await?)?
        }
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

fn user_list_query(args: &UserListCommand) -> Vec<(String, String)> {
    let mut query = Vec::new();
    if let Some(limit) = args.limit {
        query.push(("limit".to_string(), limit.to_string()));
    }
    if let Some(offset) = args.offset {
        query.push(("offset".to_string(), offset.to_string()));
    }
    query
}

fn user_create_body(args: UserCreateCommand) -> anyhow::Result<Value> {
    if let Some(body) = args.body {
        return Ok(serde_json::from_str(&body)?);
    }

    let mut object = Map::new();
    if let Some(name) = args.name {
        object.insert("name".to_string(), Value::String(name));
    }
    if let Some(auth) = args.auth {
        object.insert("auth".to_string(), Value::String(auth));
    }
    if let Some(access) = args.access {
        object.insert("access".to_string(), Value::String(access));
    }

    if object.is_empty() {
        return read_json_body_or_default(json!({}));
    }

    Ok(Value::Object(object))
}

struct PasswordBody {
    id: String,
    body: Value,
}

fn user_password_body(args: UserPasswordCommand) -> anyhow::Result<PasswordBody> {
    let mut object = Map::new();
    if let Some(current_password) = args.current_password {
        object.insert(
            "current_password".to_string(),
            Value::String(current_password),
        );
    }
    if let Some(new_password) = args.new_password {
        object.insert("new_password".to_string(), Value::String(new_password));
    }

    if object.is_empty() {
        return Ok(PasswordBody {
            id: args.id,
            body: read_json_body_or_default(json!({}))?,
        });
    }

    Ok(PasswordBody {
        id: args.id,
        body: Value::Object(object),
    })
}

async fn user_keys(command: UserKeysCommand, client: &ApiClient) -> anyhow::Result<()> {
    match command.command {
        UserKeysSubcommand::List(arg) => {
            print_json(&client.get_json::<Value>(&format!("/api/user/{}/keys", arg.id)).await?)?
        }
        UserKeysSubcommand::Create(args) => {
            let body = user_keys_create_body(args)?;
            print_json(
                &client
                    .post_json::<_, Value>(&format!("/api/user/{}/keys", body.id), &body.body)
                    .await?,
            )?;
        }
        UserKeysSubcommand::Delete(arg) => {
            print_json(
                &client
                    .delete_json::<Value>(&format!("/api/user/{}/keys/{}", arg.id, arg.key_id))
                    .await?,
            )?;
        }
    }
    Ok(())
}

struct UserKeysCreateBody {
    id: String,
    body: Value,
}

fn user_keys_create_body(args: UserKeysCreateCommand) -> anyhow::Result<UserKeysCreateBody> {
    let mut object = Map::new();
    if let Some(name) = args.name {
        object.insert("name".to_string(), Value::String(name));
    }
    if let Some(environment) = args.environment {
        object.insert("environment".to_string(), Value::String(environment));
    }
    if let Some(permissions) = args.permissions {
        object.insert("permissions".to_string(), serde_json::from_str(&permissions)?);
    }
    if let Some(expires_at) = args.expires_at {
        object.insert("expires_at".to_string(), Value::String(expires_at));
    }

    Ok(UserKeysCreateBody {
        id: args.id,
        body: Value::Object(object),
    })
}
