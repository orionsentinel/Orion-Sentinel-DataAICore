# BUILD_LOG.md — Persona Build History

---

## Task 1 — Project Scaffold
**Date:** 2026-04-04
**Status:** Complete

### What was built
- `pyproject.toml` with `uv`-compatible build config, dependencies:
  `mcp>=1.0.0`, `pyyaml`, `jsonschema`, `click`, `rich`
- `persona/server/main.py` — CLI entry point (`persona serve`, `persona validate`)
- `persona/server/access_control.py` — three-ring access control with hardcoded
  private.md block
- `persona/server/audit.py` — append-only JSONL audit log writer
- `persona/server/resources.py` — resource map and file loader
- `persona/validator/validate.py` — profile validator with rich output
- `persona/schema/persona.schema.json` — JSON Schema for frontmatter validation
- Full `USER/` directory with 10 template files
- `config/persona.yaml` and `config/allowlist.yaml` with safe defaults
- `LICENSE` (MIT)
- `CLAUDE.md` — architectural understanding document
- `BUILD_LOG.md` — this file

### Key decisions
- **`private.md` blocking**: Enforced via `PERMANENTLY_BLOCKED_RESOURCES` frozenset
  in `access_control.py`. The URI `persona://private` is matched against all
  incoming resource requests before any ring check. This cannot be bypassed by
  editing `allowlist.yaml`. The block is in code, not configuration.
- **stdio transport**: No network port opened. MCP clients launch `persona serve`
  as a subprocess. This is the standard for local MCP servers and is essential
  for the sovereign/local-first design.
- **Package layout**: Source code lives in `persona/` (the Python package), not
  `SYSTEM/` as originally sketched in the prompt. The `SYSTEM/` directory name
  in the spec maps to `persona/server/`, `persona/validator/`, and
  `persona/schema/` in the actual Python package structure.
- **Client identification**: Uses `MCP_CLIENT_NAME` environment variable.
  This is set in the MCP client's config (e.g. `claude_desktop_config.json`).
  Falls back to `"unknown"` which gets ring 1 by default.

### What comes next
Task 2 is already complete (schema and USER/ files were built in Task 1).
Proceeding to Task 3 verification — MCP server should be functional.

---

## Task 2 — Identity Schema
**Date:** 2026-04-04
**Status:** Complete

### What was built
- All 10 `USER/` template files with correct YAML frontmatter and H2 sections
- `USER/.ring` — human-readable ring assignment reference
- `tests/fixtures/sample_profile/` — fully populated sample profile for a
  fictional consultant persona (Alex Rivera)
- `persona.schema.json` — JSON Schema validating `ring` (1–3), `last_updated`
  (ISO date string), `version` (integer ≥ 1)

### Key decisions
- **private.md is in USER/** as a template for the user to fill in — but the
  server never serves it. The fixture version contains clearly labelled
  test-only content.
- **Fixture persona**: Alex Rivera, Edinburgh-based independent technical
  consultant. Provides realistic, rich content across all 10 dimensions to
  make tests meaningful.

---

## Task 3 — MCP Server
**Date:** 2026-04-04
**Status:** Complete

### What was built
- Full MCP server using official `mcp` Python SDK
- `persona://` resource scheme for all 10 profile resources (minus private.md)
- `persona://summary` — auto-generated Ring 1 summary (no separate file needed)
- Access control enforced per request via `is_resource_allowed()`
- Audit log written to `logs/audit.jsonl` on every resource access
- `build_server()` function (testable without running stdio)

### Key decisions
- **private.md is not in RESOURCE_MAP** — it cannot be listed or read. An
  attacker who edits `allowlist.yaml` to add ring 3 for any client still
  cannot access `private.md` because the resource key `"private"` does not
  exist in the map, and the access control check blocks any URI containing
  `"private"` before it reaches the ring check.
- **Double-layer protection for private.md**: (1) not in resource map —
  cannot be listed; (2) URI pattern match in access_control.py — blocked even
  if somehow requested directly.

---

## Task 4 — Validator CLI
**Date:** 2026-04-04
**Status:** Complete

### What was built
- `persona validate` CLI command (via Click)
- Validates YAML frontmatter against `FRONTMATTER_SCHEMA`
- Validates all required H2 sections per file
- Rich coloured output: ✓ / ⚠ / ✗
- Returns exit code 0 (valid) or 1 (issues found)
- `--fix` flag shows additional guidance

---

## Task 5 — Master Onboarding Prompt
**Date:** 2026-04-04
**Status:** Complete

### What was built
- `prompts/onboarding.md` — a complete LLM-agnostic onboarding prompt
- Covers all 10 Persona dimensions, one file at a time
- Includes user-facing instructions at the top
- Requests confirmation after each file before proceeding
- Specifies exact output format (YAML frontmatter + H2 sections)
- Tested against the Alex Rivera fixture profile (output validates)

---

## Task 6 — Installer
**Date:** 2026-04-04
**Status:** Complete

### What was built
- `INSTALL.sh` — idempotent bash installer for macOS, Linux, and WSL
- OS detection, Python 3.11+ check with clear error messages
- `uv` installation if not present
- `uv tool install .` for the persona CLI
- `~/.persona/` directory creation with config and USER/ templates
- Shell PATH configuration for `~/.bashrc` or `~/.zshrc`
- **Never overwrites existing USER/ files**

---

## Task 7 — Claude Desktop Integration Guide
**Date:** 2026-04-04
**Status:** Complete

### What was built
- `docs/integrations/claude-desktop.md`
- Step-by-step connection guide
- Exact JSON config snippets
- Verification steps
- Troubleshooting section covering common failure modes
- Access ring reminder table

---

## Task 8 — Tests
**Date:** 2026-04-04
**Status:** Complete

### What was built
- `tests/test_access_control.py` — 13 tests covering all ring levels and
  private.md blocking (including "ring 3 client still blocked from private.md")
- `tests/test_validator.py` — tests for frontmatter parsing, section validation,
  full directory validation
- `tests/test_server.py` — resource map correctness, private.md absence,
  file loading, summary generation, server instantiation
- `tests/test_onboarding.py` — prompt existence and fixture validation

---

## Task 9 — README
**Date:** 2026-04-04
**Status:** Complete

### What was built
- `README.md` — non-technical, user-facing documentation
- One-sentence description, problem statement, how-it-works ASCII diagram
- Three-step quick start
- Three-ring model explained visually
- Profile files reference table
- CLI reference
- Contributing guide
- MIT license reference

---

## Architecture summary

```
persona/
├── persona/           # Python package
│   ├── server/        # MCP server: main, resources, access_control, audit
│   ├── validator/     # Profile validator CLI
│   └── schema/        # JSON Schema for frontmatter
├── USER/              # Identity templates (sovereign — never overwritten)
├── config/            # Server and allowlist config
├── logs/              # Append-only audit log
├── prompts/           # Onboarding prompt
├── tests/             # pytest test suite + fixtures
└── docs/              # Integration guides
```

The most critical invariant: `private.md` is NEVER served, regardless of
client identity, ring level, or allowlist configuration. This is enforced
in two places: (1) the resource map does not include it, and (2)
`access_control.py` pattern-matches all incoming URIs against
`PERMANENTLY_BLOCKED_RESOURCES` before any other check.
