#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

install_root=${DESTDIR:-}

if [[ $EUID -ne 0 && -z $install_root ]]; then
    echo "error: run with sudo: sudo ./tools/uninstall-linux.sh" >&2
    exit 1
fi

rm -f "$install_root/usr/bin/jiaolongctl" "$install_root/usr/bin/jiaolong-tui"
rm -f "$install_root/usr/share/polkit-1/actions/io.github.tanpinsary.jiaolongonarch.policy"
rm -f "$install_root/usr/lib/jiaolongonarch/jiaolongctl"
rm -f "$install_root/usr/lib/jiaolongonarch/jiaolong-helper"
rm -f "$install_root/usr/lib/jiaolongonarch/jiaolong-tui"
rm -f "$install_root/usr/lib/jiaolongonarch/jiaolong_core.py"
rm -f "$install_root/usr/lib/jiaolongonarch/jiaolong_tui_model.py"
rmdir "$install_root/usr/lib/jiaolongonarch" 2>/dev/null || true

echo "Removed JiaoLongOnArch userspace tools and polkit policy."
