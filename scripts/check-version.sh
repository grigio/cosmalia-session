#!/usr/bin/env bash
# Validate the release version against the VERSION file and git tags.
#
#   scripts/check-version.sh            # general CI check
#   scripts/check-version.sh --expect 1.3.3
#                                       # release check: VERSION must equal this
#
# `--expect` is used by the release workflows to make sure the version being
# published matches the single source of truth in VERSION. It fails on a
# mismatch, so a tag like v1.2.4 cannot silently publish a 1.3.3 tree. Old tags
# that predate the VERSION file are still releasable: the tag itself is then
# the version (a warning is printed).

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

die() {
  echo "check-version: $*" >&2
  exit 1
}

expect=""
case "${1:-}" in
  --expect)
    expect=${2:-}
    [[ -n $expect ]] || die "--expect needs a version"
    expect=${expect#v}
    [[ $expect =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
      die "--expect must be v<major>.<minor>.<patch>, got '$expect'"
    ;;
  "") ;;
  *) die "usage: $0 [--expect <version>]" ;;
esac

have_version_file=0
version=""
if [[ -f VERSION ]]; then
  have_version_file=1
  version=$(<VERSION)
  version=${version//[[:space:]]/}
  [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
    die "VERSION must be <major>.<minor>.<patch>, got '$version'"

  if [[ -n $expect ]]; then
    [[ $version == "$expect" ]] ||
      die "VERSION=$version but the release tag says v$expect (bump VERSION or fix the tag)"
  fi
else
  [[ -n $expect ]] ||
    die "VERSION file is missing"
  version=$expect
  echo "warning: no VERSION file at this ref; using release tag v$version" >&2
fi

if (( have_version_file )); then
  # The PKGBUILD fallback is used when there is no git history (e.g. a source
  # tarball), so it must be the same version as VERSION.
  if [[ -f PKGBUILD ]]; then
    prefix="pkgver=\${pkgver:-"
    line=$(awk -v p="$prefix" 'index($0, p) == 1 { print; exit }' PKGBUILD || true)
    fallback=${line#*:-}
    fallback=${fallback%'}'}
    [[ -n $fallback ]] || die "could not read the pkgver fallback from PKGBUILD"
    [[ $fallback == "$version" ]] ||
      die "PKGBUILD fallback $fallback != VERSION $version"
  fi

  # When git history is available, make sure VERSION is not behind the newest
  # tag. This is the regression this check exists to catch: a "bump" commit
  # that sets an older version than an already released tag.
  if git rev-parse --git-dir >/dev/null 2>&1; then
    latest_tag=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)
    if [[ -n $latest_tag ]]; then
      higher=$(printf '%s\n%s\n' "$latest_tag" "$version" | sort -V | tail -1)
      [[ $higher == "$version" ]] ||
        die "VERSION=$version is older than the latest release tag v$latest_tag"
    fi
  fi
fi

echo "version: $version OK"
