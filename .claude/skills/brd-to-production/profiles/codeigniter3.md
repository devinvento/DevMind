# Project profile: CodeIgniter 3
<!-- Created by brd_gate.py profile-init. The project analyst verifies every value against the real
project in step 2 and replaces every TODO. The gate script reads the JSON block: keep it valid JSON.
Placeholders used in commands: {file} one file, {slug} the run slug, {filter} a case id, {out} the evidence
path without extension (for example docs/brd-to-production/<slug>/phases/phase-2/evidence/unit-run-3). -->

```json
{
  "stack": "codeigniter3",
  "language": "php",
  "runtime": "TODO: PHP version in production (CI3 projects often run old PHP: check!)",
  "runtime_rule": "No PHP syntax newer than production. For PHP 7.4: no match, enum, readonly, named arguments, nullsafe ?->, union types, mixed, str_contains.",
  "app_url": "TODO: http://localhost:<port>",
  "run_app": "TODO: docker compose up / php -S / Apache vhost",
  "php": "TODO: the command prefix that runs the PRODUCTION PHP version, e.g. 'docker exec -w /var/www <app-container> php' or just 'php'",
  "evidence_format": "text",
  "max_test_agents": 4,
  "test_db_per_shard": false,
  "context_full_refresh_every": 5,
  "commands": {
    "lint": "<php> -l {file}",
    "unit_all": "<php> index.php brd_test_runner run all > {out}.txt 2>&1",
    "unit_suite": "<php> index.php brd_test_runner run {slug} > {out}.txt 2>&1",
    "unit_one": "<php> index.php brd_test_runner run {slug} {filter} > {out}.txt 2>&1",
    "migrate_up": "TODO: <php> index.php migrate (if the project has a CLI migrate controller)",
    "migrate_down": "TODO: <php> index.php migrate version <previous timestamp>"
  },
  "test_dir": "tests/brd/{slug}",
  "ui": {"enabled": true, "login_path": "/index.php/login", "user_selector": "input[name=\"username\"]", "pass_selector": "input[name=\"password\"]", "failed_url_re": "/login"},
  "protected_paths": ["system/", "application/third_party/", "vendor/", "application/config/database.php"],
  "test_data_rule": "The shipped runner wraps each test in START TRANSACTION/ROLLBACK (InnoDB only). It refuses DB hosts not in BRD_TEST_DB_ALLOW."
}
```

## Phase 0 recipe
1. Run `GATE install-harness`. This copies `application/controllers/Brd_test_runner.php`, which is CLI-only and refuses web requests, plus `tests/brd/lib/BrdTestCase.php` and the smoke suite. No Composer is needed. The code is PHP 7.4 compatible.
2. Check that the tables are InnoDB, which the rollback needs: `SELECT engine, COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() GROUP BY engine`.
3. If the DB hostname is not one of `localhost`, `127.0.0.1`, `db`, `mysql`, `mariadb`, `database`, `staging-db` or `test-db`, set `BRD_TEST_DB_ALLOW=<host>`. It must only ever name a dev or test database host.
4. Set `BRD_PROD_PHP=<major.minor>` (e.g. `7.4`) in the command environment so TC-0-04 checks the runtime; then run `unit_suite` with slug `_smoke`. 4 PASS is expected.
5. Exclude `Brd_test_runner.php` from production deploys, or confirm it returns 404 over the web.

## Writing tests
- **Location:** `tests/brd/<slug>/<Area>Test.php`, extending `BrdTestCase`.
- **Tags:** tag every method with `/** @case TC-2-01 @ac AC-002.1 */`.
- **CodeIgniter access:** `$this->CI` is the CodeIgniter instance and `$this->db` the database.
- **Output:** the runner prints lines like `PASS TC-2-01 [AC-002.1] Class::method`. Cite them as `evidence/unit-run-K.txt:<line>`.
- **Permissions:** look for the project's permission helper. Many CI3 apps use `has_module_permission` or `has_module_action_permission`.
