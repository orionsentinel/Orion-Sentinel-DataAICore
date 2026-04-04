"""Audit log writer for Persona MCP server.

Writes one JSON line per resource access to logs/audit.jsonl.
The audit log is append-only and never truncated by Persona.
"""

from __future__ import annotations

import json
import logging
from datetime import datetime, timezone
from pathlib import Path

logger = logging.getLogger(__name__)


def log_access(
    log_dir: Path,
    client: str,
    resource: str,
    ring: int,
    granted: bool,
) -> None:
    """Append one access record to logs/audit.jsonl."""
    log_dir.mkdir(parents=True, exist_ok=True)
    record = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "client": client,
        "resource": resource,
        "ring": ring,
        "granted": granted,
    }
    log_path = log_dir / "audit.jsonl"
    try:
        with log_path.open("a") as f:
            f.write(json.dumps(record) + "\n")
    except OSError as exc:
        logger.error("Failed to write audit log: %s", exc)
