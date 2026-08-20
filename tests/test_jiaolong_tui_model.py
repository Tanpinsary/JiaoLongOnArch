# SPDX-License-Identifier: GPL-2.0-or-later
from __future__ import annotations

import os
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.jiaolong_tui_model import (
    GPU_MODES,
    KEYBOARD_MODES,
    PROFILE_OPTIONS,
    build_command,
    dashboard_from_status,
)


class JiaoLongTuiModelTest(unittest.TestCase):
    def test_controls_expose_only_reviewed_values(self) -> None:
        self.assertEqual(PROFILE_OPTIONS, ("quiet", "balanced", "performance"))
        self.assertEqual(GPU_MODES, ("hybrid", "discrete"))
        self.assertEqual(KEYBOARD_MODES, ("off", "cyclic", "fixed", "custom"))

    def test_reads_never_request_privilege(self) -> None:
        command = build_command(
            Path("/tool"), ("--json", "status"), write=False, euid=1000
        )
        self.assertEqual(command, ["/tool", "--json", "status"])

    def test_real_writes_use_pkexec_for_non_root(self) -> None:
        with patch.dict(os.environ, {}, clear=True):
            command = build_command(
                Path("/tool"), ("profile", "quiet"), write=True, euid=1000
            )
        self.assertEqual(command, ["pkexec", "/tool", "profile", "quiet"])

    def test_fake_sysfs_writes_do_not_elevate(self) -> None:
        with patch.dict(os.environ, {"JIAOLONG_SYSFS_ROOT": "/tmp/sysroot"}):
            command = build_command(
                Path("/tool"), ("profile", "quiet"), write=True, euid=1000
            )
        self.assertEqual(command, ["/tool", "profile", "quiet"])

    def test_dashboard_contains_only_reviewed_status(self) -> None:
        status = {
            "dmi": {"product_name": "Jiaolong Series MRID6", "board_name": "MRID6-23"},
            "write_allowlisted": True,
            "wmi": {
                "control_driver": "bitland-mifs-wmi",
                "event_driver": "bitland-mifs-wmi",
                "values": {"gpu_mode": "discrete", "kb_mode": "fixed"},
            },
            "hwmon": [
                {
                    "values": {
                        "temp1_input": "59000",
                        "fan1_input": "1980",
                        "fan2_input": "1976",
                        "fan3_input": "0",
                    }
                }
            ],
            "platform_profiles": [
                {"values": {"name": "bitland-mifs-wmi", "profile": "balanced"}}
            ],
            "leds": [{"brightness": "2", "max_brightness": "3"}],
        }
        view = dashboard_from_status(status)
        self.assertTrue(view.write_ready)
        self.assertEqual(view.temperature, "59 °C")
        self.assertEqual(view.fans, "1980 / 1976 / 0 RPM")
        self.assertEqual(view.profile, "balanced")
        self.assertEqual(view.keyboard, "fixed / 2/3")


if __name__ == "__main__":
    unittest.main()
