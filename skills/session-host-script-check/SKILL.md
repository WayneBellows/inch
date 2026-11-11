---
name: session-host-script-check
description: Check a PowerShell script before it runs on an AVD session host (Nerdio scripted action, az vm run-command, scheduled task). Session hosts run Windows PowerShell 5.1, so PowerShell 7 syntax fails there. Runs the 5.1 parser, then looks for traps the parser cannot see. Read-only. Use before deploying any script to a session host.
---

# Will this run on a session host?

Session hosts run **Windows PowerShell 5.1**, not PowerShell 7. A script that works on an admin laptop with PowerShell 7 can fail on the host at parse time with exit code 1 and no useful message. This skill checks the script first. It never changes the script without asking.

## Step 1: run the real 5.1 parser

On a Windows machine, with `powershell.exe` (5.1), not `pwsh`:

```powershell
powershell.exe -NoProfile -Command "$e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile('C:\path\script.ps1',[ref]$null,[ref]$e); $e | ForEach-Object { '{0}:{1} {2}' -f $_.Extent.StartLineNumber, $_.Extent.StartColumnNumber, $_.Message }"
```

No output means it parses. This catches the PowerShell 7 shortcuts, which are parse errors on 5.1:

| PowerShell 7 | Use on 5.1 |
|---|---|
| `$a ?? $b` | `if ($a) { $a } else { $b }` |
| `$c ? $a : $b` | `if ($c) { $a } else { $b }` |
| `cmd1 && cmd2`, `cmd1 \|\| cmd2` | `cmd1; if ($?) { cmd2 }` |

## Step 2: look for what the parser misses

These parse cleanly and fail only when the script runs. They behave the same in 5.1 and 7, so they are PowerShell traps, not 5.1 traps.

| Look for | What happens | Fix |
|---|---|---|
| `SomeFunc (if ($x) { 'a' } else { 'b' })` - a bare `(if` as an argument | "The term 'if' is not recognized" | Assign to a variable first, or use `$(if ...)` |
| `@($list)` inside an `[ordered]@{}` when `$list` is an empty `List[object]` | "Argument types do not match" | `$list.ToArray()` |
| `$o?.Name` | No error: it reads a variable called `o?` and returns nothing | A plain `if`. `Set-StrictMode -Version Latest` turns it into an error |

A pattern for the first one that does not also flag the valid `$(if ...)`: `(?<!\$)\(\s*if \(`

## Step 3: for Nerdio scripted actions

See section 3 of [RULES.md](../../RULES.md): no here-strings and no backtick-escaped quotes.

## Report

List each finding with line number, what will happen on the host, and the fix. If nothing is found, say which checks ran. The admin decides whether to change the script.

## Tested

All traps above re-tested 24 October 2026 on Windows PowerShell 5.1.26100 and PowerShell 7.6.8.
