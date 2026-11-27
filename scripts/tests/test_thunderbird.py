"""Profile safety, portability and age round-trip tests, with no live account data."""

import base64
import contextlib
import gzip
import importlib.util
import io
import json
import shutil
import sqlite3
import subprocess
import tempfile
import unittest
from contextlib import closing
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "thunderbird.py"
spec = importlib.util.spec_from_file_location("thunderbird", SCRIPT)
assert spec is not None and spec.loader is not None
thunderbird = importlib.util.module_from_spec(spec)
spec.loader.exec_module(thunderbird)


class ThunderbirdTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.root = self.home / ".thunderbird"
        self.root.mkdir(mode=0o700)
        (self.root / "user.js").write_text('user_pref("mailnews.headers.sendUserAgent", false);\n')
        self.profile = self.root / "original"
        self.profile.mkdir()
        self.identity = self.home / "identity.txt"
        self.document = self.home / "secrets.toml"
        self.payload = {
            "version": 1,
            "prefs": {
                "mail.account.account1.server": "server1",
                "mail.account.account1.identities": "id1",
                "mail.accountmanager.accounts": "account1",
                "mail.identity.id1.useremail": "person@example.invalid",
                "mail.server.server1.type": "imap",
                "mail.server.server1.directory-rel": "[ProfD]ImapMail/mail.example.invalid",
                "ldap_2.servers.example.carddav.url": "https://mail.example.invalid/dav/",
            },
            "files": {
                "logins.json": base64.b64encode(b'{"logins": []}').decode(),
                "key4.db": base64.b64encode(b"test NSS database").decode(),
                "ImapMail/mail.example.invalid/msgFilterRules.dat": base64.b64encode(b'version="9"\n').decode(),
            },
        }
        self.output = contextlib.redirect_stdout(io.StringIO())
        self.output.__enter__()
        self.addCleanup(self.output.__exit__, None, None, None)
        self.stopped = patch.object(thunderbird, "require_stopped")
        self.stopped.start()
        self.addCleanup(self.stopped.stop)

    def register_original(self, accounts=False):
        (self.root / "profiles.ini").write_text(
            "[Profile0]\nName=original\nIsRelative=1\nPath=original\nDefault=1\n"
            "[InstallTEST]\nDefault=original\nLocked=1\n"
            "[General]\nVersion=2\nStartWithLastProfile=1\n"
        )
        (self.root / "installs.ini").write_text("[TEST]\nDefault=original\nLocked=1\n")
        prefs = 'user_pref("mail.account.account9.server", "server9");\n' if accounts else ""
        (self.profile / "prefs.js").write_text(prefs)

    def test_install_default_takes_precedence(self):
        self.register_original()
        config = thunderbird.read_ini(self.root / "profiles.ini")
        config["Profile1"] = {"Name": "old", "Path": "old", "Default": "1"}
        thunderbird.save_ini(self.root / "profiles.ini", config)
        self.assertEqual(thunderbird.selected_profile(self.root), self.profile)

    def test_ambiguous_install_defaults_fail(self):
        self.register_original()
        config = thunderbird.read_ini(self.root / "profiles.ini")
        config["InstallOTHER"] = {"Default": "other"}
        thunderbird.save_ini(self.root / "profiles.ini", config)
        with self.assertRaises(thunderbird.SetupError):
            thunderbird.selected_profile(self.root)

    def test_portable_settings_exclude_sync_and_device_state(self):
        prefs = dict(self.payload["prefs"])
        prefs.update({
            "mail.server.server1.directory": str(self.profile / "ImapMail/mail.example.invalid"),
            "mail.server.server1.clientid": "device-only",
            "mail.server.server1.serverIDResponse": "cached response",
            "mail.server.server1.lastFilterTime": 123,
            "ldap_2.servers.example.carddav.token": "old sync token",
            "toolkit.telemetry.cachedProfileGroupID": "device-only",
        })
        self.assertEqual(thunderbird.portable_prefs(prefs, self.profile), self.payload["prefs"])

    def test_external_mail_directory_fails(self):
        prefs = {"mail.server.server1.directory": "/somewhere/else"}
        with self.assertRaises(thunderbird.SetupError):
            thunderbird.portable_prefs(prefs, self.profile)
        prefs["mail.server.server1.directory-rel"] = "[ProfD]../../elsewhere"
        with self.assertRaises(thunderbird.SetupError):
            thunderbird.portable_prefs(prefs, self.profile)

    def test_snapshot_rejects_traversal_and_missing_login_key(self):
        for name in (".", "../logins.json", "/logins.json", "Mail/../../prefs.js", "unrelated.txt"):
            with self.subTest(name=name):
                payload = dict(self.payload, files={name: ""})
                with self.assertRaises(thunderbird.SetupError):
                    thunderbird.validate_snapshot(payload)
        payload = dict(self.payload, files={"logins.json": self.payload["files"]["logins.json"]})
        with self.assertRaises(thunderbird.SetupError):
            thunderbird.validate_snapshot(payload)

    def test_existing_accounts_are_never_decrypted_or_overwritten(self):
        self.register_original(accounts=True)
        before = (self.profile / "prefs.js").read_bytes()
        with patch.object(thunderbird, "open_snapshot") as opened:
            thunderbird.setup(self.root, self.document, self.identity)
        opened.assert_not_called()
        self.assertEqual((self.profile / "prefs.js").read_bytes(), before)
        self.assertTrue((self.profile / "user.js").is_symlink())
        self.assertEqual(thunderbird.selected_profile(self.root), self.profile)

    def test_missing_identity_defers_without_changing_registry(self):
        self.register_original()
        before = (self.root / "profiles.ini").read_bytes()
        with patch.object(thunderbird, "open_snapshot") as opened:
            thunderbird.setup(self.root, self.document, self.identity)
        opened.assert_not_called()
        self.assertEqual((self.root / "profiles.ini").read_bytes(), before)
        self.assertFalse((self.root / "arch-config").exists())

    def test_clean_home_restores_automatically_after_identity_arrives(self):
        with patch.object(thunderbird, "open_snapshot", return_value=self.payload) as opened:
            thunderbird.setup(self.root, self.document, self.identity)
            opened.assert_not_called()
            self.assertIsNone(thunderbird.selected_profile(self.root))
            self.identity.touch()
            thunderbird.setup(self.root, self.document, self.identity)
        opened.assert_called_once()
        self.assertEqual(thunderbird.selected_profile(self.root), self.root / "arch-config")
        self.assertTrue(thunderbird.has_accounts(self.root / "arch-config"))

    def test_restore_is_private_portable_and_idempotent(self):
        self.register_original()
        self.identity.touch()
        with patch.object(thunderbird, "open_snapshot", return_value=self.payload) as opened:
            thunderbird.setup(self.root, self.document, self.identity)
            thunderbird.setup(self.root, self.document, self.identity)
        opened.assert_called_once()
        restored = self.root / "arch-config"
        prefs = thunderbird.read_prefs(restored / "prefs.js")
        self.assertEqual(prefs["mail.server.server1.directory"], str(restored / "ImapMail/mail.example.invalid"))
        self.assertEqual((restored / "key4.db").read_bytes(), b"test NSS database")
        self.assertEqual(restored.stat().st_mode & 0o777, 0o700)
        self.assertEqual((restored / "key4.db").stat().st_mode & 0o777, 0o600)
        self.assertTrue((restored / "user.js").is_symlink())
        self.assertTrue(self.profile.exists())
        self.assertEqual(thunderbird.selected_profile(self.root), restored)
        self.assertEqual(thunderbird.read_ini(self.root / "installs.ini")["TEST"]["Default"], "arch-config")
        self.assertEqual(len(list(self.root.glob("profiles.ini.pre-stow.*"))), 1)

    def test_separate_restore_preserves_existing_profile_and_credentials(self):
        self.register_original(accounts=True)
        (self.profile / "key4.db").write_bytes(b"original keys")
        self.identity.touch()
        with patch.object(thunderbird, "open_snapshot", return_value=self.payload):
            thunderbird.setup(self.root, self.document, self.identity, new_profile=True)
        self.assertEqual((self.profile / "key4.db").read_bytes(), b"original keys")
        self.assertEqual(thunderbird.selected_profile(self.root), self.root / "arch-config")

    def test_incomplete_restore_is_not_overwritten(self):
        destination = self.root / "arch-config"
        destination.mkdir()
        (destination / "key4.db").write_bytes(b"existing keys")
        with self.assertRaises(thunderbird.SetupError):
            thunderbird.seed_profile(self.root, self.payload)
        self.assertEqual((destination / "key4.db").read_bytes(), b"existing keys")

    def test_profile_inside_repo_is_refused(self):
        with self.assertRaises(thunderbird.SetupError):
            thunderbird.require_local(thunderbird.REPO / "target/private-profile")

    def test_previous_user_js_is_preserved(self):
        destination = self.profile / "user.js"
        destination.write_text("// original settings\n")
        thunderbird.link_preferences(self.root, self.profile)
        backups = list(self.profile.glob("user.js.pre-stow.*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), "// original settings\n")
        thunderbird.link_preferences(self.root, self.profile)
        self.assertEqual(len(list(self.profile.glob("user.js.pre-stow.*"))), 1)

    def test_database_snapshot_includes_wal(self):
        database = self.profile / "key4.db"
        with closing(sqlite3.connect(database)) as source:
            source.execute("PRAGMA journal_mode=WAL")
            source.execute("CREATE TABLE example (value TEXT)")
            source.execute("INSERT INTO example VALUES ('test-only')")
            source.commit()
            content = thunderbird.database_bytes(database)
        path = self.profile / "restored.db"
        path.write_bytes(content)
        with closing(sqlite3.connect(path)) as connection:
            self.assertEqual(connection.execute("SELECT value FROM example").fetchone(), ("test-only",))

    @unittest.skipUnless(shutil.which("age") and shutil.which("age-keygen"), "age binaries unavailable")
    def test_real_age_round_trip_and_wrong_identity(self):
        subprocess.run(["age-keygen", "-o", str(self.identity)], check=True, capture_output=True)
        recipient = subprocess.run(["age-keygen", "-y", str(self.identity)], check=True, capture_output=True, text=True).stdout.strip()
        value = base64.b64encode(gzip.compress(json.dumps(self.payload).encode())).decode()
        plaintext = f"recipients = [{json.dumps(recipient)}]\n[secrets.{thunderbird.RECORD}]\nvalue = {json.dumps(value)}\n"
        sealed = subprocess.run(["age", "--armor", "--recipient", recipient], input=plaintext, text=True, capture_output=True, check=True).stdout
        self.document.write_text(
            f"[groups.thunderbird]\nrecipients = [{json.dumps(recipient)}]\n"
            f"[groups.thunderbird.secrets.{thunderbird.RECORD}]\nnote = 'test snapshot'\n"
            f"[sealed]\nthunderbird = '''\n{sealed}'''\n"
        )
        self.assertEqual(thunderbird.open_snapshot(self.document, self.identity), self.payload)
        other_identity = self.home / "other.txt"
        subprocess.run(["age-keygen", "-o", str(other_identity)], check=True, capture_output=True)
        with self.assertRaises(thunderbird.SetupError):
            thunderbird.open_snapshot(self.document, other_identity)


class RunningProcessTests(unittest.TestCase):
    def test_running_thunderbird_is_refused(self):
        with (
            patch.object(thunderbird.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)),
            self.assertRaises(thunderbird.SetupError),
        ):
            thunderbird.require_stopped()

    def test_failed_process_check_is_refused(self):
        with (
            patch.object(thunderbird.subprocess, "run", return_value=subprocess.CompletedProcess([], 2)),
            self.assertRaises(thunderbird.SetupError),
        ):
            thunderbird.require_stopped()


if __name__ == "__main__":
    unittest.main()
