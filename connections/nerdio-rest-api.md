# Nerdio Manager REST API

The REST API reaches more than the MCP server, and it can write (create and update scripted actions and shell apps). Inch reads freely and writes only after the admin says yes.

## Before you start

- A Nerdio Manager admin turns on REST API access. The Nerdio Help Center has the steps. That gives you five values: the base URL, the token URL, the client ID, the client secret and the scope.
- PowerShell 7 (`pwsh`). It runs on Windows, macOS and Linux.

## Set the secrets

1. Copy [../.env.example](../.env.example) to `.env` in the root of this folder.
2. Fill in the five values. `.env` is in `.gitignore`. Never commit it, never paste the secret into chat.

| Variable | Example |
|---|---|
| `NME_BASE_URL` | `https://nmw-app-xxxxxxxx.azurewebsites.net` |
| `NME_TOKEN_URL` | `https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/token` |
| `NME_CLIENT_ID` | The app (client) ID |
| `NME_CLIENT_SECRET` | The client secret |
| `NME_SCOPE` | `api://<nerdio-app-id>/.default` |

If these are already set as environment variables, the helper uses them and `.env` is not needed.

## Check it works

```powershell
pwsh skills/nerdio-rest-api/scripts/nme.ps1 check
```

It prints which variables are set (with their length, never the value), gets a token, and reads one endpoint. Expected last line: `OK: token and read work`.

## How Inch uses it

All calls go through one helper: [skills/nerdio-rest-api/scripts/nme.ps1](../skills/nerdio-rest-api/scripts/nme.ps1). The skills say which commands to run. A command that changes something refuses to run unless it gets `-Approved`, and Inch adds that only after the admin types yes.
