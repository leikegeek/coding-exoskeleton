---
name: exoskeleton-code
description: Execute Exoskeleton pipeline B in Codex from a confirmed design into code, verification, audit, and delivery records. Use when the user asks for /code, continue coding, implement a confirmed plan, or governed development.
---

# Exoskeleton Code

Follow the workflow in `../../references/commands/code.md`.

Codex-specific rules:
- Use Codex's default local editing model; do not create a separate command layer for slash commands.
- Use repo skills from `.agents/skills` and plugin skills through progressive disclosure.
- Load applicable governance references from `../../references/rules`: always `shared`, plus the current family-common and profile named by `AGENTS.md` / `.exoskeleton/harness-config.json`.
- When the workflow calls for a specialist agent, prefer the matching Codex custom agent from `.codex/agents`; otherwise read `../../references/agents/<agent-name>.md` and run the role in the current thread.
- Respect Codex sandbox and approval prompts; do not bypass them from workflow instructions.
- Record verification commands and results in the final response.
