# Maintainer: Tanpinsary
pkgname=jiaolongonarch
pkgver=0.1.0
pkgrel=1
pkgdesc="Safe firmware controls and TUI for MECHREVO Jiaolong MRID6 laptops"
arch=('any')
url="https://github.com/Tanpinsary/JiaoLongOnArch"
license=('GPL-2.0-or-later')
depends=('python' 'python-textual' 'polkit')
makedepends=('git')
checkdepends=('ruff')
optdepends=('linux>=7.1: upstream bitland-mifs-wmi kernel driver')
options=('!debug')
source=("JiaoLongOnArch::git+${_git_url:-$url.git}#${_source_ref:-tag=v$pkgver}")
sha256sums=('SKIP')

check() {
    cd JiaoLongOnArch
    ruff check tools/jiaolongctl tools/jiaolong-tui tools/*.py tests/*.py
    ruff format --check tools/jiaolongctl tools/jiaolong-tui tools/*.py tests/*.py
    python -m unittest discover -s tests -v
    bash -n tools/*.sh
}

package() {
    cd JiaoLongOnArch
    local appdir="$pkgdir/usr/lib/jiaolongonarch"

    install -d -m 0755 "$appdir" "$pkgdir/usr/bin" \
        "$pkgdir/usr/share/polkit-1/actions" \
        "$pkgdir/usr/share/doc/$pkgname"
    install -m 0755 tools/jiaolongctl "$appdir/jiaolongctl"
    install -m 0755 tools/jiaolong-helper "$appdir/jiaolong-helper"
    install -m 0755 tools/jiaolong-tui "$appdir/jiaolong-tui"
    install -m 0644 tools/jiaolong_core.py "$appdir/jiaolong_core.py"
    install -m 0644 tools/jiaolong_tui_model.py "$appdir/jiaolong_tui_model.py"
    install -m 0644 packaging/io.github.tanpinsary.jiaolongonarch.policy \
        "$pkgdir/usr/share/polkit-1/actions/io.github.tanpinsary.jiaolongonarch.policy"
    ln -s ../lib/jiaolongonarch/jiaolongctl "$pkgdir/usr/bin/jiaolongctl"
    ln -s ../lib/jiaolongonarch/jiaolong-tui "$pkgdir/usr/bin/jiaolong-tui"
    install -m 0644 README.md CHANGELOG.md docs/roadmap.md \
        "$pkgdir/usr/share/doc/$pkgname/"
}
