# Project profile: Node.js (Express / Nest / Next / other)
<!-- Created by brd_gate.py profile-init. The project analyst verifies every value against the real
project in step 2 and replaces every TODO. The gate script reads the JSON block: keep it valid JSON.
Placeholders used in commands: {file} one file, {slug} the run slug, {filter} a case id, {out} the evidence
path without extension (for example docs/brd-to-production/<slug>/phases/phase-2/evidence/unit-run-3). -->

```json
{
  "stack": "node",
  "language": "javascript/typescript",
  "runtime": "TODO: Node version in production (node -v) and framework",
  "runtime_rule": "No language or Node APIs newer than production Node.",
  "app_url": "TODO: http://localhost:3000",
  "run_app": "TODO: npm run dev",
  "evidence_format": "junit",
  "max_test_agents": 4,
  "test_db_per_shard": false,
  "context_full_refresh_every": 5,
  "commands": {
    "lint": "TODO: npx tsc --noEmit -p . (TypeScript) or node --check {file}",
    "unit_all": "TODO: npx vitest run --reporter=junit --outputFile={out}.xml > {out}.txt 2>&1   (or: npx jest --ci --reporters=default --reporters=jest-junit with JEST_JUNIT_OUTPUT_FILE={out}.xml)",
    "unit_suite": "TODO: same as unit_all with the path tests/brd/{slug}",
    "unit_one": "TODO: same with -t {filter}",
    "migrate_up": "TODO: prisma migrate deploy / knex migrate:latest / typeorm migration:run, or none",
    "migrate_down": "TODO: knex migrate:rollback / typeorm migration:revert, or none"
  },
  "test_dir": "tests/brd/{slug}",
  "ui": {"enabled": true, "login_path": "/login", "failed_url_re": "/login"},
  "protected_paths": ["node_modules/", "dist/", "build/", ".next/", ".env"],
  "test_data_rule": "Use a test database URL (DATABASE_URL in .env.test) and per-test cleanup or transactions."
}
```

## Phase 0 recipe
1. Use the test runner the project already has, Jest or Vitest. If it has none, ask the user which one to add as a dev dependency. Never install globally.
2. Make the runner write JUnit XML:
   - **Vitest:** nothing to add. `--reporter=junit --outputFile={out}.xml` is built in.
   - **Jest:** add `jest-junit` as a dev dependency, and set `JEST_JUNIT_OUTPUT_FILE={out}.xml` in `unit_all`.
3. Create `tests/brd/_smoke/brd-smoke.test.js` (`.ts` in a TypeScript project). With Vitest, add `import { test, expect } from 'vitest';` as the first line, unless the project enables `globals`:
   ```js
   test('TC-0-01 Node runtime matches production', () => {
     const want = process.env.BRD_PROD_NODE;        // for example "20"; unset means skip
     if (!want) return;                             // record as not checked in the report
     expect(process.versions.node.split('.')[0]).toBe(String(want).split('.')[0]);
   });

   test('TC-0-02 the application module loads', async () => {
     const mod = await import('../../../src/app.js'); // TODO: the project's real entry module
     expect(mod).toBeTruthy();
   });
   ```
4. Make sure the runner's include pattern covers `tests/brd/**`, or add it to the config.
5. Run `unit_suite` with slug `_smoke`. Both smoke tests must pass, and `{out}.xml` must exist.

## Test naming
Put the case id at the start of the test title: `test('TC-2-01 points for 1250 sale', ...)`.
