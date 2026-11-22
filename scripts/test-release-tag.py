#!/usr/bin/env python3
"""Exercise tag identity checks against real local repositories; no network."""
import pathlib, subprocess, tempfile, unittest

HELPER = pathlib.Path(__file__).with_name("check-release-tag.sh").resolve()

class ReleaseTagTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = pathlib.Path(self.tmp.name)
        self.remote = self.root / "remote.git"
        self.repo = self.root / "repo"
        self.git("init", "--bare", str(self.remote))
        self.git("init", "-b", "main", str(self.repo))
        self.git("config", "user.email", "test@example.invalid", cwd=self.repo)
        self.git("config", "user.name", "Release test", cwd=self.repo)
        self.git("commit", "--allow-empty", "-m", "first", cwd=self.repo)
        self.first = self.git("rev-parse", "HEAD", cwd=self.repo).strip()
        self.git("commit", "--allow-empty", "-m", "second", cwd=self.repo)
        self.second = self.git("rev-parse", "HEAD", cwd=self.repo).strip()
        self.git("remote", "add", "origin", str(self.remote), cwd=self.repo)
        self.git("push", "origin", "main", cwd=self.repo)

    def git(self, *args, cwd=None):
        return subprocess.check_output(["git", *args], cwd=cwd, stderr=subprocess.DEVNULL, text=True)

    def check(self, tag, expected, missing="required", remote=None):
        return subprocess.run(["bash", "-c", 'source "$1"; check_release_tag "$2" "$3" "$4" "$5"',
            "test", str(HELPER), str(remote or self.remote), tag, expected, missing], capture_output=True, text=True)

    def test_matching_and_mismatched_lightweight_and_annotated_tags(self):
        for tag, annotated in [("light", False), ("annotated", True)]:
            self.git("tag", *(["-a", "-m", "release"] if annotated else []), tag, self.first, cwd=self.repo)
            self.git("push", "origin", "refs/tags/"+tag, cwd=self.repo)
            self.assertEqual(self.check(tag, self.first).returncode, 0)
            mismatch = self.check(tag, self.second)
            self.assertNotEqual(mismatch.returncode, 0)
            self.assertIn("publication stopped", mismatch.stderr)

    def test_missing_and_unreachable_are_distinct(self):
        self.assertNotEqual(self.check("missing", self.second).returncode, 0)
        self.assertEqual(self.check("missing", self.second, "allow-missing").returncode, 0)
        self.assertNotEqual(self.check("missing", self.second, "allow-missing", self.root/"absent.git").returncode, 0)

if __name__ == "__main__":
    unittest.main()
