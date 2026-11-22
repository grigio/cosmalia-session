#!/usr/bin/env bash
# Build a minimal CachyOS-based live ISO that boots straight into Cosmalia.
#
# Run as the normal user (makepkg refuses to run as root).  Only mkarchiso is
# invoked through sudo.  Nothing on the host is installed or overwritten:
# packages are built into iso/local-repo and the ISO appears in iso/out/.
set -euo pipefail

ISO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd -- "$ISO_DIR/.." && pwd)"
SOURCE_PROFILE="$ISO_DIR/profile"
REPO_DIR="${ISO_REPO_DIR:-$ISO_DIR/local-repo}"
OUT_DIR="${ISO_OUT_DIR:-$ISO_DIR/out}"
WORK_DIR="${ISO_WORK_DIR:-/tmp/opencode/cosmalia-iso-work}"
# Work on a copy: generated pacman.conf / mirrorlists never touch the source tree.
PROFILE="$WORK_DIR/profile"
COMP_SOURCE="${COMP_SOURCE_DIR:-$ISO_DIR/../../cosmic-comp-traffic}"
ALACRITTY_SOURCE="${ALACRITTY_SOURCE_DIR:-$ISO_DIR/../../alacritty-blur-pkg}"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
SUDO=(); (( EUID == 0 )) || SUDO=(sudo)

command -v makepkg >/dev/null || { echo "makepkg not found" >&2; exit 1; }
command -v repo-add >/dev/null || { echo "repo-add not found (install pacman)" >&2; exit 1; }
command -v mkarchiso >/dev/null || { echo "mkarchiso not found (install archiso)" >&2; exit 1; }

mkdir -p "$REPO_DIR" "$OUT_DIR"
# mkarchiso uses _run_once markers in the work dir; reuse would silently skip
# the changed profile files.  This directory is build-only scratch space.
"${SUDO[@]}" rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cp -a "$SOURCE_PROFILE" "$PROFILE"
rm -f "$OUT_DIR"/*.iso

# ---------------------------------------------------------------------------
# 1. Build cosmalia-session from this source tree (pure file-copy package).
# ---------------------------------------------------------------------------
log "Building cosmalia-session package from $SRC_DIR"
(
  cd "$SRC_DIR"
  PKGDEST="$REPO_DIR" makepkg --noconfirm --force
)

# ---------------------------------------------------------------------------
# 2. Reuse the newest locally built cosmic-comp-traffic package.
#    Set COSMIC_COMP_PKG to override the source.
# ---------------------------------------------------------------------------
if [[ -n "${COSMIC_COMP_PKG:-}" ]]; then
  comp_pkg="$COSMIC_COMP_PKG"
  [[ -f "$comp_pkg" ]] || { echo "COSMIC_COMP_PKG does not exist: $comp_pkg" >&2; exit 1; }
else
  comp_pkg="$(find "$COMP_SOURCE/out" -maxdepth 1 -name 'cosmic-comp-traffic-*.pkg.tar.zst' \
              -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2- || true)"
  [[ -n "$comp_pkg" && -f "$comp_pkg" ]] || {
    echo "No cosmic-comp-traffic package found in $COMP_SOURCE/out" >&2
    echo "Build there first, or set COSMIC_COMP_PKG=/path/to/pkg.tar.zst" >&2
    exit 1
  }
fi
log "Using $comp_pkg"
cp -f "$comp_pkg" "$REPO_DIR/"

# 2b. Locally built alacritty (with COSMIC blur/scrolling patches).
if [[ -n "${ALACRITTY_PKG:-}" ]]; then
  alacritty_pkg="$ALACRITTY_PKG"
else
  alacritty_pkg="$(find "$ALACRITTY_SOURCE" -maxdepth 1 -name 'alacritty-blur-*.pkg.tar.zst' \
                   -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2- || true)"
fi
if [[ -n "$alacritty_pkg" && -f "$alacritty_pkg" ]]; then
  log "Using $alacritty_pkg"
  cp -f "$alacritty_pkg" "$REPO_DIR/"
else
  # No local patched build (e.g. in CI): use the upstream repo package.
  log "No local alacritty-blur package; using 'alacritty' from the repos"
  sed -i 's/^alacritty-blur$/alacritty/' "$PROFILE/packages.x86_64"
fi

# ---------------------------------------------------------------------------
# 3. Generate pacman configs and create a local package repository.
# ---------------------------------------------------------------------------
# Build-time config: host mirrors + our local repo.  Drop host-only options
# (DownloadUser, IgnorePkg, HoldPkg, eye candy) that do not belong in a chroot.
filter_pacman_conf() {
  sed -E \
    -e '/^DownloadUser[[:space:]]*=/d' \
    -e '/^IgnorePkg[[:space:]]*=/d' \
    -e '/^HoldPkg[[:space:]]*=/d' \
    -e '/^ILoveCandy$/d' \
    -e '/^Color$/d' \
    -e '/^VerbosePkgLists$/d' \
    "$1"
}

filter_pacman_conf /etc/pacman.conf > "$PROFILE/pacman.conf"
cat >> "$PROFILE/pacman.conf" <<EOF

# Packages that are not in any CachyOS/Arch repository.
[cosmalia]
SigLevel = Optional TrustAll
Server = file://$REPO_DIR
EOF

# Config shipped inside the live image (no local file:// repo).
filter_pacman_conf /etc/pacman.conf > "$PROFILE/airootfs/etc/pacman.conf"
mkdir -p "$PROFILE/airootfs/etc/pacman.d"
cp -f /etc/pacman.d/*mirrorlist "$PROFILE/airootfs/etc/pacman.d/"

rm -f "$REPO_DIR/cosmalia.db.tar.gz" "$REPO_DIR/cosmalia.files.tar.gz"
repo-add "$REPO_DIR/cosmalia.db.tar.gz" "$REPO_DIR"/*.pkg.tar.zst >/dev/null
log "Local repository ready:"
ls -1 "$REPO_DIR"/*.pkg.tar.zst | sed 's|.*/|    |'

# ---------------------------------------------------------------------------
# 4. Build the ISO.
# ---------------------------------------------------------------------------
log "Running mkarchiso (work: $WORK_DIR, output: $OUT_DIR)"
"${SUDO[@]}" env "PATH=$PATH" mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE"

echo
log "Finished. ISO files:"
ls -lh "$OUT_DIR"/*.iso
