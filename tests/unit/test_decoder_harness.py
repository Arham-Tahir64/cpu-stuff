"""Test decoder checker failures, including bad control/field expectations."""

import resource
import subprocess
import tempfile
import unittest
from pathlib import Path


class DecoderHarnessTests(unittest.TestCase):
    # Canonical NOP is ADDI x0,x0,0: reg-write intent + RS1 + immediate I.
    GOOD = "00000013 0c048000 0000 12\n"

    def run_vector(self, contents, *, limited=True):
        with tempfile.TemporaryDirectory(dir="build/decoder") as directory:
            path = Path(directory) / "vectors.txt"
            path.write_text(contents, encoding="ascii")
            command = ["./build/decoder/obj/decoder_test", f"+vectors={path}"]
            if limited:
                command.append("+limit=1")
            return subprocess.run(command, text=True, capture_output=True, timeout=5)

    def expect_failure(self, contents, message, *, limited=True):
        result = self.run_vector(contents, limited=limited)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn(message, result.stdout + result.stderr)

    def test_known_good_vector(self):
        result = self.run_vector(self.GOOD)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_wrong_write_control_fails(self):
        self.expect_failure("00000013 04048000 0000 12\n", "row=1")

    def test_unsafe_illegal_expectation_fails(self):
        self.expect_failure("00000000 10000800 0000 28\n", "row=1")

    def test_wrong_register_field_fails(self):
        self.expect_failure("00000013 0c048000 0001 12\n", "row=1")

    def test_empty_file_fails(self):
        self.expect_failure("", "empty vector file")

    def test_truncated_row_fails(self):
        self.expect_failure("00000013 0c048000\n", "bad vector")

    def test_malformed_tail_fails(self):
        self.expect_failure(self.GOOD + "garbage\n", "bad vector", limited=False)

    def test_bad_coverage_id_fails(self):
        self.expect_failure("00000013 0c048000 0000 29\n", "bad coverage ID")

    def test_missing_instruction_coverage_fails(self):
        self.expect_failure(self.GOOD, "was never exercised", limited=False)


if __name__ == "__main__":
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    unittest.main()
