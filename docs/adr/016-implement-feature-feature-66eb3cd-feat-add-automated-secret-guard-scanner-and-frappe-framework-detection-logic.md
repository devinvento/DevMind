# ADR 016: Implement Feature: FEATURE [66eb3cd]: feat: add automated secret guard scanner and frappe framework detection logic

Date: 2026-11-12
Status: Accepted

## Context
The DevMind Enterprise AI Operating System aims to provide an intelligent, developer-friendly AI engineering environment. A critical aspect of this involves ensuring robust security practices and streamlining the developer workflow, particularly concerning sensitive data and AI memory management. Prior to this change, there was a potential risk of developers (or AI agents) accidentally committing sensitive information (like API keys, passwords, or configuration files) to Git repositories, which could lead to significant security vulnerabilities. Additionally, managing AI context and chat history across different development environments was a manual and often inconsistent process. The system also lacked an automated, intelligent way to detect project technology stacks (such as the Frappe framework) to apply appropriate AI skills and operational rules. This commit addresses these challenges by implementing previously planned features that enhance security, improve cross-environment consistency, and enable smarter project-specific automation.

## Decision
This architectural decision introduces several key features:

1.  **Automated Secret Guard Scanner & Pre-push Hook:** A new `devmind scan` command and a Git `pre-push` hook have been implemented. This mechanism scans outgoing commits for a wide range of sensitive data patterns, including API keys, passwords, tokens, private keys, `.env` files, database dumps, and AI chat history. If secrets are detected, the push is blocked, preventing sensitive information from being committed to the repository. This guard is designed to work for both human-initiated and AI agent-generated commits. The `secret-guard` capability is also bundled as an auto-installed AI skill.
2.  **Frappe Framework and Generic Stack Detection Logic:** A system for detecting project technology stacks (e.g., Frappe, Laravel, Django, FastAPI, Next.js, React, Node) has been integrated, utilizing `profiles/*.yaml` files. This includes specific logic for auto-detecting nested Frappe applications. Based on the detected stack, DevMind will automatically apply a tailored set of domain rules, ECC skills, and DevMind-specific skills.
3.  **AI Memory Synchronization via Google Drive:** Functionality for syncing AI chat history, session summaries, and Claude auto-memory across different machines has been introduced. This is managed via `devmind memory push/pull` commands and integrates with Google Drive. A one-click "Connect Google Drive" feature within the VS Code extension simplifies setup, and automatic push/pull options are configurable.
4.  **Automated Skill Installation:** Core DevMind skills, including `secret-guard`, are now bundled with the VS Code extension and automatically installed into `project/.agents/skills/` and `project/.claude/skills/` upon extension activation.
5.  **Enhanced Git Hooks:** Beyond the `pre-push` Secret Guard, `post-commit` memory queueing and a `Claude Code SessionEnd` hook for auto-pushing AI memory are integrated into the workflow.

## Consequences
- **Benefits:**
  - **Enhanced Security Posture:** The `Secret Guard` significantly reduces the risk of accidental or malicious leakage of sensitive information into Git repositories, protecting credentials, proprietary data, and AI interactions. This applies universally to human and AI contributions.
  - **Improved Developer Productivity and Consistency:** AI memory synchronization ensures developers have a consistent AI context across all their machines, enabling seamless continuation of work and improving the intelligence and effectiveness of AI agents.
  - **Smarter Project Initialization and Configuration:** Automated stack detection (e.g., Frappe, Laravel) allows DevMind to intelligently tailor its tooling, agents, and rules to the specific project environment, reducing manual setup and configuration overhead.
  - **Streamlined Onboarding and Project Setup:** Auto-installation of essential skills (like `secret-guard`) and intelligent stack profiles simplify the process of setting up new projects or onboarding new team members, ensuring a baseline of required tooling.
  - **Reduced Manual Overhead:** Git hooks for secret scanning and auto-memory sync automate critical tasks, allowing developers to focus more on coding and less on administrative or preventative measures.

- **Trade-offs / Risks:**
  - **Potential for False Positives in Secret Guard:** The `pre-push` hook might occasionally misidentify legitimate code patterns as secrets, leading to blocked pushes and requiring manual overrides or configuration adjustments, potentially disrupting developer workflow.
  - **Dependency on External Services and Tools:** The reliance on Google Drive for AI memory sync and `rclone` for its implementation introduces external dependencies, which could have implications for security audits, installation robustness, and long-term maintenance.
  - **Increased System Complexity:** Introducing stack profiles, automated skill installation, and multiple Git hooks adds layers of configuration and interaction logic, which could increase the complexity of debugging or customizing DevMind's behavior.
  - **Performance Overhead:** The execution of the `pre-push` hook for secret scanning and the background processes for auto-memory synchronization might introduce minor performance overhead to Git operations or the overall system responsiveness.
  - **Data Privacy and Governance Concerns:** Storing AI memory (including chat history) on Google Drive, while convenient, might raise data privacy, compliance, or data sovereignty concerns for some organizations, necessitating clear policies and user awareness.
