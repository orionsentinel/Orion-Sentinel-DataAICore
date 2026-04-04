# Persona Ring Configuration
# This file documents the sensitivity tier of each USER/ profile file.
# Do not change ring assignments without understanding the access implications.
#
# Ring 1 — Public identity: served to ALL connected MCP clients
# Ring 2 — Contextual data: served to allowlisted clients only
# Ring 3 — Sensitive: served only to clients with explicit ring 3 access
# NEVER  — private.md is hardcoded as blocked in server code

identity.md:       1
skills.md:         1
history.md:        1
communication.md:  1
current-focus.md:  2
goals.md:          2
relationships.md:  2
preferences.md:    2
constraints.md:    3
private.md:        NEVER
