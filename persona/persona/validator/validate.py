"""Schema validator for Persona profile files.

Validates YAML frontmatter and required H2 sections for each USER/ file.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

import jsonschema
import yaml
from rich.console import Console
from rich.table import Table

console = Console()

# Required H2 sections per file
REQUIRED_SECTIONS: dict[str, list[str]] = {
    "identity.md": [
        "## Name",
        "## Role",
        "## Background",
        "## What I do",
        "## How I describe myself to AI",
    ],
    "skills.md": [
        "## Core expertise",
        "## Professional skills",
        "## Tools and technologies",
        "## What I'm learning",
    ],
    "history.md": [
        "## Career summary",
        "## Key experiences",
        "## Education and credentials",
        "## Notable projects",
    ],
    "communication.md": [
        "## Preferred tone",
        "## Response style",
        "## What I find unhelpful",
        "## Language preferences",
    ],
    "current-focus.md": [
        "## Current role or situation",
        "## Active projects",
        "## Immediate priorities",
        "## What I need AI help with most",
    ],
    "goals.md": [
        "## Short-term goals (this quarter)",
        "## Medium-term goals (this year)",
        "## Long-term vision",
        "## What success looks like",
    ],
    "relationships.md": [
        "## Key collaborators",
        "## Clients or stakeholders",
        "## Mentors and advisors",
        "## Community memberships",
    ],
    "preferences.md": [
        "## Working style",
        "## Decision-making approach",
        "## Tools I use",
        "## Strong opinions",
    ],
    "constraints.md": [
        "## Hard limits",
        "## Sensitivities",
        "## Things AI should never assume about me",
        "## Context that requires caution",
    ],
    "private.md": [
        "## Personal notes",
        "## Confidential context",
    ],
}

FRONTMATTER_SCHEMA = {
    "type": "object",
    "required": ["ring", "last_updated", "version"],
    "properties": {
        "ring": {"type": "integer", "minimum": 1, "maximum": 3},
        "last_updated": {"type": "string"},
        "version": {"type": "integer", "minimum": 1},
    },
    "additionalProperties": True,
}


def _parse_frontmatter(content: str) -> tuple[dict[str, Any] | None, str]:
    """Split YAML frontmatter from markdown body."""
    if not content.startswith("---"):
        return None, content
    parts = content.split("---", 2)
    if len(parts) < 3:
        return None, content
    try:
        fm = yaml.safe_load(parts[1]) or {}
    except yaml.YAMLError:
        return None, content
    return fm, parts[2]


def _validate_file(filepath: Path) -> list[str]:
    """Return list of error strings for one profile file."""
    errors: list[str] = []
    content = filepath.read_text(encoding="utf-8")
    frontmatter, body = _parse_frontmatter(content)

    if frontmatter is None:
        errors.append("missing YAML frontmatter block (must start with ---)")
        return errors

    try:
        jsonschema.validate(frontmatter, FRONTMATTER_SCHEMA)
    except jsonschema.ValidationError as exc:
        errors.append(f"frontmatter error: {exc.message}")

    filename = filepath.name
    required = REQUIRED_SECTIONS.get(filename, [])
    for section in required:
        # Check for exact match at line start (case-insensitive)
        if not any(
            line.strip().lower() == section.lower()
            for line in body.splitlines()
        ):
            errors.append(f"missing section: {section}")

    return errors


def run_validation(user_dir: Path, show_fix: bool = False) -> int:
    """Validate all profile files in user_dir. Returns exit code (0/1)."""
    if not user_dir.exists():
        console.print(f"[red]Directory not found: {user_dir}[/red]")
        return 1

    all_files = sorted(REQUIRED_SECTIONS.keys())
    total_issues = 0

    table = Table(show_header=False, box=None, padding=(0, 1))

    for filename in all_files:
        filepath = user_dir / filename
        if not filepath.exists():
            table.add_row(
                "[yellow]⚠[/yellow]",
                f"[bold]{filename}[/bold]",
                "[yellow]file not found[/yellow]",
            )
            total_issues += 1
            continue

        errors = _validate_file(filepath)

        if not errors:
            # Read ring from frontmatter for display
            content = filepath.read_text(encoding="utf-8")
            fm, _ = _parse_frontmatter(content)
            ring = fm.get("ring", "?") if fm else "?"
            updated = fm.get("last_updated", "unknown") if fm else "unknown"
            table.add_row(
                "[green]✓[/green]",
                f"[bold]{filename}[/bold]",
                f"[dim]valid (Ring {ring}, updated {updated})[/dim]",
            )
        else:
            for err in errors:
                table.add_row(
                    "[red]✗[/red]",
                    f"[bold]{filename}[/bold]",
                    f"[red]{err}[/red]",
                )
                total_issues += 1

    console.print(table)

    if total_issues == 0:
        console.print("\n[green]All profile files are valid.[/green]")
        return 0

    console.print(
        f"\n[red]{total_issues} issue{'s' if total_issues != 1 else ''} found.[/red]"
    )
    if show_fix:
        console.print(
            "[dim]Run: persona validate — to recheck after editing your profile files.[/dim]"
        )
    else:
        console.print(
            "[dim]Run: persona validate --fix — to see suggestions.[/dim]"
        )
    return 1


def main(user_dir: str | None = None) -> None:
    """CLI entry point for standalone use."""
    target = Path(user_dir) if user_dir else Path("~/.persona/USER").expanduser()
    code = run_validation(target)
    sys.exit(code)
