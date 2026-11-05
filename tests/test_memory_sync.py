"""Tests for `devmind memory` (AI memory ⇄ Google Drive sync).
Uses a plain folder as the "Drive" backend so no rclone/network is needed.
Run: python3 -m unittest tests/test_memory_sync.py
"""
import json
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

DEVMIND = Path(__file__).resolve().parent.parent / "bin" / "devmind"


class Machine:
    """A fake machine: own HOME (Claude transcripts + config) and own checkout path."""

    def __init__(self, base, name, repo_rel, remote_url, drive):
        self.name, self.drive = name, drive
        self.home = base / name
        self.repo = self.home / repo_rel
        self.repo.mkdir(parents=True)
        subprocess.run(["git", "init", "-q"], cwd=self.repo, check=True)
        subprocess.run(["git", "remote", "add", "origin", remote_url], cwd=self.repo, check=True)
        self.sessions = self.home / ".claude" / "projects" / re.sub(r"[^A-Za-z0-9]", "-", str(self.repo))
        self.sessions.mkdir(parents=True)

    def env(self):
        return {**os.environ, "HOME": str(self.home), "XDG_CONFIG_HOME": str(self.home / ".config"),
                "XDG_CACHE_HOME": str(self.home / ".cache"),
                "DEVMIND_MEMORY_REMOTE": str(self.drive), "DEVMIND_MACHINE": f"{self.name}-pc"}

    def memory(self, *args):
        return subprocess.run(["python3", str(DEVMIND), "memory", *args], cwd=self.repo, text=True,
                              capture_output=True, env=self.env())

    def add_session(self, sid, title, prompt, outcome="Done.", edited=None):
        rows = [
            {"type": "ai-title", "aiTitle": title},
            {"type": "user", "timestamp": "2026-11-05T09:00:00Z", "gitBranch": "main",
             "message": {"content": "<system-reminder>internal</system-reminder>" + prompt}},
            {"type": "assistant", "timestamp": "2026-11-05T09:02:00Z", "message": {"content": [
                {"type": "tool_use", "name": "Edit", "input": {"file_path": str(self.repo / (edited or "a.php"))}},
                {"type": "text", "text": outcome}]}},
        ]
        (self.sessions / f"{sid}.jsonl").write_text("\n".join(json.dumps(r) for r in rows))

    @property
    def mem(self):
        return self.repo / ".devmind" / "memory"


class MemorySyncTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        self.drive = base / "Drive" / "DevMind-Memory"
        url = "git@github.com:invento/sundora.git"
        self.office = Machine(base, "office", "var/www/html/sundora", url, self.drive)
        self.home = Machine(base, "home", "projects/sundora", "https://github.com/invento/sundora.git", self.drive)

    def tearDown(self):
        self.tmp.cleanup()

    def test_project_key_same_across_paths_and_url_styles(self):
        a = json.loads(self.office.memory("status", "--json").stdout)
        b = json.loads(self.home.memory("status", "--json").stdout)
        self.assertEqual(a["project_key"], "github.com_invento_sundora")
        self.assertEqual(a["project_key"], b["project_key"])

    def test_capture_redacts_secrets_and_strips_reminders(self):
        self.office.add_session("s1aaaaaa-1", "Fix Shopify", "token shpat_" + "ab12" * 8 + " mail boss@client.com",
                                outcome="Moved $password = 'RealPassw0rd99' to .env")
        r = self.office.memory("capture")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        files = list((self.office.mem / "sessions").glob("*.md"))
        self.assertEqual(len(files), 1)
        self.assertRegex(files[0].name, r"^2026-11-05_office-pc_s1aaaaaa\.md$")
        text = files[0].read_text()
        for leaked in ("shpat_ab12", "boss@client.com", "RealPassw0rd99", "internal"):
            self.assertNotIn(leaked, text)
        self.assertIn("[REDACTED:shopify-token]", text)
        self.assertIn("`a.php`", text)  # path made relative to the repo

    def test_two_machines_share_memory_without_conflicts(self):
        self.office.add_session("off11111-x", "Office work", "fix order totals")
        self.assertEqual(self.office.memory("push").returncode, 0)
        self.assertEqual(self.home.memory("pull").returncode, 0)
        self.home.add_session("hom22222-y", "Home work", "add loyalty report")
        self.assertEqual(self.home.memory("sync").returncode, 0)
        self.assertEqual(self.office.memory("pull").returncode, 0)

        for m in (self.office, self.home):
            names = sorted(p.name for p in (m.mem / "sessions").glob("*.md"))
            self.assertEqual(names, ["2026-11-05_home-pc_hom22222.md", "2026-11-05_office-pc_off11111.md"])
            index = (m.mem / "chat-history.md").read_text()
            self.assertIn("Office work", index)
            self.assertIn("Home work", index)
        # generated index and local state never go to Drive
        remote = self.drive / "github.com_invento_sundora"
        self.assertFalse((remote / "chat-history.md").exists())
        self.assertFalse((remote / ".sync-state.json").exists())

    def test_session_file_contains_full_conversation(self):
        self.office.add_session("conv0000-1", "Conv", "first question about totals", outcome="Here is the detailed answer.")
        self.office.memory("capture")
        text = next((self.office.mem / "sessions").glob("*.md")).read_text()
        self.assertIn("## Conversation", text)
        self.assertIn("> first question about totals", text)
        self.assertIn("> Here is the detailed answer.", text)

    def test_claude_transcript_resumable_on_other_machine(self):
        sid = "5e55a0aa-1111-2222-3333-444455556666"
        rows = [
            {"type": "user", "sessionId": sid, "cwd": str(self.office.repo), "timestamp": "2026-11-05T09:00:00Z",
             "message": {"role": "user", "content": "deploy key is sk_live_" + "A1b2C3d4" * 3}},
            {"type": "assistant", "sessionId": sid, "cwd": str(self.office.repo) + "/application",
             "message": {"role": "assistant", "content": [
                 {"type": "tool_use", "name": "Edit", "input": {"file_path": str(self.office.repo) + "/a.php"}},
                 {"type": "text", "text": "done"}]}},
            {"type": "api-request-blob", "payload": "x" * 1000},
        ]
        (self.office.sessions / f"{sid}.jsonl").write_text("\n".join(json.dumps(r) for r in rows) + "\n")
        self.assertEqual(self.office.memory("push").returncode, 0)
        r = self.home.memory("pull")
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertIn("1 Claude session(s) installed", r.stdout)

        installed = self.home.sessions / f"{sid}.jsonl"   # home's own ~/.claude/projects/<home path slug>/
        self.assertTrue(installed.exists())
        lines = [json.loads(l) for l in installed.read_text().splitlines()]
        self.assertEqual(lines[0]["cwd"], str(self.home.repo))                 # path rewritten to home checkout
        self.assertEqual(lines[1]["cwd"], str(self.home.repo) + "/application")
        self.assertEqual(lines[1]["message"]["content"][0]["input"]["file_path"], str(self.home.repo) + "/a.php")
        self.assertNotIn("sk_live_", installed.read_text())                    # redacted before upload
        self.assertFalse(any(l.get("type") == "api-request-blob" for l in lines))
        self.assertFalse((self.home.mem / "transcripts").exists())            # never inside the repo

        # Imported session must not produce a duplicate "home-pc" summary
        self.home.memory("capture")
        self.assertEqual([p.name for p in (self.home.mem / "sessions").glob("*home-pc*")], [])

        # Home continues the session -> office receives the continuation
        with open(installed, "a") as fh:
            fh.write(json.dumps({"type": "user", "sessionId": sid, "cwd": str(self.home.repo),
                                 "message": {"role": "user", "content": "continued at home"}}) + "\n")
        self.assertEqual(self.home.memory("push").returncode, 0)
        r = self.office.memory("pull")
        self.assertIn("1 Claude session(s) installed", r.stdout)
        office_copy = (self.office.sessions / f"{sid}.jsonl").read_text()
        self.assertIn("continued at home", office_copy)
        self.assertIn(str(self.office.repo), office_copy)
        self.assertNotIn(str(self.home.repo), office_copy)

    def test_local_changes_are_not_overwritten(self):
        sid = "c0ff11c7-0000"
        (self.office.sessions / f"{sid}.jsonl").write_text(json.dumps({"type": "user", "message": {"content": "v1"}}) + "\n")
        self.office.memory("push")
        self.home.memory("pull")
        h = self.home.sessions / f"{sid}.jsonl"
        with open(h, "a") as fh:
            fh.write(json.dumps({"type": "user", "message": {"content": "home edit"}}) + "\n")
        self.home.memory("push")
        # office ALSO changed its copy without pulling first -> keep office's local version
        with open(self.office.sessions / f"{sid}.jsonl", "a") as fh:
            fh.write(json.dumps({"type": "user", "message": {"content": "office edit"}}) + "\n")
        r = self.office.memory("pull")
        self.assertIn("kept local", r.stdout)
        self.assertIn("office edit", (self.office.sessions / f"{sid}.jsonl").read_text())

    def test_claude_auto_memory_synced_and_index_merged(self):
        om = self.office.sessions / "memory"; om.mkdir()
        (om / "git-split.md").write_text("---\nname: git-split\n---\nGit = code, Drive = memory\n")
        (om / "MEMORY.md").write_text("- [Git split](git-split.md) - office fact\n")
        hm = self.home.sessions / "memory"; hm.mkdir()
        (hm / "home-pref.md").write_text("---\nname: home-pref\n---\nPrefers Banglish replies\n")
        (hm / "MEMORY.md").write_text("- [Home pref](home-pref.md) - home fact\n")

        self.assertEqual(self.office.memory("push").returncode, 0)
        r = self.home.memory("sync")
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertTrue((hm / "git-split.md").exists())
        idx = (hm / "MEMORY.md").read_text()
        self.assertIn("office fact", idx)
        self.assertIn("home fact", idx)

        r = self.office.memory("pull")
        self.assertIn("Claude memory file(s) merged", r.stdout)
        self.assertTrue((om / "home-pref.md").exists())
        idx = (om / "MEMORY.md").read_text()
        self.assertIn("office fact", idx)
        self.assertIn("home fact", idx)
        self.assertEqual(idx.count("office fact"), 1)
        self.assertFalse((self.office.mem / "claude-memory").exists())   # never inside the repo

    def test_claude_memory_secret_blocks_push(self):
        om = self.office.sessions / "memory"; om.mkdir()
        (om / "leak.md").write_text("token: ghp_" + "x" * 36 + "\n")
        r = self.office.memory("push")
        self.assertEqual(r.returncode, 1)
        self.assertIn("blocked", r.stdout)

    def test_push_is_idempotent(self):
        self.office.add_session("idem0000-z", "Once", "hello")
        self.office.memory("push")
        r = self.office.memory("push")
        self.assertIn("0 file(s) copied", r.stdout)

    def test_push_blocked_when_memory_file_contains_secret(self):
        self.office.mem.mkdir(parents=True, exist_ok=True)
        (self.office.mem / "decisions.md").write_text("Stripe key: sk_live_" + "A1b2C3d4" * 3 + "\n")
        r = self.office.memory("push")
        self.assertEqual(r.returncode, 1)
        self.assertIn("blocked", r.stdout)
        self.assertFalse((self.drive / "github.com_invento_sundora" / "decisions.md").exists())

    def test_not_connected_points_to_connect(self):
        env = {**self.office.env(), "DEVMIND_MEMORY_REMOTE": "devmind-gdrive:DevMind-Memory"}
        r = subprocess.run(["python3", str(DEVMIND), "memory", "push"], cwd=self.office.repo, text=True,
                           capture_output=True, env=env)
        self.assertEqual(r.returncode, 1)
        self.assertIn("devmind memory connect", r.stdout)
        st = json.loads(subprocess.run(["python3", str(DEVMIND), "memory", "status", "--json"], cwd=self.office.repo,
                                       text=True, capture_output=True, env=env).stdout)
        self.assertFalse(st["backend_ready"])


class ConnectHelpersTest(unittest.TestCase):
    """Unit tests for the Google Drive connect helpers (no network, no Google login)."""

    @classmethod
    def setUpClass(cls):
        from importlib.machinery import SourceFileLoader
        cls.dm = SourceFileLoader("devmind_cli", str(DEVMIND)).load_module()

    def test_authorize_blob_is_unpadded_urlsafe_base64(self):
        import base64
        blob = base64.urlsafe_b64encode(json.dumps({"scope": "drive.file"}).encode()).decode().rstrip("=")
        self.assertNotIn("=", blob)
        src = DEVMIND.read_text()
        self.assertIn('urlsafe_b64encode(json.dumps({"scope": "drive.file"})', src)

    def test_parse_authorize_token_all_rclone_formats(self):
        import base64
        tok = {"access_token": "ya29.FAKE", "token_type": "Bearer", "refresh_token": "1//FAKE", "expiry": "2026-11-05T10:00:00Z"}
        want = json.dumps(tok, separators=(",", ":"))
        wrap = lambda body: f"NOTICE: Got code\nPaste the following into your remote machine --->\n{body}\n<---End paste\n"
        nested = json.dumps({"token": json.dumps(tok)})
        b64 = base64.urlsafe_b64encode(nested.encode()).decode()
        cases = {
            "plain json (old rclone)": json.dumps(tok),
            "base64 {token: str}, unpadded (new rclone)": b64.rstrip("="),
            "base64 padded std": base64.b64encode(nested.encode()).decode(),
            "base64 wrapped over lines": b64[:40] + "\n" + b64[40:],
            "base64 {token: dict}": base64.urlsafe_b64encode(json.dumps({"token": tok}).encode()).decode(),
        }
        for name, body in cases.items():
            with self.subTest(name):
                self.assertEqual(json.loads(self.dm._parse_authorize_token(wrap(body))), json.loads(want))
        self.assertIsNone(self.dm._parse_authorize_token("no markers here"))
        self.assertIsNone(self.dm._parse_authorize_token(wrap("not-a-token")))

    def test_write_rclone_remote_keeps_other_remotes_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as tmp:
            conf = Path(tmp) / "rclone.conf"
            conf.write_text("[mydrive]\ntype = drive\n\n[s3]\ntype = s3\n")
            orig = self.dm._rclone_config_path
            self.dm._rclone_config_path = lambda _rc: conf
            try:
                self.dm._write_rclone_remote("rclone", "devmind-gdrive", '{"access_token":"A"}')
                self.dm._write_rclone_remote("rclone", "devmind-gdrive", '{"access_token":"B"}')
            finally:
                self.dm._rclone_config_path = orig
            text = conf.read_text()
            self.assertIn("[mydrive]", text)
            self.assertIn("[s3]", text)
            self.assertEqual(text.count("[devmind-gdrive]"), 1)
            self.assertIn('token = {"access_token":"B"}', text)
            self.assertIn("scope = drive.file", text)
            self.assertEqual(conf.stat().st_mode & 0o777, 0o600)

    def test_encrypted_rclone_config_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            conf = Path(tmp) / "rclone.conf"
            conf.write_text("# Encrypted rclone configuration File\n\nRCLONE_ENCRYPT_V0:\nabc\n")
            orig = self.dm._rclone_config_path
            self.dm._rclone_config_path = lambda _rc: conf
            try:
                with self.assertRaises(RuntimeError):
                    self.dm._write_rclone_remote("rclone", "devmind-gdrive", "{}")
            finally:
                self.dm._rclone_config_path = orig


if __name__ == "__main__":
    unittest.main()
