use clap::Parser;

use crate::cli::{AuthSubcommand, AuthTokenSubcommand, Cli, Command};

#[test]
fn parses_auth_token_get_set_clear() {
    let get = Cli::try_parse_from(["monk", "auth", "token", "get"]).expect("get should parse");
    assert_auth_token_subcommand(get, AuthTokenSubcommand::Get);

    let clear = Cli::try_parse_from(["monk", "auth", "token", "clear"]).expect("clear should parse");
    assert_auth_token_subcommand(clear, AuthTokenSubcommand::Clear);
}

#[test]
fn parses_auth_token_set_with_positional_token() {
    let cli = Cli::try_parse_from(["monk", "auth", "token", "set", "jwt-test-value"]).expect("set should parse");

    match cli.command {
        Command::Auth(auth) => match auth.command {
            AuthSubcommand::Token(token) => match token.command {
                AuthTokenSubcommand::Set(args) => {
                    assert_eq!(args.token, "jwt-test-value");
                }
                other => panic!("expected token set command, got {other:?}"),
            },
            other => panic!("expected auth token command, got {other:?}"),
        },
        other => panic!("expected auth command, got {other:?}"),
    }
}

fn assert_auth_token_subcommand(cli: Cli, expected: AuthTokenSubcommand) {
    match cli.command {
        Command::Auth(auth) => match auth.command {
            AuthSubcommand::Token(token) => match (token.command, expected) {
                (AuthTokenSubcommand::Get, AuthTokenSubcommand::Get) => {}
                (AuthTokenSubcommand::Clear, AuthTokenSubcommand::Clear) => {}
                (AuthTokenSubcommand::Set(_), AuthTokenSubcommand::Set(_)) => {}
                (actual, expected) => panic!("expected {expected:?}, got {actual:?}"),
            },
            other => panic!("expected auth token command, got {other:?}"),
        },
        other => panic!("expected auth command, got {other:?}"),
    }
}
