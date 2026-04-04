"""Tests for audit log writer and main.py utility functions."""

from __future__ import annotations

import json
import os
from pathlib import Path
from unittest.mock import patch

import pytest
import yaml

from persona.server.audit import log_access
from persona.server.main import _get_client_id, _resolve_persona_dir


class TestLogAccess:
    def test_creates_audit_file(self, tmp_path: Path) -> None:
        log_access(tmp_path, "claude-desktop", "persona://identity", 1, True)
        log_file = tmp_path / "audit.jsonl"
        assert log_file.exists()

    def test_record_structure(self, tmp_path: Path) -> None:
        log_access(tmp_path, "cursor", "persona://skills", 1, True)
        record = json.loads((tmp_path / "audit.jsonl").read_text().strip())
        assert record["client"] == "cursor"
        assert record["resource"] == "persona://skills"
        assert record["ring"] == 1
        assert record["granted"] is True
        assert "timestamp" in record

    def test_denied_access_logged(self, tmp_path: Path) -> None:
        log_access(tmp_path, "unknown", "persona://goals", 2, False)
        record = json.loads((tmp_path / "audit.jsonl").read_text().strip())
        assert record["granted"] is False

    def test_multiple_records_appended(self, tmp_path: Path) -> None:
        log_access(tmp_path, "client-a", "persona://identity", 1, True)
        log_access(tmp_path, "client-b", "persona://goals", 2, False)
        lines = (tmp_path / "audit.jsonl").read_text().strip().splitlines()
        assert len(lines) == 2

    def test_creates_log_dir_if_missing(self, tmp_path: Path) -> None:
        nested = tmp_path / "deep" / "logs"
        log_access(nested, "test", "persona://identity", 1, True)
        assert (nested / "audit.jsonl").exists()

    def test_write_failure_does_not_raise(self, tmp_path: Path) -> None:
        # Make log dir a file to cause write failure
        bad_path = tmp_path / "audit.jsonl"
        bad_path.mkdir()  # directory where file expected
        # Should not raise — just log the error
        log_access(tmp_path, "test", "persona://identity", 1, True)


class TestGetClientId:
    def test_returns_env_var_if_set(self) -> None:
        with patch.dict(os.environ, {"MCP_CLIENT_NAME": "my-tool"}):
            assert _get_client_id() == "my-tool"

    def test_returns_unknown_if_not_set(self) -> None:
        env = {k: v for k, v in os.environ.items() if k != "MCP_CLIENT_NAME"}
        with patch.dict(os.environ, env, clear=True):
            assert _get_client_id() == "unknown"


class TestResolvePersonaDir:
    def test_resolves_from_config(self, tmp_path: Path) -> None:
        persona_dir = tmp_path / "my_persona"
        persona_dir.mkdir()
        config = {"persona_dir": str(persona_dir)}
        config_path = tmp_path / "persona.yaml"
        config_path.write_text(yaml.dump(config))
        result = _resolve_persona_dir(config_path)
        assert result == persona_dir.resolve()

    def test_defaults_when_config_missing(self, tmp_path: Path) -> None:
        config_path = tmp_path / "nonexistent.yaml"
        result = _resolve_persona_dir(config_path)
        assert result == Path("~/.persona").expanduser().resolve()

    def test_expands_tilde(self, tmp_path: Path) -> None:
        config = {"persona_dir": "~/.persona"}
        config_path = tmp_path / "persona.yaml"
        config_path.write_text(yaml.dump(config))
        result = _resolve_persona_dir(config_path)
        assert "~" not in str(result)


class TestValidatorMain:
    def test_validator_main_exits_0_on_valid_profile(self) -> None:
        from persona.validator.validate import run_validation
        fixtures = Path(__file__).parent / "fixtures" / "sample_profile"
        assert run_validation(fixtures) == 0

    def test_validator_main_exits_1_on_broken_profile(self, tmp_path: Path) -> None:
        from persona.validator.validate import run_validation
        broken = tmp_path / "identity.md"
        broken.write_text("---\nring: 4\nversion: 1\n---\n## Name\n")
        assert run_validation(tmp_path) == 1

    def test_validator_show_fix_flag(self, tmp_path: Path) -> None:
        from persona.validator.validate import run_validation
        broken = tmp_path / "identity.md"
        broken.write_text("---\nring: 4\nversion: 1\n---\n## Name\n")
        # Should not raise — just display extra guidance
        result = run_validation(tmp_path, show_fix=True)
        assert result == 1
