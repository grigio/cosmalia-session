#!/usr/bin/env bash
# Tests for scripts/verify.sh with a fake root and stub commands, so no files
# are written under /usr and no real systemd/pacman state is needed.
set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
verify="$root/scripts/verify.sh"

failures=0
tmp=""
# shellcheck disable=SC2329  # invoked via the EXIT trap below
cleanup() { [[ -n $tmp ]] && rm -rf -- "$tmp"; }
trap cleanup EXIT
tmp=$(mktemp -d)

fake_root="$tmp/root"
bin="$tmp/bin"
mkdir -p "$bin" \
    "$fake_root/usr/share/xdg-desktop-portal/portals" \
    "$fake_root/usr/share/wayland-sessions" \
    "$fake_root/usr/bin"

# Required binaries, plus the two commands verify.sh queries for state.
for name in cosmic-comp noctalia cosmic-settings-daemon xdg-desktop-portal \
    gnome-keyring-daemon wireplumber pacman systemctl; do
    printf '#!/bin/sh\nexit 0\n' >"$bin/$name"
    chmod +x "$bin/$name"
done

required=(
    /usr/share/xdg-desktop-portal/portals/cosmic.portal
    /usr/share/xdg-desktop-portal/portals/gtk.portal
    /usr/share/xdg-desktop-portal/portals/wlr.portal
    /usr/share/xdg-desktop-portal/portals/gnome-keyring.portal
    /usr/share/xdg-desktop-portal/cosmalia-portals.conf
    /usr/share/wayland-sessions/cosmalia.desktop
    /usr/bin/cosmalia-session-default
    /usr/bin/cosmalia-session
)
for path in "${required[@]}"; do
    mkdir -p "$fake_root$(dirname "$path")"
    : >"$fake_root$path"
done

run_verify() {
    COSMALIA_ROOT="$fake_root" PATH="$bin:$PATH" "$verify" >"$tmp/out" 2>&1
}

fail() {
    echo "  FAIL: $*" >&2
    cat "$tmp/out" >&2
    failures=$((failures + 1))
}

echo "case: complete installation"
run_verify || fail "verify.sh failed on a complete installation"
grep -q 'All checks passed' "$tmp/out" || fail "verify.sh printed no success message"

echo "case: missing required file"
rm -f "$fake_root/usr/share/wayland-sessions/cosmalia.desktop"
if run_verify; then
    fail "verify.sh succeeded with a missing session entry"
fi
grep -q '1 check(s) failed' "$tmp/out" || fail "verify.sh did not report the missing file"

echo
if (( failures == 0 )); then
    echo "All verify.sh tests passed."
    exit 0
fi
echo "$failures test(s) failed."
exit 1
