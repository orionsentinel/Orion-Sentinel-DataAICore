"""Tests that onboarding prompt exists and fixture output validates."""

from __future__ import annotations

from pathlib import Path

import pytest

from persona.validator.validate import run_validation

FIXTURES = Path(__file__).parent / "fixtures" / "sample_profile"
ONBOARDING = Path(__file__).parent.parent / "prompts" / "onboarding.md"


class TestOnboardingPrompt:
    def test_onboarding_prompt_exists(self) -> None:
        assert ONBOARDING.exists(), "prompts/onboarding.md must exist"

    def test_onboarding_prompt_not_empty(self) -> None:
        content = ONBOARDING.read_text()
        assert len(content) > 500, "Onboarding prompt seems too short"

    def test_onboarding_prompt_contains_user_instructions(self) -> None:
        content = ONBOARDING.read_text()
        assert "Copy" in content or "paste" in content.lower()

    def test_fixture_profile_passes_validation(self) -> None:
        """The sample fixtures represent valid onboarding output."""
        result = run_validation(FIXTURES)
        assert result == 0, "Sample fixtures (onboarding output) should pass validation"
