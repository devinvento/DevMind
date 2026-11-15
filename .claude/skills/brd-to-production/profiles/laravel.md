# Project profile: Laravel
<!-- Created by brd_gate.py profile-init. The project analyst verifies every value against the real
project in step 2 and replaces every TODO. The gate script reads the JSON block: keep it valid JSON.
Placeholders used in commands: {file} one file, {slug} the run slug, {filter} a case id, {out} the evidence
path without extension (for example docs/brd-to-production/<slug>/phases/phase-2/evidence/unit-run-3). -->

```json
{
  "stack": "laravel",
  "language": "php",
  "runtime": "TODO: PHP and Laravel versions in production (php -v, php artisan --version)",
  "runtime_rule": "No PHP syntax newer than the production PHP version; no Laravel APIs newer than the installed major.",
  "app_url": "http://127.0.0.1:8000",
  "run_app": "php artisan serve (or sail up / docker compose)",
  "evidence_format": "junit",
  "max_test_agents": 4,
  "test_db_per_shard": false,
  "context_full_refresh_every": 5,
  "commands": {
    "lint": "php -l {file}",
    "unit_all": "php artisan test --log-junit {out}.xml > {out}.txt 2>&1",
    "unit_suite": "php artisan test tests/brd/{slug} --log-junit {out}.xml > {out}.txt 2>&1",
    "unit_one": "php artisan test --filter {filter} --log-junit {out}.xml > {out}.txt 2>&1",
    "migrate_up": "php artisan migrate --env=testing",
    "migrate_down": "php artisan migrate:rollback --step=1 --env=testing"
  },
  "test_dir": "tests/brd/{slug}",
  "ui": {"enabled": true, "login_path": "/login", "user_selector": "input[name=\"email\"]", "pass_selector": "input[name=\"password\"]", "failed_url_re": "/login"},
  "protected_paths": ["vendor/", "bootstrap/cache/", "storage/", "public/build/", "node_modules/", ".env"],
  "test_data_rule": "Use the RefreshDatabase or DatabaseTransactions trait and a testing database (.env.testing / phpunit.xml DB_DATABASE). Never the real DB."
}
```

## Phase 0 recipe
1. Check `phpunit.xml`. `DB_CONNECTION` and `DB_DATABASE` must point to a test database or SQLite in-memory. If not, plan `.env.testing`. In Laravel 10 and older, `--log-junit` is passed through to PHPUnit. Pest uses `--log-junit` as well.
2. Run `GATE install-harness`. This copies `tests/brd/_smoke/BrdSmokeTest.php`, namespace `Tests\\brd\\_smoke`, which composer's `Tests\\` mapping autoloads.
3. Run `unit_suite` with slug `_smoke`.

## Conventions
- **Test names:** the method name carries the case id: `public function test_TC_2_01_points_for_1250_sale(): void`.
- **Permissions:** Gates and Policies (`$this->authorize`, `can` middleware) and Form Requests' `authorize()`. Test with `actingAs($user)` for each role, expecting 403.
- **Migrations:** each migration needs a working `down()`. Test `migrate`, then `migrate:rollback`, then `migrate` on the testing database.
