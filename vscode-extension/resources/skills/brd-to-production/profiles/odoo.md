# Project profile: Odoo
<!-- Created by brd_gate.py profile-init. The project analyst verifies every value against the real
project in step 2 and replaces every TODO. The gate script reads the JSON block: keep it valid JSON.
Placeholders used in commands: {file} one file, {slug} the run slug, {filter} a case id, {out} the evidence
path without extension (for example docs/brd-to-production/<slug>/phases/phase-2/evidence/unit-run-3). -->

```json
{
  "stack": "odoo",
  "language": "python",
  "runtime": "TODO: Odoo version (odoo-bin --version) and Python version",
  "runtime_rule": "Use only the ORM/API of the installed Odoo major version. All changes live in custom addons, never in odoo/addons core.",
  "app_url": "http://localhost:8069",
  "run_app": "TODO: ./odoo-bin -c odoo.conf, or the docker compose service",
  "database": "TODO: a TEST database name (never production)",
  "custom_addon": "TODO: the custom addon that receives all changes",
  "evidence_format": "text",
  "max_test_agents": 4,
  "test_db_per_shard": false,
  "context_full_refresh_every": 5,
  "commands": {
    "lint": "python -m py_compile {file}",
    "unit_all": "./odoo-bin -c odoo.conf -d <test_db> -u <custom_addon> --test-enable --test-tags /<custom_addon> --stop-after-init --log-level=test > {out}.txt 2>&1",
    "unit_suite": "./odoo-bin -c odoo.conf -d <test_db> -u <custom_addon> --test-enable --test-tags /<custom_addon>:TestBrd --stop-after-init --log-level=test > {out}.txt 2>&1",
    "unit_one": "./odoo-bin -c odoo.conf -d <test_db> -u <custom_addon> --test-enable --test-tags /<custom_addon>:TestBrd.{filter} --stop-after-init --log-level=test > {out}.txt 2>&1",
    "junit_alternative": "python -m pytest --odoo-database=<test_db> <addon>/tests -v --junitxml={out}.xml   (pytest-odoo plugin)",
    "migrate_up": "./odoo-bin -c odoo.conf -d <test_db> -u <custom_addon> --stop-after-init",
    "migrate_down": "none: restore the test DB backup taken before the phase; data changes go in migrations/<version>/pre-|post-*.py"
  },
  "test_dir": "<custom_addon>/tests",
  "ui": {"enabled": true, "login_path": "/web/login", "user_selector": "input[name=\"login\"]", "pass_selector": "input[name=\"password\"]", "failed_url_re": "/web/login"},
  "protected_paths": ["odoo/", "addons/", "odoo-bin", "*/site-packages/*"],
  "test_data_rule": "TransactionCase rolls back each test. Run only on a test database."
}
```

## Phase 0 recipe
1. Make sure a test database exists. Ask the user before creating one.
2. Add `<custom_addon>/tests/__init__.py`, importing `test_brd_smoke`, and `test_brd_smoke.py`:
   ```python
   from odoo.tests.common import TransactionCase, tagged

   @tagged('post_install', '-at_install')
   class TestBrd(TransactionCase):
       def test_TC_0_01_env_works(self):
           self.assertTrue(self.env['res.users'].search_count([]) > 0)
   ```
3. **Evidence:** run with `--log-level=test`. Odoo prints `FAIL: test_TC_0_01...` or `ERROR: ...` for failures, but prints no per-test PASS line. So either:
   - use the pytest-odoo command in `junit_alternative` and set `evidence_format` to `junit` (preferred); or
   - cite the log's summary line `0 failed, 0 error(s) of N tests` for each case. In that case the gate cannot confirm cases one by one, so the test report must say so and the orchestrator re-runs the suite itself.

## Conventions
- **Models:** inherit with `_inherit`. Views use `<xpath>` inheritance. Never copy core views.
- **Access rights:** `security/ir.model.access.csv` and record rules (`ir.rule`). Test them with `with_user(user)` and with `AccessError` expected.
- **Version bumps:** bump `__manifest__.py` `version` when the data model changes.
