# Project profile: CodeIgniter 4
<!-- Created by brd_gate.py profile-init. The project analyst verifies every value against the real
project in step 2 and replaces every TODO. The gate script reads the JSON block: keep it valid JSON.
Placeholders used in commands: {file} one file, {slug} the run slug, {filter} a case id, {out} the evidence
path without extension (for example docs/brd-to-production/<slug>/phases/phase-2/evidence/unit-run-3). -->

```json
{
  "stack": "codeigniter4",
  "language": "php",
  "runtime": "TODO: PHP and CodeIgniter 4 versions in production",
  "runtime_rule": "No PHP syntax newer than production PHP.",
  "app_url": "http://localhost:8080",
  "run_app": "php spark serve",
  "evidence_format": "junit",
  "max_test_agents": 4,
  "test_db_per_shard": false,
  "context_full_refresh_every": 5,
  "commands": {
    "lint": "php -l {file}",
    "unit_all": "vendor/bin/phpunit --log-junit {out}.xml > {out}.txt 2>&1",
    "unit_suite": "vendor/bin/phpunit tests/brd/{slug} --log-junit {out}.xml > {out}.txt 2>&1",
    "unit_one": "vendor/bin/phpunit --filter {filter} --log-junit {out}.xml > {out}.txt 2>&1",
    "migrate_up": "php spark migrate",
    "migrate_down": "php spark migrate:rollback"
  },
  "test_dir": "tests/brd/{slug}",
  "ui": {"enabled": true, "login_path": "/login", "user_selector": "input[name=\"email\"], input[name=\"username\"]", "pass_selector": "input[name=\"password\"]", "failed_url_re": "/login"},
  "protected_paths": ["vendor/", "system/", "writable/", ".env"],
  "test_data_rule": "Use DatabaseTestTrait with the 'tests' DB group (app/Config/Database.php) and $refresh = true. Never the default group."
}
```

## Phase 0 recipe
1. Check that the `tests` database group in `app/Config/Database.php` or `.env` (`database.tests.*`) points to a test database.
2. Run `GATE install-harness`. This copies `tests/brd/_smoke/BrdSmokeTest.php`. Then run `unit_suite` with slug `_smoke`.

## Conventions
- **Filters:** auth filters live in `app/Config/Filters.php`. Shield or Myth:Auth groups and permissions may also apply. Test the forbidden role, expecting a redirect or 403.
- **Migrations:** each migration needs a working `down()`.
