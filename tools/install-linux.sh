#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
install_root=${DESTDIR:-}
dest="$install_root/usr/lib/jiaolongonarch"

if [[ $EUID -ne 0 && -z $install_root ]]; then
    echo "error: run with sudo: sudo ./tools/install-linux.sh" >&2
    exit 1
fi

if [[ -z $install_root ]] && ! python3 -c 'import textual' 2>/dev/null; then
    echo "error: Textual is missing; on Arch install it with:" >&2
    echo "  sudo pacman -S python-textual" >&2
    exit 1
fi

install -d -m 0755 "$dest" "$install_root/usr/bin" \
    "$install_root/usr/share/polkit-1/actions"
install -m 0755 "$repo/tools/jiaolongctl" "$dest/jiaolongctl"
install -m 0755 "$repo/tools/jiaolong-helper" "$dest/jiaolong-helper"
install -m 0755 "$repo/tools/jiaolong-tui" "$dest/jiaolong-tui"
install -m 0644 "$repo/tools/jiaolong_core.py" "$dest/jiaolong_core.py"
install -m 0644 "$repo/tools/jiaolong_tui_model.py" "$dest/jiaolong_tui_model.py"
install -m 0644 \
    "$repo/packaging/io.github.tanpinsary.jiaolongonarch.policy" \
    "$install_root/usr/share/polkit-1/actions/io.github.tanpinsary.jiaolongonarch.policy"
ln -sfn ../lib/jiaolongonarch/jiaolongctl "$install_root/usr/bin/jiaolongctl"
ln -sfn ../lib/jiaolongonarch/jiaolong-tui "$install_root/usr/bin/jiaolong-tui"

echo "Installed jiaolongctl, jiaolong-tui and the restricted polkit helper."
