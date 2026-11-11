---
name: nme-shell-apps
description: List and read Nerdio Manager for Enterprise shell apps and their versions through the REST API, and create a shell app or add a version after the admin says yes. Never deletes. Use when the admin asks what shell apps exist, what a shell app's scripts do, or wants a new app or version added.
---

# Nerdio shell apps

A shell app is an app Nerdio Manager installs with three PowerShell scripts: **detect** (is it installed?), **install** and **uninstall**. Each app has one or more versions.

Every call goes through [../nerdio-rest-api/scripts/nme.ps1](../nerdio-rest-api/scripts/nme.ps1). Set up the connection first: [connections/nerdio-rest-api.md](../../connections/nerdio-rest-api.md).

## Read (no approval needed)

```powershell
pwsh skills/nerdio-rest-api/scripts/nme.ps1 app-list            # id, name, publisher, public or not
pwsh skills/nerdio-rest-api/scripts/nme.ps1 app-show 2          # all three scripts
pwsh skills/nerdio-rest-api/scripts/nme.ps1 app-versions 2      # versions and their source files
```

When the admin asks "what does this app do", read `app-show` and explain each script. Point out anything risky (a download over HTTP, no hash check, a detect script that always exits 0).

## Create a shell app (needs the admin's yes)

1. Write the three scripts for Windows PowerShell 5.1 and check each with [session-host-script-check](../session-host-script-check/SKILL.md).
   - **Detect:** exit `0` if the app is installed, any other code if not.
   - **Install** and **uninstall:** exit `0` on success.
2. Put the app in a JSON file. These fields are required by the live API spec (10 November 2026):

   ```json
   {
     "name": "7-Zip",
     "description": "7-Zip file archiver",
     "publisher": "Igor Pavlov",
     "isPublic": false,
     "fileUnzip": false,
     "detectBeforeUnzip": false,
     "detectScript": "if (Test-Path 'C:\\Program Files\\7-Zip\\7z.exe') { exit 0 } else { exit 1 }",
     "installScript": "...",
     "uninstallScript": "...",
     "versions": [
       { "name": "24.08", "isPreview": false, "installScriptOverride": null,
         "file": { "sourceUrl": "https://example.com/7z2408-x64.msi", "sha256": "<hash>" } }
     ]
   }
   ```

   Use `"file": null` when the install script downloads the file itself. Give a `sha256` whenever there is a file.
3. Show the request: `pwsh skills/nerdio-rest-api/scripts/nme.ps1 app-create .\app.json -DryRun`
4. Wait for "yes". Then run it again with `-Approved`.

## Add a version (needs the admin's yes)

Put one version in a JSON file (`name` and `isPreview` are required), then:

```powershell
pwsh skills/nerdio-rest-api/scripts/nme.ps1 app-add-version 2 .\version.json -DryRun
```

After the yes, run it again with `-Approved`. Add new versions as `"isPreview": true` first, so the admin can test them before they reach every host.

## Not here

Changing or deleting an existing app or version. Tell the admin what to change and where in Nerdio Manager. Field names change between releases: if the API refuses a field, pull the live spec (see [nerdio-rest-api](../nerdio-rest-api/SKILL.md)).

## Tested

Lab, 10 November 2026, against the live API spec:

- Reads: `app-list`, `app-show`, `app-versions`.
- `app-create` with the JSON shape above and `"file": null`. Job status `Completed`.
- `app-add-version` with a preview version and an install script override. Job status `Completed`, and `app-versions` showed both versions.
- Without `-Approved`, the change was refused (exit code 3).

The shell app was not installed on a host in this test.
