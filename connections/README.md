# Connections

A connection is how Inch reaches another system. There are two kinds:

- **MCP server.** A set of tools the agent can call. MCP (Model Context Protocol) is an open standard, so the same server works with Claude Code, Codex, GitHub Copilot, Cursor, Gemini CLI and others. Only the config file is different.
- **REST API.** Inch calls the API with a helper script. The secrets go in a `.env` file in the root of this folder. `.env` is in `.gitignore`, so it never gets committed.

| Connection | File | What Inch can do with it |
|---|---|---|
| Nerdio Manager MCP server | [nerdio-mcp.md](nerdio-mcp.md) | Read config, task log and the Nerdio Help Center. Read-only |
| Azure MCP Server | [azure-mcp.md](azure-mcp.md) | Read Azure resources, Log Analytics and cost. Start it read-only |
| Nerdio Manager REST API | [nerdio-rest-api.md](nerdio-rest-api.md) | Read anything the API exposes. Write scripted actions and shell apps, after the admin says yes |

## Add a connection to your agent

All the example files use the common `mcpServers` shape: [mcp.example.json](mcp.example.json). Put the entries where your agent looks for them:

| Agent | Where MCP servers go |
|---|---|
| Claude Code | `.mcp.json` in this folder, or `claude mcp add` |
| Codex CLI | `~/.codex/config.toml`, as `[mcp_servers.<name>]` tables |
| GitHub Copilot in VS Code | `.vscode/mcp.json`, under `servers` instead of `mcpServers` |
| Cursor | `.cursor/mcp.json` |
| Gemini CLI | `.gemini/settings.json` |

Field names and file places change between versions. Check your agent's own documentation if one of these does not work.

## Add a new connection

1. Make `<name>.md` in this folder. Say what it is, what it needs, how to connect, and how to check it works.
2. If it needs secrets, add the variable **names** (never the values) to [../.env.example](../.env.example).
3. Add one row to the table above and to the Connections table in [../AGENTS.md](../AGENTS.md).
4. Say whether it is read-only. If it can change things, the skill that uses it must ask the admin first ([RULES.md](../RULES.md), rule 2).
