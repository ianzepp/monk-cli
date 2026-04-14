# Auth

Authenticate, register, refresh, and inspect tenant state.

This branch covers both the explicit bootstrap flows and the normal login path.

For new users, start with `monk auth register` to create the tenant and first
local session, then use `monk auth login` on later machines or fresh shells.

Common uses:

- `monk auth register --tenant acme --username alice --email alice@example.com --password @auth-password.txt`
- `printf 'secret-pass' | monk auth login --tenant acme --username alice --password -`
- `monk auth refresh`
- `monk auth dissolve request --tenant acme --username alice --password @secret.txt`
- `monk auth dissolve confirm --confirmation-token <token>`
- `monk auth token get`
- `monk auth token clear`
- `monk auth tenants`

Use `--help` on `login`, `register`, `refresh`, `dissolve`, `token`, or `tenants` for the next level down.
