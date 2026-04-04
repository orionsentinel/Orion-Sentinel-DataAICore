"""Tests for Persona profile validator."""

from __future__ import annotations

from pathlib import Path

import pytest

from persona.validator.validate import _parse_frontmatter, _validate_file, run_validation


FIXTURES = Path(__file__).parent / "fixtures" / "sample_profile"


class TestParseFrontmatter:
    def test_valid_frontmatter_parsed(self) -> None:
        content = "---\nring: 1\nlast_updated: '2026-01-01'\nversion: 1\n---\n\n## Name\n"
        fm, body = _parse_frontmatter(content)
        assert fm is not None
        assert fm["ring"] == 1
        assert "## Name" in body

    def test_missing_frontmatter_returns_none(self) -> None:
        content = "## Name\n\nSome content"
        fm, body = _parse_frontmatter(content)
        assert fm is None

    def test_malformed_yaml_returns_none(self) -> None:
        content = "---\n: invalid: yaml: [\n---\n## Name"
        fm, body = _parse_frontmatter(content)
        assert fm is None


class TestValidateFile:
    def test_valid_identity_file_passes(self, tmp_path: Path) -> None:
        content = (
            "---\nring: 1\nlast_updated: '2026-01-01'\nversion: 1\n---\n\n"
            "## Name\n\nTest\n\n"
            "## Role\n\nTest\n\n"
            "## Background\n\nTest\n\n"
            "## What I do\n\nTest\n\n"
            "## How I describe myself to AI\n\nTest\n"
        )
        f = tmp_path / "identity.md"
        f.write_text(content)
        errors = _validate_file(f)
        assert errors == []

    def test_missing_section_reported(self, tmp_path: Path) -> None:
        content = (
            "---\nring: 1\nlast_updated: '2026-01-01'\nversion: 1\n---\n\n"
            "## Name\n\nTest\n\n"
            "## Role\n\nTest\n\n"
            "## Background\n\nTest\n\n"
            "## What I do\n\nTest\n"
            # Missing: ## How I describe myself to AI
        )
        f = tmp_path / "identity.md"
        f.write_text(content)
        errors = _validate_file(f)
        assert any("How I describe myself to AI" in e for e in errors)

    def test_invalid_ring_value_reported(self, tmp_path: Path) -> None:
        content = (
            "---\nring: 4\nlast_updated: '2026-01-01'\nversion: 1\n---\n\n"
            "## Name\n## Role\n## Background\n## What I do\n"
            "## How I describe myself to AI\n"
        )
        f = tmp_path / "identity.md"
        f.write_text(content)
        errors = _validate_file(f)
        assert any("ring" in e.lower() or "4" in e for e in errors)

    def test_missing_frontmatter_reported(self, tmp_path: Path) -> None:
        content = "## Name\n\nNo frontmatter here\n"
        f = tmp_path / "identity.md"
        f.write_text(content)
        errors = _validate_file(f)
        assert any("frontmatter" in e for e in errors)

    def test_missing_last_updated_reported(self, tmp_path: Path) -> None:
        content = (
            "---\nring: 1\nversion: 1\n---\n\n"
            "## Name\n## Role\n## Background\n## What I do\n"
            "## How I describe myself to AI\n"
        )
        f = tmp_path / "identity.md"
        f.write_text(content)
        errors = _validate_file(f)
        assert any("last_updated" in e for e in errors)


class TestRunValidation:
    def test_valid_fixtures_pass(self) -> None:
        """All sample fixtures should pass validation."""
        result = run_validation(FIXTURES)
        assert result == 0

    def test_missing_directory_returns_error(self, tmp_path: Path) -> None:
        result = run_validation(tmp_path / "nonexistent")
        assert result == 1

    def test_broken_file_causes_failure(self, tmp_path: Path) -> None:
        # Write a deliberately broken identity.md
        broken = tmp_path / "identity.md"
        broken.write_text("---\nring: 4\nversion: 1\n---\n## Name\n")
        result = run_validation(tmp_path)
        assert result == 1

    def test_empty_directory_flags_missing_files(self, tmp_path: Path) -> None:
        result = run_validation(tmp_path)
        assert result == 1
