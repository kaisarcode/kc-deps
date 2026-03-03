#!/bin/bash
# dev/build/openssl.sh
# Summary: Downloads and compiles OpenSSL 1.1.1w (LTS) for all architectures.
#
# Author:  KaisarCode
# Website: https://kaisarcode.com
# License: GNU GPL v3.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPS_ROOT="$(dirname "$SCRIPT_DIR")"

OPENSSL_VER="1.1.1w"
OPENSSL_TAR="openssl-${OPENSSL_VER}.tar.gz"
OPENSSL_URL="https://www.openssl.org/source/${OPENSSL_TAR}"

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

normalize_pkgconfig_files() {
    PKGCONFIG_DIR="$1/lib/pkgconfig"
    if [ ! -d "$PKGCONFIG_DIR" ]; then
        return 0
    fi
    find "$PKGCONFIG_DIR" -type f -name "*.pc" | while IFS= read -r pc_file; do
        sed -i '1s|^prefix=.*$|prefix=${pcfiledir}/../..|' "$pc_file"
    done
}

normalize_crehash_script() {
    CREHASH_FILE="$1/bin/c_rehash"
    if [ ! -f "$CREHASH_FILE" ]; then
        return 0
    fi
    perl -0pi -e 's|my \$dir = ".*?";\nmy \$prefix = ".*?";|use Cwd qw(abs_path);\nuse File::Basename qw(dirname);\nmy \$prefix = \$ENV{OPENSSL_PREFIX} || dirname(dirname(abs_path(\$0)));\nmy \$dir = \$prefix;|s' "$CREHASH_FILE"
}

# Build Function
build_arch() {
    ARCH=$1
    TARGET_DIR="$LIB_DIR/$ARCH"
    
    echo "----------------------------------------"
    echo "Building OpenSSL for $ARCH..."
    echo "----------------------------------------"

    cd "$SRC_DIR"
    mkdir -p "$TARGET_DIR"

    # Cleanup previous build
    make distclean >/dev/null 2>&1 || true

    case "$ARCH" in
        "x86_64")
            ./config --prefix="$TARGET_DIR" --openssldir="$TARGET_DIR" -fPIC shared
            ;;
        "win64")
            # Requires mingw-w64 cross-compiler
            ./Configure mingw64 --cross-compile-prefix=x86_64-w64-mingw32- --prefix="$TARGET_DIR" --openssldir="$TARGET_DIR" shared
            ;;
        "aarch64")
             # Requires aarch64-linux-gnu-gcc
            ./Configure linux-aarch64 --cross-compile-prefix=aarch64-linux-gnu- --prefix="$TARGET_DIR" --openssldir="$TARGET_DIR" shared
            ;;
        "arm64-v8a")
            # Requires Android NDK
            export ANDROID_NDK_HOME="$(resolve_ndk_root)"
            TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"
            export PATH="$TOOLCHAIN/bin:$PATH"
            
            # Explicitly set toolchain variables for Configure
            export AR=llvm-ar
            export AS=llvm-as
            export CC=aarch64-linux-android24-clang
            export CXX=aarch64-linux-android24-clang++
            export RANLIB=llvm-ranlib
            export LD=ld.lld
            export STRIP=llvm-strip
            
            ./Configure android-arm64 \
                -D__ANDROID_API__=24 --prefix="$TARGET_DIR" --openssldir="$TARGET_DIR" shared
            ;;
        *)
            echo "Skipping unsupported arch: $ARCH"
            return
            ;;
    esac

    # Parallel Build
    make -j$(nproc)
    make install_sw

    # Cleanup static libs to enforce dynamic linking (but keep import libs for Windows)
    find "$TARGET_DIR"/lib -type f -name "*.a" ! -name "*.dll.a" -delete
    normalize_pkgconfig_files "$TARGET_DIR"
    normalize_crehash_script "$TARGET_DIR"
    
    echo "Installed to $TARGET_DIR"
}

# Execution
EXT_DIR="$DEPS_ROOT/src"
LIB_DIR="$DEPS_ROOT/lib/openssl"
SRC_DIR="$EXT_DIR/openssl"

# Download Source
if [ ! -d "$SRC_DIR" ]; then
    echo "Downloading OpenSSL ${OPENSSL_VER}..."
    mkdir -p "$EXT_DIR"
    cd "$EXT_DIR"
    wget -q "$OPENSSL_URL" || curl -O "$OPENSSL_URL"
    tar -xzf "$OPENSSL_TAR"
    mv "openssl-${OPENSSL_VER}" openssl
    rm "$OPENSSL_TAR"
fi

# Build for all supported architectures
build_arch "x86_64"
build_arch "win64"
build_arch "aarch64"
build_arch "arm64-v8a"
