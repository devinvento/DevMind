<p align="center">
  <img src="DevMind.png" alt="DevMind AI Engineering Logo" width="320"/>
</p>

# 🚀 DevMind Enterprise AI Operating System & CLI Suite (v3.0.0)

An intelligent, developer-friendly AI Engineering Operating System & Unified CLI Tool (`devmind`). It unifies **Everything Claude Code (ECC)**, **Graphify Knowledge Graphs**, **Specialized Agent Personas**, **Operational Workflows**, **Git & Database Intelligence**, **Project Memory Layer**, **ADR Management**, and **Antigravity IDE MCP Integration** into a single cohesive operating framework.

---

## 📊 System Architecture & 11-Step Pipeline

```mermaid
flowchart TD
    Start(["▶ Start: ./setup-ai-project.sh [DIR]"]) --> Step1["1. Validate Target Project Directory"]

    subgraph Phase1 ["Phase 1: System-Level Dependency & CLI Installation"]
        Step1 --> Step2{"2. Verify System Tools, DevMind CLI & ECC Repo<br/>(git, curl, python3, node, uv, graphify, devmind, ECC)"}
        Step2 -- "Missing" --> AutoInstall["Auto-Install Missing Tools & CLI to ~/.local/bin/devmind"]
        Step2 -- "Ready" --> Phase2
        AutoInstall --> Phase2
    end

    subgraph Phase2 ["Phase 2: Intelligent Stack & Context Extraction"]
        Phase2 --> Step3["3. Detect Project Stack (Laravel, CodeIgniter, Frappe, Django, Node, React, etc.)"]
        Step3 --> Step4["4. Detect Test Suite & Database Architecture"]
        Step4 --> Step5["5. Generate Intelligence Docs & Memory (.devmind/memory/, docs/adr/, DATABASE.md, ARCHITECTURE.md, SECURITY.md)"]
    end

    subgraph Phase3 ["Phase 3: Agent Framework & Rule Mapping"]
        Step5 --> Step6["6. Generate Specialized Agents (.agents/agents/)"]
        Step6 --> Step7["7. Generate Operational Workflows (.agents/workflows/)"]
        Step7 --> Step8["8. Generate Domain Rules & Symlink ECC Skills (.agents/rules/, .agents/skills/)"]
        Step8 --> Step9["9. Create Master Operating Manual (.agents/AGENTS.md)"]
    end

    subgraph Phase4 ["Phase 4: Knowledge Graph, MCP & CLI Diagnostics"]
        Step9 --> Step10["10. Build Graphify Graph & HTML Visualizer + Configure Antigravity MCP"]
        Step10 --> Step11["11. Run devmind doctor & Engineering Score (0-100%)"]
    end

    Step11 --> End(["✅ Setup Complete: DevMind CLI & AI Pair Programming Ready"])
```

---

## 💻 `devmind` CLI Suite Command Reference

The `devmind` CLI tool provides full control over AI context, task planning, dependency impact, security auditing, and project memory:

| Command | Description |
| :--- | :--- |
| `devmind doctor` | Runs 8-dimensional diagnostic suite & calculates Engineering Score (0–100%). |
| `devmind sync` | Automatically updates Graphify graph, HTML visualizer, and intelligence docs. |
| `devmind plan "<task>"` | AI Task Planner: affected modules, risk level, required database tables & tests. |
| `devmind impact <file>` | Impact Analysis: dependency resolution & downstream/upstream consumers. |
| `devmind blame <file>` | Git Intelligence: commit history, author changes, and change rationale. |
| `devmind audit security` | Security Scanner: secret detection, SQLi, XSS, OWASP checks, and security score. |
| `devmind db analyze` | Database Intelligence v2: table relationships, foreign keys, missing indexes. |
| `devmind review` | AI Code Review Bot inspecting uncommitted `git diff`. |
| `devmind adr create "<title>"` | Creates a new Architecture Decision Record in `docs/adr/`. |
| `devmind adr list` | Lists existing Architecture Decision Records. |
| `devmind infra audit` | Audits production infrastructure (Nginx, PHP-FPM, Docker, Redis, MariaDB). |

---

## 🧠 Project Memory Layer (`.devmind/memory/`) & ADRs

DevMind maintains a long-term engineering memory so AI agents never repeat past mistakes:
- **`decisions.md`**: Architectural & technical design choices.
- **`known-issues.md`**: Active technical debt & known bugs.
- **`failed-attempts.md`**: Past technical approaches that failed and rationale.
- **`project-history.md`**: System evolution log.
- **`docs/adr/`**: Sequential Architecture Decision Records (e.g., `001-initial-architecture.md`).

---

## 🛡️ Master AI Operating Manual (`.agents/AGENTS.md`)

- **Forbidden Actions**: No committing secrets, no force-pushing, no modifying core framework files, no commenting out failing tests.
- **Before Changing Code**: Mandatory search, Graphify dependency check, and implementation plan creation.
- **After Changing Code**: Test execution, `git diff` review, and `devmind sync`.

---

## 📊 DevMind Engineering Score Matrix

```
====================================================
      DEVMIND ENGINEERING SCORE & DIAGNOSTICS      
====================================================

  AI Context       [███████████████████░] 95%
  Architecture     [██████████████████░░] 90%
  Testing          [█████████████████░░░] 85%
  Security         [██████████████████░░] 90%
  Documentation    [███████████████████░] 95%
  Database         [██████████████████░░] 90%
  Code Quality     [█████████████████░░░] 88%
  Infrastructure   [████████████████░░░░] 82%

----------------------------------------------------
  Overall DevMind Engineering Score: 89% / 100% 🎉
====================================================
```

---

## 🚀 Usage & Quick Start

```bash
# 1. Run Setup & Install DevMind CLI
./setup-ai-project.sh /path/to/project

# 2. Run Diagnostics
devmind doctor

# 3. Plan a Task
devmind plan "Add OTP verification"

# 4. Check File Impact
devmind impact setup-ai-project.sh

# 5. Sync AI Context
devmind sync
```

---

## 🧩 DevMind VS Code Extension (`vscode-extension/`)

DevMind provides a native VS Code Extension that brings AI context, diagnostics, and knowledge graph tools directly into your IDE:

- **Sidebar Dashboard**: System health score, project memory explorer, ADR manager, and Graphify status.
- **Status Bar Badge**: Live engineering score indicator (`$(brain) DevMind: 89%`).
- **File Explorer Context Menu**: Right-click any file to trigger **DevMind: File Impact Analysis** and **Git Blame Intelligence**.
- **Interactive Knowledge Graph**: Render Graphify network graphs directly in VS Code Webview tabs.

### Quick Extension Setup:
```bash
cd vscode-extension
npm install
npm run compile
```

