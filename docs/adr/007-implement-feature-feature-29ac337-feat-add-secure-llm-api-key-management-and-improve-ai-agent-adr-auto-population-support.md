# ADR 007: Implement Feature: FEATURE [29ac337]: feat: add secure LLM API key management and improve AI agent ADR auto-population support

Date: 2026-08-10
Status: Accepted

## Context
The DevMind CLI and workflow orchestrator previously required manual drafting of the Architecture Decision Record (ADR) contents (Context, Decision, Consequences) when new ADRs were created. Furthermore, managing LLM API keys securely without committing them to repositories or storing them in plain text `.env` files was a challenge. To automate the process and secure the environment, a mechanism was needed to securely manage API keys and auto-populate ADR sections.

## Decision
We implemented a dual-mode ADR auto-population strategy combined with secure API key storage in the VS Code extension:
1. **Secure API Key Management:** Implemented `devmind.configureAPIKeys` command in the VS Code extension which leverages VS Code's `context.secrets` storage. The `DevMindRunner` retrieves these secrets and injects them as environment variables (`GEMINI_API_KEY`, `OPENAI_API_KEY`, etc.) during CLI execution.
2. **Direct API Integration:** Enhanced the `devmind` CLI (`bin/devmind`) to query LLM APIs (Gemini, Claude, DeepSeek, or OpenAI) directly to auto-populate the Context, Decision, and Consequences of the ADR based on git diffs/commit info when keys are present in the environment.
3. **Agentic Fallback Auto-Population:** If no keys are present, the CLI outputs the `<!-- DEVMIND_PENDING_ADR_AI_POPULATION -->` comment marker, signaling to active AI coding agents (such as Antigravity) to intercept, read the recent git commits, and auto-populate the sections.

## Consequences
- **Benefits:**
  - Secure storage of LLM API keys using native VS Code secret storage.
  - Automatic drafting of ADR files, reducing developer overhead and ensuring high-quality documentation.
  - Fallback logic ensures ADRs are populated even if keys are not exported in the shell environment.
- **Trade-offs / Risks:**
  - Direct API mode requires an active internet connection to call LLM APIs.
  - Commits made outside of VS Code (without environment keys exported) will default to fallback mode, requiring coding agents to resolve the placeholders.
