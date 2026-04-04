"""Resource definitions and loading for Persona MCP server.

Maps persona:// URIs to USER/ markdown files and assigns ring levels.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

# Maps URI suffix → (filename, ring_required, description)
RESOURCE_MAP: dict[str, tuple[str, int, str]] = {
    "identity": ("identity.md", 1, "Who you are"),
    "skills": ("skills.md", 1, "What you know"),
    "history": ("history.md", 1, "Where you've been"),
    "communication": ("communication.md", 1, "How you work"),
    "current-focus": ("current-focus.md", 2, "What you're doing now"),
    "goals": ("goals.md", 2, "What you're working toward"),
    "relationships": ("relationships.md", 2, "Key people in your world"),
    "preferences": ("preferences.md", 2, "Tools, style, opinions"),
    "constraints": ("constraints.md", 3, "Hard limits and sensitivities"),
    "summary": (None, 1, "Auto-generated 200-word summary from Ring 1 files"),
}

# private.md is NOT in RESOURCE_MAP — it is never listed or served


@dataclass
class PersonaResource:
    uri: str
    name: str
    filename: str | None  # None for generated resources like summary
    ring: int
    description: str


def get_all_resources() -> list[PersonaResource]:
    """Return all defined (non-private) persona resources."""
    return [
        PersonaResource(
            uri=f"persona://{key}",
            name=key,
            filename=fname,
            ring=ring,
            description=desc,
        )
        for key, (fname, ring, desc) in RESOURCE_MAP.items()
    ]


def load_file(user_dir: Path, filename: str) -> str:
    """Read a profile markdown file and return its contents."""
    path = user_dir / filename
    if not path.exists():
        return f"# {filename}\n\n*This profile section has not been filled in yet.*\n"
    return path.read_text(encoding="utf-8")


def generate_summary(user_dir: Path) -> str:
    """Generate a ~200-word summary from Ring 1 files only."""
    ring1_files = ["identity.md", "skills.md", "history.md", "communication.md"]
    sections: list[str] = []

    for fname in ring1_files:
        path = user_dir / fname
        if path.exists():
            content = path.read_text(encoding="utf-8")
            # Strip YAML frontmatter
            if content.startswith("---"):
                parts = content.split("---", 2)
                if len(parts) >= 3:
                    content = parts[2].strip()
            # Take first non-empty paragraph
            for line in content.splitlines():
                line = line.strip()
                if line and not line.startswith("#"):
                    sections.append(line)
                    break

    if not sections:
        return "No Ring 1 profile data available yet."

    summary = " ".join(sections)
    # Trim to ~200 words
    words = summary.split()
    if len(words) > 200:
        summary = " ".join(words[:200]) + "…"

    return f"# Persona Summary\n\n{summary}\n"
