# Project Architecture Overview

Generated: 2026-08-10 16:06:16
Target Project: /var/www/html/DevMind

## Project Architecture Map

Project
│
├── API / Controllers / Routes
  └── None detected
│
├── Business Logic / Services / Models
  └── None detected
│
├── Database
  └── None explicitly configured
│
├── Queue
  └── Python RQ (Redis Queue)
│
├── Cache
  └── Redis
│
├── External APIs
  └── None explicitly configured
│
└── Authentication
  └── JWT (JSON Web Tokens)


## Graphify Knowledge Graph Insights
- **Total Concept Nodes**: 224
- **Relations (Edges)**: 360
- **Key Code Communities / Micro-systems**:
  - **Community #0**: setup-ai-project.sh, setup-ai-project.sh script, log(), success(), warn()
  - **Community #1**: index.ts, registerCommands(), devmindRunner.ts, DevMindRunner, .constructor()
  - **Community #2**: package.json, name, displayName, description, version
  - **Community #3**: contributes, viewsContainers, activitybar, views, devmind-explorer
  - **Community #4**: README.md, 🚀 DevMind Enterprise AI Operating System & CLI Suite (v3.0.0), 📊 Graphical System Architecture & Workflow, 1. Master System Pipeline (11-Step Integration), 2. VS Code Extension & File Impact Workflow

## Architectural Principles
1. **Modular Design**: Keep core domain business logic decoupled from transport/presentation layers.
2. **Service Layer**: Move complex logic from controllers or routing handlers into dedicated service or domain modules.
3. **Immutability & Safety**: Minimize unexpected side effects. Validate inputs strictly at system boundaries.
4. **Graphify Alignment**: Consult `graphify-out/graph.json` before modifying core shared components.
