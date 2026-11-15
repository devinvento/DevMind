# brd-to-production

This is a multi-agent Claude Code skill. It takes a business requirements document (BRD) to
committed, independently tested code, one phase at a time. You approve the plan before any code
changes, and a final audit checks the result.

It works on any stack. A per-project profile holds everything that differs between stacks.
Templates are included for these:

| Template | Stack |
|----------|-------|
| `python` | plain Python with pytest |
| `fastapi` | FastAPI |
| `django` | Django |
| `frappe` | Frappe / ERPNext |
| `odoo` | Odoo |
| `laravel` | Laravel |
| `codeigniter3` | CodeIgniter 3 |
| `codeigniter4` | CodeIgniter 4 |
| `node` | Node.js |
| `generic` | anything else |

## Install

You can unzip it into one project or into your user folder.

**One project.** Unzip it in the project root:
```
unzip brd-to-production.zip -d /path/to/project
# → .claude/skills/brd-to-production/  and  .claude/agents/brd-*.md
```

**Every project on this machine.** Unzip it into your home folder:
```
unzip brd-to-production.zip -d ~
# → ~/.claude/skills/brd-to-production/  and  ~/.claude/agents/brd-*.md
```

Both installs work. The orchestrator checks where the skill lives and passes that path to the agents.

Start a new Claude Code session afterwards, so the agents are loaded.

## Requirements

| Tool | Needed for | Notes |
|------|------------|-------|
| Claude Code | everything | CLI, desktop app or IDE extension |
| Git | every gate | the project must be a git repository |
| Python 3.8+ | the gate script | standard library only, on any project, whatever its language |
| Node.js 18+ | browser and API flows | `npm install` in `tests/brd/ui`, done in phase 0 |
| Chrome, Chromium or Edge | browser flows | found automatically on Linux, macOS and Windows, or set `CHROME_PATH` |
| The project's own runtime | unit tests | Python, PHP, Node, bench or odoo-bin, at the production version |

**Windows:** use WSL, or Git Bash plus Python.

## Use

```
/brd-to-production path/to/BRD.pdf
```

The workflow runs these steps:
1. It detects the stack and creates `docs/brd-to-production/PROJECT-PROFILE.md`.
2. It analyses the BRD and the project, read-only.
3. It writes a plan and a proposal. **It then stops for your approval.**
4. Phase 0 sets up testing.
5. Each phase goes through: implement, independent unit and browser or API tests, gate checks, fixes, retests, commit.
6. A final audit writes a compliance report.

Every requirement, decision, test run, bug and commit is recorded under `docs/brd-to-production/<slug>/`.

## Test credentials

The browser tests read logins from `.env.brd-test` in the project root. Keep this file out of git,
because the gates refuse to continue while it is tracked:

```
BRD_USER_ADMIN=...
BRD_PASS_ADMIN=...
BRD_TOKEN_CASHIER=...      # for API flows
```

## What has been verified

| Stack | What was run | Result |
|-------|--------------|--------|
| FastAPI | detection; pytest JUnit evidence; live API flows with a token; a full bug, fix and retest loop through the completion gate | passed |
| Django | detection; pytest-django smoke tests; a real browser login to Django admin, with missing, wrong and right credentials | passed |
| CodeIgniter 3 | the shipped runner on PHP 7.4: pass, fail, error and skip, rollback, web access refused, unknown DB host refused | passed |
| PHPUnit and Jest | the evidence parser, on JUnit files in their documented formats (hand-written, not real runs) | passed |

Frappe, Odoo, Laravel, CodeIgniter 4 and Node have profile templates and recipes, but no live test run yet.
For Frappe, the `bench run-tests` options and the test base class were checked on a real ERPNext v16 install.
