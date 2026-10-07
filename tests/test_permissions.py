import contextlib
import importlib.machinery
import importlib.util
import io
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

loader = importlib.machinery.SourceFileLoader(
    "setup_permissions", str(Path(__file__).parents[1] / "scripts/setup-permissions")
)
spec = importlib.util.spec_from_loader(loader.name, loader)
setup = importlib.util.module_from_spec(spec)
loader.exec_module(setup)


class PermissionsTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.target = Path(self.directory.name) / "test.rules"
        self.backup = Path(self.directory.name) / "backups"
        for name, value in [("TARGET", self.target), ("BACKUP", self.backup)]:
            patcher = patch.object(setup, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)

    def run_installer(self, *arguments, uid=0):
        with patch("sys.argv", ["setup-permissions", *arguments]), \
                patch.object(setup.os, "geteuid", return_value=uid), \
                patch.object(setup.pwd, "getpwnam", return_value=SimpleNamespace(pw_uid=1000)), \
                patch.object(setup.os, "chown"), \
                contextlib.redirect_stdout(io.StringIO()), \
                contextlib.redirect_stderr(io.StringIO()):
            return setup.main()

    def test_preview_works_without_root_and_does_not_write(self):
        self.assertEqual(self.run_installer("install", "--user", "alice", "--dry-run", uid=1000), 0)
        self.assertFalse(self.target.exists())
        self.assertFalse(self.backup.exists())

    def test_real_install_requires_root(self):
        with self.assertRaises(SystemExit):
            self.run_installer("install", "--user", "alice", uid=1000)
        self.assertFalse(self.target.exists())

    def test_install_and_remove_preserve_previous_rule_in_backups(self):
        previous = "// Existing local rule\n"
        self.target.write_text(previous)
        self.assertEqual(self.run_installer("install", "--user", "alice"), 0)
        generated = self.target.read_text()
        self.assertIn('subject.user === "alice"', generated)
        self.assertEqual(self.target.stat().st_mode & 0o777, 0o644)
        self.assertEqual(self.run_installer("remove"), 0)
        self.assertFalse(self.target.exists())
        self.assertCountEqual([item.read_text() for item in self.backup.iterdir()], [previous, generated])

    def test_remove_does_not_delete_an_unrelated_rule(self):
        self.target.write_text("// Administrator rule\n")
        with self.assertRaises(SystemExit):
            self.run_installer("remove")
        self.assertEqual(self.target.read_text(), "// Administrator rule\n")

    def test_install_refuses_symbolic_link(self):
        other = Path(self.directory.name) / "other.rules"
        other.write_text("// Preserve this\n")
        self.target.symlink_to(other)
        with self.assertRaises(SystemExit):
            self.run_installer("install", "--user", "alice")
        self.assertEqual(other.read_text(), "// Preserve this\n")

    def test_username_is_encoded_as_javascript_string(self):
        rule = setup.render_rule('alice"\\example')
        self.assertIn('subject.user === "alice\\"\\\\example"', rule)
        self.assertNotIn("__USERNAME_JSON__", rule)


if __name__ == "__main__":
    unittest.main()
