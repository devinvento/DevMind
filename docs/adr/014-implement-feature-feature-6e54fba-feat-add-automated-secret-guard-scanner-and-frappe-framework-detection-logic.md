# ADR 014: Implement Feature: FEATURE [6e54fba]: feat: add automated secret guard scanner and frappe framework detection logic

Date: 2026-11-05
Status: Accepted

## Context
The project `devmind` is an AI-powered development assistant designed to provide intelligence, automation, and security features. A critical challenge in software development is the accidental commitment of sensitive information (secrets, credentials) into version control systems, leading to severe security breaches. Additionally, accurate identification of the underlying technology stack, such as the Frappe Framework, is crucial for `devmind` to provide tailored and effective assistance.

This change addresses these two key areas by introducing an automated secret guard scanner to prevent data exposure and enhancing the detection logic for Frappe-based projects to improve the system's contextual understanding and intelligence capabilities.

## Decision
Two primary technical decisions were implemented:

1.  **Automated Secret Guard Scanner (`devmind scan`):**
    *   A new command `devmind scan` was added to `bin/devmind` to allow on-demand scanning for sensitive data.
    *   A comprehensive list of regular expressions (`SECRET_PATTERNS`) was defined to detect common secret types, including private keys, various API keys (AWS, GitHub, OpenAI, Stripe, Slack, Google, Shopify), JWTs, database connection URLs with embedded passwords, and generic hardcoded credentials.
    *   Scanning logic was implemented to operate in different modes: `--staged` (for pre-commit checks), `--pre-push` (for pre-push hooks), `--range` (for a specific commit range), and `--all` (for the entire repository).
    *   Mechanisms for managing false positives were included: a `.secretscanignore` file for project-wide exclusions and an inline `devmind:allow-secret` marker for specific lines.
    *   Performance optimization was considered for large files, specifically SQL dumps, by bypassing scanning if they exceed a defined size threshold.
    *   Preliminary detection for suspicious `import os` and `os.system` patterns was added to flag potential supply chain risks in Python files.

2.  **Enhanced Frappe Framework Detection:**
    *   A robust `has_frappe_app` function was developed to accurately identify Frappe applications. This function recursively searches for the co-existence of `hooks.py` and `modules.txt` files within a defined depth, while explicitly skipping common non-code directories (e.g., `.git`, `node_modules`, `venv`).
    *   The `get_stack_names` function, responsible for identifying the project's technology stack, was updated to leverage this new `has_frappe_app` logic for more precise Frappe detection.
    *   The `cmd_sync` function was modified to pass an environment variable `DEVMIND_SKIP_GRAPH=1` to project setup scripts, preventing redundant graph generation if the graph was already refreshed upstream, thereby optimizing the synchronization process.

## Consequences
-   **Benefits:**
    -   **Enhanced Security Posture:** Significantly reduces the risk of accidentally committing sensitive credentials, API keys, and other secrets, thereby preventing potential security breaches and data exposure.
    -   **Proactive Vulnerability Detection:** Provides developers with a powerful tool to proactively identify and rectify secret leakage before it impacts production, aligning with shift-left security principles.
    -   **Improved Project Intelligence:** More accurate detection of Frappe Framework projects enables `devmind` to offer more precise, context-aware assistance, recommendations, and automation tailored to the Frappe ecosystem.
    -   **Reduced False Positives in Frappe Detection:** The specific check for both `hooks.py` and `modules.txt` prevents incorrect identification of Frappe apps based on generic `hooks.py` files found in other Python packages.
    -   **Performance Optimization:** The `DEVMIND_SKIP_GRAPH` mechanism avoids unnecessary re-computation during synchronization, leading to faster execution of `devmind sync`.
    -   **Basic Supply Chain Risk Awareness:** The inclusion of `os.system` and `import os` checks adds a foundational layer for detecting potentially malicious code or unexpected system interactions.
-   **Trade-offs / Risks:**
    -   **Potential for False Positives in Secret Scanning:** While mechanisms for suppression exist, regular expression-based scanning can still produce false positives, requiring developer intervention to ignore, which might introduce slight friction into development workflows.
    -   **Performance Overhead for Large Scans:** Scanning entire repositories (`--all` mode) or very large diffs, despite optimizations for SQL dumps, can still be resource-intensive and might cause noticeable delays depending on project size.
    -   **Ongoing Pattern Maintenance:** The `SECRET_PATTERNS` list requires continuous maintenance and updates to detect new types of secrets or variations of existing ones, as adversaries evolve their methods.
    -   **Increased Complexity of `bin/devmind`:** The `devmind` script itself becomes larger and more complex with the addition of the scanning logic, potentially increasing its maintenance burden.
