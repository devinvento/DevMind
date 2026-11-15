# Project profile: Django
<!-- Created by brd_gate.py profile-init. The project analyst verifies every value against the real
project in step 2 and replaces every TODO. The gate script reads the JSON block: keep it valid JSON.
Placeholders used in commands: {file} one file, {slug} the run slug, {filter} a case id, {out} the evidence
path without extension (for example docs/brd-to-production/<slug>/phases/phase-2/evidence/unit-run-3). -->

```json
{
  "stack": "django",
  "language": "python",
  "runtime": "TODO: Python and Django versions in production (python -m django --version)",
  "runtime_rule": "No Python syntax or Django APIs newer than production versions.",
  "app_url": "http://127.0.0.1:8000",
  "run_app": "python manage.py runserver 8000",
  "evidence_format": "junit",
  "max_test_agents": 4,
  "test_db_per_shard": false,
  "context_full_refresh_every": 5,
  "commands": {
    "lint": "python -m py_compile {file}",
    "check": "python manage.py check && python manage.py makemigrations --check --dry-run",
    "unit_all": "python -m pytest -v --junitxml={out}.xml > {out}.txt 2>&1",
    "unit_suite": "python -m pytest tests/brd/{slug} -v --junitxml={out}.xml > {out}.txt 2>&1",
    "unit_one": "python -m pytest -v -k {filter} --junitxml={out}.xml > {out}.txt 2>&1",
    "migrate_up": "python manage.py migrate",
    "migrate_down": "python manage.py migrate <app_label> <previous_migration_name>"
  },
  "test_dir": "tests/brd/{slug}",
  "ui": {"enabled": true, "login_path": "/admin/login/", "user_selector": "input[name=\"username\"]", "pass_selector": "input[name=\"password\"]", "failed_url_re": "/login/"},
  "protected_paths": [".venv/", "venv/", "site-packages/", "*/migrations/0001_initial.py", "static/admin/"],
  "test_data_rule": "pytest-django gives each test a rolled-back transaction (django_db). It creates a separate test database; never point tests at the real DB."
}
```

## Phase 0 recipe
1. Add `pytest` and `pytest-django` as dev dependencies. Create `pytest.ini`, or the `[tool.pytest.ini_options]` section of `pyproject.toml`, with `DJANGO_SETTINGS_MODULE = <project>.settings` and `python_files = test_*.py`. Plan these files in Phase 0's Allowed File Areas.
2. Run `GATE install-harness`. This copies `tests/brd/_smoke/test_brd_smoke.py`.
3. Run the smoke suite. For browser tests, create test users in the dev database, for example with `python manage.py createsuperuser`, after asking the user. Store them only in `.env.brd-test`.

## Conventions
- **Migrations:** every model change needs a migration. Check that `makemigrations --check` stays clean, and that each migration can be reversed with `migrate <app> <previous>`.
- **Permissions:** `@login_required`, `@permission_required`, `PermissionRequiredMixin`, DRF `permission_classes`, and `user.has_perm`. Test both the role that has the permission and the one that doesn't.
- **Admin login:** the admin login is at `/admin/login/`. If the app has its own login page, set `login_path` to that page.
