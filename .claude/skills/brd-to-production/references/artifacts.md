# Workspace Artifact Formats & Specifications

All files reside in `docs/brd-to-production/<slug>/`.

---

## 1. `state.json` (state machine)
Created by `GATE init`, changed only through `GATE` commands, plus `test_env`, which you fill in at approval. Never edit phase statuses by hand.

```json
{
  "slug": "loyalty-system",
  "brd": "docs/brd-to-production/loyalty-system/brd/Loyalty_BRD_v2.docx",
  "created_at": "2026-11-09T10:00:00+06:00",
  "base_commit": "f2813221",
  "branch": "brd/loyalty-system",
  "preexisting_dirty": [],
  "step": "phase-2",
  "approved": true,
  "approved_at": "2026-11-09T10:15:00+06:00",
  "commit_mode": "ask",
  "test_env": {"base_url": "http://127.0.0.1:8000", "roles": ["admin", "cashier", "manager"], "env_file": ".env.brd-test"},
  "phases": [
    {"n": 0, "title": "Test harness", "status": "committed", "base": "f2813221...", "commit": "1a2b3c4", "fix_rounds": 0, "accepted": ["UI-0-02"]},
    {"n": 1, "title": "Schema and models", "status": "committed", "base": "1a2b3c4...", "commit": "3b2c1a0", "fix_rounds": 1, "accepted": []},
    {"n": 2, "title": "Point calculation", "status": "fixing", "base": "3b2c1a0...", "commit": null, "fix_rounds": 2, "accepted": []}
  ]
}
```
Phase status: `planned`, `implementing`, `fixing`, `verified` (set by `GATE complete`), `committed` (set by `GATE commit-record`).

---

## 2. `01-requirements.md` (BRD Analysis Output)
Structured testable requirements parsed from the BRD.

### Summary Matrix
| ID | Category | Priority | Summary | Source Reference |
|----|----------|----------|---------|------------------|
| REQ-001 | Business | Must | Increase repeat customer retention | BRD §1.2 |
| REQ-002 | Functional | Must | Accrue 1 point per 100 BDT spent | BRD §3.1 |
| REQ-003 | Technical | Must | Sub-50ms point calculation overhead | BRD §5.2 |
| REQ-004 | Constraint | Must | Zero points on discounted items | BRD §3.4 |

### Requirement Specification Detail
```markdown
### REQ-002: Customer Point Accrual on Completed Sale
- **Source**: BRD §3.1, page 5 ("Customers shall earn 1 loyalty point for every 100 BDT spent on net sale total.")
- **Category**: Functional
- **Priority**: Must (MoSCoW)
- **Actors**: Cashier, Customer, POS Terminal
- **Preconditions**: Customer profile attached to sale; sale status is completed.
- **Business Rule**: `points = floor(net_subtotal / 100)`. Excludes tax and shipping.
- **Dependencies**: REQ-004 (discount exclusions), REQ-001.
- **Acceptance Criteria**:
  - `AC-002.1`: Given a sale of 1,250 BDT with an attached customer, when checkout is completed, then 12 loyalty points are credited to the customer account.
  - `AC-002.2`: Given a sale of 1,250 BDT without an attached customer, when completed, then zero points are credited.
  - `AC-002.3`: Given a sale containing a 100% discounted item, when completed, then no points accrue for that item.
```

### Workflows & User Journeys
Step-by-step user/system flow diagrams (text or mermaid):
- Workflow 1: Customer Point Accrual at Register
- Workflow 2: Loyalty Tier Elevation
- Workflow 3: Point Reversal on Item Return

### Clarifications, Gaps & Conflicts
- **Ambiguities (`AMB-xx`)**: Missing unit/precision, undefined boundary condition, unclear rounding rule.
- **Conflicts (`CON-xx`)**: Contradictory statements between sections (e.g., BRD §2 vs BRD §4).
- **Missing Requirements (`MIS-xx`)**: Unspecified edge conditions (refund handling, multi-currency conversion, concurrency, authorization roles, audit logging).

---

## 3. `02-project-analysis.md` (Existing Project Analysis Output)
Deep dive into the current application architecture and codebase (strictly read-only).

1. **Stack & System Environment**: language and runtime versions (dev vs production), framework and version, database engine and version, web server, cache, queues. Must agree with PROJECT-PROFILE.md.
2. **Directory & Module Map**: Directory structure, core modules relevant to the BRD with file paths.
3. **Database Schema & Models**: Existing tables, relationships, indexes, migrations mechanism.
4. **APIs, Routes & Controllers**: Relevant HTTP endpoints, authentication mechanism, payload formats.
5. **Existing Workflows**: How current features work under the hood (e.g. cart calculation, checkout sequence).
6. **Reusable Components & Utilities**: Existing helpers, service classes, models, and UI templates that can be leveraged without rewriting.
7. **Technical Limitations & Architectural Issues**: Code coupling, global states, deprecated methods, slow queries.
8. **Known Bugs & Technical Debt**: Existing issues in the affected code area (`path/to/file.php:line`).
9. **Project Conventions & Rules**: Layering conventions, naming standards, migration rules, security rules.
10. **Application & Test Run Commands**: Exact shell commands to run the web server, queue workers, migrations, and test suites.

---

## 4. `03-plan.md` (Architecture, Gap Analysis & Phased Plan)
The formal technical blueprint and contract.

1. **BRD vs. Current Project Comparison**: Side-by-side comparison table.
2. **Gap Analysis**:
   - *Missing Features*: Brand new tables, endpoints, and logic needed.
   - *Required Modifications*: Existing methods and views that must be safely extended.
   - *Reusable Functionality*: Existing components used as-is.
3. **Architecture Decisions (ADRs)**: Context, Decision, Consequences for each major technical choice.
4. **Database Changes**: Tables added/modified, migration file names, reversible rollback SQL, data backfill strategy.
5. **API Changes**: Endpoints added/altered, request/response contracts, backward compatibility guarantees.
6. **Dependencies & Risks**: Third-party services, performance bottlenecks, mitigation strategies.
7. **Phase-by-Phase Plan.** The gate script parses these fields, so keep the heading `## Phase N: <title>` and the bold field names exactly as shown. Glob entries go in backticks. A trailing `/` means the whole directory. `*` matches across folders. Phase 0 is always the test setup from the profile's recipe. The paths below are examples: use your stack's layout.
```markdown
## Phase 0: Test harness
- **Goal**: Install the brd-to-production test harness and prove it runs.
- **REQ IDs Covered**: none (infrastructure)
- **Allowed File Areas**:
  - `.gitignore`
  - (plus any test config the profile recipe needs, e.g. `pytest.ini`, `phpunit.xml`, `application/controllers/Brd_test_runner.php`)
  - `tests/brd/`
  - `.gitignore`
- **Acceptance Criteria**:
  - `AC-P0.1`: smoke unit suite passes with the profile's `unit_suite` on the production runtime version.
  - `AC-P0.2`: login page smoke flow passes with no console errors.
- **Unit & Scenario Tests**: TC-0-01..04 (shipped smoke suite).
- **Browser / UI Flows**: UI-0-01, UI-0-02.
- **Regression Scope**: none.
- **Rollback**: delete the files listed above.

## Phase 1: Schema & data models
- **Goal**: Loyalty tables and data access layer.
- **REQ IDs Covered**: REQ-002, REQ-004
- **Deliverables**: Migration `20261109110000_create_loyalty_tables.php`, model `Loyalty.php`.
- **Allowed File Areas**:
  - `loyalty/migrations/0002_*.py`
  - `loyalty/models.py`
  - `loyalty/services/points.py`
- **Acceptance Criteria**:
  - `AC-002.1`: (copied from 01-requirements.md)
  - `AC-P1.1`: migration up() and down() both run cleanly and down() restores the schema.
- **Unit & Scenario Tests**: TC-1-01 balance for new customer; TC-1-02 unknown customer id; ...
- **Browser / UI Flows**: none (no UI in this phase).
- **Regression Scope**: customers CRUD, sale completion (existing flows).
- **Rollback**: `php index.php migrate version <previous>`; delete files.
```
Every AC listed under **Acceptance Criteria** must end up with an evidence-confirmed PASS row, or with a case the user accepted. That is what `GATE coverage` and `GATE complete` check.

   **Test Shards (optional).** For a phase with more than 3 ACs or several independent flows, split the testing into shards so more testers run in parallel. Smaller phases leave it out: each shard re-reads the phase, so two testers are faster there. Put the table right under its bold field, inside the phase:
```markdown
- **Test Shards**:

| id | agent | ACs | depends_on | resources |
|----|-------|-----|------------|-----------|
| S1 | brd-test-engineer | AC-002.1, AC-002.2 | - | none |
| S2 | brd-test-engineer | AC-004.1 | - | db:write |
| S3 | brd-ui-tester | AC-001.3 | - | server, db:read |
| S4 | brd-ui-tester | AC-005.1 | S3 | server, db:write |
```
   - **ACs:** every AC of the phase belongs to exactly one shard.
   - **depends_on:** shard ids that must PASS first (S4 needs the login flow of S3), or `-`.
   - **resources:** `none`, `db:read`, `db:write`, `server`, `fixtures:<name>`. Two shards that write the same test DB, or one writing while another reads it, never run together. The profile's `test_db_per_shard: true` lifts that only for shards without `server`, because the app server has a single DB. Two shards with the same `fixtures:<name>` never run together.
   - `GATE shards WS N` checks the table and prints the waves. The profile's `max_test_agents` (default 4) caps how many run at once.
8. **Testing Strategy**: Environments, fixtures, tools, regression suite scope.

---

## 5. `proposal.md` (Human Review & Approval Document)
The complete proposal presented to the user prior to any implementation.

**Mandatory 10 Sections**:
1. Executive Summary & BRD Analysis Summary
2. Existing Project Analysis Summary
3. BRD vs. Current Project Comparison Table
4. Gap Analysis (Missing Features / Modifications / Reusable Components)
5. Proposed Architecture & Technical Approach
6. Detailed Phase-by-Phase Implementation Plan
7. Database & API Changes (with Migration & Rollback specs)
8. Dependencies, Constraints & Risk Mitigation
9. Testing Strategy, Acceptance Criteria & Evidence Protocol
10. Open Questions & Required Human Decisions

---

## 6. `phases/phase-N/implementation.md` (implementation log)
Written by `brd-implementer`. Use these bold field names, because `GATE scope` reads **Out-of-Scope Changes**:
```markdown
- **Files Changed**:
  - `loyalty/models.py` (new): balance, credit, debit, ledger.
  - `loyalty/migrations/0002_ledger.py` (new).
- **REQs & ACs Implemented**: REQ-002 (AC-002.1, AC-002.2), REQ-004 (AC-004.1)
- **Design Decisions**: ledger table instead of a balance column, because AC-004.2 needs history.
- **Out-of-Scope Changes**:
  - `sales/services.py`: one call to `credit_points()` after the sale is saved; needed for AC-002.1, no other change.
- **Migrations**: up OK, down OK, up OK (output below).
- **Self-Checks**: (commands and raw output: the profile's `lint` on every changed file, `unit_all`)
- **Known Limits**: ...
```
A changed file outside the phase's Allowed File Areas that is not listed under **Out-of-Scope Changes** fails the scope gate.

---

## 7. `phases/phase-N/test-report.md` (unit and scenario report)
Written by `brd-test-engineer`. The gate reads the table: the first column holds the case id (`TC-…`), there are columns named REQ/AC, Status and Evidence, and Status is exactly one of PASS, FAIL, BLOCKED, NOT RUN.

| Test ID | REQ / AC | Scenario Type | Description | Status | Evidence |
|---------|----------|---------------|-------------|--------|----------|
| TC-2-01 | AC-002.1 | Positive | 1,250 BDT sale earns 12 points | PASS | `evidence/unit-run-1.xml` |
| TC-2-02 | AC-002.2 | Negative | sale without customer earns 0 | FAIL | `evidence/unit-run-1.xml` BUG-2-U01 |
| TC-2-03 | AC-002.3 | Edge | 100% discounted item earns 0 | PASS | `evidence/unit-run-2.txt:5` |
| TC-2-04 | AC-REG.1 | Regression | cash checkout unchanged | PASS | `evidence/unit-run-2.txt:9` |
| TC-2-05 | AC-002.4 | Concurrency | two terminals redeem together | NOT RUN | needs two DB sessions; asked user |

- **Evidence reference:** a JUnit file (`evidence/unit-run-K.xml`), whose `<testcase>` with the case id in its name must have the same result; or a line (`evidence/<file>.txt:<line>`) containing the case id and a pass/fail word (`PASS`/`PASSED`/`ok`/`✓` or `FAIL`/`FAILED`/`ERROR`/`not ok`/`✕`). A skipped testcase never confirms PASS.
- **Retests:** use a new run file, and point the row at the newest run.
- **Header:** date, the commit or `git diff --stat` tested, environment, the exact commands.
- **Footer:** totals per status, and the regression suites run.

## 8. `phases/phase-N/ui-report.md` (browser report)
Written by `brd-ui-tester`. Same rules, with `UI-…` ids.

| Flow ID | REQ / AC | Role | Journey | Result | Evidence |
|---------|----------|------|---------|--------|----------|
| UI-2-01 | AC-002.1 | cashier | sale with customer, points on receipt | PASS | `evidence/ui-run-1/UI-2-01.json` `evidence/ui-run-1/UI-2-01-02-receipt.png` |
| UI-2-02 | AC-005.1 | cashier | open loyalty settings by direct URL | FAIL | `evidence/ui-run-1/UI-2-02.json` BUG-2-B01 |
| UI-2-03 | AC-005.2 | manager | edit earn rate | BLOCKED | no BRD_USER_MANAGER in .env.brd-test |

- The JSON log is the proof, and its `id` and `status` must match the row. A screenshot supports the row but never proves it.
- After the table, add a **Console & network** line for each flow: "0 errors", or the list of errors.

## 9. Bug files: `bugs-unit.md` (test engineer) and `bugs-ui.md` (UI tester)
There are two files, so the two testers never write to the same file in parallel. Ids are `BUG-<phase>-U<nn>` (unit) and `BUG-<phase>-B<nn>` (browser).
```markdown
### BUG-2-U01 Points granted on sale without customer
- **Found By**: brd-test-engineer, round 1
- **Severity**: High (Critical | High | Medium | Low)
- **Violated AC**: AC-002.2
- **Reproduce**: the profile's `unit_one` with `{filter}` = `TC-2-02`, e.g. `python -m pytest -k TC_2_02`
- **Expected**: 0 points.  **Actual**: 12 points credited to person_id 0.
- **Evidence**: `evidence/unit-run-1.txt:4`
- **Fix**: (brd-implementer) `loyalty/services/points.py`: return early when there is no customer.
- **Retest**: (tester) PASS in round 2, `evidence/unit-run-2.txt:4`
- **Status**: `verified`
```
Status values: `open` (tester), then `fixed` (implementer), then `verified` (tester, only after a passing retest). `deferred-by-user` is possible only with a `GATE log` entry quoting the user. `GATE bugs` and `GATE complete` fail while any bug has another status.

## 9a. Shard files: `phases/phase-N/shards/<id>/`
Only for phases with **Test Shards**. Each shard writes only inside its own folder:
- `report.md`: the same table as `test-report.md` (test engineer) or `ui-report.md` (UI tester), with only the shard's own ACs. Evidence paths are relative to the shard folder (`evidence/unit-run-1.xml`).
- `bugs.md`: bug ids carry the shard, `BUG-<phase>-<shard>-U<nn>` or `BUG-<phase>-<shard>-B<nn>`, so parallel shards never collide. `GATE bugs` reads these files directly.
- `evidence/`: the shard's run files.

`GATE shard-merge WS N` builds `test-report.md` and `ui-report.md` from the shard reports and rewrites the evidence paths to `shards/<id>/evidence/…`. Never edit the merged files: edit the shard report and merge again. `GATE complete` merges again by itself.

## 9b. Regression evidence: `phases/phase-N/evidence/regression-K/`
Written by `GATE regression WS N`, never by hand: one JUnit/text pair per test suite (`unit-smoke`, `unit-<slug>`, and earlier runs' slugs), `ui/` and `ui.txt` for the flows, and `summary.json` with the result of every run. The profile's optional `commands.regression` (with `{out}`) adds one more command, e.g. the project's own full suite. The run is recorded in `state.json` with a fingerprint of the code, and `GATE complete` refuses a run older than the last code or test change.

## 10. `decisions.md` (Immutable Ledger)
Append-only log. Write it only through `GATE log`, `GATE approve`, `GATE accept` and `GATE commit-record`, so every line has a timestamp. User approvals always quote the user's words.

```markdown
# Project Decision Log

- **2026-11-09 10:15:00** | `APPROVAL` | User approved proposal `proposal.md` with commit mode `auto`. Test environment confirmed as local Docker staging.
- **2026-11-09 10:45:00** | `SCOPE_EXCEPTION` | Added a helper to `common/formatting.py` for point formatting; shown to the user, who agreed: "ok".
- **2026-11-09 11:20:00** | `GIT_COMMIT` | Phase 1 committed as `3b2c1a0`.
```

---

## 11. `final-audit/99-final-audit.md` (BRD compliance report)
Evidence goes in `final-audit/evidence/`.
Written by `brd-auditor`:

1. **Executive Verdict**:
   - `FULLY COMPLIANT`: 100% of requirements verified with test evidence.
   - `COMPLIANT WITH APPROVED EXCEPTIONS`: All in-scope items met; documented deferrals.
   - `NON-COMPLIANT`: Unmet requirements or failing tests detected.
2. **Comprehensive Traceability Matrix**:
   - Table of every single `REQ-xxx` and `AC-xxx.x` from the original BRD mapped to its implementation file and passing test evidence.
3. **Full Suite Test Execution Summary**:
   - Aggregate runs of unit, scenario, regression, and browser test suites.
4. **End-to-End Workflow Verification**:
   - User journey audit across all roles.
5. **Code Quality, Security & Architecture Audit**:
   - Verification of SQL injection safety, permission checks, CSRF, code styling, and lack of core modifications.
6. **Technical Debt & Residual Risk Assessment**:
   - Future recommendations and maintainability review.

---

## 12. Phase commit message
```
feat(<slug>): phase N - <title>

Implements REQ-001, REQ-002 (AC-001.1..AC-002.3).
- <main change>
- <migration name, if any>

Tests: <x> unit/scenario PASS, <y> browser flows PASS, regression (all tests/brd suites) PASS.
Accepted not-run: <case ids or none>. Bugs fixed: BUG-N-U01, BUG-N-B01.
Record: docs/brd-to-production/<slug>/phases/phase-N/
```
End the message with the attribution trailer the session requires, if any.
