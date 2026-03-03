#!/bin/bash
# dev/build/llama.sh - llama.cpp Library Sniper Builder
# Summary: Forced engine-only build using CMake target isolation.
# Standard: KCS

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

compile() {
    arch=$1
    printf "\n\033[1;34m[BUILD] llama.cpp (%s)\033[0m\n" "$arch"
    cd "$DEPS_ROOT/src/llama.cpp"
    build_dir="build-$arch"

    printf "\033[33m[CLEAN]\033[0m Wiping build directory: $build_dir\n"
    rm -rf "$build_dir"
    mkdir -p "$build_dir"

    COMMON_FLAGS="-DBUILD_SHARED_LIBS=ON \
                  -DLLAMA_BUILD_EXAMPLES=OFF \
                  -DLLAMA_BUILD_SERVER=OFF \
                  -DLLAMA_BUILD_TESTS=OFF \
                  -DLLAMA_SERVER=OFF \
                  -DGGML_BUILD_EXAMPLES=OFF \
                  -DGGML_BUILD_TESTS=OFF"

    case "$arch" in
        "win64")
            printf "  Configuring for Windows (MinGW)...\n"
            cmake -B "$build_dir" -DCMAKE_SYSTEM_NAME=Windows \
                  -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
                  -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
                  -DCMAKE_C_FLAGS="-D_WIN32_WINNT=0x0601" \
                  -DCMAKE_CXX_FLAGS="-D_WIN32_WINNT=0x0601" \
                  $COMMON_FLAGS
            ;;
        "x86_64")
            cmake -B "$build_dir" -DGGML_CUDA=ON $COMMON_FLAGS
            ;;
        "arm64-v8a")
            ndk_root="$(resolve_ndk_root)"
            cmake -B "$build_dir" -DCMAKE_TOOLCHAIN_FILE="$ndk_root/build/cmake/android.toolchain.cmake" \
                  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-24 $COMMON_FLAGS
            ;;
        "aarch64")
            cmake -B "$build_dir" -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
                  -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
                  $COMMON_FLAGS
            ;;
        *)
            printf "\033[31m[ERROR]\033[0m Unsupported architecture: $arch\n"
            exit 1
            ;;
    esac

    printf "  Starting targeted build (Target: llama)...\n"
    cmake --build "$build_dir" --config Release --target llama --verbose -j$(nproc)

    printf "  Exporting artifacts to global lib/...\n"
    mkdir -p "$DEPS_ROOT/lib/llama.cpp/$arch"

    find "$build_dir" \( -name "*.so*" -o -name "*.dll*" -o -name "*.dll.a" \) -exec cp -d {} "$DEPS_ROOT/lib/llama.cpp/$arch/" \;
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
