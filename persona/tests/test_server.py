"""Tests for Persona MCP server construction and resource loading."""

from __future__ import annotations

from pathlib import Path
from unittest.mock import patch

import pytest
import yaml

from persona.server.resources import (
    RESOURCE_MAP,
    generate_summary,
    get_all_resources,
    load_file,
)


FIXTURES = Path(__file__).parent / "fixtures" / "sample_profile"


class TestResourceMap:
    def test_private_not_in_resource_map(self) -> None:
        """private.md must never appear in the resource map."""
        assert "private" not in RESOURCE_MAP
        for key in RESOURCE_MAP:
            assert "private" not in key.lower()

    def test_all_expected_resources_present(self) -> None:
        expected = {
            "identity", "skills", "history", "communication",
            "current-focus", "goals", "relationships", "preferences",
            "constraints", "summary",
        }
        assert set(RESOURCE_MAP.keys()) == expected

    def test_ring1_resources_correct(self) -> None:
        ring1 = {k for k, (_, ring, _) in RESOURCE_MAP.items() if ring == 1}
        assert ring1 == {"identity", "skills", "history", "communication", "summary"}

    def test_ring2_resources_correct(self) -> None:
        ring2 = {k for k, (_, ring, _) in RESOURCE_MAP.items() if ring == 2}
        assert ring2 == {"current-focus", "goals", "relationships", "preferences"}

    def test_ring3_resources_correct(self) -> None:
        ring3 = {k for k, (_, ring, _) in RESOURCE_MAP.items() if ring == 3}
        assert ring3 == {"constraints"}


class TestGetAllResources:
    def test_returns_list_of_resources(self) -> None:
        resources = get_all_resources()
        assert len(resources) == len(RESOURCE_MAP)

    def test_uris_use_persona_scheme(self) -> None:
        for res in get_all_resources():
            assert res.uri.startswith("persona://")

    def test_private_not_in_resources(self) -> None:
        uris = [r.uri for r in get_all_resources()]
        assert not any("private" in uri for uri in uris)


class TestLoadFile:
    def test_loads_existing_fixture(self) -> None:
        content = load_file(FIXTURES, "identity.md")
        assert "## Name" in content
        assert "Alex Rivera" in content

    def test_missing_file_returns_placeholder(self, tmp_path: Path) -> None:
        content = load_file(tmp_path, "nonexistent.md")
        assert "not been filled in" in content


class TestGenerateSummary:
    def test_generates_summary_from_ring1_files(self) -> None:
        summary = generate_summary(FIXTURES)
        assert "# Persona Summary" in summary
        assert len(summary) > 50

    def test_summary_from_empty_dir(self, tmp_path: Path) -> None:
        summary = generate_summary(tmp_path)
        assert "No Ring 1 profile data available" in summary

    def test_summary_does_not_include_ring2_content(self) -> None:
        summary = generate_summary(FIXTURES)
        # goals.md content should not appear in Ring 1 summary
        # "NLnet grant" is in goals.md (ring 2), not ring 1 files
        assert "NLnet grant" not in summary


class TestBuildServer:
    def test_server_instantiates(self, tmp_path: Path) -> None:
        """Server should build without error given a valid persona_dir."""
        from persona.server.main import build_server

        user_dir = tmp_path / "USER"
        user_dir.mkdir()
        config_dir = tmp_path / "config"
        config_dir.mkdir()
        allowlist = {"clients": {"unknown": {"ring": 1}}}
        (config_dir / "allowlist.yaml").write_text(yaml.dump(allowlist))

        with patch("persona.server.main._get_client_id", return_value="unknown"):
            server = build_server(tmp_path)
        assert server is not None
        assert server.name == "persona"
