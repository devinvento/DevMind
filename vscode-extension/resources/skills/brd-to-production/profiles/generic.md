# Project profile: generic (stack not recognised)
<!-- Created by brd_gate.py profile-init. The project analyst verifies every value against the real
project in step 2 and replaces every TODO. The gate script reads the JSON block: keep it valid JSON.
Placeholders used in commands: {file} one file, {slug} the run slug, {filter} a case id, {out} the evidence
path without extension (for example docs/brd-to-production/<slug>/phases/phase-2/evidence/unit-run-3). -->

```json
{
  "stack": "generic",
  "language": "TODO",
  "runtime": "TODO: language/runtime version in production",
  "runtime_rule": "TODO: compatibility rule for new code",
  "app_url": "TODO or none",
  "run_app": "TODO",
  "evidence_format": "junit",
  "max_test_agents": 4,
  "test_db_per_shard": false,
  "context_full_refresh_every": 5,
  "commands": {
    "lint": "TODO: syntax check for one file {file}",
    "unit_all": "TODO: run every test, write JUnit XML to {out}.xml and the console to {out}.txt",
    "unit_suite": "TODO: run tests/brd/{slug} only",
    "unit_one": "TODO: run one case matching {filter}",
    "migrate_up": "TODO or none",
    "migrate_down": "TODO or none"
  },
  "test_dir": "tests/brd/{slug}",
  "ui": {"enabled": false},
  "protected_paths": ["TODO: framework core, vendored libraries, generated files"],
  "test_data_rule": "TODO: how tests stay away from real data"
}
```

## Phase 0 recipe
Pick the project's own test framework, or the standard one for the language, and agree it with the user at approval. Whatever you pick must do two things:
- produce **JUnit XML**, which almost every runner can, or print one line per test containing the case id and PASS or FAIL;
- carry the case id, such as `TC-2-01` or `TC_2_01`, in each test's name.
