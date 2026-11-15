# Project profile: Python (pytest)
<!-- Created by brd_gate.py profile-init. The project analyst verifies every value against the real
project in step 2 and replaces every TODO. The gate script reads the JSON block: keep it valid JSON.
Placeholders used in commands: {file} one file, {slug} the run slug, {filter} a case id, {out} the evidence
path without extension (for example docs/brd-to-production/<slug>/phases/phase-2/evidence/unit-run-3). -->

```json
{
  "stack": "python",
  "language": "python",
  "runtime": "TODO: Python version used in production (python --version on the server)",
  "runtime_rule": "No syntax or stdlib features newer than the production Python version.",
  "app_url": "TODO or none",
  "run_app": "TODO: command that starts the app, or none for a library/CLI",
  "evidence_format": "junit",
  "max_test_agents": 4,
  "test_db_per_shard": false,
  "context_full_refresh_every": 5,
  "commands": {
    "lint": "python -m py_compile {file}",
    "unit_all": "python -m pytest tests -v --junitxml={out}.xml > {out}.txt 2>&1",
    "unit_suite": "python -m pytest tests/brd/{slug} -v --junitxml={out}.xml > {out}.txt 2>&1",
    "unit_one": "python -m pytest tests -v -k {filter} --junitxml={out}.xml > {out}.txt 2>&1",
    "migrate_up": "none",
    "migrate_down": "none"
  },
  "test_dir": "tests/brd/{slug}",
  "ui": {"enabled": false},
  "protected_paths": [".venv/", "venv/", "env/", "site-packages/", "*.egg-info/", "dist/", "build/"],
  "test_data_rule": "Use tmp_path and fixtures; never touch real files, databases or services."
}
```

## Phase 0 recipe
1. Use the project's virtualenv (`.venv`, poetry, uv or pipenv: check the README). Add `pytest` as a dev dependency the way the project manages dependencies. Never install globally.
2. Run `GATE install-harness` to copy `tests/brd/_smoke/test_brd_smoke.py`, and point `TC-0-02` at the project's main package.
3. Run `unit_suite` with slug `_smoke`. Both smoke tests must pass.

## Test naming
The case id goes in the test function name: `def test_TC_2_01_points_for_1250_sale():`. The gate matches `TC_2_01` to `TC-2-01`.
Cite the JUnit file as evidence: `evidence/unit-run-3.xml`.
