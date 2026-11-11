# Nerdio Manager MCP server

Read-only. Public preview from Nerdio Manager for Enterprise 8.2.

## What it gives Inch

- The live configuration of one Nerdio Manager install: host pools, session hosts, auto-scale, scripted actions, images and more.
- The task log, with each task's detail. This is better than a CSV export, which only has the task summary.
- The Nerdio Help Center articles, so answers come from the documentation, not from memory.

The agent sees only what your own Nerdio Manager role can see.

## Before you start

- A Nerdio Manager admin turns the MCP server on in Nerdio Manager.
- You need Node.js (for `npx`) and an Entra ID account with a Nerdio Manager role.

## Connect

Nerdio's bridge signs you in with your own Entra ID account. Replace the URL with your Nerdio Manager app URL.

```json
{
  "mcpServers": {
    "nerdio": {
      "command": "npx",
      "args": ["-y", "@nerdio-inc/mcp-bridge", "https://<your-nerdio-manager-app>/mcp"]
    }
  }
}
```

See [README.md](README.md) for where this goes in your agent.

## Check it works

Ask: "Using the Nerdio MCP server, read the root path and list the areas you can see." You should get a list of areas such as host pools and the knowledge base. A sign-in window opens the first time.

## Tested

Lab, 16 October 2026, with more than one agent.
