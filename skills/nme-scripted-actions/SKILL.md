---
name: nme-scripted-actions
description: List, read, write, upload and run Nerdio Manager for Enterprise scripted actions through the REST API. Reads run freely; create, update and run happen only after the admin sees the exact change and types yes. Never deletes. Use when the admin asks about a scripted action, wants one written or uploaded, or wants one run on named hosts or as a runbook.
---

# Nerdio scripted actions

Every call goes through the helper [../nerdio-rest-api/scripts/nme.ps1](../nerdio-rest-api/scripts/nme.ps1). Run it with `pwsh`. Set up the connection first: [connections/nerdio-rest-api.md](../../connections/nerdio-rest-api.md). Run `pwsh skills/nerdio-rest-api/scripts/nme.ps1 check` once per session.

## Two kinds of scripted action

| `executionEnvironment` | Runs where | Run it with |
|---|---|---|
| `CustomScript` | On the session host (Windows PowerShell 5.1) | `sa-run-hostpool` |
| `AzureAutomation` | As an Azure Automation runbook | `sa-run` |

`executionTimeout` (minutes) is optional in the API spec. The helper sends it only for `AzureAutomation` with mode `Individual` (`-Timeout`, default 30), and leaves it out for everything else. If the API refuses a create or update because of the timeout, show the admin the error as it came back.

## Read (no approval needed)

```powershell
pwsh skills/nerdio-rest-api/scripts/nme.ps1 sa-list "fslogix"     # id, name, type, mode, tags
pwsh skills/nerdio-rest-api/scripts/nme.ps1 sa-show 71            # full record and script body
pwsh skills/nerdio-rest-api/scripts/nme.ps1 job 4711              # status of a job
pwsh skills/nerdio-rest-api/scripts/nme.ps1 job-tasks 4711        # each task's output
```

There is no "get one" call in the API (it returns 405). `sa-show` lists all and filters.

## Write a new script

1. Ask what it must do, where it runs (host or runbook), and the parameters.
2. Write it for **Windows PowerShell 5.1**, ASCII only. Follow sections 2 and 3 of [RULES.md](../../RULES.md). No here-strings.
3. Write a transcript or clear `Write-Output` lines, so the job output shows what happened.
4. Run [session-host-script-check](../session-host-script-check/SKILL.md) on it. Fix what it finds.
5. Save it as `<Name>.ps1`. The file name becomes the scripted action name.

## Upload (needs the admin's yes)

1. Look for the name first: `sa-list "<name>"`.
   - **Same name exists:** ask the admin. Update that one, or pick a new name with `-Name`.
   - **Similar names exist:** show them and ask before you make another.
2. Show the request without sending it:
   ```powershell
   pwsh skills/nerdio-rest-api/scripts/nme.ps1 sa-create .\Fix-Thing.ps1 -Environment CustomScript -Mode Individual -Description "..." -DryRun
   ```
3. Show the admin the output. Wait for "yes".
4. Run the same command with `-Approved` in place of `-DryRun`.

To replace the script of an existing action, use `sa-update <id> <file.ps1>` the same way. It sends only the new script; the name, type and tags stay as they are.

If an update fails, show the admin the error as it came back. Do not delete and re-create the action to get round it: the ID would change, and anything that points at the old ID would break.

## Run (needs the admin's yes)

On named session hosts (FQDNs, as Nerdio Manager shows them):

```powershell
pwsh skills/nerdio-rest-api/scripts/nme.ps1 sa-run-hostpool 71 -Subscription <sub> -ResourceGroup <rg> -HostPool <pool> -Hosts avd-0.contoso.local -DryRun
```

- The helper always needs `-Hosts`. It will not run on a whole pool by default.
- It skips hosts that are not running, does one host at a time, and stops at the first failure.
- It does not restart hosts unless the admin asks for `-RestartVms`.
- The action may need to be assigned to the host pool in Nerdio Manager, or the hosts are skipped. If the job shows no tasks, check this first.

As a runbook:

```powershell
pwsh skills/nerdio-rest-api/scripts/nme.ps1 sa-run 12 -Subscription <sub> -Param VMName=avd-0 -MinutesToWait 30 -DryRun
```

Then, after the yes, the same command with `-Approved`. Follow the job with `job` and `job-tasks` and report the result with the job ID.

A runbook declares its parameters in a comment block at the top of the script. `-Param Name=Value` fills them:

```powershell
<# Variables:
{
  "Greeting": { "Description": "Test text", "IsRequired": false, "DefaultValue": "default" }
}
#>
Write-Output ("Greeting=" + $Greeting)
```

## Where the output is

- **Runbook (`sa-run`):** `job-tasks <id>` shows the script's own output, in the "Wait for completion" task.
- **Host pool (`sa-run-hostpool`):** the job you get back only plans the work. Nerdio makes one child job per host, and the REST API returns 404 for those child jobs. Read them in the Nerdio Manager task log: with the [Nerdio MCP server](../../connections/nerdio-mcp.md), query `/jobs` for jobs created after the run, find the one whose `parentJobId` is your job ID, then read its tasks. The child job shows whether the script ran and succeeded. It does not show what the script printed.

## Report

Say what you read or changed, the scripted action ID, and the job ID. Quote the job output for any failure. Never report success from the request alone: check the job.

## Tested

Lab, 10 November 2026, against the live API spec:

- Reads: list, show and job output.
- Create: a `CustomScript` action with no `executionTimeout` sent. The API saved it and set the timeout to 30 itself. Job status `Completed`.
- A second create with the same name: the helper refused it before sending.
- Update: sent only the new script. The name, type, timeout, tags and description stayed the same. Job status `Completed`.
- Without `-Approved`, every change was refused (exit code 3).

- Run as a runbook: a `Variables` block and `-Param Greeting=...`. The job completed, and the output showed the value that was passed in.
- Run on one named session host (0 user sessions, no restart). The parent job and the per-host child job both completed, and the Custom Script Extension reported "Finished executing command". The child job was readable only through the MCP server.
