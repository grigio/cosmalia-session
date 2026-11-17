#!/usr/bin/env bash
# Verify Cosmalia session installation
# Run after installing the package or running install.sh
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Prefix for the checked file paths. Empty for a real installation; tests set
# COSMALIA_ROOT to a temporary tree so no files have to be written to /usr.
root=${COSMALIA_ROOT:-}

check_bin() {
    if command -v "$1" >/dev/null; then
        echo -e "${GREEN}✓${NC} $1"
        return 0
    else
        echo -e "${RED}✗${NC} $1 (missing)"
        return 1
    fi
}

check_opt_bin() {
    if command -v "$1" >/dev/null; then
        echo -e "${GREEN}✓${NC} $1 (optional)"
    else
        echo -e "${YELLOW}⚠${NC} $1 (optional, not installed)"
    fi
    return 0
}

check_file() {
    if [[ -f "$root$1" ]]; then
        echo -e "${GREEN}✓${NC} $1"
        return 0
    else
        echo -e "${RED}✗${NC} $1 (missing)"
        return 1
    fi
}

check_unit() {
    if systemctl --user list-unit-files "$1" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $1"
        return 0
    else
        echo -e "${RED}✗${NC} $1 (missing)"
        return 1
    fi
}

echo "=== Cosmalia Session Verification ==="
echo

errors=0

echo "Checking required binaries..."
check_bin cosmic-comp || errors=$((errors + 1))
check_bin noctalia || errors=$((errors + 1))
check_bin cosmic-settings-daemon || errors=$((errors + 1))
echo
echo "Checking optional apps/helpers (not required to start the session)..."
check_opt_bin cosmic-settings
check_opt_bin cosmic-screenshot
check_opt_bin inotifywait
echo
check_bin xdg-desktop-portal || errors=$((errors + 1))
check_bin gnome-keyring-daemon || errors=$((errors + 1))
check_bin wireplumber || errors=$((errors + 1))

echo
echo "Checking portal backends..."
check_file /usr/share/xdg-desktop-portal/portals/cosmic.portal || errors=$((errors + 1))
check_file /usr/share/xdg-desktop-portal/portals/gtk.portal || errors=$((errors + 1))
check_file /usr/share/xdg-desktop-portal/portals/wlr.portal || errors=$((errors + 1))
check_file /usr/share/xdg-desktop-portal/portals/gnome-keyring.portal || errors=$((errors + 1))

echo
echo "Checking compositor variant..."
if pacman -Qq cosmic-comp-traffic >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} cosmic-comp-traffic installed (patched compositor)"
else
    echo -e "${YELLOW}⚠${NC} cosmic-comp-traffic NOT installed (using stock cosmic-comp)"
    echo "       Traffic-light decorations and gestures will not work."
fi

echo
echo "Checking systemd user units..."
check_unit cosmalia-session.target || errors=$((errors + 1))
check_unit noctalia.service || errors=$((errors + 1))
check_unit cosmic-settings-daemon.service || errors=$((errors + 1))

echo
echo "Checking portal configuration..."
check_file /usr/share/xdg-desktop-portal/cosmalia-portals.conf || errors=$((errors + 1))

echo
echo "Checking XDG session entry..."
check_file /usr/share/wayland-sessions/cosmalia.desktop || errors=$((errors + 1))

echo
echo "Checking greeter helper..."
check_file /usr/bin/cosmalia-session-default || errors=$((errors + 1))

echo
echo "Checking session launcher..."
check_file /usr/bin/cosmalia-session || errors=$((errors + 1))

echo
if (( errors == 0 )); then
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}$errors check(s) failed.${NC}"
    exit 1
fi