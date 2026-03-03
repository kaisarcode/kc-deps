#!/bin/bash
# install.sh - Global production runtime installer for deps.
# Summary: Installs only the compiled shared dependencies for runtime use.
#
# Author:  KaisarCode
# Website: https://kaisarcode.com
# License: GNU GPL v3.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_ROOT="$SCRIPT_DIR/lib"
SYS_LIB_ROOT="/usr/local/lib/kaisarcode"

pass() {
    printf "\033[32m[PASS]\033[0m %s\n" "$1"
}

fail() {
    printf "\033[31m[FAIL]\033[0m %s\n" "$1"
    exit 1
}

if ! command -v sudo >/dev/null 2>&1; then
    fail "sudo is required."
fi

sudo mkdir -p "$SYS_LIB_ROOT"

for vendor_dir in "$LIB_ROOT"/*; do
    [ -d "$vendor_dir" ] || continue
    vendor="$(basename "$vendor_dir")"
    sudo mkdir -p "$SYS_LIB_ROOT/$vendor"
    sudo rsync -a --delete "$vendor_dir"/ "$SYS_LIB_ROOT/$vendor"/
    pass "Installed runtime artifacts for $vendor."
done

printf "\n\033[1;32m[SUCCESS]\033[0m Production runtime installed.\n"
