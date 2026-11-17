#!/usr/bin/env bash
# Verify that files.manifest matches the source tree and the RPM %files list.
# Also make sure the Arch and Nix packagers still copy the shared files/ tree.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

die() { echo "check-manifest: $*" >&2; exit 1; }

[[ -f files.manifest ]] || die "files.manifest is missing"

failures=0
fail() { echo "  FAIL: $*" >&2; failures=$((failures + 1)); }

# Map an installed path back to the file in this repo that provides it.
source_of() {
    case $1 in
        /usr/bin/cosmalia-session-default) echo scripts/set-default-greetd.sh ;;
        /usr/share/doc/cosmalia-session/README.md) echo README.md ;;
        /usr/share/licenses/cosmalia-session/LICENSE) echo LICENSE ;;
        /usr/*) echo "files$1" ;;
        *) echo "" ;;
    esac
}

echo "Checking manifest sources..."
while IFS= read -r path; do
    [[ -z $path || $path == \#* ]] && continue
    src=$(source_of "$path")
    [[ -n $src ]] || fail "$path: cannot map to a source file"
    [[ -e $src ]] || fail "$path: source $src does not exist"
done <files.manifest

# Normalize the RPM %files section to absolute paths.
spec_files=$(
    sed -n '/^%files$/,/^%changelog$/p' cosmalia-session.spec |
        sed -e 's/^%license[[:space:]]*//' \
            -e 's|%{_bindir}|/usr/bin|g' \
            -e 's|%{_datadir}|/usr/share|g' \
            -e 's|%{_prefix}|/usr|g' \
            -e 's|%{_docdir}|/usr/share/doc|g' \
            -e 's|%{_licensedir}|/usr/share/licenses|g' \
            -e 's|%{name}|cosmalia-session|g' \
            -e '/^%/d' -e '/^[[:space:]]*$/d' |
        sort -u
)
manifest_files=$(grep -vE '^\s*(#|$)' files.manifest | sort -u)

echo "Checking RPM %files against manifest..."
diff=$(comm -3 <(printf '%s\n' "$manifest_files") <(printf '%s\n' "$spec_files"))
if [[ -n $diff ]]; then
    echo "$diff" >&2
    fail "cosmalia-session.spec %files and files.manifest differ"
fi

# The tree-copying packagers must not be narrowed to a hand-maintained list.
echo "Checking Arch/Nix tree installs..."
# shellcheck disable=SC2016  # patterns are literal shell text, not expansions
grep -qF 'cp -a "$startdir/files/." "$pkgdir/"' PKGBUILD ||
    fail "PKGBUILD no longer copies the whole files/ tree"
# shellcheck disable=SC2016
grep -qF 'cp -r $src/files/* $out/' packages/cosmalia-session.nix ||
    fail "Nix package no longer copies the whole files/ tree"

echo
if (( failures == 0 )); then
    echo "Manifest OK ($(printf '%s\n' "$manifest_files" | wc -l) files)."
    exit 0
fi
echo "$failures manifest check(s) failed."
exit 1
