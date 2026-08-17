# SPDX-License-Identifier: GPL-2.0-or-later
from __future__ import annotations

import csv
import io
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
TOOL = PROJECT_ROOT / "tools" / "fan-sample.py"


class FanSampleTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.hwmon = self.root / "sys/class/hwmon/hwmon6"
        self.hwmon.mkdir(parents=True)
        (self.hwmon / "name").write_text("bitland_mifs\n", encoding="utf-8")
        for name, value in (
            ("temp1_input", "54000"),
            ("fan1_input", "2100"),
            ("fan2_input", "2200"),
            ("fan3_input", "0"),
            ("fan1_label", "CPU"),
            ("fan2_label", "GPU"),
            ("fan3_label", "SYS"),
        ):
            (self.hwmon / name).write_text(value + "\n", encoding="utf-8")
        self.env = os.environ | {"JIAOLONG_SYSFS_ROOT": str(self.root)}

    def tearDown(self) -> None:
        self.temp.cleanup()

    def run_tool(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(TOOL), *arguments],
            check=False,
            capture_output=True,
            text=True,
            env=self.env,
        )

    def test_single_sample_reads_hwmon_values(self) -> None:
        result = self.run_tool("--no-gpu", "--duration", "0")
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = list(csv.DictReader(io.StringIO(result.stdout)))
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["temp1_input"], "54000")
        self.assertEqual(rows[0]["fan1_input"], "2100")
        self.assertEqual(rows[0]["fan2_input"], "2200")
        self.assertEqual(rows[0]["fan3_input"], "0")

    def test_missing_hwmon_is_an_error(self) -> None:
        (self.hwmon / "name").write_text("k10temp\n", encoding="utf-8")
        result = self.run_tool("--no-gpu", "--duration", "0")
        self.assertEqual(result.returncode, 2)
        self.assertIn("no bitland_mifs hwmon", result.stderr)

    def test_sampler_has_no_sysfs_or_file_write_path(self) -> None:
        script = TOOL.read_text(encoding="utf-8")
        self.assertNotIn('open("w"', script)
        self.assertNotIn('open("a"', script)
        self.assertNotIn(".write_text(", script)
        self.assertNotIn(".write_bytes(", script)
        self.assertNotIn("stream.write(", script)


if __name__ == "__main__":
    unittest.main()
