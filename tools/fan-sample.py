#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Read-only hwmon sampler for JiaoLongOnArch stage 2 fan identification.

The script polls the bitland_mifs hwmon device and optionally nvidia-smi.
It never opens WMI/sysfs control attributes for writing, so it cannot change
platform profile, GPU mode, keyboard mode, fan_boost, LED brightness, EC RAM,
or any WMI method input.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import os
import subprocess
import sys
import time
from pathlib import Path

SYSFS_ROOT = Path(os.environ.get("JIAOLONG_SYSFS_ROOT", "/")).resolve()


def rooted(path: str) -> Path:
    return SYSFS_ROOT / path.removeprefix("/")


def read_text(path: Path) -> str | None:
    try:
        return path.read_text(encoding="utf-8", errors="replace").strip("\x00\n")
    except (FileNotFoundError, PermissionError, OSError):
        return None


def find_bitland_hwmon() -> Path | None:
    for hwmon in sorted(rooted("/sys/class/hwmon").glob("hwmon*")):
        if read_text(hwmon / "name") == "bitland_mifs":
            return hwmon
    return None


def gpu_temperature_c() -> str:
    try:
        result = subprocess.run(
            [
                "nvidia-smi",
                "--query-gpu=temperature.gpu",
                "--format=csv,noheader,nounits",
            ],
            check=False,
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (FileNotFoundError, PermissionError, subprocess.TimeoutExpired):
        return ""
    if result.returncode != 0:
        return ""
    return result.stdout.strip().splitlines()[0].strip()


def sample(hwmon: Path, *, include_gpu: bool) -> dict[str, str]:
    values: dict[str, str] = {}
    for pattern in ("temp*_input", "fan*_input"):
        for item in sorted(hwmon.glob(pattern)):
            if (value := read_text(item)) is not None:
                values[item.name] = value
    if include_gpu:
        values["gpu_temp_c"] = gpu_temperature_c()
    return values


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Poll bitland_mifs hwmon read-only values; redirect stdout to a CSV file"
        )
    )
    parser.add_argument(
        "--duration",
        type=float,
        default=10.0,
        help="total seconds to sample (default: 10, use 0 for one sample)",
    )
    parser.add_argument(
        "--interval", type=float, default=1.0, help="seconds between samples"
    )
    parser.add_argument("--no-gpu", action="store_true", help="do not call nvidia-smi")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    hwmon = find_bitland_hwmon()
    if hwmon is None:
        print("error: no bitland_mifs hwmon device found", file=sys.stderr)
        return 2

    labels = {}
    for item in sorted(hwmon.glob("fan*_label")):
        if (value := read_text(item)) is not None:
            labels[item.name] = value

    columns = [
        "unix_time",
        "iso_time",
        "temp1_input",
        "fan1_input",
        "fan2_input",
        "fan3_input",
    ]
    if not args.no_gpu:
        columns.append("gpu_temp_c")

    writer = csv.DictWriter(sys.stdout, fieldnames=columns, extrasaction="ignore")
    writer.writeheader()

    if args.duration <= 0:
        writer.writerow(
            {
                "unix_time": f"{time.time():.3f}",
                "iso_time": dt.datetime.now()
                .astimezone()
                .isoformat(timespec="seconds"),
                **sample(hwmon, include_gpu=not args.no_gpu),
            }
        )
        return 0

    deadline = time.monotonic() + args.duration
    while True:
        writer.writerow(
            {
                "unix_time": f"{time.time():.3f}",
                "iso_time": dt.datetime.now()
                .astimezone()
                .isoformat(timespec="seconds"),
                **sample(hwmon, include_gpu=not args.no_gpu),
            }
        )
        now = time.monotonic()
        if now >= deadline:
            break
        time.sleep(max(0.0, min(args.interval, deadline - now)))

    for name, label in sorted(labels.items()):
        print(f"# {name}={label}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
