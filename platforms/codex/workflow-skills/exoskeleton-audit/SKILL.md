---
name: exoskeleton-audit
description: Run an Exoskeleton unified audit in Codex for local diffs, commits, branches, or merge requests. Use when the user asks for /audit, code review, MR review, or delivery risk review.
---

# Exoskeleton Audit

Follow the workflow in `../../references/commands/audit.md`.

Codex-specific rules:
- Default to Codex's review posture: findings first, ordered by severity, with file and line references.
- Load applicable governance references from `../../references/rules`: always `shared`, plus the current family-common and profile named by `AGENTS.md` / `.exoskeleton/harness-config.json`.
- Prefer the `audit-reviewer` Codex custom agent from `.codex/agents`; otherwise read `../../references/agents/audit-reviewer.md` and run that role in the current thread.
- Use Git evidence before broad file scans when the audit target is a diff, commit, or branch.
- Keep audit work read-only unless the user asks for fixes.
