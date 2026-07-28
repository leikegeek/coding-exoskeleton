---
name: exoskeleton-start
description: Start Exoskeleton pipeline A in Codex: turn a requirement into a reviewed technical design. Use when the user asks for /start, requirement intake, solution design, or design review before coding.
---

# Exoskeleton Start

Follow the workflow in `../../references/commands/start.md`.

Codex-specific rules:
- Use Codex skills by name when a referenced workflow skill is available.
- Use `AGENTS.md` as the authoritative project profile.
- Load applicable governance references from `../../references/rules`: always `shared`, plus the current family-common and profile named by `AGENTS.md` / `.exoskeleton/harness-config.json`.
- When design review or architecture review is required, prefer the matching Codex custom agent from `.codex/agents`; otherwise read `../../references/agents/<agent-name>.md` and run the role in the current thread.
- Stop at the user confirmation gate before entering coding.
- Keep implementation out of this skill unless the user later invokes `exoskeleton-code` or explicitly asks to continue coding after confirming the design.
