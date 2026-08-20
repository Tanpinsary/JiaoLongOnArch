# SPDX-License-Identifier: GPL-2.0-or-later
"""Command and view model shared by the JiaoLong Textual frontend."""

from __future__ import annotations

import os
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Sequence

try:
    from .jiaolong_core import collect_status
except ImportError:
    from jiaolong_core import collect_status

PROFILE_OPTIONS = ("quiet", "balanced", "performance")
KEYBOARD_MODES = ("off", "cyclic", "fixed", "custom")
GPU_MODES = ("hybrid", "discrete")


class TuiCommandError(RuntimeError):
    """A safe error returned by jiaolongctl or the privilege helper."""


@dataclass(frozen=True)
class Dashboard:
    hardware: str
    driver: str
    temperature: str
    fans: str
    profile: str
    gpu_mode: str
    keyboard: str
    keyboard_mode: str
    brightness: str
    write_ready: bool

    @property
    def profile_option(self) -> str | None:
        return {
            "low-power": "quiet",
            "balanced": "balanced",
            "balanced-performance": "performance",
        }.get(self.profile)


def build_command(
    tool: Path,
    arguments: Sequence[str],
    *,
    write: bool,
    euid: int | None = None,
) -> list[str]:
    """Build a command without a shell; writes are elevated as a single action."""
    command = [str(tool), *arguments]
    effective_uid = os.geteuid() if euid is None else euid
    if write and effective_uid != 0 and "JIAOLONG_SYSFS_ROOT" not in os.environ:
        return ["pkexec", *command]
    return command


def read_status() -> dict[str, Any]:
    """Read status in-process; this path never requests privilege."""
    return collect_status()


def run_action(tool: Path, arguments: Sequence[str]) -> str:
    result = subprocess.run(
        build_command(tool, arguments, write=True),
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise TuiCommandError(result.stderr.strip() or "control command failed")
    return result.stdout.strip()


def dashboard_from_status(status: dict[str, Any]) -> Dashboard:
    dmi = status.get("dmi", {})
    wmi = status.get("wmi", {})
    values = wmi.get("values", {})
    hwmon = status.get("hwmon", [])
    sensors = hwmon[0].get("values", {}) if hwmon else {}
    profiles = status.get("platform_profiles", [])
    profile = next(
        (
            item.get("values", {}).get("profile")
            for item in profiles
            if item.get("values", {}).get("name") == "bitland-mifs-wmi"
        ),
        "unavailable",
    )
    leds = status.get("leds", [])
    brightness = leds[0].get("brightness", "?") if leds else "?"
    maximum = leds[0].get("max_brightness", "?") if leds else "?"
    temperature = sensors.get("temp1_input")
    temperature_text = (
        f"{int(temperature) / 1000:.0f} °C"
        if temperature is not None
        else "unavailable"
    )
    fan_values = [sensors.get(f"fan{index}_input") for index in (1, 2, 3)]
    fans = " / ".join(value if value is not None else "?" for value in fan_values)
    write_ready = bool(
        status.get("write_allowlisted")
        and wmi.get("control_driver") == "bitland-mifs-wmi"
        and wmi.get("event_driver") == "bitland-mifs-wmi"
    )
    return Dashboard(
        hardware=f"{dmi.get('product_name', '?')} / {dmi.get('board_name', '?')}",
        driver=(
            "ready"
            if write_ready
            else f"control={wmi.get('control_driver') or 'unbound'}, "
            f"event={wmi.get('event_driver') or 'unbound'}"
        ),
        temperature=temperature_text,
        fans=f"{fans} RPM",
        profile=profile,
        gpu_mode=values.get("gpu_mode", "unavailable"),
        keyboard=f"{values.get('kb_mode', 'unavailable')} / {brightness}/{maximum}",
        keyboard_mode=values.get("kb_mode", "unavailable"),
        brightness=brightness,
        write_ready=write_ready,
    )
