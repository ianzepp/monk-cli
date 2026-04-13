# Root-level usage notes

By default, `monk` talks to the public Monk API at `https://monk-api.com`.

Examples:

```bash
monk auth register --tenant acme --username alice
monk auth login --tenant acme
monk public llms
monk describe list
monk data list users
monk data get users 123
monk find query users --where '{"active":true}'
monk aggregate run users --count
monk bulk export
monk fs get /docs/README.md
```

Useful onboarding sequence for new users:

```bash
monk auth register --tenant acme --username alice
monk auth login --tenant acme
monk public llms
monk health
monk describe list
monk data list <model>
```

Machine-readable output is available with `--json`:

```bash
monk --json auth login --tenant acme
monk --json describe list
```

If you are automating against Monk, start from the root command tree and then
move down into the resource branch you need.
