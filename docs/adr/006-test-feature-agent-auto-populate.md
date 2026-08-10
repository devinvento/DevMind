# ADR 006: Test Feature Agent Auto Populate

Date: 2026-08-10
Status: Accepted

## Context
The `devmind` CLI uses `devmind adr create` to generate Architecture Decision Records (ADRs) upon developer planning or commit triggers. Previously, this required either manually writing the files from placeholders or configuring external LLM API keys in the environment. However, when developers are using sophisticated coding agents (like Antigravity, Claude Code, or Cursor), the agent itself is already active, has direct LLM access, and can automate writing the ADR without requiring the developer to configure raw API keys in their shell environment.

## Decision
We implemented a workflow rule for active coding agents to automatically populate new ADR files:
1. Updated `bin/devmind` to include a warning directive `[DEVMIND AI INSTRUCTION]` in stdout and append the marker comment `<!-- DEVMIND_PENDING_ADR_AI_POPULATION -->` when generating the template ADR.
2. Created a new rule in `.agents/rules/architecture.md` (and updated the setup script generator) instructing any active AI agent to scan the ADR directory, detect the pending marker comment, query its LLM with the recent git diff context, write the structured ADR contents, and remove the marker comment.

## Consequences
- **Benefits:**
  - Developers using AI agents get fully automated, context-aware ADR content generation out-of-the-box without configuring environment variables or API keys.
  - Zero-friction documentation alignment with code changes.
- **Trade-offs / Risks:**
  - AI agents must be running to auto-populate files containing the marker. If a developer works outside an agent, the template remains placeholder-filled unless they have environment API keys set.
