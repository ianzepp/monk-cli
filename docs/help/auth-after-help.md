# Auth

Authenticate, register, refresh, and inspect tenant state.

This branch covers both the explicit bootstrap flows and the normal login path.

Common uses:

- `monk auth login --tenant acme`
- `monk auth register --tenant acme --username alice`
- `monk auth refresh`
- `monk auth tenants`

Use `--help` on `login`, `register`, `refresh`, or `tenants` for the next level down.
