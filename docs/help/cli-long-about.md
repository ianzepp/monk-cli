# Monk CLI

`monk` is the command-line client for the Monk API.

It is organized as a command tree with a small set of root surfaces and a
larger set of resource-specific branches:

- `public` for unauthenticated discovery documents
- `auth` for login, registration, token refresh, and tenant selection
- `health` for a quick service check
- `docs` for direct API documentation access
- `describe`, `data`, `find`, `aggregate`, and `bulk` for model and record work
- `acls`, `stat`, `tracked`, and `trashed` for record metadata and lifecycle
- `user` for account and sudo workflows
- `cron` for scheduled process management
- `fs` for tenant filesystem access
- `app` for dynamic application paths

For first-time use, the shortest onboarding path is usually:

1. `monk auth register` or `monk auth login`
2. `monk public llms` or `monk docs root`
3. `monk describe list` or `monk data list <model>`
4. `monk health`

The CLI prefers structured output and explicit subcommands so it can be driven by
scripts or agents without guessing hidden state.
