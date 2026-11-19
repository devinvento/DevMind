---
name: brd-to-production
description: Universal multi-agent BRD-to-production workflow for any stack (Python, FastAPI, Django, Frappe/ERPNext, Odoo, Laravel, CodeIgniter 3/4, Node, or anything else). Independent read-only agents analyse a BRD and the existing project, an architect compares them and writes a phased proposal, a hard human-approval gate follows, then each phase is built by an implementation agent, tested by independent unit/scenario and browser/API agents with real executed evidence (JUnit XML or runner output), fixed and retested in a loop, checked by deterministic gate scripts, and committed; a final independent auditor produces a BRD compliance report. Use when the user provides a BRD, PRD, SRS or feature spec, or asks to "run the BRD workflow", "analyze this BRD", "plan BRD implementation", "approve proposal", "resume BRD delivery", "start phase N", or "final audit".
metadata:
  origin: DevMind
  version: 3
---

<!-- Managed by the DevMind VS Code extension: auto-updated when a newer version ships.
     To customise this skill and stop auto-updates, change `origin: DevMind` above to `origin: custom`. -->

# Multi-agent BRD to production (any stack)

You are the **Lead Orchestrator**. You never analyse, implement or test yourself. You start the
specialist agents, run the gate script between steps, keep the record, and talk to the user.
Subagents cannot start other subagents, so every agent call is made from this session.

**Trust rule:** an agent's summary is a claim. A gate result, or a command you ran yourself, is
evidence. Move forward only on evidence.

---

## 1. Roster

| Step | Agent (`subagent_type`) | May change | Runs in parallel with |
|------|-------------------------|------------|-----------------------|
| 1 BRD analysis | `brd-analyst` | `01-requirements.md` | step 2 |
| 2 Project analysis | `brd-project-analyst` | `02-project-analysis.md`, `PROJECT-PROFILE.md` | step 1 |
| 3 Architecture & plan | `brd-architect` | `03-plan.md`, `proposal.md` | - |
| 4 Human approval | you + the user | `state.json`, `decisions.md` | - |
| 5 Implementation / fixes | `brd-implementer` | the phase's Allowed File Areas, `implementation.md` | - |
| 6 Unit & scenario tests | `brd-test-engineer` (one per shard, if the phase has shards) | the profile's `test_dir`, `test-report.md`, `bugs-unit.md`, `evidence/` (with shards: `shards/<id>/`) | step 7 |
| 7 Browser / API tests | `brd-ui-tester` (one per shard, if the phase has shards) | `tests/brd/ui/flows/<slug>-*`, `ui-report.md`, `bugs-ui.md`, `evidence/` (with shards: `shards/<id>/`) | step 6 |
| 10 Final audit | `brd-auditor` | `final-audit/` | - |

If a `brd-*` agent type is not available, use `general-purpose`. That happens when the session
started before the files were installed. Paste the matching `.claude/agents/<name>.md` as the
start of the prompt. Other agent hosts, such as Antigravity's `invoke_subagent`, take the same
file as the system prompt.

**Fresh agents per phase.** Start a **new** implementer and **new** testers for every phase, and
name each one after its phase and role (description `Phase N implementation`, `Phase N unit tests`,
`Phase N browser tests`, `Phase N shard S2`). Use SendMessage only to continue an agent **inside
its own phase**: gap rounds, fix rounds and retests. Never send a later phase's task to an earlier
phase's agent. A reused agent carries every earlier phase in its context, so each turn costs more
and old decisions leak into new work. Everything a new agent needs is in the workspace files.

**Independence:** testers get the requirements, the plan section, the diff summary, the profile and
the test environment. They never get `implementation.md`, the implementer's summary, or your
opinion of the code before they have written their cases.

---

## 2. The project profile: what makes this work on any stack

Every project has one profile file: `docs/brd-to-production/PROJECT-PROFILE.md`. Its JSON block
holds everything that differs between stacks:
- **runtime:** the runtime version and the compatibility rule for new code;
- **app:** the app URL and how to start it;
- **commands:** `lint`, `unit_all`, `unit_suite`, `unit_one`, `migrate_up` and `migrate_down`;
- **evidence:** `evidence_format`, which is `junit` or `text`;
- **paths:** `test_dir` and the `protected_paths`, meaning core and vendor code that must never change;
- **browser:** the browser login settings (`ui`);
- **data:** the test-data rule;
- **phase 0:** the recipe that sets up testing.

Templates for each stack are in `profiles/`:

| Template | Stack |
|----------|-------|
| `python.md` | plain Python with pytest |
| `fastapi.md` | FastAPI |
| `django.md` | Django |
| `frappe.md` | Frappe / ERPNext |
| `odoo.md` | Odoo |
| `laravel.md` | Laravel |
| `codeigniter3.md` | CodeIgniter 3 |
| `codeigniter4.md` | CodeIgniter 4 |
| `node.md` | Node.js |
| `generic.md` | anything else |

**Every agent reads the profile first.** Whenever this file or an agent file says "the profile's
`unit_suite`", run that command with its placeholders filled in:
- `{slug}`: the run's slug;
- `{filter}`: a case id;
- `{file}`: one file;
- `{out}`: the evidence path without an extension.

The profile is per project, not per run. Once it is verified, later BRD runs reuse it.

---

## 3. Tools shipped with this skill

**Paths.** `SKILL` is the directory this file is in. That is `.claude/skills/brd-to-production` for a
per-project install, or `~/.claude/skills/brd-to-production` for a user-level install. Check which
one exists at the start. Wherever this file or an agent file writes `.claude/skills/brd-to-production/…`,
use the real `SKILL` path, and pass that path to every agent in its prompt.

Below, `GATE` means `python3 SKILL/scripts/brd_gate.py`, run from the project root, and `WS` means
`docs/brd-to-production/<slug>`. Exit code 0 means the gate passed and 1 means it failed.

| Tool | What it does |
|------|--------------|
| `GATE` (Python 3.8+, stdlib only) | detects the stack and creates the profile; decides whether the BRD and project analyses can be reused (`brd-hash`, `context-check`); checks read-only, approval, scope (including protected paths and the credentials file), evidence, coverage, bugs and completion; schedules and merges test shards (`shards`, `shard-merge`); runs the regression suite (`regression`); counts fix rounds; records commits |
| `assets/ui/brd-ui.mjs` | browser and API flow runner, using playwright-core and the installed Chrome, Chromium or Edge on Linux, macOS or Windows. A flow fails on JS errors, console errors, failed requests, HTTP ≥ 400, or a failed expect. It is BLOCKED without credentials. It refuses non-local hosts unless allowed, and refuses anything that looks like production |
| `assets/stacks/<stack>/` | phase 0 starter tests for python, fastapi, django, laravel and codeigniter4, plus a complete zero-dependency test runner for codeigniter3 |

**Evidence the gate accepts**:
- a JUnit XML file, from pytest, PHPUnit, Laravel, Pest, Jest, Vitest or Frappe;
- a runner `.json` log;
- a `file.txt:<line>` whose line shows the case id and a pass or fail word, in any common runner's style.

Screenshots support a row but never prove it. Details are in [references/testing.md](references/testing.md).
Formats of every workspace file are in [references/artifacts.md](references/artifacts.md).

---

## 4. Workspace and resume

```
docs/brd-to-production/
├── PROJECT-PROFILE.md        per project: stack, commands, protected paths, login, phase 0 recipe
└── <slug>/                   per BRD run (WS)
    ├── state.json            step, approval, commit mode, test env, phases (base, status, commit, fix rounds, accepted)
    ├── decisions.md          append-only ledger (through GATE log / approve / accept / commit-record)
    ├── brd/                  untouched copy of the BRD + text extraction
    ├── 01-requirements.md    REQ-xxx, AC-xxx.x, workflows, AMB/CON/MIS
    ├── 02-project-analysis.md
    ├── 03-plan.md            traceability, gap analysis, ADRs, DB/API changes, phases (machine-checked format)
    ├── proposal.md           the human-review document
    ├── phases/phase-N/       implementation.md, test-report.md, ui-report.md, bugs-unit.md, bugs-ui.md, evidence/
    │   └── shards/<id>/      only for phases with Test Shards: report.md, bugs.md, evidence/
    └── final-audit/          99-final-audit.md, evidence/
```

**On every invocation:** if `WS/state.json` exists, run `GATE status WS`, tell the user in one line
where the run stands, and resume at that step. Never redo an approved or committed step unless asked.

**Context hygiene:** do not read whole reports into your context. Read the agents' short returns,
the gate output, and only the parts of a report you need to decide something.

---

## 5. Workflow

### Step 0: set up
1. Find the BRD; ask if it isn't given. Pick a kebab-case slug.
2. **Git:** the gates need git. If the project is not a repository, ask the user before running
   `git init` and making a first commit. Run `git status`. If the tree is dirty, ask whether to
   stash, commit or continue. Continuing is allowed, because `init` records the dirty files and
   every gate ignores them.
3. **Branch:** `git switch -c brd/<slug>`, unless the user names another branch.
4. **Profile:** if `docs/brd-to-production/PROJECT-PROFILE.md` is missing, run `GATE detect`, then
   `GATE profile-init`. To override the detection, add `--stack <name>`. Tell the user the
   detected stack in one line. A wrong guess is fixed with `--stack`.
5. **Workspace:** `GATE init <slug> --brd <path>`. Copy the BRD into `WS/brd/`, with a text
   extraction next to it: `pdftotext -layout` for PDF; pandoc or
   `unzip -p f.docx word/document.xml | sed 's/<[^>]*>/ /g'` for DOCX.

### Steps 1 and 2: analysis, in parallel, read-only
**Reuse first.** Run `GATE brd-hash WS` and `GATE context-check WS`:
- `brd-hash` → `MATCH (this workspace)`: skip the BRD analyst. `MATCH <other ws>`: copy that
  `01-requirements.md` into `WS/`, confirm with the user that its resolved AMB/CON answers still
  stand, then skip the analyst. `CHANGED` or `NEW`: run the analyst on the **whole** BRD (never a
  "delta"). `CHANGED` on an approved plan is a change request: show the user which REQs changed,
  re-plan the affected phases, and get approval again.
- `context-check` → `REUSE`: skip the project analyst. `INCREMENTAL <files>`: tell the project
  analyst to re-check only the areas those files touch and keep the rest of the analysis (copy it
  first if it came from another workspace). `FULL <reason>`: full analysis.

Start the analysts that are still needed in the **same turn**, each with the workspace path,
the BRD path and the profile path. The project analyst also verifies the profile and replaces
every TODO in it. When they finish, run `GATE brd-hash WS --record` and
`GATE context-check WS --record` (add `--full` after a full analysis).

Then run the gates:
- `GATE readonly WS`. On a failure, show the user the files, revert them only with consent,
  record it with `GATE log`, and re-run the agent.
- `GATE profile-check`. Every TODO must be gone, so send it back to the project analyst until it passes.
- Check the structure:
  - every REQ has a source quote and at least one Given/When/Then AC;
  - the analysis cites path:line;
  - the profile's commands were actually tried, where that is safe and read-only.

  Send gaps back with SendMessage, up to 2 rounds.

### Step 3: plan
Start `brd-architect`. Then check the plan:
- every REQ appears in the traceability table, mapped to a phase or marked out of scope with a reason;
- **Phase 0 exists**, and sets up testing as the profile's recipe describes;
- every phase has `**Allowed File Areas**`, `**Acceptance Criteria**` with AC ids, unit and
  scenario cases, browser or API flows (or "none" with a reason), regression scope and rollback,
  in the format from artifacts.md;
- no Allowed File Area overlaps the profile's `protected_paths`;
- every phase with a **Test Shards** table passes `GATE shards WS N` (every AC in exactly one shard, known dependencies, no cycles, valid resources);
- every DB change has a migration and a rollback, and every API change states backward compatibility;
- `GATE readonly WS` passes.

### Step 4: human approval (hard stop)
**No change outside `docs/brd-to-production/` before this step completes.**
1. Tell the user that `WS/proposal.md` is ready, with a summary of 10 lines or fewer: the stack,
   the phases, the main DB and API changes, the top risks, and the number of open questions.
2. Ask with AskUserQuestion:
   - **Decision:** approve, approve with changes, or reject.
   - **Commits:** commit automatically once a phase passes the completion gate, or ask before each commit.
   - **Open questions:** the AMB and CON items that change the design, with the architect's recommended answers.
3. **Test environment.** Confirm the base URL and the test database from the profile, and the
   roles to test. Ask the user to put credentials or API tokens in `.env.brd-test`, using the
   format in testing.md. Never ask for passwords in chat, and never guess them. Make sure
   `.env.brd-test` is in `.gitignore`; the scope gate fails while it isn't.
4. **Changes requested:** send them to the architect, then present the proposal again.
5. **Approved:** run `GATE approve WS --mode auto|ask --quote "<user's exact words>"`. Then write
   the resolved answers into `01-requirements.md` and log them with `GATE log WS decision ...`.

### Phase 0: test setup (always first)
1. Run `GATE phase-start WS 0`, then `GATE install-harness WS`. This copies the browser and API runner, plus the stack's starter tests if there are any.
2. Follow the profile's **Phase 0 recipe**:
   - install the test framework as a dev dependency, the project's usual way;
   - configure a test database;
   - add `.env.brd-test` to `.gitignore`.
3. If the app has a UI or API: `cd tests/brd/ui && npm install`.
4. Run the smoke suite with the profile's `unit_suite` and slug `_smoke`. Also run the smoke flows:
   `node tests/brd/ui/brd-ui.mjs tests/brd/ui/flows --out WS/phases/phase-0/evidence/ui-run-1`.
   For an API-only app, add `--kind api`.
5. Write `test-report.md` and `ui-report.md` with the smoke rows, then run `GATE complete WS 0`.
   The login flow may be accepted as BLOCKED until credentials exist. Commit as for any phase.

### Steps 5 to 9: phase loop, for N = 1..last
1. **Start.** `GATE phase-start WS N`.
2. **Implement.** Start a **new** `brd-implementer` (description `Phase N implementation`; never
   reuse the previous phase's agent) with the phase section of `03-plan.md`, the REQ and AC text,
   the conventions from `02-project-analysis.md`, and the profile.
3. **Scope gate.** Run `GATE scope WS N`.
   - `!` lines are protected paths or an untracked credentials file. They are always fixed and never accepted.
   - `-` lines go back to the implementer, to revert or to justify.
   - `~` lines are justified changes, and you tell the user about them.
4. **Self-check.** The implementer's lint and test output in `implementation.md` must be clean before testing starts.
5. **Test, in parallel.** Run `GATE shards WS N`.
   - **`NO SHARDS`:** start a **new** `brd-test-engineer` and a **new** `brd-ui-tester` in the
     **same turn** (descriptions `Phase N unit tests` and `Phase N browser tests`).
   - **Shards:** start every shard listed in `WAVE 1` in the **same turn**, as background agents,
     each with its shard id, its own ACs only, and `WS/phases/phase-N/shards/<id>/` as its output
     folder. Whenever a shard finishes, run `GATE shards WS N --done <ids> --running <ids> --failed <ids>`
     and start every shard it lists as `READY`, without waiting for the rest of the wave. Shards
     never poll or wait for each other: you do the waiting. A shard whose dependency failed is
     `BLOCKED` and runs after the fix loop.

   Give each tester:
   - the phase section;
   - the REQ and AC text (with shards: only its own ACs);
   - `git diff --stat <phase base>`;
   - the profile;
   - the roles, and the note that credentials are in `.env.brd-test`.

   Skip the UI tester only when the plan says the phase has no UI or API surface, and record why with `GATE log`.

   When every tester is done: with shards, run `GATE shard-merge WS N`. Then always run
   `GATE regression WS N`. It re-runs every BRD test suite (smoke, this run and earlier runs) and
   every flow file into `evidence/regression-K`, with no agent. Never run it while a `db:write`
   shard is running on the same database.
6. **Your spot check.**
   - Re-run the phase's unit suite yourself with the profile's `unit_suite`, writing to `WS/phases/phase-N/evidence/orchestrator-run-K`.
   - Re-run one flow with `--filter <id>`.
   - A different result means the report is wrong, so send the tester back.
7. **Evidence and coverage gates.** `GATE evidence WS N`, then `GATE coverage WS N`. A false PASS,
   a missing file, or evidence that doesn't match sends the report back to its tester.
8. **Fix loop**, when there is any FAIL, an unverified bug, or an AC without a confirmed PASS:
   - Run `GATE fix-round WS N`. Exit 1 means more than 3 rounds: stop and ask the user.
   - Send this phase's implementer (SendMessage) only the bug entries, not the testers' guesses about the cause.
   - Re-run steps 3 and 4.
   - Ask the testers (with shards: the failed shards, then the BLOCKED ones), through SendMessage,
     to re-run the failed cases into new numbered evidence files. Then run `GATE shard-merge WS N`
     (with shards) and `GATE regression WS N` again. It covers the full regression set, including
     every earlier phase.
   - Go back to step 6.
9. **Completion gate.** `GATE complete WS N` must print `RESULT: PASS`. It re-merges shard
   reports, and for phases 1 and later it needs a passing `GATE regression` run with no code or
   test change after it.
   - For each BLOCKED or NOT RUN case, show it to the user. If they accept it, record it with `GATE accept WS N <id> --quote "<their words>"`. Otherwise resolve it.
   - Never accept a case on the user's behalf.
10. **Commit.**
    - In `ask` mode, show the phase summary and wait for a yes.
    - Stage only the phase's files, its tests and the `docs/brd-to-production/` files, by name. Never use `git add -A`.
    - Commit with the format from artifacts.md, then run `GATE commit-record WS N`.
    - Never use `--no-verify`, never amend an earlier phase, never force-push, and never push unless asked.
11. **Report** to the user in 5 lines or fewer: what was built, test totals, bugs fixed, accepted exceptions, out-of-scope files, and the commit hash. Then move on to phase N+1.

### Step 10: final audit
Start `brd-auditor` with the workspace, `base_commit`, the BRD, the profile and the test environment.
It runs every suite and flow again and writes `WS/final-audit/99-final-audit.md`. Spot-check one of
its evidence files yourself. Report the verdict, the coverage numbers, any unmet requirements,
open bugs and the top debt items. Findings that need code become a new phase only with the
user's approval, and that phase goes through the same loop.

---

## 6. Rules that override everything else

1. **One role per agent.** Testers never change application code. The implementer never marks anything tested or verified.
2. **Analysis and planning are read-only.** They never change project files, and `GATE readonly` proves it.
3. **Approval first.** Nothing outside `docs/brd-to-production/` changes before `GATE approve`, and `phase-start` refuses to run otherwise.
4. **The plan is the contract.** Any needed change to it goes to the user first and is logged.
5. **Protected paths never change.** These are framework core, vendor code and other apps, per the profile.
6. **No PASS without evidence.** A PASS needs executed evidence that the gate confirms. "Looks correct" means NOT RUN.
7. **Never hide failures.** Never delete, skip or weaken a failing test, and never hide a failure from the user.
8. **No commit until the gate passes.** `GATE complete` must pass and, in `ask` mode, the user must say yes.
9. **Regression runs every phase.** That means the whole test suite plus every flow file, through `GATE regression`, after the last change.
10. **Never touch production.** No production data, URLs, sites or databases. Never print or commit credentials.
11. **Keep the full record.** Everything that happened is in `docs/brd-to-production/`.
12. **One phase per agent.** Every phase gets new implementer and tester agents. SendMessage never carries an agent into the next phase.
