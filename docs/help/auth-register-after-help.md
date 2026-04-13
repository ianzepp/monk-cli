# Auth Register

Create a new tenant identity and local session.

Use this for initial bootstrap when you do not already have an account or saved
state on the current machine.

Typical onboarding flow:

1. `monk auth register --tenant <tenant> --username <user>`
2. `monk auth login --tenant <tenant>` on later runs or other machines
3. continue with `monk public llms`, `monk describe list`, or `monk data list <model>`

This branch is intentionally concise; use the command itself for the full flag list.
