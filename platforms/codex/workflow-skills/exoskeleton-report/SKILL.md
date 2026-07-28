---
name: exoskeleton-report
description: Generate Exoskeleton governance reports in Codex from hook logs, delivery records, audit records, or workflow state. Use when the user asks for /report or governance/status reporting.
---

# Exoskeleton Report

Follow the workflow in `../../references/commands/report.md`.

Codex-specific rules:
- Read `.exoskeleton/` state first, then legacy `.cursor/` state only as fallback.
- Include Codex hook, custom-agent, approval-rule, and plugin installation status when those assets are present.
- Report hook activity, task mode, verification status, and unresolved governance gaps plainly.
