# Connecting Persona to Claude Desktop

This guide shows you how to connect Persona to Claude Desktop so that Claude
automatically knows who you are and how you work — before you say a word.

---

## Prerequisites

- Persona installed and running (`persona --help` should work in your terminal)
- Your profile built (`persona validate` should show all green)
- Claude Desktop installed (version 0.10 or later)

---

## Step 1 — Find your Claude Desktop config file

Claude Desktop reads its MCP server configuration from a JSON file on your machine.

| Platform | Location |
|----------|----------|
| macOS | `~/Library/Application Support/Claude/claude_desktop_config.json` |
| Windows | `%APPDATA%\Claude\claude_desktop_config.json` |
| Linux | `~/.config/Claude/claude_desktop_config.json` |

If the file does not exist, create it (Claude Desktop will create it on first
launch, but you can create it manually).

---

## Step 2 — Add Persona to the config

Open `claude_desktop_config.json` in a text editor. Add the `persona` entry
to the `mcpServers` section:

```json
{
  "mcpServers": {
    "persona": {
      "command": "persona",
      "args": ["serve"]
    }
  }
}
```

If you already have other MCP servers configured, add `persona` alongside them:

```json
{
  "mcpServers": {
    "your-existing-server": {
      "command": "...",
      "args": ["..."]
    },
    "persona": {
      "command": "persona",
      "args": ["serve"]
    }
  }
}
```

---

## Step 3 — Set the client name (optional but recommended)

Persona uses the `MCP_CLIENT_NAME` environment variable to identify the
connecting client and apply the correct access ring. To give Claude Desktop
access to Ring 2 (contextual) data, add the environment variable:

```json
{
  "mcpServers": {
    "persona": {
      "command": "persona",
      "args": ["serve"],
      "env": {
        "MCP_CLIENT_NAME": "claude-desktop"
      }
    }
  }
}
```

The name `claude-desktop` is pre-configured in `config/allowlist.yaml` with
Ring 2 access. This gives Claude Desktop access to your identity, skills,
history, communication style, current focus, goals, relationships, and
preferences — but not your sensitive constraints.

To grant Ring 3 access (constraints.md), add `claude-desktop` to your
allowlist with `ring: 3`:

```yaml
# config/allowlist.yaml
clients:
  claude-desktop:
    ring: 3
    description: "Full access — trusted primary assistant"
```

---

## Step 4 — Restart Claude Desktop

Fully quit Claude Desktop and relaunch it. It will start the Persona MCP
server automatically as a subprocess when it loads.

---

## Step 5 — Verify the connection

Open a new conversation in Claude Desktop and ask:

> "What do you know about me?"

If Persona is connected correctly, Claude will respond with information from
your Ring 1 profile (identity, skills, history, communication style). You
should see content that matches what you wrote in your `USER/` files.

You can also ask:

> "List the MCP resources available to you."

Claude should list the `persona://` resources it can see.

---

## Troubleshooting

### "persona: command not found"

The `persona` command is not in your PATH. Try:

```bash
# Find where uv installed persona
uv tool dir

# Add to PATH (replace with actual path)
export PATH="$HOME/.local/bin:$PATH"
```

Then use the full path in your config:

```json
{
  "mcpServers": {
    "persona": {
      "command": "/Users/yourname/.local/bin/persona",
      "args": ["serve"]
    }
  }
}
```

### Claude doesn't seem to know anything about me

Check that your profile files contain actual content (not just the template
placeholders). Run:

```bash
persona validate
```

All files should show `✓ valid`. If any show warnings or errors, edit the
relevant file in `~/.persona/USER/` and re-validate.

### I can see Ring 1 data but not Ring 2

Your client is not in the allowlist with Ring 2 access. Check:

```bash
cat ~/.persona/config/allowlist.yaml
```

Ensure `claude-desktop` is listed with `ring: 2` or higher, and that the
`MCP_CLIENT_NAME` environment variable in your config matches exactly.

### The server crashes on startup

Run the server manually to see the error:

```bash
persona serve --log-level DEBUG
```

Common causes:
- Missing `~/.persona/config/persona.yaml` — re-run `INSTALL.sh`
- Python version mismatch — ensure Python 3.11+ is installed
- Corrupted profile file — run `persona validate` to identify the issue

---

## Access rings reminder

| Ring | Files | Claude Desktop access |
|------|-------|----------------------|
| 1 | identity, skills, history, communication | Always (default) |
| 2 | current-focus, goals, relationships, preferences | With `ring: 2` in allowlist |
| 3 | constraints | With `ring: 3` in allowlist |
| Never | private.md | Never, under any circumstance |

---

## Other AI tools

Persona works with any MCP-compatible tool. For other integrations:

- **Cursor**: Use the same JSON config in Cursor's MCP settings. Set
  `MCP_CLIENT_NAME` to `cursor`. The default allowlist grants Cursor Ring 1.
- **ChatGPT**: Requires a local MCP bridge (ChatGPT does not natively support
  MCP yet). Community bridges exist — check the Persona README for links.
- **Other tools**: Any tool that supports MCP stdio transport should work.
  Consult the tool's documentation for where to add MCP server configuration.
