# CLAUDE.md — Architectural Understanding

## What I Am Building

**Persona** is a local-first, sovereign personal context portfolio that exposes
a user's identity and working context to any AI tool via the Model Context
Protocol (MCP). The user defines who they are once; every MCP-compatible AI
tool reads it automatically.

---

## Core Insight

The problem Persona solves: every AI tool starts from zero. The user repeats
themselves constantly — their role, preferences, working style, constraints.
Persona eliminates that by hosting a structured identity profile locally as
MCP resources that any compatible AI can read before the conversation starts.

---

## Architecture Decisions

### Data Model: Three-Ring Access Control

Profile data is organised into three sensitivity tiers (rings):

| Ring | Files | Access |
|------|-------|--------|
| 1 — Public | identity, skills, history, communication | All connected clients |
| 2 — Contextual | current-focus, goals, relationships, preferences | Allowlisted clients only |
| 3 — Sensitive | constraints | Explicitly ring-3 allowlisted clients only |
| NEVER | private.md | No client, ever, under any circumstance |

This is enforced in `SYSTEM/server/access_control.py` in code — not just
configuration. The `private.md` file is hardcoded as a blocked resource,
meaning even if `allowlist.yaml` is manually edited to request Ring 3 access,
the server will never serve `private.md`.

### Transport: stdio

The server uses `stdio` transport (not HTTP/SSE). This is the standard
transport for local MCP servers — the MCP client (Claude Desktop, Cursor, etc.)
launches the server as a subprocess and communicates over stdin/stdout. No
network port is opened, no authentication is needed, no firewall configuration
is required. This is essential for the "sovereign, local-first" design principle.

### Package Manager: uv

`uv` is used as the package manager for speed and reproducibility. The project
is defined in `pyproject.toml` with a `[project.scripts]` entry that makes
`persona` available as a CLI command after `uv tool install .` or `uv run persona`.

### Schema: YAML Frontmatter + Markdown

Each profile file uses YAML frontmatter (Jekyll/Hugo convention) with mandatory
fields: `ring` (1, 2, or 3), `last_updated` (ISO date), `version` (integer).
The body is structured markdown with defined H2 sections. This is human-editable
in any text editor and machine-parseable by the validator.

---

## Critical Constraints

1. **`private.md` is sacred** — blocked in code, not config. See `access_control.py`.
2. **`USER/` is sovereign** — installer never overwrites existing files.
3. **No network calls** — stdio transport only. Zero telemetry.
4. **MIT licensed** — no proprietary dependencies.

---

## Task Execution Plan

1. **Task 1** — Scaffold: pyproject.toml, directory structure, placeholder files
2. **Task 2** — Schema: YAML frontmatter spec, H2 section definitions, sample fixtures
3. **Task 3** — MCP Server: resource exposure, access control, audit log
4. **Task 4** — Validator CLI: `persona validate` with rich output
5. **Task 5** — Onboarding prompt: LLM-agnostic profile builder
6. **Task 6** — Installer: `INSTALL.sh` for macOS/Linux
7. **Task 7** — Claude Desktop integration guide
8. **Task 8** — Tests: pytest with ≥80% coverage
9. **Task 9** — README: non-technical audience

---

## File Ownership Model

- `SYSTEM/` — infrastructure code, versioned and upgradeable
- `USER/` — identity data, sovereign, never touched by the installer after creation
- `config/` — server configuration, editable by the user
- `logs/` — append-only audit log

---

## MCP SDK Notes

Using the official `mcp` Python package. Resources are exposed using the
`@server.list_resources()` and `@server.read_resource()` decorators. The
server runs via `mcp.run()` with `stdio` transport, which Claude Desktop and
other MCP clients launch as a subprocess.
