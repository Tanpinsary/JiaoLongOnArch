# SPDX-License-Identifier: GPL-2.0-or-later
from __future__ import annotations

import os
import subprocess
import unittest
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
HELPER = PROJECT_ROOT / "tools" / "jiaolong-helper"


class JiaolongHelperTest(unittest.TestCase):
    def run_helper(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(HELPER), *arguments],
            check=False,
            capture_output=True,
            text=True,
            env=os.environ | {"JIAOLONG_SYSFS_ROOT": "/nonexistent-test-sysfs"},
        )

    def test_rejects_unknown_commands(self) -> None:
        result = self.run_helper("write-path", "/sys/arbitrary", "value")
        self.assertEqual(result.returncode, 2)
        self.assertIn("invalid choice", result.stderr)

    def test_rejects_unreviewed_values(self) -> None:
        self.assertEqual(self.run_helper("profile", "full-speed").returncode, 2)
        self.assertEqual(self.run_helper("gpu-mode", "uma").returncode, 2)
        self.assertEqual(self.run_helper("keyboard-brightness", "4").returncode, 2)

    def test_gpu_mode_requires_confirmation_flag(self) -> None:
        result = self.run_helper("gpu-mode", "hybrid")
        self.assertEqual(result.returncode, 2)
        self.assertIn("--confirm-reboot-required", result.stderr)

    def test_source_has_no_arbitrary_path_interface(self) -> None:
        source = HELPER.read_text(encoding="utf-8")
        self.assertNotIn("write_sysfs", source)
        self.assertNotIn("Path(", source)
        self.assertNotIn("subprocess", source)


if __name__ == "__main__":
    unittest.main()
