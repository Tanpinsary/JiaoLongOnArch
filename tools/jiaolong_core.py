# SPDX-License-Identifier: GPL-2.0-or-later
"""Importable safety API backed by the existing jiaolongctl implementation.

Keeping this adapter small preserves the reviewed CLI implementation while CLI,
TUI and the privileged helper converge on one API. A later packaging-only change
can move the implementation without changing consumers.
"""

from __future__ import annotations

import importlib.util
import sys
from importlib.machinery import SourceFileLoader
from pathlib import Path
from types import ModuleType
from typing import Any


def _load_cli() -> ModuleType:
    path = Path(__file__).with_name("jiaolongctl")
    name = "_jiaolongctl_core"
    if loaded := sys.modules.get(name):
        return loaded
    loader = SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(name, loader)
    if spec is None:
        raise ImportError(f"cannot load core implementation from {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    loader.exec_module(module)
    return module


_core = _load_cli()

JiaolongError = _core.JiaolongError
PROFILE_MAP: dict[str, str] = _core.PROFILE_MAP
GPU_MODES: tuple[str, ...] = _core.GPU_MODES
KEYBOARD_MODES: tuple[str, ...] = _core.KEYBOARD_MODES


def collect_status() -> dict[str, Any]:
    return _core.collect_status()


def set_profile(mode: str, *, dry_run: bool = False) -> None:
    _core.set_profile(mode, dry_run=dry_run)


def set_gpu_mode(mode: str, *, confirmed: bool, dry_run: bool = False) -> None:
    _core.set_gpu_mode(mode, confirmed=confirmed, dry_run=dry_run)


def set_keyboard_brightness(value: int, *, dry_run: bool = False) -> None:
    _core.set_keyboard_brightness(value, dry_run=dry_run)


def set_keyboard_mode(mode: str, *, dry_run: bool = False) -> None:
    _core.set_keyboard_mode(mode, dry_run=dry_run)
