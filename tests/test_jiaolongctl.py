# SPDX-License-Identifier: GPL-2.0-or-later
from __future__ import annotations

import gzip
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
TOOL = PROJECT_ROOT / "tools" / "jiaolongctl"
CONTROL_GUID = "B60BFB48-3E5B-49E4-A0E9-8CFFE1B3434B"
EVENT_GUID = "46C93E13-EE9B-4262-8488-563BCA757FEF"

DMI = {
    "sys_vendor": "MECHREVO",
    "product_name": "Jiaolong Series MRID6",
    "product_version": "1",
    "board_vendor": "MECHREVO",
    "board_name": "MRID6-23",
    "board_version": "Base Board Version",
    "bios_vendor": "INSYDE Corp.",
    "bios_version": "MRID6_23_P_V35",
    "bios_date": "01/10/2024",
}


class JiaolongCtlTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.env = os.environ | {"JIAOLONG_SYSFS_ROOT": str(self.root)}
        self._create_fake_sysfs()

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _write(self, relative: str, value: str) -> Path:
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value + "\n", encoding="utf-8")
        return path

    def _create_fake_sysfs(self) -> None:
        for field, value in DMI.items():
            self._write(f"sys/class/dmi/id/{field}", value)

        driver = self.root / "sys/bus/wmi/drivers/bitland-mifs-wmi"
        driver.mkdir(parents=True)
        for guid in (CONTROL_GUID, EVENT_GUID):
            device = self.root / f"sys/bus/wmi/devices/{guid}"
            device.mkdir(parents=True)
            (device / "driver").symlink_to(driver)

        self._write(f"sys/bus/wmi/devices/{CONTROL_GUID}/gpu_mode", "hybrid")
        self._write(f"sys/bus/wmi/devices/{CONTROL_GUID}/kb_mode", "fixed")

        profile = "sys/class/platform-profile/platform-profile-0"
        self._write(f"{profile}/name", "bitland-mifs-wmi")
        self._write(
            f"{profile}/choices",
            "low-power balanced balanced-performance performance",
        )
        self._write(f"{profile}/profile", "balanced")

        led = "sys/class/leds/bitland-mifs-wmi::kbd_backlight"
        self._write(f"{led}/brightness", "2")
        self._write(f"{led}/max_brightness", "3")

        hwmon = "sys/class/hwmon/hwmon0"
        self._write(f"{hwmon}/name", "bitland_mifs")
        self._write(f"{hwmon}/temp1_input", "55000")
        self._write(f"{hwmon}/fan1_input", "2600")
        self._write(f"{hwmon}/fan1_label", "CPU")

        config = self.root / "proc/config.gz"
        config.parent.mkdir(parents=True)
        with gzip.open(config, "wt", encoding="utf-8") as stream:
            stream.write("CONFIG_BITLAND_MIFS_WMI=m\n")
            stream.write("CONFIG_ACPI_WMI=y\n")

    def run_tool(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(TOOL), *arguments],
            check=False,
            capture_output=True,
            text=True,
            env=self.env,
        )

    def test_status_reports_exact_allowlist_and_upstream_driver(self) -> None:
        result = self.run_tool("--json", "status")
        self.assertEqual(result.returncode, 0, result.stderr)
        status = json.loads(result.stdout)
        self.assertTrue(status["write_allowlisted"])
        self.assertEqual(status["wmi"]["control_driver"], "bitland-mifs-wmi")
        self.assertEqual(status["wmi"]["values"]["gpu_mode"], "hybrid")
        self.assertIn("fan_boost", status["disabled_interfaces"])

    def test_profile_maps_official_performance_without_full_speed(self) -> None:
        result = self.run_tool("profile", "performance")
        self.assertEqual(result.returncode, 0, result.stderr)
        value = (
            self.root / "sys/class/platform-profile/platform-profile-0/profile"
        ).read_text(encoding="utf-8")
        self.assertEqual(value, "balanced-performance\n")

    def test_gpu_mode_requires_confirmation_then_writes_without_reboot(self) -> None:
        denied = self.run_tool("gpu-mode", "discrete")
        self.assertEqual(denied.returncode, 4)
        self.assertIn("--confirm-reboot-required", denied.stderr)

        allowed = self.run_tool("gpu-mode", "discrete", "--confirm-reboot-required")
        self.assertEqual(allowed.returncode, 0, allowed.stderr)
        value = (self.root / f"sys/bus/wmi/devices/{CONTROL_GUID}/gpu_mode").read_text(
            encoding="utf-8"
        )
        self.assertEqual(value, "discrete\n")
        self.assertIn("No reboot was started", allowed.stdout)

    def test_keyboard_controls_write_only_reviewed_ranges(self) -> None:
        brightness = self.run_tool("keyboard-brightness", "3")
        self.assertEqual(brightness.returncode, 0, brightness.stderr)
        value = (
            self.root / "sys/class/leds/bitland-mifs-wmi::kbd_backlight/brightness"
        ).read_text(encoding="utf-8")
        self.assertEqual(value, "3\n")

        mode = self.run_tool("keyboard-mode", "cyclic")
        self.assertEqual(mode.returncode, 0, mode.stderr)
        value = (self.root / f"sys/bus/wmi/devices/{CONTROL_GUID}/kb_mode").read_text(
            encoding="utf-8"
        )
        self.assertEqual(value, "cyclic\n")

    def test_dmi_mismatch_blocks_every_write(self) -> None:
        self._write("sys/class/dmi/id/bios_version", "MRID6_23_P_V36")
        result = self.run_tool("profile", "balanced")
        self.assertEqual(result.returncode, 4)
        self.assertIn("does not exactly match", result.stderr)

    def test_dry_run_does_not_modify_sysfs(self) -> None:
        result = self.run_tool("--dry-run", "profile", "quiet")
        self.assertEqual(result.returncode, 0, result.stderr)
        value = (
            self.root / "sys/class/platform-profile/platform-profile-0/profile"
        ).read_text(encoding="utf-8")
        self.assertEqual(value, "balanced\n")
        self.assertIn("DRY-RUN", result.stdout)


if __name__ == "__main__":
    unittest.main()
