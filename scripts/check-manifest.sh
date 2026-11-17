#!/usr/bin/env bash
# Verify that files.manifest matches the source tree and the RPM %files list.
# Also make sure the Arch and Nix packagers still copy the shared files/ tree.
# Snippets checked below are literal shell text copied from the packaging
# files; the $vars in them must not be expanded by shellcheck.
# shellcheck disable=SC2016
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

# Tree copying alone is not enough: the helper, docs, license and the mirrored
# Nix-standard tree must stay in sync too, or files silently disappear from one
# of the three packages.
require_snippet() {
    local file=$1 snippet=$2
    grep -qF -- "$snippet" "$file" || fail "$file no longer contains: $snippet"
}

echo "Checking helper, docs, license and mirrored trees..."
# shellcheck disable=SC2016  # literal snippets, not shell expansions
require_snippet PKGBUILD '"$startdir/scripts/set-default-greetd.sh"'
require_snippet PKGBUILD '"$startdir/README.md"'
require_snippet PKGBUILD '"$startdir/LICENSE"'
require_snippet packages/cosmalia-session.nix '$src/scripts/set-default-greetd.sh'
require_snippet packages/cosmalia-session.nix '$src/README.md'
require_snippet packages/cosmalia-session.nix '$src/LICENSE'
require_snippet packages/cosmalia-session.nix 'cp $out/usr/lib/systemd/user/* $out/share/systemd/user/'
for mirror in 'cp -r $out/usr/bin/. $out/bin/' \
    'cp -r $out/usr/share/. $out/share/' \
    'cp -r $out/usr/lib/. $out/lib/'; do
    require_snippet packages/cosmalia-session.nix "$mirror"
done

echo
if (( failures == 0 )); then
    echo "Manifest OK ($(printf '%s\n' "$manifest_files" | wc -l) files)."
    exit 0
fi
echo "$failures manifest check(s) failed."
exit 1
