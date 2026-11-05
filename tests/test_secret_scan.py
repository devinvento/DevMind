"""Tests for `devmind scan` (Secret Guard). Run: python3 -m unittest tests/test_secret_scan.py"""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

DEVMIND = Path(__file__).resolve().parent.parent / "bin" / "devmind"
ZERO = "0" * 40


def sh(cwd, *args, stdin=None):
    return subprocess.run(list(args), cwd=cwd, text=True, capture_output=True, input=stdin)


class SecretScanTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.remote = root / "remote.git"
        self.repo = root / "work"
        sh(root, "git", "init", "-q", "--bare", str(self.remote))
        self.repo.mkdir()
        for cmd in (["git", "init", "-q", "-b", "main"],
                    ["git", "config", "user.email", "t@example.com"],
                    ["git", "config", "user.name", "t"],
                    ["git", "remote", "add", "origin", str(self.remote)]):
            sh(self.repo, *cmd)
        self.write("README.md", "hello\n")
        self.commit("init")
        sh(self.repo, "git", "push", "-q", "origin", "main")

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, rel, content):
        p = self.repo / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content)

    def commit(self, msg):
        sh(self.repo, "git", "add", "-A", "-f")
        sh(self.repo, "git", "commit", "-q", "-m", msg)

    def scan(self, *args, stdin=None):
        env = {**os.environ}
        env.pop("DEVMIND_SKIP_SECRET_SCAN", None)
        return subprocess.run(["python3", str(DEVMIND), "scan", *args], cwd=self.repo, text=True,
                              capture_output=True, input=stdin, env=env)

    def staged(self, rel, content):
        self.write(rel, content)
        sh(self.repo, "git", "add", "-f", rel)
        return self.scan("--staged")

    # --- detections -------------------------------------------------------
    def test_codeigniter_db_password_blocked(self):
        r = self.staged("application/config/database.php", "$db['default']['password'] = 'S3cr3tPass!';\n")
        self.assertEqual(r.returncode, 1, r.stdout)
        self.assertIn("hardcoded-credential", r.stdout)
        self.assertNotIn("S3cr3tPass", r.stdout, "secret value must be masked in output")

    def test_api_keys_blocked(self):
        for line in ("ANTHROPIC='sk-ant-api03-" + "a" * 40 + "'",
                     "stripe = 'sk_live_" + "A1b2C3d4" * 3 + "'",
                     "key = 'AKIA" + "ABCDEFGHIJKLMNOP" + "'",
                     "token = 'ghp_" + "x" * 36 + "'",
                     "-----BEGIN RSA PRIVATE KEY-----"):
            with self.subTest(line=line[:20]):
                r = self.staged("cfg.py", line + "\n")
                self.assertEqual(r.returncode, 1, r.stdout)
                sh(self.repo, "git", "reset", "-q")

    def test_sensitive_files_blocked(self):
        for rel in (".env", "deploy/server.pem", ".devmind/memory/sessions/2026-11-05.md",
                    ".devmind/memory/chat-history.md"):
            with self.subTest(rel=rel):
                r = self.staged(rel, "x\n")
                self.assertEqual(r.returncode, 1, r.stdout)
                self.assertIn("sensitive-file", r.stdout)
                sh(self.repo, "git", "reset", "-q")

    # --- false positives --------------------------------------------------
    def test_placeholders_and_env_example_allowed(self):
        self.write(".env.example", "DB_PASS=\n")
        self.write("cfg.php", "$c = ['password' => 'changeme', 'api_key' => getenv('KEY'),"
                              " 'secret' => '${APP_SECRET}'];\n")
        self.write("schema.sql", "CREATE TABLE t (id INT);\n")
        sh(self.repo, "git", "add", "-A")
        r = self.scan("--staged")
        self.assertEqual(r.returncode, 0, r.stdout)

    def test_validation_rules_and_translations_allowed(self):
        self.write("app/Http/Controllers/LoginController.php",
                   "$rules = ['password' => 'required|min:8', 'password_confirm' => 'same:password'];\n")
        self.write("lang/de/business.php", "'password' => 'Passwort',\n")
        self.write("application/libraries/stripe/tests/TestCase.php", "const API_KEY = 'sk_test_fake123456';\n")
        sh(self.repo, "git", "add", "-A")
        r = self.scan("--staged")
        self.assertEqual(r.returncode, 0, r.stdout)

    def test_real_token_in_vendor_tests_still_blocked(self):
        r = self.staged("vendor/lib/tests/x.php", "$t = 'shpat_" + "a1" * 16 + "';\n")
        self.assertEqual(r.returncode, 1, r.stdout)

    def test_inline_and_file_allowlist(self):
        self.write("a.py", "k = 'AKIAABCDEFGHIJKLMNOP'  # devmind:allow-secret\n")
        self.write("fixtures/fake.py", "password = 'fixturePass123'\n")
        self.write(".secretscanignore", "fixtures/*\n")
        sh(self.repo, "git", "add", "-A")
        r = self.scan("--staged")
        self.assertEqual(r.returncode, 0, r.stdout)

    # --- pre-push integration ---------------------------------------------
    def test_pre_push_scans_only_unpushed_commits(self):
        self.write("ok.txt", "fine\n")
        self.commit("clean")
        head = sh(self.repo, "git", "rev-parse", "HEAD").stdout.strip()
        base = sh(self.repo, "git", "rev-parse", "origin/main").stdout.strip()
        r = self.scan("--pre-push", stdin=f"refs/heads/main {head} refs/heads/main {base}\n")
        self.assertEqual(r.returncode, 0, r.stdout)

        self.write("leak.py", "password = 'RealPassw0rd'\n")
        self.commit("leak")
        head = sh(self.repo, "git", "rev-parse", "HEAD").stdout.strip()
        r = self.scan("--pre-push", stdin=f"refs/heads/main {head} refs/heads/main {base}\n")
        self.assertEqual(r.returncode, 1, r.stdout)
        # New branch (remote sha is zeros) must also be scanned
        r = self.scan("--pre-push", stdin=f"refs/heads/feature {head} refs/heads/feature {ZERO}\n")
        self.assertEqual(r.returncode, 1, r.stdout)

    def test_skip_env_var(self):
        self.write(".env", "X=1\n")
        sh(self.repo, "git", "add", "-f", ".env")
        r = subprocess.run(["python3", str(DEVMIND), "scan"], cwd=self.repo, text=True, capture_output=True,
                           env={**os.environ, "DEVMIND_SKIP_SECRET_SCAN": "1"})
        self.assertEqual(r.returncode, 0)


if __name__ == "__main__":
    unittest.main()
