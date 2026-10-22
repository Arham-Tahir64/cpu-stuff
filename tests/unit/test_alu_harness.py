"""Check that bad vector inputs and wrong expectations really fail the SV test.

Run after building build/alu/obj/alu_test. These checks protect the file reader,
assertion enablement and failure exit codes, not just the ALU's happy path.
"""

import resource
import subprocess
import tempfile
import unittest
from pathlib import Path


class AluHarnessTests(unittest.TestCase):
    def run_vector(self, contents: str, *, limited: bool = True):
        with tempfile.TemporaryDirectory(dir="build/alu") as directory:
            path = Path(directory) / "vectors.txt"
            path.write_text(contents, encoding="ascii")
            command = ["./build/alu/obj/alu_test", f"+vectors={path}"]
            if limited:
                command.append("+limit=1")
            return subprocess.run(command, text=True, capture_output=True, timeout=5)

    def expect_failure(self, contents, message, *, limited=True):
        result = self.run_vector(contents, limited=limited)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn(message, result.stdout + result.stderr)

    def test_known_good_vector(self):
        result = self.run_vector("0 ffffffff 00000001 00000000 0\n")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_wrong_result_fails(self):
        self.expect_failure("0 ffffffff 00000001 00000001 0\n", "row=1")

    def test_wrong_invalid_flag_fails(self):
        self.expect_failure("0 ffffffff 00000001 00000000 1\n", "row=1")

    def test_empty_file_fails(self):
        self.expect_failure("", "empty vector file")

    def test_truncated_row_fails(self):
        self.expect_failure("0 ffffffff 00000001\n", "bad vector")

    def test_malformed_tail_fails(self):
        self.expect_failure("0 ffffffff 00000001 00000000 0\ngarbage\n",
                            "bad vector", limited=False)

    def test_incomplete_control_coverage_fails(self):
        self.expect_failure("0 ffffffff 00000001 00000000 0\n",
                            "was never exercised", limited=False)


if __name__ == "__main__":
    # Expected assertion failures abort; do not leave large core dumps behind.
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    unittest.main()
