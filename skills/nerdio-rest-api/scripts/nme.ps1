#Requires -Version 7
<#
.SYNOPSIS
  Inch helper for the Nerdio Manager for Enterprise REST API.

.DESCRIPTION
  One script for every Nerdio REST call Inch makes. Reads run straight away.
  Anything that changes Nerdio Manager refuses to run without -Approved.
  The agent adds -Approved only after the admin has seen the change and typed yes.
  Use -DryRun to print the request without sending it.

  Secrets come from environment variables, or from a .env file in the agent's
  root folder (three levels up from this script). Values are never printed.

.EXAMPLE
  pwsh nme.ps1 check
  pwsh nme.ps1 get /api/v1/arm/account
  pwsh nme.ps1 sa-list "login"
  pwsh nme.ps1 sa-show 102
  pwsh nme.ps1 sa-create .\Fix-Thing.ps1 -Environment CustomScript -Mode Individual -DryRun
  pwsh nme.ps1 sa-update 102 .\Fix-Thing.ps1 -Approved
  pwsh nme.ps1 sa-run 102 -Subscription <sub-id> -Param Name=Value -Approved
  pwsh nme.ps1 sa-run-hostpool 102 -Subscription <sub> -ResourceGroup <rg> -HostPool <pool> -Hosts host1.contoso.local -Approved
  pwsh nme.ps1 job 4711
  pwsh nme.ps1 job-tasks 4711
  pwsh nme.ps1 app-list
  pwsh nme.ps1 app-show 12
  pwsh nme.ps1 app-versions 12
  pwsh nme.ps1 app-create .\app.json -DryRun
  pwsh nme.ps1 app-add-version 12 .\version.json -Approved
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$Command = 'help',
    [Parameter(Position = 1)][string]$Arg1,
    [Parameter(Position = 2)][string]$Arg2,

    # Scripted action fields
    [string]$Name,
    [string]$Description,
    [ValidateSet('CustomScript', 'AzureAutomation')][string]$Environment = 'CustomScript',
    [ValidateSet('Combined', 'Individual', 'IndividualWithRestart')][string]$Mode = 'Individual',
    [int]$Timeout = 0,
    [string[]]$Tags = @(),

    # Running a scripted action
    [string]$Subscription,
    [string]$ResourceGroup,
    [string]$HostPool,
    [string[]]$Hosts,
    [string[]]$Param = @(),
    [int]$MinutesToWait = 30,
    [switch]$RestartVms,

    # Safety
    [switch]$Approved,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$Vars = 'NME_BASE_URL', 'NME_TOKEN_URL', 'NME_CLIENT_ID', 'NME_CLIENT_SECRET', 'NME_SCOPE'

function Import-DotEnv {
    $root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..') -ErrorAction SilentlyContinue
    if (-not $root) { return }
    $file = Join-Path $root '.env'
    if (-not (Test-Path -LiteralPath $file)) { return }
    foreach ($line in Get-Content -LiteralPath $file) {
        if ($line -match '^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$') {
            $key = $Matches[1]; $val = $Matches[2].Trim('"', "'")
            if ($val -and -not [Environment]::GetEnvironmentVariable($key)) {
                [Environment]::SetEnvironmentVariable($key, $val)
            }
        }
    }
}

function Assert-Vars {
    $missing = @($Vars | Where-Object { -not [Environment]::GetEnvironmentVariable($_) })
    if ($missing.Count) { throw "Missing: $($missing -join ', '). See connections/nerdio-rest-api.md." }
}

$script:Token = $null
function Get-Headers {
    if (-not $script:Token) {
        Assert-Vars
        $script:Token = (Invoke-RestMethod -Uri $env:NME_TOKEN_URL -Method POST -ContentType 'application/x-www-form-urlencoded' -Body @{
                grant_type    = 'client_credentials'
                client_id     = $env:NME_CLIENT_ID
                client_secret = $env:NME_CLIENT_SECRET
                scope         = $env:NME_SCOPE
            }).access_token
    }
    @{ Authorization = "Bearer $($script:Token)" }
}

function Invoke-Nme([string]$Method, [string]$Path, $Body) {
    $uri = $env:NME_BASE_URL.TrimEnd('/') + '/' + $Path.TrimStart('/')
    $args2 = @{ Uri = $uri; Method = $Method; Headers = (Get-Headers) }
    if ($null -ne $Body) {
        $args2.Body = ($Body | ConvertTo-Json -Depth 20)
        $args2.ContentType = 'application/json'
    }
    # Assign first: Invoke-RestMethod writes a JSON array as ONE object, and
    # returning the variable unrolls it so @() and Where-Object see each item.
    try { $result = Invoke-RestMethod @args2; return $result }
    catch {
        $code = $_.Exception.Response.StatusCode.value__
        $detail = $_.ErrorDetails.Message
        throw "$Method $Path failed: HTTP $code $detail"
    }
}

# Every change goes through here. No -Approved, no change.
function Invoke-Change([string]$What, [string]$Method, [string]$Path, $Body) {
    Write-Output "CHANGE: $What"
    Write-Output "REQUEST: $Method $Path"
    if ($null -ne $Body) {
        $shown = $Body | ConvertTo-Json -Depth 20
        if ($shown.Length -gt 3000) { $shown = $shown.Substring(0, 3000) + "`n... (cut for display)" }
        Write-Output $shown
    }
    if ($DryRun) { Write-Output 'DRY RUN: nothing was sent.'; return }
    if (-not $Approved) {
        Write-Output 'REFUSED: this changes Nerdio Manager. Show the admin the change above. Run again with -Approved only after they type yes.'
        exit 3
    }
    Invoke-Nme $Method $Path $Body | ConvertTo-Json -Depth 20
}

function Get-ScriptedAction([int]$Id) {
    # There is no GET by id (it returns 405). List, then filter.
    $sa = @(Invoke-Nme GET '/api/v1/scripted-actions') | Where-Object { $_.id -eq $Id }
    if (-not $sa) { throw "No scripted action with id $Id." }
    $sa
}

function Read-ScriptFile([string]$Path) {
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { throw "Script file not found: $Path" }
    $text = Get-Content -LiteralPath $Path -Raw
    if ($text -match '@"|"@|@''|''@') {
        Write-Warning 'The script has a here-string. Nerdio Manager wraps scripts and a here-string can break them (RULES.md section 3).'
    }
    $text
}

Import-DotEnv

switch ($Command) {
    'help' { Get-Help $PSCommandPath -Detailed; break }

    'check' {
        foreach ($v in $Vars) {
            $val = [Environment]::GetEnvironmentVariable($v)
            if ($val) { "{0,-18} set (len {1})" -f $v, $val.Length } else { "{0,-18} MISSING" -f $v }
        }
        Assert-Vars
        $null = Get-Headers
        'Token: OK'
        $n = @(Invoke-Nme GET '/api/v1/scripted-actions').Count
        "Read: $n scripted actions"
        'OK: token and read work'
        break
    }

    'get' {
        if (-not $Arg1) { throw 'Usage: get <api path>' }
        ConvertTo-Json -Depth 20 -InputObject (Invoke-Nme GET $Arg1)
        break
    }

    # ---------- Scripted actions ----------
    'sa-list' {
        $all = @(Invoke-Nme GET '/api/v1/scripted-actions')
        if ($Arg1) { $all = @($all | Where-Object { $_.name -like "*$Arg1*" }) }
        $all | Sort-Object name | Select-Object id, name, executionEnvironment, executionMode, executionTimeout, @{ n = 'tags'; e = { $_.tags -join ',' } } |
            Format-Table -AutoSize | Out-String -Width 220
        break
    }

    'sa-show' {
        Get-ScriptedAction ([int]$Arg1) | ConvertTo-Json -Depth 10
        break
    }

    'sa-create' {
        $script = Read-ScriptFile $Arg1
        $n = if ($Name) { $Name } else { [IO.Path]::GetFileNameWithoutExtension($Arg1) }
        $same = @(Invoke-Nme GET '/api/v1/scripted-actions') | Where-Object { $_.name -eq $n }
        if ($same) { throw "A scripted action called '$n' already exists (id $($same[0].id)). Ask the admin: update it with sa-update, or use -Name for a new name." }
        $body = [ordered]@{
            name                 = $n
            description          = $(if ($Description) { $Description } else { '' })
            script               = $script
            executionEnvironment = $Environment
            executionMode        = $Mode
            tags                 = $Tags
        }
        # executionTimeout is optional in the spec. Send it only for a runbook run per host.
        if ($Environment -eq 'AzureAutomation' -and $Mode -eq 'Individual') {
            $body.executionTimeout = $(if ($Timeout) { $Timeout } else { 30 })
        }
        Invoke-Change "Create scripted action '$n' ($Environment, $Mode)" POST '/api/v1/scripted-actions' $body
        break
    }

    'sa-update' {
        $current = Get-ScriptedAction ([int]$Arg1)
        $script = Read-ScriptFile $Arg2
        # Send only the script. Other fields stay as they are.
        $body = [ordered]@{ script = $script }
        Invoke-Change "Replace the script of '$($current.name)' (id $($current.id))" PATCH "/api/v1/scripted-actions/$($current.id)" $body
        break
    }

    'sa-run' {
        if (-not $Subscription) { throw 'sa-run needs -Subscription (the Azure subscription the runbook runs against).' }
        $current = Get-ScriptedAction ([int]$Arg1)
        if ($current.executionEnvironment -ne 'AzureAutomation') { throw "'$($current.name)' is a $($current.executionEnvironment) action. Use sa-run-hostpool." }
        if ($MinutesToWait -lt 10 -or $MinutesToWait -gt 180) { throw '-MinutesToWait must be 10 to 180.' }
        $bind = [ordered]@{}
        foreach ($p in $Param) {
            $k, $v = $p -split '=', 2
            $bind[$k] = @{ value = $v; isSecure = $false }
        }
        $body = [ordered]@{ subscriptionId = $Subscription; minutesToWait = $MinutesToWait; paramsBindings = $bind }
        Invoke-Change "Run runbook '$($current.name)' (id $($current.id)) in subscription $Subscription" POST "/api/v1/scripted-actions/$($current.id)/execution" $body
        break
    }

    'sa-run-hostpool' {
        if (-not ($Subscription -and $ResourceGroup -and $HostPool)) { throw 'sa-run-hostpool needs -Subscription, -ResourceGroup and -HostPool.' }
        if (-not $Hosts) { throw 'Name the hosts with -Hosts (FQDNs). Running on a whole pool must be a separate, explicit admin decision.' }
        $current = Get-ScriptedAction ([int]$Arg1)
        $body = [ordered]@{
            jobPayload = [ordered]@{
                config        = [ordered]@{
                    activeDirectoryId = $null
                    scriptedActions   = @([ordered]@{ type = 'Action'; id = $current.id; params = @{}; groupParams = @{} })
                }
                bulkJobParams = [ordered]@{
                    restartVms                 = [bool]$RestartVms
                    excludeNotRunning          = $true
                    sessionHostsToProcessNames = $Hosts
                    enableDrainMode            = $false
                    taskParallelism            = 1
                    countFailedTaskToStopWork  = 1
                    minutesBeforeRemove        = $null
                    message                    = $null
                }
            }
            failurePolicy = $null
        }
        $path = "/api/v1/arm/hostpool/$Subscription/$ResourceGroup/$HostPool/script-execution"
        Invoke-Change "Run '$($current.name)' on $($Hosts -join ', ') in $HostPool (restart: $([bool]$RestartVms))" POST $path $body
        break
    }

    'job' { Invoke-Nme GET "/api/v1/job/$Arg1" | ConvertTo-Json -Depth 10; break }

    'job-tasks' {
        @(Invoke-Nme GET "/api/v1/job/$Arg1/tasks") | ForEach-Object {
            "--- $($_.name) [$($_.status)]"
            $_.resultPlain
        }
        break
    }

    # ---------- Shell apps ----------
    'app-list' {
        (Invoke-Nme GET '/api/v1/shell-app').items | Sort-Object name |
            Select-Object id, name, publisher, isPublic, createdAt | Format-Table -AutoSize | Out-String -Width 220
        break
    }

    'app-show' { Invoke-Nme GET "/api/v1/shell-app/$Arg1" | ConvertTo-Json -Depth 10; break }

    'app-versions' {
        (Invoke-Nme GET "/api/v1/shell-app/$Arg1/version").items |
            Select-Object name, isPreview, createdAt, @{ n = 'source'; e = { $_.file.sourceUrl } } | Format-Table -AutoSize | Out-String -Width 220
        break
    }

    'app-create' {
        if (-not $Arg1 -or -not (Test-Path -LiteralPath $Arg1)) { throw 'Usage: app-create <app.json>. See skills/nme-shell-apps/SKILL.md for the shape.' }
        $body = Get-Content -LiteralPath $Arg1 -Raw | ConvertFrom-Json
        Invoke-Change "Create shell app '$($body.name)'" POST '/api/v1/shell-app' $body
        break
    }

    'app-add-version' {
        if (-not $Arg2 -or -not (Test-Path -LiteralPath $Arg2)) { throw 'Usage: app-add-version <app id> <version.json>' }
        $body = Get-Content -LiteralPath $Arg2 -Raw | ConvertFrom-Json
        Invoke-Change "Add version '$($body.name)' to shell app $Arg1" POST "/api/v1/shell-app/$Arg1/version" $body
        break
    }

    default { throw "Unknown command '$Command'. Run: pwsh nme.ps1 help" }
}
