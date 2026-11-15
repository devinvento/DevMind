# Project profile: FastAPI
<!-- Created by brd_gate.py profile-init. The project analyst verifies every value against the real
project in step 2 and replaces every TODO. The gate script reads the JSON block: keep it valid JSON.
Placeholders used in commands: {file} one file, {slug} the run slug, {filter} a case id, {out} the evidence
path without extension (for example docs/brd-to-production/<slug>/phases/phase-2/evidence/unit-run-3). -->

```json
{
  "stack": "fastapi",
  "language": "python",
  "runtime": "TODO: Python version in production",
  "runtime_rule": "No syntax newer than the production Python; keep Pydantic major version as installed (v1 vs v2 APIs differ).",
  "app_url": "http://127.0.0.1:8000",
  "run_app": "TODO: e.g. uvicorn app.main:app --port 8000",
  "evidence_format": "junit",
  "max_test_agents": 4,
  "test_db_per_shard": false,
  "context_full_refresh_every": 5,
  "commands": {
    "lint": "python -m py_compile {file}",
    "unit_all": "python -m pytest tests -v --junitxml={out}.xml > {out}.txt 2>&1",
    "unit_suite": "python -m pytest tests/brd/{slug} -v --junitxml={out}.xml > {out}.txt 2>&1",
    "unit_one": "python -m pytest tests -v -k {filter} --junitxml={out}.xml > {out}.txt 2>&1",
    "migrate_up": "TODO: alembic upgrade head, or none",
    "migrate_down": "TODO: alembic downgrade -1, or none"
  },
  "test_dir": "tests/brd/{slug}",
  "ui": {"enabled": true, "api_only": true, "login_path": "none", "notes": "API flows (kind: 'api') with BRD_TOKEN_<ROLE>; enable UI flows only if the project serves HTML"},
  "protected_paths": [".venv/", "venv/", "site-packages/", "alembic/versions/*_initial*.py"],
  "test_data_rule": "Override the DB dependency with a test database or a transaction that rolls back (app.dependency_overrides). Never use the production DATABASE_URL."
}
```

## Phase 0 recipe
1. Add `pytest` and `httpx` as dev dependencies in the project's virtualenv. `httpx` is required by `fastapi.testclient`.
2. Run `GATE install-harness`, then set `BRD_APP=<module>:<app>` for the smoke test, for example `app.main:app`.
3. Find out how the app gets its DB session (`Depends(get_db)`). Then write a `tests/brd/conftest.py` that overrides it with a test database or a rolled-back transaction.
4. Run the smoke suite. Start the server with `run_app` and run the API smoke flow `API-0-01` with the browser runner, using `BRD_BASE_URL=http://127.0.0.1:8000` and `BRD_SMOKE_API_PATH=/openapi.json`.

## Testing notes
- **Endpoint tests:** use `TestClient(app)` for unit and scenario tests. For each endpoint, test the success response, validation errors (422), the auth failure (401/403) and not found (404).
- **API flows:** run them against the live server with the runner's `kind: 'api'` flows. Use `token(role)` for Bearer auth, or post to the login endpoint.
- **Permissions:** test every protected route with no token, a wrong-role token and a right-role token.
