#!/usr/bin/env bash
# Tests for scripts/set-default-greetd.sh, focusing on the fragile -c rewrite.
# Run as root (the helper uses sudo otherwise):
#   sudo ./scripts/test-set-default-greetd.sh
set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
helper="$root/scripts/set-default-greetd.sh"

if [[ $EUID -ne 0 ]]; then
    echo "run as root (or with passwordless sudo): sudo $0" >&2
    exit 1
fi

failures=0
tmp=""
# shellcheck disable=SC2329  # invoked via the EXIT trap below
cleanup() { [[ -n $tmp ]] && rm -rf -- "$tmp"; }
trap cleanup EXIT
tmp=$(mktemp -d)

session="$tmp/cosmalia-session"
printf '#!/bin/sh\nexit 0\n' >"$session"
chmod +x "$session"

fail() { echo "  FAIL: $*" >&2; failures=$((failures + 1)); }
contains() { grep -qF -- "$2" "$1" 2>/dev/null; }

# $1 = name, $2 = gtkgreet command line in config.toml, $3 = expected -c text
case_c() {
    local name=$1 conf_line=$2 expected=$3
    local dir="$tmp/$name"
    mkdir -p "$dir"
    printf '[default_session]\n%s\nuser = "greeter"\n' "$conf_line" >"$dir/config.toml"
    printf 'other-session\n' >"$dir/environments"

    echo "case: $name"
    GREETD_CONFIG="$dir/config.toml" GREETD_ENVIRONMENTS="$dir/environments" \
        COSMALIA_SESSION="$session" "$helper" >"$dir/out" 2>"$dir/err" ||
        fail "$name: helper exited nonzero: $(cat "$dir/err")"

    contains "$dir/config.toml" "$expected" ||
        fail "$name: expected '$expected' in config, got: $(grep '^ *command' "$dir/config.toml")"
    contains "$dir/environments" "$session" ||
        fail "$name: session missing from environments"
    contains "$dir/out" "rewrote -c" || fail "$name: did not report rewriting -c"
}

case_c unquoted \
    'command = "gtkgreet -c /old/session"' \
    "gtkgreet -c $session"

case_c double_quoted \
    'command = "gtkgreet -c \"/old/session\""' \
    "gtkgreet -c $session"

case_c single_quoted \
    "command = \"gtkgreet -c '/old/session'\"" \
    "gtkgreet -c $session"

case_c toml_escaped \
    'command = "gtkgreet -c \\"/old/session\\""' \
    "gtkgreet -c $session"

case_c equals_form \
    'command = "gtkgreet -c=/old/session"' \
    "gtkgreet -c $session"

# No -c: prepend to environments, leave the config line alone.
dir="$tmp/no_c"; mkdir -p "$dir"
printf '[default_session]\ncommand = "gtkgreet"\nuser = "greeter"\n' >"$dir/config.toml"
printf 'other-session\n' >"$dir/environments"
echo "case: no_c"
GREETD_CONFIG="$dir/config.toml" GREETD_ENVIRONMENTS="$dir/environments" \
    COSMALIA_SESSION="$session" "$helper" >"$dir/out" 2>"$dir/err" ||
    fail "no_c: helper exited nonzero: $(cat "$dir/err")"
contains "$dir/config.toml" 'command = "gtkgreet"' || fail "no_c: config command changed"
[[ $(head -1 "$dir/environments") == "$session" ]] ||
    fail "no_c: session not prepended, got: $(head -1 "$dir/environments")"

# --list: append only, never touch the config.
dir="$tmp/list_only"; mkdir -p "$dir"
printf 'command = "gtkgreet -c /keep/this"\n' >"$dir/config.toml"
printf 'other-session\n' >"$dir/environments"
before=$(cat "$dir/config.toml")
echo "case: list_only"
GREETD_CONFIG="$dir/config.toml" GREETD_ENVIRONMENTS="$dir/environments" \
    COSMALIA_SESSION="$session" "$helper" --list >"$dir/out" 2>"$dir/err" ||
    fail "list_only: helper exited nonzero: $(cat "$dir/err")"
[[ $(cat "$dir/config.toml") == "$before" ]] || fail "list_only: config was modified"
contains "$dir/environments" "$session" || fail "list_only: session not added"

# Idempotency: running twice must not duplicate the dropdown entry.
dir="$tmp/idempotent"; mkdir -p "$dir"
printf 'command = "gtkgreet -c /old/session"\n' >"$dir/config.toml"
: >"$dir/environments"
echo "case: idempotent"
for _ in 1 2; do
    GREETD_CONFIG="$dir/config.toml" GREETD_ENVIRONMENTS="$dir/environments" \
        COSMALIA_SESSION="$session" "$helper" >/dev/null 2>&1 ||
        fail "idempotent: helper exited nonzero"
done
count=$(grep -cxF -- "$session" "$dir/environments")
[[ $count -eq 1 ]] || fail "idempotent: expected 1 entry, got $count"

echo
if (( failures == 0 )); then
    echo "All set-default-greetd.sh tests passed."
    exit 0
fi
echo "$failures test(s) failed."
exit 1
