#!/bin/bash
# dev/build/glfw.sh - GLFW Library Builder
# Summary: Downloads and compiles GLFW for supported architectures.
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
GLFW_VER="3.4"
GLFW_URL="https://github.com/glfw/glfw/archive/refs/tags/${GLFW_VER}.tar.gz"

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

fetch() {
    mkdir -p "$DEPS_ROOT/src"
    cd "$DEPS_ROOT/src"
    if [ ! -d "glfw" ]; then
        curl -L "$GLFW_URL" -o "glfw-${GLFW_VER}.tar.gz"
        tar -xf "glfw-${GLFW_VER}.tar.gz"
        mv "glfw-${GLFW_VER}" glfw
        rm "glfw-${GLFW_VER}.tar.gz"
    fi
}

copy_headers() {
    arch="$1"
    dst="$DEPS_ROOT/lib/glfw/$arch/include/GLFW"
    src="$DEPS_ROOT/src/glfw/include/GLFW"
    mkdir -p "$dst"
    cp "$src"/*.h "$dst/"
}

copy_artifacts() {
    arch="$1"
    build_dir="$DEPS_ROOT/src/glfw/build-$arch"
    dst="$DEPS_ROOT/lib/glfw/$arch/lib"
    mkdir -p "$dst"

    find "$build_dir" -type f \
        \( -name "libglfw3.a" -o -name "glfw3.lib" -o -name "glfw3.dll" \) \
        -exec cp -f {} "$dst/" \;
}

resolve_wayland_flags() {
    arch="$1"
    mode_wayland="${KC_GLFW_WAYLAND:-auto}"
    mode_x11="${KC_GLFW_X11:-auto}"

    if [ "$mode_wayland" = "on" ]; then
        wayland="ON"
    elif [ "$mode_wayland" = "off" ]; then
        wayland="OFF"
    elif command -v wayland-scanner >/dev/null 2>&1 && [ "$arch" = "x86_64" ]; then
        wayland="ON"
    else
        wayland="OFF"
    fi

    if [ "$mode_x11" = "on" ]; then
        x11="ON"
    elif [ "$mode_x11" = "off" ]; then
        x11="OFF"
    elif [ "$arch" = "x86_64" ]; then
        x11="ON"
    else
        x11="OFF"
    fi

    if [ "$arch" = "x86_64" ] && [ "$wayland" = "OFF" ] && [ "$x11" = "OFF" ]; then
        printf "\033[31m[ERROR]\033[0m GLFW requires at least one Linux backend.\n"
        exit 1
    fi

    printf "%s\n" "-DGLFW_BUILD_WAYLAND=${wayland} -DGLFW_BUILD_X11=${x11}"
}

compile_arch() {
    arch="$1"
    src_dir="$DEPS_ROOT/src/glfw"
    build_dir="$src_dir/build-$arch"

    printf "\n\033[1;34m[BUILD] GLFW (%s)\033[0m\n" "$arch"
    rm -rf "$build_dir"

    platform_flags="$(resolve_wayland_flags "$arch")"
    common_flags="-DGLFW_BUILD_DOCS=OFF \
        -DGLFW_BUILD_EXAMPLES=OFF \
        -DGLFW_BUILD_TESTS=OFF \
        $platform_flags \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON"

    case "$arch" in
        "x86_64")
            cmake -S "$src_dir" -B "$build_dir" $common_flags
            ;;
        "win64")
            cmake -S "$src_dir" -B "$build_dir" \
                -DCMAKE_SYSTEM_NAME=Windows \
                -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
                -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
                -DCMAKE_C_FLAGS="-D_WIN32_WINNT=0x0601" \
                -DCMAKE_CXX_FLAGS="-D_WIN32_WINNT=0x0601" \
                $common_flags
            ;;
        "aarch64")
            cmake -S "$src_dir" -B "$build_dir" \
                -DCMAKE_SYSTEM_NAME=Linux \
                -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
                -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
                -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
                $common_flags
            ;;
        "arm64-v8a")
            ndk_root="$(resolve_ndk_root)"
            cmake -S "$src_dir" -B "$build_dir" \
                -DCMAKE_TOOLCHAIN_FILE="$ndk_root/build/cmake/android.toolchain.cmake" \
                -DANDROID_ABI=arm64-v8a \
                -DANDROID_PLATFORM=android-24 \
                $common_flags
            ;;
        *)
            printf "\033[31m[ERROR]\033[0m Unsupported architecture: %s\n" "$arch"
            exit 1
            ;;
    esac

    cmake --build "$build_dir" --config Release --target glfw -j"$(nproc)"
    copy_headers "$arch"
    copy_artifacts "$arch"
    printf "\033[32m[OK]\033[0m glfw built for %s\n" "$arch"
}

run_build() {
    fetch
    if [ -n "$1" ]; then
        compile_arch "$1"
        return 0
    fi
    compile_arch "x86_64"
    compile_arch "win64"
    compile_arch "aarch64"
    compile_arch "arm64-v8a"
}

run_build "$1"
