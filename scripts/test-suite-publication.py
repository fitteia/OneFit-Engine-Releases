#!/usr/bin/env python3
"""Run the publication gate with local Git and a recording GitHub stub."""
import importlib.util
import os
import pathlib
import subprocess
import unittest

HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("tagtests", HERE / "test-release-tag.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class PublicationTests(module.ReleaseTagTests):
    def publish(self, remote_commit, final_commit=None, exists=True):
        if remote_commit:
            self.git("tag", "suite-test", remote_commit, cwd=self.repo)
            self.git("push", "origin", "refs/tags/suite-test", cwd=self.repo)
        (self.repo / "scripts").mkdir()
        (self.repo / "scripts/check-release-tag.sh").write_text((HERE / "check-release-tag.sh").read_text())
        stage = self.repo / "build/test"
        stage.mkdir(parents=True)
        bindir = self.root / "bin"
        bindir.mkdir()
        calls = self.root / "calls"
        gh = bindir / "gh"
        gh.write_text('''#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$CALLS"
if [ "$1 $2" = 'release view' ]; then exit "$EXISTS_CODE"; fi
if [ "$1" = api ]; then echo "$FINAL_COMMIT"; fi
''')
        gh.chmod(0o755)
        source = (HERE / "make-suite-release.sh").read_text()
        gate = source[source.index("# The release tag must hold"):]
        prelude = 'set -euo pipefail\nsuite=suite-test\nhere_repo=test/repo\nstage=build/test\nall=asset\nprerelease=\n'
        env = dict(os.environ, PATH=str(bindir)+os.pathsep+os.environ["PATH"], CALLS=str(calls),
                   FINAL_COMMIT=final_commit or self.second, EXISTS_CODE="0" if exists else "1")
        result = subprocess.run(["bash", "-c", prelude+gate], cwd=self.repo, env=env, capture_output=True, text=True)
        return result, calls.read_text() if calls.exists() else ""

    def test_mismatch_stops_before_any_github_call(self):
        result, calls = self.publish(self.first)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("publication stopped", result.stderr)
        self.assertEqual(calls, "")

    def test_matching_release_can_resume(self):
        result, calls = self.publish(self.second)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("release upload", calls)

    def test_missing_tag_can_create_release(self):
        result, calls = self.publish(None, exists=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("release create", calls)

    def test_final_verification_failure_is_nonzero(self):
        result, _ = self.publish(self.second, final_commit=self.first)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Verification failed", result.stderr)

if __name__ == "__main__":
    unittest.main()
