---
name: exoskeleton-init
description: Initialize or refresh the Exoskeleton project profile for a repository before governed Codex workflows. Use when the user asks for /init, project profiling, tech-stack detection, or AGENTS.md generation.
---

# Exoskeleton Init

Follow the workflow in `../../references/commands/init.md`.

Codex-specific rules:
- Treat `AGENTS.md` as the durable repository guidance surface.
- Prefer concise project guidance that fits Codex instruction discovery limits.
- Record active governance references by profile: always `../../references/rules/shared`, plus the selected family-common and profile rule folders.
- Keep generated project state under `.exoskeleton/`; use `.codex/` only for Codex configuration and hooks.
- Do not write global Codex config unless the user explicitly asks for a personal default.
