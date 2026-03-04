#!/bin/bash
# install-dev.sh - Global development environment installer for deps.
# Summary: Installs compiled shared dependencies and build toolchains once.
#
# Author:  KaisarCode
# Website: https://kaisarcode.com
# License: GNU GPL v3.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_ROOT="$SCRIPT_DIR/lib"
SYS_LIB_ROOT="/usr/local/lib/kaisarcode"
SYS_TOOLCHAINS_ROOT="/usr/local/share/kaisarcode/toolchains"
NDK_VER="android-ndk-r27c"
NDK_ZIP="android-ndk-r27c-linux.zip"
NDK_URL="https://dl.google.com/android/repository/${NDK_ZIP}"
RUST_VER="1.67.1"
RUSTUP_INIT_URL="https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init"
IM_VER="6.9.13-16"
ZLIB_VER="1.3.1"
PNG_VER="1.6.43"
OPENSSL_VER="1.1.1w"
RESVG_VER="0.45.1"

pass() {
    printf "\033[32m[PASS]\033[0m %s\n" "$1"
}

fail() {
    printf "\033[31m[FAIL]\033[0m %s\n" "$1"
    exit 1
}

require_sudo() {
    if ! command -v sudo >/dev/null 2>&1; then
        fail "sudo is required."
    fi
}

install_compiled_libs() {
    require_sudo
    sudo mkdir -p "$SYS_LIB_ROOT"
    for vendor_dir in "$LIB_ROOT"/*; do
        [ -d "$vendor_dir" ] || continue
        vendor="$(basename "$vendor_dir")"
        sudo mkdir -p "$SYS_LIB_ROOT/$vendor"
        sudo rsync -a --delete "$vendor_dir"/ "$SYS_LIB_ROOT/$vendor"/
        pass "Installed compiled artifacts for $vendor."
    done
}

install_dev_headers() {
    require_sudo
    if [ -d "$SCRIPT_DIR/src/llama.cpp/include" ]; then
        for arch_dir in "$SYS_LIB_ROOT/llama.cpp"/*; do
            [ -d "$arch_dir" ] || continue
            sudo mkdir -p "$arch_dir/include/ggml"
            sudo rsync -a "$SCRIPT_DIR/src/llama.cpp/include/" "$arch_dir/include/"
            sudo rsync -a "$SCRIPT_DIR/src/llama.cpp/ggml/include/" "$arch_dir/include/ggml/"
        done
        pass "Installed development headers for llama.cpp."
    fi
    if [ -d "$SCRIPT_DIR/src/stable-diffusion.cpp/include" ]; then
        for arch_dir in "$SYS_LIB_ROOT/stable-diffusion.cpp"/*; do
            [ -d "$arch_dir" ] || continue
            sudo mkdir -p "$arch_dir/include"
            sudo rsync -a "$SCRIPT_DIR/src/stable-diffusion.cpp/include/" "$arch_dir/include/"
        done
        pass "Installed development headers for stable-diffusion.cpp."
    fi
}

install_sources() {
    src_root="$SCRIPT_DIR/src"
    mkdir -p "$src_root"
    cd "$src_root"

    [ -d "llama.cpp" ] || git clone https://github.com/ggml-org/llama.cpp.git llama.cpp
    [ -d "stable-diffusion.cpp" ] || git clone https://github.com/leejet/stable-diffusion.cpp.git stable-diffusion.cpp
    if [ ! -d "sqlite3" ]; then
        mkdir -p sqlite3
        curl -L https://www.sqlite.org/2025/sqlite-amalgamation-3490100.zip -o sqlite3.zip
        unzip -q sqlite3.zip -d sqlite3-tmp
        cp sqlite3-tmp/*/sqlite3.c sqlite3-tmp/*/sqlite3.h sqlite3/
        rm -rf sqlite3-tmp sqlite3.zip
    fi
    if [ ! -d "openssl" ]; then
        curl -L "https://www.openssl.org/source/openssl-${OPENSSL_VER}.tar.gz" -o "openssl-${OPENSSL_VER}.tar.gz"
        tar -xzf "openssl-${OPENSSL_VER}.tar.gz"
        mv "openssl-${OPENSSL_VER}" openssl
        rm "openssl-${OPENSSL_VER}.tar.gz"
    fi
    if [ ! -d "ImageMagick" ]; then
        curl -L -o im.tar.gz "https://github.com/ImageMagick/ImageMagick6/archive/refs/tags/${IM_VER}.tar.gz"
        tar -xf im.tar.gz
        mv "ImageMagick6-${IM_VER}" "ImageMagick"
        rm im.tar.gz
    fi
    if [ ! -d "zlib" ]; then
        curl -L -o zlib.tar.gz "https://github.com/madler/zlib/releases/download/v${ZLIB_VER}/zlib-${ZLIB_VER}.tar.gz"
        tar -xf zlib.tar.gz
        mv "zlib-${ZLIB_VER}" "zlib"
        rm zlib.tar.gz
    fi
    if [ ! -d "libpng" ]; then
        curl -L -o libpng.tar.gz "https://download.sourceforge.net/libpng/libpng-${PNG_VER}.tar.gz"
        tar -xf libpng.tar.gz
        mv "libpng-${PNG_VER}" "libpng"
        rm libpng.tar.gz
    fi
    if [ ! -d "resvg" ]; then
        curl -L -o "resvg-${RESVG_VER}.tar.gz" "https://github.com/linebender/resvg/archive/refs/tags/v${RESVG_VER}.tar.gz"
        tar -xf "resvg-${RESVG_VER}.tar.gz"
        mv "resvg-${RESVG_VER}" resvg
        rm "resvg-${RESVG_VER}.tar.gz"
    fi
    pass "Source trees verified under $src_root."
}

install_ndk() {
    require_sudo
    ndk_root="$SYS_TOOLCHAINS_ROOT/ndk/$NDK_VER"
    if [ -x "$ndk_root/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android24-clang" ]; then
        pass "Android NDK already present."
        return 0
    fi
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN
    mkdir -p "$tmp_dir" "$SYS_TOOLCHAINS_ROOT/ndk"
    curl -L "$NDK_URL" -o "$tmp_dir/$NDK_ZIP"
    unzip -q "$tmp_dir/$NDK_ZIP" -d "$tmp_dir"
    sudo rm -rf "$ndk_root"
    sudo mkdir -p "$SYS_TOOLCHAINS_ROOT/ndk"
    sudo mv "$tmp_dir/$NDK_VER" "$ndk_root"
    pass "Android NDK installed to $ndk_root."
}

install_rust() {
    require_sudo
    rust_root="$SYS_TOOLCHAINS_ROOT/rust"
    sudo mkdir -p "$rust_root/bin" "$rust_root/rustup" "$rust_root/cargo"
    if [ ! -x "$rust_root/bin/rustup-init" ]; then
        sudo curl -L "$RUSTUP_INIT_URL" -o "$rust_root/bin/rustup-init"
        sudo chmod +x "$rust_root/bin/rustup-init"
    fi
    export RUSTUP_HOME="$rust_root/rustup"
    export CARGO_HOME="$rust_root/cargo"
    export PATH="$CARGO_HOME/bin:$PATH"
    if [ ! -x "$CARGO_HOME/bin/cargo" ]; then
        sudo -E "$rust_root/bin/rustup-init" -y --default-toolchain "$RUST_VER" --profile minimal --no-modify-path
    fi
    sudo -E "$CARGO_HOME/bin/rustup" toolchain install "$RUST_VER" --profile minimal >/dev/null
    sudo -E "$CARGO_HOME/bin/rustup" default "$RUST_VER" >/dev/null
    sudo -E "$CARGO_HOME/bin/rustup" target add \
        x86_64-unknown-linux-gnu \
        x86_64-pc-windows-gnu \
        aarch64-unknown-linux-gnu \
        aarch64-linux-android >/dev/null
    pass "Rust toolchain installed to $rust_root."
}

main() {
    install_compiled_libs
    install_sources
    install_dev_headers
    install_ndk
    install_rust
    printf "\n\033[1;32m[SUCCESS]\033[0m Development runtime and toolchains installed.\n"
}

main "$@"
