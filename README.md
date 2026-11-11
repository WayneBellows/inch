# Inch

<img src="assets/inch-loop.gif" alt="Inch, a small teal pixel-art window with a progress bar" width="200" align="right">

Inch is what I call the agent that runs my skills, prompts and rules for Azure Virtual Desktop and Nerdio Manager work. This repo is everything Inch is made of, shared so you can give the same things to your own agent.

Inch reads, checks and suggests. The admin decides. Every prompt and skill here has been run against a real environment (my lab) before it was added, and each one says what it needs, what you still check yourself, and what happened when I tested it, including when the first version got it wrong.

The progress bar is the point: one small fix at a time, written down so it is never made twice. It never reaches 100%.

## Use it as an agent

This folder is a whole agent. It is not tied to one AI vendor.

1. Copy or clone the folder to a new place: `git clone https://github.com/WayneBellows/inch.git my-inch`
2. Open your agent in that folder. It reads [AGENTS.md](AGENTS.md) (Codex, GitHub Copilot, Cursor and others), [CLAUDE.md](CLAUDE.md) (Claude Code) or [GEMINI.md](GEMINI.md) (Gemini CLI). The last two only point at `AGENTS.md`, so every agent gets the same instructions.
3. Connect what you need from [connections/](connections/README.md). For the Nerdio REST API, copy `.env.example` to `.env` and fill it in. `.env` is never committed.
4. Optional, Claude Code only: run `pwsh ./setup.ps1` so Claude Code also loads `skills/` as native skills.

Then ask it something, such as "which hosts in pool X were left running last week?".

## What is in here

| Path | What it is |
|---|---|
| [AGENTS.md](AGENTS.md) | Who Inch is, and where everything is. The agent reads this first |
| [RULES.md](RULES.md) | Mistakes written down once. Read every session. You can also copy them into your own agent |
| [skills/](skills/) | Repeatable jobs, in the open `SKILL.md` format |
| [prompts/](prompts/README.md) | One tested question each. Paste into any agent |
| [connections/](connections/README.md) | MCP servers and the REST API, with example config |

## The rules every prompt and skill follows

1. **Reads first, writes only on your yes.** Most skills only read. The few that can change Nerdio Manager (create, update or run a scripted action, add a shell app) show the exact change and wait for you to type yes. Nothing here deletes anything.
2. **Quote the evidence.** The agent quotes the log line or the query result it relied on, so you can check it.
3. **Say "the log does not show it".** A good prompt asks the agent to admit when the data does not explain something, instead of guessing.
4. **Ask about what did not happen.** A host that nothing ever tried to stop never appears in a list of stop actions. Ask for both.
5. **You make the call.** The agent reads; the admin decides.

## Prompts

| Prompt | Works with | Tested |
|---|---|---|
| [Why didn't this host stop?](prompts/why-didnt-this-host-stop.md) | Any agent that can read a file (a task log export) | 16 Oct 2026 |
| [Which hosts are still running, and why?](prompts/which-hosts-are-still-running.md) | An agent connected to the Nerdio Manager MCP server | 16 Oct 2026 |
| [Which counter is my Log Analytics bill?](prompts/which-counter-is-my-log-analytics-bill.md) | An agent connected to Microsoft's Azure MCP Server | 15 Oct 2026 |

## Skills

| Skill | What it does | Tested |
|---|---|---|
| [avd-hosts-left-running](skills/avd-hosts-left-running/SKILL.md) | Finds hosts that were started and never stopped, and quotes why | 16 Oct 2026 |
| [session-host-script-check](skills/session-host-script-check/SKILL.md) | Checks a PowerShell script will run on a 5.1 session host | 24 Oct 2026 |
| [nerdio-rest-api](skills/nerdio-rest-api/SKILL.md) | Reads from the Nerdio Manager REST API, and avoids its traps. Holds the `nme.ps1` helper | 5 Oct 2026, helper 10 Nov 2026 |
| [nme-scripted-actions](skills/nme-scripted-actions/SKILL.md) | Lists, reads, writes, uploads and runs scripted actions. Changes only on your yes | Reads, create, update, run 10 Nov 2026 |
| [nme-shell-apps](skills/nme-shell-apps/SKILL.md) | Lists and reads shell apps; adds an app or version on your yes | Reads, create, add version 10 Nov 2026 |

## Rules

See [RULES.md](RULES.md): agent safety, PowerShell on session hosts, Nerdio scripted actions, `az vm run-command`, and the Nerdio REST API.

## Connecting an agent

See [connections/](connections/README.md): the Nerdio Manager MCP server, Microsoft's Azure MCP Server and the Nerdio Manager REST API, with example config for each agent. The MCP servers run read-only, and none of them is tied to one AI vendor. I tested both MCP servers with an agent other than the one I normally use.

## Disclaimer

These are my own prompts, skills and rules, shared as they are, with no warranty. They are not an official Nerdio or Microsoft resource. Run them against a test environment first, check the agent's answer against the source, and follow your organisation's rules on AI tools and data.

## Licence

MIT. See [LICENSE](LICENSE).
