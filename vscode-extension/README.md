<p align="center">
  <img src="icon.png" alt="DevMind Logo" width="200"/>
</p>

# 🚀 DevMind VS Code Extension

Official VS Code Extension for the **DevMind Enterprise AI Engineering Operating System & CLI Suite**.

---

## ⚡ Features

1. **🩺 Live Engineering Score & Diagnostics**:
   - Status bar item showing real-time Engineering Score badge (`DevMind: 89%`).
   - Run `devmind doctor` diagnostics directly from VS Code.

2. **🧠 Project Memory & ADR Explorer**:
   - Interactive Sidebar view browsing `.devmind/memory/` files.
   - Manage and create Architecture Decision Records (`docs/adr/`).

3. **📊 Knowledge Graph & Impact Analysis**:
   - Open embedded interactive HTML Knowledge Graph visualizers.
   - Right-click any file in the Explorer for instant **File Impact Analysis** and **Git Blame Intelligence**.

4. **🤖 AI Task Planning & Code Review**:
   - Execute `DevMind: Plan AI Task` with interactive prompt boxes.
   - Run security audits, database schema checks, and AI code reviews on uncommitted git diffs.

---

## 💻 Available Commands

- `DevMind: Run Doctor Diagnostics` (`devmind.doctor`)
- `DevMind: Sync AI Context & Knowledge Graph` (`devmind.sync`)
- `DevMind: Plan AI Task` (`devmind.plan`)
- `DevMind: File Impact Analysis` (`devmind.impact`)
- `DevMind: Git Blame Intelligence` (`devmind.blame`)
- `DevMind: Audit Security` (`devmind.auditSecurity`)
- `DevMind: Analyze Database Schema` (`devmind.dbAnalyze`)
- `DevMind: AI Code Review` (`devmind.review`)
- `DevMind: Create ADR Record` (`devmind.createADR`)
- `DevMind: List ADR Records` (`devmind.listADRs`)
- `DevMind: Open Knowledge Graph` (`devmind.openGraph`)

---

## ⚙️ Configuration

- `devmind.cliPath`: Specify path to `devmind` executable (default: `devmind` or workspace fallback `bin/devmind`).
- `devmind.autoSyncOnSave`: Automatically refresh AI context when architecture files are updated.
