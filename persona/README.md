# Persona

**Tell every AI tool who you are — once.**

---

## The problem

Every time you open a new AI conversation, you start from zero. You explain
your role, your preferences, your constraints, your context — over and over.
Your AI tools know nothing about you unless you tell them, every single time.

Persona fixes that. You define who you are once, in plain language, stored
privately on your own machine. Every AI tool you connect reads it automatically.

---

## How it works

```
Your profile files          Persona MCP server          Your AI tools
(markdown on your           (runs locally,              (Claude, Cursor,
 machine)                    stdio transport)             ChatGPT bridge)
     │                            │                            │
     │  identity.md               │   persona://identity       │
     │  skills.md       ─────────▶│   persona://skills  ──────▶│
     │  goals.md                  │   persona://summary        │
     │  constraints.md            │                            │
     │  private.md ✗ BLOCKED      │                            │
```

Persona is a local server that speaks the **Model Context Protocol (MCP)** —
the open standard that lets AI tools request structured context from external
sources. When you open Claude Desktop, it asks Persona what it knows about
you. Persona reads your profile files and responds. Claude starts the
conversation already knowing your role, your preferences, and how you like
to work.

Your files never leave your machine. There is no cloud, no account, no
subscription. Just your words, stored where you put them.

---

## Quick start

**Step 1 — Install**

```bash
git clone https://github.com/[your-org]/persona
cd persona
./INSTALL.sh
```

**Step 2 — Build your profile**

Open `prompts/onboarding.md`, copy the prompt, and paste it into Claude,
ChatGPT, or any AI assistant. It will guide you through a 20-minute
conversation and produce your complete profile files. Save them to
`~/.persona/USER/`.

Then check everything looks right:

```bash
persona validate
```

**Step 3 — Connect your AI tool**

Add Persona to Claude Desktop (or any MCP-compatible tool):

```json
{
  "mcpServers": {
    "persona": {
      "command": "persona",
      "args": ["serve"],
      "env": { "MCP_CLIENT_NAME": "claude-desktop" }
    }
  }
}
```

Restart Claude Desktop. Ask: *"What do you know about me?"*

Full guide: [docs/integrations/claude-desktop.md](docs/integrations/claude-desktop.md)

---

## The three-ring model

Not everything you know about yourself should go to every AI tool. Persona
uses three rings to control what each tool can see.

```
┌─────────────────────────────────────────────────┐
│  Ring 3 — Sensitive                             │
│  constraints.md                                 │
│  ┌───────────────────────────────────────────┐  │
│  │  Ring 2 — Contextual                      │  │
│  │  current-focus · goals · relationships    │  │
│  │  preferences                              │  │
│  │  ┌─────────────────────────────────────┐  │  │
│  │  │  Ring 1 — Public identity           │  │  │
│  │  │  identity · skills · history        │  │  │
│  │  │  communication · summary            │  │  │
│  │  └─────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────┘  │
│                                                 │
│  private.md — NEVER shared with any tool        │
└─────────────────────────────────────────────────┘
```

| Ring | What it contains | Who gets it |
|------|-----------------|-------------|
| 1 | Who you are, what you know, your communication style | All connected tools |
| 2 | Current focus, goals, relationships, preferences | Tools you explicitly trust |
| 3 | Hard limits, sensitivities, what to never assume | Tools you fully authorise |
| Never | private.md — your personal notes | Nobody. Ever. Hardcoded. |

You control which tools get which ring in `~/.persona/config/allowlist.yaml`.

---

## Your profile files

| File | Ring | What it contains |
|------|------|-----------------|
| `identity.md` | 1 | Your name, role, background |
| `skills.md` | 1 | Your expertise and tools |
| `history.md` | 1 | Your career and credentials |
| `communication.md` | 1 | How you like AI to talk to you |
| `current-focus.md` | 2 | What you're working on right now |
| `goals.md` | 2 | What you're working toward |
| `relationships.md` | 2 | Key people in your world |
| `preferences.md` | 2 | How you work and your opinions |
| `constraints.md` | 3 | Hard limits and sensitivities |
| `private.md` | Never | Your private notes — never served |

---

## CLI reference

```bash
persona serve              # Start the MCP server
persona validate           # Check your profile files
persona validate --fix     # Show fix suggestions
persona --help             # Full help
```

---

## Integrations

- [Claude Desktop](docs/integrations/claude-desktop.md)
- Cursor (see Claude Desktop guide — same process)
- Other MCP-compatible tools — any tool supporting MCP stdio transport works

---

## Design principles

1. **Sovereign** — all data stays on your machine
2. **Vendor-neutral** — works with any MCP-compatible AI tool
3. **Non-technical friendly** — a non-developer can install and use this
4. **MIT licensed** — fully open source, no proprietary dependencies
5. **No network** — stdio transport only; nothing leaves your machine

---

## Contributing

Persona is early-stage and welcomes contributions. The most valuable help right now:

- **Testing on different platforms** — macOS, Linux, WSL
- **Testing with different AI tools** — Cursor, other MCP clients
- **Improving the onboarding prompt** — making it work better across different AI models
- **Documentation** — especially non-technical user guides

To contribute:

1. Fork the repository
2. Create a branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Run the tests: `uv run pytest`
5. Open a pull request

Please read `CLAUDE.md` before making architectural changes — it documents the
decisions that must not be reversed without discussion.

---

## Acknowledgements

Inspired by [danielmiessler/Personal_AI_Infrastructure](https://github.com/danielmiessler/Personal_AI_Infrastructure).
Built on the [Model Context Protocol](https://modelcontextprotocol.io) by Anthropic.

---

## License

MIT — see [LICENSE](LICENSE).

---

*Persona is submitted to the NLnet Foundation for open internet infrastructure funding.*
