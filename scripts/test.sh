#!/usr/bin/env bash
# Build and test one package from this repository in a throwaway project.
# Usage: scripts/test.sh <package> [version]
set -euo pipefail
pkg="${1:?package name}"; ver="${2:-}"
root="$(cd "$(dirname "$0")/.." && pwd)"
first="${pkg:0:1}"
[ -f "$root/packages/$first/$pkg/xmake.lua" ] || { echo "packages/$first/$pkg/xmake.lua not found"; exit 1; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/xmake.lua" <<LUA
add_rules("mode.release")
add_repositories("local-repo $root")
add_requires("$pkg${ver:+ $ver}")
target("pkgtest")
    set_kind("phony")
    add_packages("$pkg")
LUA
cd "$tmp"
xmake f -y -c
xmake require -y --force --info "$pkg"
xmake -y
echo "OK: $pkg"
