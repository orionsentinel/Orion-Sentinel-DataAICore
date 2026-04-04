"""Tests for Persona access control enforcement."""

from __future__ import annotations

import tempfile
from pathlib import Path

import pytest
import yaml

from persona.server.access_control import (
    PERMANENTLY_BLOCKED_RESOURCES,
    get_client_ring,
    is_resource_allowed,
)


@pytest.fixture()
def config_dir(tmp_path: Path) -> Path:
    """Return a temp config directory with a standard allowlist."""
    allowlist = {
        "clients": {
            "claude-desktop": {"ring": 2, "description": "Primary assistant"},
            "trusted-client": {"ring": 3, "description": "Ring 3 access"},
            "cursor": {"ring": 1, "description": "Code editor"},
            "unknown": {"ring": 1, "description": "Default"},
        }
    }
    (tmp_path / "allowlist.yaml").write_text(yaml.dump(allowlist))
    return tmp_path


class TestGetClientRing:
    def test_known_client_returns_correct_ring(self, config_dir: Path) -> None:
        assert get_client_ring("claude-desktop", config_dir) == 2

    def test_unknown_client_falls_back_to_default(self, config_dir: Path) -> None:
        assert get_client_ring("some-random-tool", config_dir) == 1

    def test_ring_clamped_to_valid_range(self, tmp_path: Path) -> None:
        allowlist = {"clients": {"bad-client": {"ring": 99}}}
        (tmp_path / "allowlist.yaml").write_text(yaml.dump(allowlist))
        assert get_client_ring("bad-client", tmp_path) == 3

    def test_missing_allowlist_returns_ring_1(self, tmp_path: Path) -> None:
        assert get_client_ring("anyone", tmp_path) == 1


class TestIsResourceAllowed:
    def test_ring1_allowed_for_unknown_client(self, config_dir: Path) -> None:
        assert is_resource_allowed("persona://identity", 1, "unknown", config_dir)

    def test_ring1_allowed_for_unknown_unregistered_client(self, config_dir: Path) -> None:
        assert is_resource_allowed("persona://skills", 1, "mystery-app", config_dir)

    def test_ring2_blocked_for_ring1_client(self, config_dir: Path) -> None:
        assert not is_resource_allowed("persona://goals", 2, "cursor", config_dir)

    def test_ring2_allowed_for_ring2_client(self, config_dir: Path) -> None:
        assert is_resource_allowed("persona://goals", 2, "claude-desktop", config_dir)

    def test_ring3_blocked_for_ring2_client(self, config_dir: Path) -> None:
        assert not is_resource_allowed("persona://constraints", 3, "claude-desktop", config_dir)

    def test_ring3_allowed_for_ring3_client(self, config_dir: Path) -> None:
        assert is_resource_allowed("persona://constraints", 3, "trusted-client", config_dir)

    # private.md — the most critical tests
    def test_private_blocked_for_ring1_client(self, config_dir: Path) -> None:
        assert not is_resource_allowed("persona://private", 3, "cursor", config_dir)

    def test_private_blocked_for_ring2_client(self, config_dir: Path) -> None:
        assert not is_resource_allowed("persona://private", 3, "claude-desktop", config_dir)

    def test_private_blocked_for_ring3_client(self, config_dir: Path) -> None:
        """Even a ring-3 client must never access private.md."""
        assert not is_resource_allowed("persona://private", 3, "trusted-client", config_dir)

    def test_private_blocked_regardless_of_ring_required(self, config_dir: Path) -> None:
        """private.md blocked even if ring_required=1 is passed."""
        assert not is_resource_allowed("persona://private", 1, "trusted-client", config_dir)

    def test_private_blocked_by_partial_uri_match(self, config_dir: Path) -> None:
        """Block any URI containing 'private' to prevent bypass attempts."""
        assert not is_resource_allowed("persona://private", 1, "anyone", config_dir)

    def test_permanently_blocked_set_contains_private(self) -> None:
        assert "persona://private" in PERMANENTLY_BLOCKED_RESOURCES
