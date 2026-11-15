"""Tests for the brd-to-production gate script's cache, shard and regression commands.
Run: python3 -m unittest tests/test_brd_gate.py"""
import json
import os
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

GATE = Path(__file__).resolve().parent.parent / ".claude" / "skills" / "brd-to-production" / "scripts" / "brd_gate.py"
ROOT = "docs/brd-to-production"

PROFILE = {
    "stack": "python", "evidence_format": "junit", "max_test_agents": 4, "test_db_per_shard": False,
    "context_full_refresh_every": 2,
    "commands": {"lint": "true", "unit_all": "true", "unit_one": "true",
                 "unit_suite": "python3 make_junit.py tests/brd/{slug} {out}"},
    "test_dir": "tests/brd/{slug}", "ui": {"enabled": False}, "protected_paths": ["vendor/"],
}

# writes a JUnit file with one passing case per *.ok file and one failing case per *.bad file
MAKE_JUNIT = textwrap.dedent("""\
    import os, sys
    d, out = sys.argv[1], sys.argv[2]
    cases = []
    for f in sorted(os.listdir(d)):
        if f.endswith(".ok"):
            cases.append('<testcase classname="t" name="%s"/>' % f)
        elif f.endswith(".bad"):
            cases.append('<testcase classname="t" name="%s"><failure message="boom"/></testcase>' % f)
    open(out + ".xml", "w").write("<testsuite>%s</testsuite>" % "".join(cases))
    sys.exit(1 if any(f.endswith(".bad") for f in os.listdir(d)) else 0)
""")

PLAN = textwrap.dedent("""\
    # Plan

    ## Phase 1: Orders
    - **Allowed File Areas**: `app/`
    - **Acceptance Criteria**: AC-001.1, AC-001.2, AC-002.1, AC-003.1
    - **Test Shards**:

    | id | agent | ACs | depends_on | resources |
    |----|-------|-----|------------|-----------|
    | S1 | brd-test-engineer | AC-001.1, AC-001.2 | - | none |
    | S2 | brd-test-engineer | AC-002.1 | - | db:write |
    | S3 | brd-ui-tester | AC-003.1 | S1 | server, db:write |

    - **Regression Scope**: none.

    ## Phase 2: Next
    - **Allowed File Areas**: `app/`
    - **Acceptance Criteria**: AC-009.1
""")


def run(cwd, *args):
    return subprocess.run([sys.executable, str(GATE), *args], cwd=cwd, text=True, capture_output=True)


class GateTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self.tmp.name)
        for cmd in (["git", "init", "-q", "-b", "main"], ["git", "config", "user.email", "t@example.com"],
                    ["git", "config", "user.name", "t"]):
            subprocess.run(cmd, cwd=self.repo, check=True)
        self.write("app/main.py", "print(1)\n")
        self.write("make_junit.py", MAKE_JUNIT)
        self.write("brd.md", "# BRD\nREQ one\n")
        self.write(f"{ROOT}/PROJECT-PROFILE.md", "# Profile\n```json\n" + json.dumps(PROFILE, indent=2) + "\n```\n")
        self.commit("init")
        r = run(self.repo, "init", "orders", "--brd", "brd.md")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.ws = f"{ROOT}/orders"

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, rel, content):
        p = self.repo / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content)

    def commit(self, msg):
        subprocess.run(["git", "add", "-A"], cwd=self.repo, check=True)
        subprocess.run(["git", "commit", "-q", "-m", msg], cwd=self.repo, check=True)

    def state(self, ws=None):
        return json.loads((self.repo / (ws or self.ws) / "state.json").read_text())

    # ---------- brd-hash ----------
    def test_brd_hash_new_record_match_changed(self):
        self.assertIn("NEW", run(self.repo, "brd-hash", self.ws).stdout)
        self.assertEqual(run(self.repo, "brd-hash", self.ws, "--record").returncode, 1)  # no requirements yet
        self.write(f"{self.ws}/01-requirements.md", "# REQ\n")
        self.assertEqual(run(self.repo, "brd-hash", self.ws, "--record").returncode, 0)
        r = run(self.repo, "brd-hash", self.ws)
        self.assertEqual(r.returncode, 0)
        self.assertIn("MATCH (this workspace)", r.stdout)
        self.write("brd.md", "# BRD\nREQ one changed\n")
        r = run(self.repo, "brd-hash", self.ws)
        self.assertEqual(r.returncode, 1)
        self.assertIn("CHANGED", r.stdout)

    def test_brd_hash_matches_other_workspace(self):
        self.write(f"{self.ws}/01-requirements.md", "# REQ\n")
        run(self.repo, "brd-hash", self.ws, "--record")
        run(self.repo, "init", "orders-2", "--brd", "brd.md")
        r = run(self.repo, "brd-hash", f"{ROOT}/orders-2")
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertIn(f"MATCH {ROOT}/orders", r.stdout)

    def test_brd_hash_changed_after_approval_is_change_request(self):
        self.write(f"{self.ws}/01-requirements.md", "# REQ\n")
        run(self.repo, "brd-hash", self.ws, "--record")
        run(self.repo, "approve", self.ws, "--mode", "ask", "--quote", "yes")
        self.write("brd.md", "# BRD v2\n")
        self.assertIn("change request", run(self.repo, "brd-hash", self.ws).stdout)

    # ---------- context-check ----------
    def record_context(self, *extra):
        self.write(f"{self.ws}/02-project-analysis.md", "# Analysis\n")
        r = run(self.repo, "context-check", self.ws, "--record", *extra)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_context_full_when_never_recorded(self):
        r = run(self.repo, "context-check", self.ws)
        self.assertEqual(r.returncode, 1)
        self.assertIn("FULL", r.stdout)

    def test_context_reuse_then_incremental(self):
        self.record_context()
        r = run(self.repo, "context-check", self.ws)
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertIn("REUSE", r.stdout)
        self.write("app/main.py", "print(2)\n")
        self.commit("change")
        r = run(self.repo, "context-check", self.ws)
        self.assertIn("INCREMENTAL", r.stdout)
        self.assertIn("app/main.py", r.stdout)

    def test_context_uncommitted_change_counts(self):
        self.record_context()
        self.write("app/new.py", "x = 1\n")
        self.assertIn("app/new.py", run(self.repo, "context-check", self.ws).stdout)

    def test_context_dirty_file_unchanged_since_record_is_not_a_change(self):
        self.write("app/main.py", "print('dirty')\n")
        self.record_context()
        self.assertIn("REUSE", run(self.repo, "context-check", self.ws).stdout)

    def test_context_full_on_dependency_or_schema_change(self):
        self.record_context()
        self.write("requirements.txt", "flask\n")
        r = run(self.repo, "context-check", self.ws)
        self.assertEqual(r.returncode, 1)
        self.assertIn("requirements.txt", r.stdout)
        os.remove(self.repo / "requirements.txt")
        self.write("db/migrations/001_init.py", "x\n")
        self.assertIn("FULL", run(self.repo, "context-check", self.ws).stdout)

    def test_context_full_when_commit_gone(self):
        self.record_context()
        st = self.state()
        st["context"]["last_analyzed_commit"] = "0" * 40
        (self.repo / self.ws / "state.json").write_text(json.dumps(st))
        self.assertIn("no longer exists", run(self.repo, "context-check", self.ws).stdout)

    def test_context_full_after_refresh_limit(self):
        self.record_context("--full")
        self.record_context()
        self.record_context()  # 2 incremental, limit is 2
        r = run(self.repo, "context-check", self.ws)
        self.assertEqual(r.returncode, 1)
        self.assertIn("incremental refreshes", r.stdout)
        self.record_context("--full")
        self.assertEqual(self.state()["context"]["incremental_count"], 0)

    # ---------- shards ----------
    def write_plan(self, plan=PLAN):
        self.write(f"{self.ws}/03-plan.md", plan)

    def test_shards_waves(self):
        self.write_plan()
        r = run(self.repo, "shards", self.ws, "1")
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertIn("WAVE 1: S1 S2", r.stdout)
        self.assertIn("WAVE 2: S3", r.stdout)  # needs S1, and both S2 and S3 write the DB

    def test_shards_ready_waiting_blocked(self):
        self.write_plan()
        r = run(self.repo, "shards", self.ws, "1", "--done", "S1", "--running", "S2")
        self.assertIn("READY: none", r.stdout)
        self.assertIn("WAITING: S3 (shares a resource with S2)", r.stdout)
        r = run(self.repo, "shards", self.ws, "1", "--done", "S1,S2")
        self.assertIn("READY: S3", r.stdout)
        r = run(self.repo, "shards", self.ws, "1", "--failed", "S1", "--done", "S2")
        self.assertIn("BLOCKED: S3", r.stdout)
        r = run(self.repo, "shards", self.ws, "1", "--done", "S1,S2,S3")
        self.assertIn("ALL DONE", r.stdout)

    def test_shards_per_shard_db_only_isolates_non_server_shards(self):
        prof = dict(PROFILE, test_db_per_shard=True)
        self.write(f"{ROOT}/PROJECT-PROFILE.md", "```json\n" + json.dumps(prof) + "\n```\n")
        self.write_plan(PLAN.replace("| S3 | brd-ui-tester | AC-003.1 | S1 | server, db:write |",
                                     "| S3 | brd-test-engineer | AC-003.1 | - | db:write |"))
        self.assertIn("WAVE 1: S1 S2 S3", run(self.repo, "shards", self.ws, "1").stdout)

    def test_shards_max_agents(self):
        prof = dict(PROFILE, max_test_agents=1)
        self.write(f"{ROOT}/PROJECT-PROFILE.md", "```json\n" + json.dumps(prof) + "\n```\n")
        self.write_plan()
        out = run(self.repo, "shards", self.ws, "1").stdout
        self.assertIn("WAVE 1: S1", out)
        self.assertIn("WAVE 3: S3", out)

    def test_shards_validation(self):
        bad = PLAN.replace("| S2 | brd-test-engineer | AC-002.1 | - | db:write |",
                           "| S2 | brd-test-engineer | AC-001.1 | S3 | db:wrote |")
        bad = bad.replace("| S1 | brd-test-engineer | AC-001.1, AC-001.2 | - | none |",
                          "| S1 | brd-test-engineer | AC-001.1, AC-001.2 | S2 | none |")
        self.write_plan(bad)
        r = run(self.repo, "shards", self.ws, "1")
        self.assertEqual(r.returncode, 1)
        self.assertIn("AC-001.1: must belong to exactly one shard", r.stdout)
        self.assertIn("AC-002.1: must belong to exactly one shard", r.stdout)
        self.assertIn("resource 'db:wrote'", r.stdout)

    def test_shards_cycle(self):
        self.write_plan(PLAN.replace("| S1 | brd-test-engineer | AC-001.1, AC-001.2 | - | none |",
                                     "| S1 | brd-test-engineer | AC-001.1, AC-001.2 | S3 | none |"))
        r = run(self.repo, "shards", self.ws, "1")
        self.assertEqual(r.returncode, 1)
        self.assertIn("dependency cycle", r.stdout)

    def test_no_shards_table(self):
        self.write_plan()
        r = run(self.repo, "shards", self.ws, "2")
        self.assertEqual(r.returncode, 0)
        self.assertIn("NO SHARDS", r.stdout)

    # ---------- shard-merge ----------
    def write_shard(self, sid, rows):
        d = f"{self.ws}/phases/phase-1/shards/{sid}"
        body = "| Test ID | AC | Scenario | Status | Evidence |\n|---|---|---|---|---|\n"
        for cid, ac, status in rows:
            body += f"| {cid} | {ac} | case | {status} | `evidence/run-1.xml` |\n"
            cases = "".join(f'<testcase classname="t" name="{c}"/>' for c, _, s in rows if s == "PASS")
            self.write(f"{d}/evidence/run-1.xml", f"<testsuite>{cases}</testsuite>")
        self.write(f"{d}/report.md", body)

    def test_shard_merge_and_evidence(self):
        self.write_plan()
        self.write_shard("S1", [("TC-1-01", "AC-001.1", "PASS"), ("TC-1-02", "AC-001.2", "PASS")])
        self.write_shard("S2", [("TC-1-03", "AC-002.1", "PASS")])
        self.write_shard("S3", [("UI-1-01", "AC-003.1", "PASS")])
        r = run(self.repo, "shard-merge", self.ws, "1")
        self.assertEqual(r.returncode, 0, r.stdout)
        unit = (self.repo / self.ws / "phases/phase-1/test-report.md").read_text()
        self.assertIn("shards/S1/evidence/run-1.xml", unit)
        self.assertIn("UI-1-01", (self.repo / self.ws / "phases/phase-1/ui-report.md").read_text())
        r = run(self.repo, "evidence", self.ws, "1")
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertEqual(run(self.repo, "coverage", self.ws, "1").returncode, 0)

    def test_shard_merge_errors(self):
        self.write_plan()
        self.write_shard("S1", [("TC-1-01", "AC-001.1", "PASS")])
        self.write_shard("S2", [("TC-1-01", "AC-002.1", "PASS")])
        r = run(self.repo, "shard-merge", self.ws, "1")
        self.assertEqual(r.returncode, 1)
        self.assertIn("TC-1-01: in both S1 and S2", r.stdout)
        self.assertIn("S3: shards/S3/report.md is missing", r.stdout)

    def test_shard_merge_refuses_hand_written_report(self):
        self.write_plan()
        for sid in ("S1", "S2"):
            self.write_shard(sid, [(f"TC-1-0{sid[1]}", "AC-001.1" if sid == "S1" else "AC-002.1", "PASS")])
        self.write_shard("S3", [("UI-1-01", "AC-003.1", "PASS")])
        self.write(f"{self.ws}/phases/phase-1/test-report.md", "| Test ID | Status |\n|---|---|\n| TC-1-09 | PASS |\n")
        self.assertIn("written by hand", run(self.repo, "shard-merge", self.ws, "1").stdout)

    def test_shard_bugs_are_counted(self):
        self.write(f"{self.ws}/phases/phase-1/shards/S1/bugs.md", "### BUG-1-01\n- **Status**: open\n")
        r = run(self.repo, "bugs", self.ws, "1")
        self.assertEqual(r.returncode, 1)
        self.assertIn("BUG-1-01", r.stdout)

    # ---------- regression ----------
    def test_regression_pass_fail_and_staleness(self):
        self.write("tests/brd/orders/a.ok", "")
        self.write("tests/brd/_smoke/s.ok", "")
        r = run(self.repo, "regression", self.ws, "1")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("PASS unit orders (1 pass, 0 fail", r.stdout)
        reg = self.state()["phases"][0]["regression"]
        self.assertEqual((reg["k"], reg["result"]), (1, "PASS"))
        self.assertTrue((self.repo / self.ws / "phases/phase-1/evidence/regression-1/summary.json").exists())

        self.write("tests/brd/orders/b.bad", "")
        r = run(self.repo, "regression", self.ws, "1")
        self.assertEqual(r.returncode, 1)
        self.assertEqual(self.state()["phases"][0]["regression"]["k"], 2)

    def test_complete_requires_fresh_regression(self):
        self.write_plan()
        self.write("tests/brd/orders/a.ok", "")
        run(self.repo, "regression", self.ws, "1")
        self.assertIn("run 1 PASS, code unchanged since", run(self.repo, "complete", self.ws, "1").stdout)
        self.write("app/main.py", "print(3)\n")
        r = run(self.repo, "complete", self.ws, "1")
        self.assertEqual(r.returncode, 1)
        self.assertIn("changed after regression run 1", r.stdout)

    def test_regression_nothing_to_run_fails(self):
        r = run(self.repo, "regression", self.ws, "1")
        self.assertEqual(r.returncode, 1)
        self.assertIn("nothing to run", r.stdout)


if __name__ == "__main__":
    unittest.main()
