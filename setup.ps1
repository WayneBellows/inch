<#
.SYNOPSIS
  Optional. Lets Claude Code find the skills in skills/ as native skills.

.DESCRIPTION
  Every agent can use Inch without this: AGENTS.md lists the skills and says
  when to read each SKILL.md. Claude Code can also load skills on its own from
  .claude/skills. This script points .claude/skills at skills/, so there is one
  copy and nothing to keep in step.

  On Windows it makes a directory junction (no admin rights needed).
  On macOS and Linux it makes a symbolic link.
  It also copies .env.example to .env if there is no .env yet.
#>
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$link = Join-Path $root '.claude\skills'
$target = Join-Path $root 'skills'

New-Item -ItemType Directory -Force -Path (Join-Path $root '.claude') | Out-Null

if (Test-Path -LiteralPath $link) {
    Write-Output ".claude/skills is already there. Nothing to do."
}
elseif ($IsLinux -or $IsMacOS) {
    New-Item -ItemType SymbolicLink -Path $link -Target $target | Out-Null
    Write-Output "Linked .claude/skills -> skills/"
}
else {
    New-Item -ItemType Junction -Path $link -Target $target | Out-Null
    Write-Output "Linked .claude/skills -> skills/ (junction)"
}

$envFile = Join-Path $root '.env'
if (-not (Test-Path -LiteralPath $envFile)) {
    Copy-Item -LiteralPath (Join-Path $root '.env.example') -Destination $envFile
    Write-Output "Made .env from .env.example. Fill in the values (see connections/nerdio-rest-api.md)."
}
