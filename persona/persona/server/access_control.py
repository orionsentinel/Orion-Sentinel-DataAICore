"""Access control enforcement for Persona MCP server.

Implements the three-ring model:
  Ring 1 — served to all connected clients
  Ring 2 — served only to allowlisted clients
  Ring 3 — served only to clients with explicit ring: 3 in allowlist
  private.md — NEVER served under any circumstances (enforced in code)
"""

from __future__ import annotations

import logging
from pathlib import Path
from typing import Any

import yaml

logger = logging.getLogger(__name__)

# Hardcoded block list — these URIs are NEVER served regardless of config
PERMANENTLY_BLOCKED_RESOURCES: frozenset[str] = frozenset(
    {
        "persona://private",
        "private.md",
        "private",
    }
)


def _load_allowlist(config_dir: Path) -> dict[str, Any]:
    """Load allowlist.yaml from config directory."""
    allowlist_path = config_dir / "allowlist.yaml"
    if not allowlist_path.exists():
        logger.warning("No allowlist.yaml found; all clients treated as ring 1")
        return {"clients": {}}
    with allowlist_path.open() as f:
        data = yaml.safe_load(f) or {}
    return data


def get_client_ring(client_id: str, config_dir: Path) -> int:
    """Return the ring level granted to a client.

    Falls back to ring 1 for unknown clients.
    """
    allowlist = _load_allowlist(config_dir)
    clients = allowlist.get("clients", {})
    if client_id in clients:
        ring = int(clients[client_id].get("ring", 1))
        return max(1, min(3, ring))  # clamp to valid range
    # Default: unknown clients get ring 1
    default = clients.get("unknown", {})
    return int(default.get("ring", 1))


def is_resource_allowed(
    uri: str,
    ring_required: int,
    client_id: str,
    config_dir: Path,
) -> bool:
    """Return True if the client is permitted to access the resource.

    private.md is always denied regardless of client or ring.
    """
    # Absolute block — private.md is never served
    uri_lower = uri.lower()
    for blocked in PERMANENTLY_BLOCKED_RESOURCES:
        if blocked in uri_lower:
            logger.warning(
                "Blocked attempt to access private resource uri=%s client=%s",
                uri,
                client_id,
            )
            return False

    client_ring = get_client_ring(client_id, config_dir)
    granted = client_ring >= ring_required
    return granted
