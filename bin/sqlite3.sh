#!/bin/bash
# dev/build/sqlite3.sh - SQLite3 Shared Library Builder
# Summary: Compiles SQLite3 for all supported architectures.
# Standard: KCS
#
# Author:  KaisarCode
# Website: https://kaisarcode.com
# License: GNU GPL v3.0
#
# © 2026 KaisarCode

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPS_ROOT="$(dirname "$SCRIPT_DIR")"

resolve_ndk_root() {
    if [ -n "${KC_NDK_ROOT:-}" ]; then
        printf "%s\n" "$KC_NDK_ROOT"
        return 0
    fi
    if [ -n "${KC_TOOLCHAINS:-}" ]; then
        printf "%s/ndk/android-ndk-r27c\n" "$KC_TOOLCHAINS"
        return 0
    fi
    printf "/usr/local/share/kaisarcode/toolchains/ndk/android-ndk-r27c\n"
}

setup_ndk() {
    export NDK_PATH="$(resolve_ndk_root)"
    [ -d "$NDK_PATH" ] || return 1
}

compile() {
    arch=$1
    printf "\n\033[1;34m[BUILD] SQLite3 (%s)\033[0m\n" "$arch"
    cd "$DEPS_ROOT/src/sqlite3"
    mkdir -p "$DEPS_ROOT/lib/sqlite3/$arch"

    case "$arch" in
        "x86_64")
            CMD="gcc -O3 -fPIC -shared -v sqlite3.c -o $DEPS_ROOT/lib/sqlite3/x86_64/sqlite3.so -lpthread -ldl"
            ;;
        "win64")
            CMD="x86_64-w64-mingw32-gcc -O3 -shared -v sqlite3.c -o $DEPS_ROOT/lib/sqlite3/win64/sqlite3.dll -lpthread"
            ;;
        "aarch64")
            CMD="aarch64-linux-gnu-gcc -O3 -fPIC -shared -v sqlite3.c -o $DEPS_ROOT/lib/sqlite3/aarch64/sqlite3.so -lpthread -ldl"
            ;;
        "arm64-v8a")
            setup_ndk
            CMD="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android24-clang -O3 -fPIC -shared -v sqlite3.c -o $DEPS_ROOT/lib/sqlite3/arm64-v8a/sqlite3.so -ldl"
            ;;
        *)
            printf "\033[31m[ERROR]\033[0m Unsupported architecture: $arch\n"
            exit 1
            ;;
    esac

    printf "  Executing: $CMD\n"
    $CMD
}

run_build() {
    if [ -z "$1" ]; then
        for a in x86_64 win64 aarch64 arm64-v8a; do
            compile "$a"
        done
    else
        compile "$1"
    fi
}

run_build "$1"
