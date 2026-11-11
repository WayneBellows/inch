# Azure MCP Server (Microsoft)

Microsoft's MCP server for Azure. It runs on your machine and signs in as you through the Azure CLI. Start it read-only.

## What it gives Inch

Reads across Azure: resources, Log Analytics queries, Monitor and more. Inch uses it for questions such as "which counter is my Log Analytics bill?".

## Before you start

- Node.js (for `npx`).
- The Azure CLI, signed in: `az login`. The agent can see only what your account can see.

## Connect

```json
{
  "mcpServers": {
    "azure": {
      "command": "npx",
      "args": ["-y", "@azure/mcp@latest", "server", "start", "--read-only"]
    }
  }
}
```

Keep `--read-only`. Without it the server can change resources.

Docs: https://learn.microsoft.com/en-us/azure/developer/azure-mcp-server/overview

## Check it works

Ask: "Using the Azure MCP server, list my subscriptions." You should see the same list as `az account list --output table`.

## Tested

Lab, 15 October 2026.
