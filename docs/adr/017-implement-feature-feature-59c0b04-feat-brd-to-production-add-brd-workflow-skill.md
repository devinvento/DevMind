# ADR 017: Implement Feature: FEATURE [59c0b04]: feat(brd-to-production): add BRD workflow skill with caches, test shards and regression gate

Date: 2026-11-15
Status: Accepted

## Context
This change introduces a comprehensive "BRD to Production" workflow skill aimed at automating and streamlining the process of converting Business Requirements Documents (BRDs) into actionable development artifacts, including structured requirements, architectural plans, and test specifications. The problem it solves is the manual, often slow, and error-prone translation of high-level business requirements into detailed technical tasks, leading to inconsistencies, misinterpretations, and delays in the software development lifecycle. By integrating AI agents and sophisticated gatekeeping mechanisms, the goal is to enhance efficiency, ensure consistency, and improve the overall quality and speed of project delivery from the initial BRD stage.

## Decision
The decision was to implement a new `brd-to-production` workflow skill. This skill orchestrates a suite of seven specialized AI agents (e.g., `brd-analyst`, `brd-architect`) to automatically process BRDs. Key components of this workflow include:
1.  **AI Agents:** Each agent is designed for a specific task (e.g., analysis, architecture, planning), with clearly defined inputs, rules, and outputs, ensuring structured and traceable artifact generation.
2.  **`brd_gate.py` for Workflow Management:**
    *   **Caching and Context Reuse:** Implements `brd-hash` and `context-check` mechanisms to safely reuse previous BRD or project analyses, reducing redundant processing.
    *   **Test Sharding:** Schedules dependency and resource-aware tester waves, allowing for parallel execution of tests, and includes a `shard-merge` function to consolidate reports.
    *   **Regression Gate:** Enforces quality by re-running every BRD suite and flow, requiring a fresh passing run for completion, thus preventing regressions.
3.  **Profile Configurations:** Introduced new configuration parameters (`max_test_agents`, `test_db_per_shard`, `context_full_refresh_every`) to manage testing resources and caching policies effectively.
4.  **Documentation and Testing:** Accompanying `tests/test_brd_gate.py` and `docs/plans/brd-speed-and-caching-plan.md` validate the implementation and document the caching strategy.

## Consequences
-   **Benefits:**
    -   **Accelerated Development Cycle:** Automation of BRD analysis, architecture planning, and test generation significantly reduces the time from requirement definition to development readiness.
    -   **Enhanced Consistency and Quality:** Standardized agent outputs, explicit acceptance criteria, and a rigorous regression gate ensure higher quality and fewer errors in requirements, plans, and testing.
    -   **Improved Scalability and Efficiency:** Test sharding enables parallel testing, while caching mechanisms reduce redundant work, leading to faster execution times for complex projects.
    -   **Greater Traceability and Auditability:** Structured outputs from agents (e.g., traceable requirements, detailed plans) improve the ability to track changes and audit decisions throughout the workflow.
    -   **Early Issue Detection:** Agents are designed to identify ambiguities, conflicts, and missing requirements early, reducing costly rework in later phases.
-   **Trade-offs / Risks:**
    -   **Increased System Complexity:** The introduction of a new multi-agent workflow, caching layers, and sharding mechanisms adds significant architectural complexity, potentially increasing maintenance overhead.
    -   **Dependency on Agent Reliability:** The accuracy and quality of the generated artifacts are heavily reliant on the performance and 'intelligence' of the AI agents, posing a risk of misinterpretations or 'hallucinations'.
    -   **Resource Consumption:** Managing multiple AI agents, test shards, and maintaining caches can be resource-intensive in terms of compute, storage, and memory, especially for large-scale operations.
    -   **Configuration and Tuning Overhead:** Optimal performance requires careful configuration and continuous tuning of the new profile parameters (`max_test_agents`, `test_db_per_shard`, `context_full_refresh_every`).
