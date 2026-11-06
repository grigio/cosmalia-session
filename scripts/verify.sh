#!/usr/bin/env bash
# Verify Cosmalia session installation
# Run after installing the package or running install.sh
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_bin() {
    if command -v "$1" >/dev/null; then
        echo -e "${GREEN}✓${NC} $1"
        return 0
    else
        echo -e "${RED}✗${NC} $1 (missing)"
        return 1
    fi
}

check_file() {
    if [[ -f "$1" ]]; then
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
check_bin cosmic-comp || ((errors++))
check_bin noctalia || ((errors++))
check_bin cosmic-settings-daemon || ((errors++))
check_bin cosmic-screenshot || ((errors++))
check_bin xdg-desktop-portal || ((errors++))
check_bin gnome-keyring-daemon || ((errors++))
check_bin wireplumber || ((errors++))

echo
echo "Checking portal backends..."
check_file /usr/share/xdg-desktop-portal/portals/cosmic.portal || ((errors++))
check_file /usr/share/xdg-desktop-portal/portals/gnome.portal || ((errors++))
check_file /usr/share/xdg-desktop-portal/portals/gtk.portal || ((errors++))
check_file /usr/share/xdg-desktop-portal/portals/wlr.portal || ((errors++))
check_file /usr/share/xdg-desktop-portal/portals/gnome-keyring.portal || ((errors++))

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
check_unit cosmalia-session.target || ((errors++))
check_unit noctalia.service || ((errors++))
check_unit cosmic-settings-daemon.service || ((errors++))

echo
echo "Checking portal configuration..."
check_file /usr/share/xdg-desktop-portal/cosmalia-portals.conf || ((errors++))

echo
echo "Checking XDG session entry..."
check_file /usr/share/wayland-sessions/cosmalia.desktop || ((errors++))

echo
echo "Checking greeter helper..."
check_file /usr/bin/cosmalia-session-default || ((errors++))

echo
echo "Checking session launcher..."
check_file /usr/bin/cosmalia-session || ((errors++))

echo
if (( errors == 0 )); then
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}$errors check(s) failed.${NC}"
    exit 1
fi