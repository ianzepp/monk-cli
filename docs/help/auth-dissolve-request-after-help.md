# Auth Dissolve Request

Request a short-lived confirmation token for tenant dissolution.

This is the first step of the two-step dissolve flow. The returned token must
be passed to `monk auth dissolve confirm`.

This branch is intentionally concise; use the command itself for the full flag list.
