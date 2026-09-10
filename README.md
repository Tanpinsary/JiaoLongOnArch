# JiaoLongOnArch

JiaoLongOnArch is a small, safety-focused userspace control tool for the 2023
MECHREVO Jiaolong 16 Pro (`MRID6-23`, Ryzen 7 7745HX / RTX 4060) on Arch Linux.
It works with the upstream `bitland-mifs-wmi` kernel driver and deliberately
does not ship a competing DKMS module.

The project provides a command-line interface, a Textual TUI, and a restricted
polkit helper. It turns the firmware controls already exposed by the upstream
driver into an explicit, model-checked interface.

## Scope

- Read temperatures, fan channels, power profile, GPU mode, keyboard state,
  driver binding, and DMI compatibility.
- Select the verified `quiet`, `balanced`, and `performance` profiles.
- Set keyboard brightness and mode, and select Hybrid or Discrete GPU mode.
- Require an exact DMI, motherboard, and BIOS allowlist match before a write.

This is not an arbitrary WMI or EC write utility. It does not expose manual
fan control, `fan_boost`, UMA mode, firmware profile 3, EC RAM access, Ryzen
SMU controls, GPU overclocking, undervolting, or power-limit changes.

## Requirements

- Arch Linux with a kernel that includes `bitland-mifs-wmi` (Arch Linux 7.1 or
  later).
- The targeted MRID6-23 machine and supported BIOS. Read-only status remains
  useful elsewhere; firmware writes are refused when the allowlist does not
  match.
- `python-textual` and polkit for a system-wide installation.

Check that the upstream driver is available before using the controls:

```bash
zgrep CONFIG_BITLAND_MIFS_WMI /proc/config.gz
modinfo bitland-mifs-wmi
sudo modprobe bitland-mifs-wmi
./tools/jiaolongctl status
```

## Start the TUI

From a development checkout, install the locked Python dependencies and run
the TUI as your regular user:

```bash
uv sync
uv run ./tools/jiaolong-tui
```

The dashboard refreshes read-only state every five seconds. When a control
needs administrator rights, the TUI invokes the restricted helper through
`pkexec`; do not start the whole TUI with `sudo`. GPU-mode changes require an
explicit reboot confirmation and never reboot the machine automatically.

For a system-wide installation:

```bash
sudo pacman -S python-textual
sudo ./tools/install-linux.sh
jiaolong-tui
```

This installs `jiaolongctl`, `jiaolong-tui`, and the narrowly scoped polkit
helper. Remove them with `sudo ./tools/uninstall-linux.sh`.

## CLI

Start with the read-only status command. Dry runs validate the complete write
path without changing sysfs:

```bash
./tools/jiaolongctl status
./tools/jiaolongctl --dry-run profile balanced
./tools/jiaolongctl --dry-run keyboard-brightness 2
./tools/jiaolongctl --dry-run gpu-mode hybrid --confirm-reboot-required
```

On this hardware, the WMI event GUID can be claimed by `redmi-wmi`. If
`jiaolongctl status` returns 5, follow the documented binding workaround before
attempting any write.

## Packaging and AUR

**AUR status: not published.** The repository includes a `PKGBUILD` for the
tagged release and future AUR packaging, but there is currently no
`jiaolongonarch` AUR package to install with an AUR helper. Until then, use the
system-wide installation above or build from the included `PKGBUILD`.

## Documentation

The repository keeps conclusions and reproducible instructions, not raw probe
reports or measurement dumps. See:

- [hardware](docs/hardware.md) and [protocol](docs/protocol.md)
- [upstream and Arch integration](docs/upstream-status.md)
- [validated behavior and known limits](docs/test-plan.md)
- [TUI and core roadmap](docs/roadmap.md)

The verified MRID6-23 results cover the driver binding, conservative keyboard
and profile controls, Discrete mode, and suspend/resume stability. The detailed
evidence remains in `docs/`.

## Development

Tests use temporary sysfs fixtures and do not touch firmware:

```bash
uv sync --locked --dev
make check
```

Licensed under GPL-2.0-or-later.
