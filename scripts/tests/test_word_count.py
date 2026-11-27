"""Selection word count notifications, without accessing the real clipboard."""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "word-count.sh"


class WordCountTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.notification = self.directory / "notification.json"
        self.arguments = self.directory / "arguments.json"
        self.environment = {
            **os.environ,
            "PATH": f"{self.directory}:{os.environ['PATH']}",
            "NOTIFICATION": str(self.notification),
            "ARGUMENTS": str(self.arguments),
        }
        self.mock_command(
            "wl-paste",
            "import json, os, sys, time\n"
            "from pathlib import Path\n"
            "Path(os.environ['ARGUMENTS']).write_text(json.dumps(sys.argv[1:]))\n"
            "time.sleep(float(os.environ.get('PASTE_DELAY', '0')))\n"
            "sys.stdout.write(os.environ.get('SELECTION', ''))\n"
            "sys.exit(int(os.environ.get('PASTE_STATUS', '0')))\n",
        )
        self.mock_command(
            "notify-send",
            "import json, os, sys\n"
            "from pathlib import Path\n"
            "Path(os.environ['NOTIFICATION']).write_text(json.dumps(sys.argv[1:]))\n",
        )

    def mock_command(self, name, content):
        command = self.directory / name
        command.write_text("#!/usr/bin/env python3\n" + content)
        command.chmod(0o755)

    def run_count(self, selection="", **environment):
        subprocess.run(
            ["bash", str(SCRIPT)],
            env={**self.environment, "SELECTION": selection, **environment},
            check=True,
            capture_output=True,
            timeout=5,
        )
        self.assertEqual(
            json.loads(self.arguments.read_text()),
            ["--primary", "--no-newline", "--type", "text"],
        )
        arguments = json.loads(self.notification.read_text())
        self.assertEqual(arguments[:4], ["-a", "Word count", "-t", "5000"])
        return arguments[4:]

    def test_counts_words(self):
        for selection in ("one two three", "one\n\ttwo   three", "café 世界 hello"):
            with self.subTest(selection=selection):
                self.assertEqual(self.run_count(selection), ["3 words selected"])

    def test_singular(self):
        self.assertEqual(self.run_count("hello"), ["1 word selected"])

    def test_empty_selection(self):
        for selection in ("", " \n\t"):
            with self.subTest(selection=selection):
                self.assertEqual(self.run_count(selection)[0], "No words selected")

    def test_unavailable_selection(self):
        self.assertEqual(self.run_count(PASTE_STATUS="1")[0], "No selection available")

    def test_partial_failed_read_is_not_counted(self):
        self.assertEqual(self.run_count("partial text", PASTE_STATUS="1")[0], "No selection available")

    def test_unresponsive_owner(self):
        self.assertEqual(self.run_count(PASTE_DELAY="10")[0], "No selection available")

    def test_selection_is_never_executed(self):
        self.assertEqual(self.run_count("$(false) `false` <b>hello</b>"), ["3 words selected"])


if __name__ == "__main__":
    unittest.main()
