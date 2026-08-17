# SPDX-License-Identifier: GPL-2.0-or-later
from __future__ import annotations

import unittest
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]


class ProbeScriptSafetyTest(unittest.TestCase):
    def test_metadata_collector_never_invokes_firmware_method(self) -> None:
        script = (PROJECT_ROOT / "tools/collect-windows.ps1").read_text(
            encoding="utf-8"
        )
        self.assertNotIn("Invoke-CimMethod", script)
        self.assertNotIn("Invoke-WmiMethod", script)

    def test_stage2_gpu_runner_has_no_sysfs_write_path(self) -> None:
        script = (PROJECT_ROOT / "tools/stage2-gpu-load.sh").read_text(encoding="utf-8")
        code = "\n".join(
            line for line in script.splitlines() if not line.lstrip().startswith("#")
        )
        self.assertNotIn("> /sys", code)
        self.assertNotIn('>"/sys', code)
        self.assertNotIn("tee /sys", code)
        self.assertNotIn("dd of=/sys", code)
        self.assertNotIn("platform_profile", code)
        self.assertNotIn("gpu_mode", code)
        self.assertNotIn("kb_mode", code)
        self.assertNotIn("brightness", code)

    def test_stage3_writer_only_touches_reviewed_interfaces(self) -> None:
        script = (PROJECT_ROOT / "tools/stage3-write-test.sh").read_text(
            encoding="utf-8"
        )
        code = "\n".join(
            line for line in script.splitlines() if not line.lstrip().startswith("#")
        )
        self.assertNotIn("fan_boost", code)
        self.assertNotIn("gpu_mode", code)
        self.assertNotIn("uma", code)
        self.assertNotIn("0x4E", code)
        self.assertNotIn("0x4F", code)
        self.assertIn('sleep "$wait_seconds"', script)

    def test_mifs_probe_contains_get_opcode_only_and_excludes_function_20(self) -> None:
        script = (PROJECT_ROOT / "tools/probe-windows-mifs-readonly.ps1").read_text(
            encoding="utf-8"
        )
        self.assertIn("$request[1] = 0xFA", script)
        self.assertNotIn("0xFB", script)
        self.assertNotIn("\n    20 = 'MaxFanSpeedSwitch'", script)
        self.assertIn("DMI allowlist mismatch", script)


if __name__ == "__main__":
    unittest.main()
