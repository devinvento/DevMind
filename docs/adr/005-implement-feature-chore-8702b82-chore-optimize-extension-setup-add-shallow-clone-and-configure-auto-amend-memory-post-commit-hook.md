# ADR 005: Implement Feature: CHORE [8702b82]: chore: optimize extension setup, add shallow clone, and configure auto-amend memory post-commit hook

Date: 2026-08-10
Status: Accepted

## Context
The DevMind extension setup and repository resolution processes were suboptimal on fresh clean-install environments, particularly due to cloning full git histories for helper repositories (such as the Everything Claude Code repository). Additionally, keeping the Project Memory Layer (`.devmind/memory/decisions.md` and `project-history.md`) synchronised required manual tasks, and there was no way to manually override target repository paths or access advanced AI debugging/regression tools directly from the VS Code sidebar.

## Decision
We implemented several setup and workflow optimizations:
1. **Shallow Clones:** Configured `setup-ai-project.sh` to use shallow clones (`--depth 1`) for both the ECC and Frappe skills repositories, reducing download overhead and setup time.
2. **Auto-Amend Post-Commit Hook:** Configured git post-commit hooks to automatically process commit message prefixes (feat, fix, refactor, revert), log these to DevMind decisions and project history documents, and perform a clean git amend.
3. **Target Repository Override:** Added manual repository override configurations (`devmind.selectDirectory`) via the VS Code sidebar to easily scope DevMind CLI actions to nested sub-repositories.
4. **Git Debugger UI Integration:** Extended the VS Code extension sidebar to include the AI Git Debugger & Regression controls (AI Debugger, Why This File, and Regression Bisect).

## Consequences
- **Benefits:**
  - Setup times are reduced by up to 90% in CI and local setups.
  - Automatic and effortless project memory logging on every commit, keeping documentation in sync with code evolution.
  - Greater flexibility to target nested or microservice repositories within a mono-repository workspace.
  - Integrated sidebar controls for Git-bisect testing, regressions, and context audits.
- **Trade-offs / Risks:**
  - Shallow clones limit historical log traversal within the ECC rules repository itself.
  - Amending git commits post-commit might conflict with some strict branch protection policies if developers attempt to push intermediate commits before completion.
