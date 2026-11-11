---
name: nerdio-rest-api
description: Read from the Nerdio Manager for Enterprise REST API with PowerShell - bearer-token auth, the host pool and session host endpoints, and the traps that cost time (lowercase path, no list-host-pools call, no savings field). Use when scripting reads against Nerdio Manager rather than the Azure ARM API.
---

# Nerdio Manager REST API (read)

This skill reads. Writes exist in the API, but changes stay with the admin.

## Before you start

- REST API access turned on by a Nerdio Manager admin (the Nerdio Help Center has the steps). You need the token URL, client ID, client secret, scope and your Nerdio Manager base URL.
- Keep the secret out of scripts and chat. Read it from a secret store or an environment variable.
- Pull the live API spec first: `GET <base>/swagger/v1/swagger.json` with the bearer token. Without the token you get a redirect to sign-in. A saved copy goes out of date between releases.

## The helper (use this first)

[scripts/nme.ps1](scripts/nme.ps1) does the token, the base URL and the traps for you. It reads the five `NME_*` values from the environment or from `.env` in the agent's root folder ([connections/nerdio-rest-api.md](../../connections/nerdio-rest-api.md)).

```powershell
pwsh skills/nerdio-rest-api/scripts/nme.ps1 check                      # are the values set, does a read work
pwsh skills/nerdio-rest-api/scripts/nme.ps1 get /api/v1/arm/account    # any GET, as JSON
```

The [nme-scripted-actions](../nme-scripted-actions/SKILL.md) and [nme-shell-apps](../nme-shell-apps/SKILL.md) skills use the same helper. Its write commands refuse to run without `-Approved`.

## Get a token (your own script)

```powershell
$tok = (Invoke-RestMethod -Uri $env:NME_TOKEN_URL -Method POST -Body @{
    grant_type    = 'client_credentials'
    client_id     = $env:NME_CLIENT_ID
    client_secret = $env:NME_CLIENT_SECRET
    scope         = $env:NME_SCOPE
} -ContentType 'application/x-www-form-urlencoded').access_token
$headers = @{ Authorization = "Bearer $tok" }
$base = $env:NME_BASE_URL.TrimEnd('/')
```

## Useful reads

```text
GET {base}/api/v1/arm/account                                   subscriptions Nerdio Manager knows
GET {base}/api/v1/arm/hostpool/{sub}/{rg}/{pool}                 host pool details
GET {base}/api/v1/arm/hostpool/{sub}/{rg}/{pool}/host            session hosts in a pool
GET {base}/api/v1/arm/hostpool/{sub}/{rg}/{pool}/auto-scale      auto-scale config
GET {base}/api/v1/usages/arm/hostpool/{sub}/{rg}/{pool}          user counts (named, concurrent, MAU)
```

## Traps

1. **The path is lowercase `hostpool`.** The console shows `hostPool`; the API wants all lowercase.
2. **There is no "list host pools" call.** `GET .../arm/hostpool/{sub}` returns 400. List pools from Azure: `az resource list --subscription <sub> --resource-type Microsoft.DesktopVirtualization/hostpools`.
3. **No savings field.** The console's auto-scale savings figure is not in the API. User Cost Attribution, where it is deployed, gives actual monthly cost per host pool per user, which is cost, not savings.
4. **No job list.** REST reads one job by ID. To search the task log, use the Nerdio Manager MCP server.

## Tested

Lab, 5 October 2026, against the live API spec. Endpoints and behaviour can change with each Nerdio Manager release, so check the spec.
