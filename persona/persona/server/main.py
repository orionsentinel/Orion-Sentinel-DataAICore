"""Persona MCP server entry point.

Starts the MCP server using stdio transport. This is the main entry
point for the `persona serve` CLI command.
"""

from __future__ import annotations

import logging
import os
from pathlib import Path

import click
import yaml
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Resource, TextContent

from persona.server.access_control import is_resource_allowed
from persona.server.audit import log_access
from persona.server.resources import generate_summary, get_all_resources, load_file

logger = logging.getLogger(__name__)


def _resolve_persona_dir(config_path: Path) -> Path:
    """Load persona_dir from config and resolve it."""
    if config_path.exists():
        with config_path.open() as f:
            cfg = yaml.safe_load(f) or {}
        raw = cfg.get("persona_dir", "~/.persona")
    else:
        raw = "~/.persona"
    return Path(raw).expanduser().resolve()


def _get_client_id() -> str:
    """Attempt to identify the connecting MCP client.

    MCP stdio clients set the MCP_CLIENT_NAME environment variable
    or can be identified via process inspection. Falls back to 'unknown'.
    """
    return os.environ.get("MCP_CLIENT_NAME", "unknown")


def build_server(persona_dir: Path) -> Server:
    """Construct and return a configured MCP Server instance."""
    user_dir = persona_dir / "USER"
    config_dir = persona_dir / "config"
    log_dir = persona_dir / "logs"
    client_id = _get_client_id()

    server = Server("persona")

    @server.list_resources()
    async def list_resources() -> list[Resource]:
        """Return the resources this client is allowed to see."""
        visible = []
        for res in get_all_resources():
            if is_resource_allowed(res.uri, res.ring, client_id, config_dir):
                visible.append(
                    Resource(
                        uri=res.uri,
                        name=res.name,
                        description=res.description,
                        mimeType="text/markdown",
                    )
                )
        return visible

    @server.read_resource()
    async def read_resource(uri: str) -> list[TextContent]:  # type: ignore[override]
        """Serve a resource if the client is authorised."""
        # Parse key from persona://key
        if uri.startswith("persona://"):
            key = uri[len("persona://"):]
        else:
            key = uri

        from persona.server.resources import RESOURCE_MAP

        if key not in RESOURCE_MAP:
            log_access(log_dir, client_id, uri, 0, False)
            raise ValueError(f"Unknown resource: {uri}")

        filename, ring_required, _ = RESOURCE_MAP[key]

        allowed = is_resource_allowed(uri, ring_required, client_id, config_dir)
        log_access(log_dir, client_id, uri, ring_required, allowed)

        if not allowed:
            raise PermissionError(
                f"Client '{client_id}' does not have ring {ring_required} access"
            )

        if key == "summary":
            content = generate_summary(user_dir)
        else:
            content = load_file(user_dir, filename)

        return [TextContent(type="text", text=content)]

    return server


@click.group()
def cli() -> None:
    """Persona — Sovereign AI Identity Infrastructure."""


@cli.command()
@click.option(
    "--config",
    default=None,
    help="Path to persona.yaml (default: ~/.persona/config/persona.yaml)",
)
@click.option("--log-level", default="INFO", help="Logging level")
def serve(config: str | None, log_level: str) -> None:
    """Start the Persona MCP server (stdio transport)."""
    import asyncio

    logging.basicConfig(level=getattr(logging, log_level.upper(), logging.INFO))

    if config:
        config_path = Path(config)
    else:
        config_path = Path("~/.persona/config/persona.yaml").expanduser()

    persona_dir = _resolve_persona_dir(config_path)
    logger.info("Starting Persona MCP server — persona_dir=%s", persona_dir)

    server = build_server(persona_dir)

    async def run() -> None:
        async with stdio_server() as (read_stream, write_stream):
            await server.run(read_stream, write_stream, server.create_initialization_options())

    asyncio.run(run())


@cli.command()
@click.argument("profile_dir", default=None, required=False)
@click.option("--fix", is_flag=True, help="Show fix suggestions for issues found")
def validate(profile_dir: str | None, fix: bool) -> None:
    """Validate USER/ profile files against the Persona schema."""
    from persona.validator.validate import run_validation

    target = Path(profile_dir) if profile_dir else Path("~/.persona/USER").expanduser()
    run_validation(target, show_fix=fix)


if __name__ == "__main__":
    cli()
