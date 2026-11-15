# Project profile: Frappe / ERPNext
<!-- Created by brd_gate.py profile-init. The project analyst verifies every value against the real
project in step 2 and replaces every TODO. The gate script reads the JSON block: keep it valid JSON.
Placeholders used in commands: {file} one file, {slug} the run slug, {filter} a case id, {out} the evidence
path without extension (for example docs/brd-to-production/<slug>/phases/phase-2/evidence/unit-run-3). -->

```json
{
  "stack": "frappe",
  "language": "python",
  "runtime": "TODO: Frappe/ERPNext version (bench version) and Python version",
  "runtime_rule": "Use only APIs of the installed Frappe major version. All changes live in a custom app, never in frappe or erpnext.",
  "app_url": "TODO: http://<site>:8000 (bench start) or the docker site URL",
  "run_app": "bench start",
  "site": "TODO: a TEST site, e.g. test_site (never the production site)",
  "custom_app": "TODO: name of the custom app that receives all changes",
  "evidence_format": "junit",
  "max_test_agents": 4,
  "test_db_per_shard": false,
  "context_full_refresh_every": 5,
  "commands": {
    "lint": "python -m py_compile {file}",
    "unit_all": "bench --site <test_site> run-tests --app <custom_app> --junit-xml-output {out}.xml > {out}.txt 2>&1",
    "unit_suite": "bench --site <test_site> run-tests --app <custom_app> --module <custom_app>.tests.brd_{slug} --junit-xml-output {out}.xml > {out}.txt 2>&1",
    "unit_one": "bench --site <test_site> run-tests --app <custom_app> --test {filter} --junit-xml-output {out}.xml > {out}.txt 2>&1",
    "migrate_up": "bench --site <test_site> migrate",
    "migrate_down": "none: Frappe has no down-migrations; plan a reverse patch and a site backup (bench --site <test_site> backup) before each phase"
  },
  "test_dir": "apps/<custom_app>/<custom_app>/tests/brd_{slug}",
  "ui": {"enabled": true, "login_path": "/login", "user_selector": "#login_email", "pass_selector": "#login_password", "submit_selector": ".btn-login", "failed_url_re": "/login"},
  "protected_paths": ["apps/frappe/", "apps/erpnext/", "apps/hrms/", "apps/payments/", "env/", "sites/*/site_config.json", "sites/common_site_config.json"],
  "test_data_rule": "Run tests only on a test site with allow_tests enabled. IntegrationTestCase/FrappeTestCase roll back per test; use frappe.generate_hash() for names."
}
```

## Phase 0 recipe
1. Confirm a separate test site exists, or ask the user before creating one with `bench new-site`. Then run `bench --site <test_site> set-config allow_tests true`.
2. Create `<custom_app>/tests/__init__.py` and `<custom_app>/tests/brd__smoke/test_brd_smoke.py`:
   ```python
   import frappe
   try:                                   # Frappe v15+ (v16 confirmed)
       from frappe.tests import IntegrationTestCase as BaseCase
   except ImportError:                    # Frappe v14
       from frappe.tests.utils import FrappeTestCase as BaseCase

   class TestBrdSmoke(BaseCase):
       def test_TC_0_01_site_connects(self):
           self.assertTrue(frappe.db.sql("select 1"))
   ```
3. Run it with `--module <custom_app>.tests.brd__smoke.test_brd_smoke`.

## Conventions
- **Where changes go:** DocTypes and Custom Fields go in the custom app. Use fixtures, or `custom_fields` in `hooks.py`.
- **Where logic goes:** use `doc_events` in `hooks.py`, controllers in `<doctype>.py`, or `override_doctype_class`.
- **Schema changes:** these are DocType JSON plus `patches.txt` entries.
- **Permissions:** Role Permission Manager, `has_permission` hooks and User Permissions. Test with users of different roles, using `frappe.set_user(...)` in tests.
- **Browser flows:** desk pages are at `/app/<doctype>`. Wait for `frappe.ready` and the network to go idle. Frappe shows server errors in modals, so assert that no `.modal.show .msgprint` error is visible.
