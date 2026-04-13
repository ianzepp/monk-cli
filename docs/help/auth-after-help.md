# Auth

Authenticate, register, refresh, and inspect tenant state.

This branch covers both the explicit bootstrap flows and the normal login path.

For new users, start with `monk auth register` to create the tenant and first
local session, then use `monk auth login` on later machines or fresh shells.

Common uses:

- `monk auth register --tenant acme --username alice`
- `monk auth login --tenant acme`
- `monk auth refresh`
- `monk auth tenants`

Use `--help` on `login`, `register`, `refresh`, or `tenants` for the next level down.
