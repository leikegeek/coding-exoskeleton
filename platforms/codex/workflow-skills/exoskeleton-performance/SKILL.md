---
name: exoskeleton-performance
description: Analyze performance risks with Exoskeleton evidence discipline in Codex. Use when the user asks for /performance, performance review, latency, throughput, rendering, database, or batch-processing analysis.
---

# Exoskeleton Performance

Follow the workflow in `../../references/commands/performance.md`.

Codex-specific rules:
- Performance claims require evidence from code, measurements, scale assumptions, or documented constraints.
- Load applicable governance references from `../../references/rules`: always `shared`, plus the current family-common and profile named by `AGENTS.md` / `.exoskeleton/harness-config.json`.
- Prefer narrow, low-risk optimization recommendations with validation steps.
- Do not change code unless the user explicitly asks to implement fixes.
