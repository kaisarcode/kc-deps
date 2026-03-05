#!/bin/bash
# dev/build/imgui.sh - Dear ImGui Source Exporter
# Summary: Downloads and exports Dear ImGui sources per architecture slot.
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
IMGUI_REF="master"
IMGUI_URL="https://codeload.github.com/ocornut/imgui/tar.gz/refs/heads/${IMGUI_REF}"

fetch() {
    mkdir -p "$DEPS_ROOT/src"
    cd "$DEPS_ROOT/src"
    if [ ! -d "imgui" ]; then
        curl -L "$IMGUI_URL" -o "imgui-${IMGUI_REF}.tar.gz"
        tar -xf "imgui-${IMGUI_REF}.tar.gz"
        mv "imgui-${IMGUI_REF}" imgui
        rm "imgui-${IMGUI_REF}.tar.gz"
    fi
}

export_arch() {
    arch="$1"
    src_dir="$DEPS_ROOT/src/imgui"
    dst="$DEPS_ROOT/lib/imgui/$arch"

    printf "\n\033[1;34m[EXPORT] ImGui (%s)\033[0m\n" "$arch"
    rm -rf "$dst"
    mkdir -p "$dst/include" "$dst/src" "$dst/backends"

    cp "$src_dir"/imgui.h "$dst/include/"
    cp "$src_dir"/imgui_internal.h "$dst/include/"
    cp "$src_dir"/imconfig.h "$dst/include/"
    cp "$src_dir"/imstb_rectpack.h "$dst/include/"
    cp "$src_dir"/imstb_textedit.h "$dst/include/"
    cp "$src_dir"/imstb_truetype.h "$dst/include/"

    cp "$src_dir"/imgui.cpp "$dst/src/"
    cp "$src_dir"/imgui_draw.cpp "$dst/src/"
    cp "$src_dir"/imgui_tables.cpp "$dst/src/"
    cp "$src_dir"/imgui_widgets.cpp "$dst/src/"

    cp "$src_dir"/backends/imgui_impl_glfw.h "$dst/backends/"
    cp "$src_dir"/backends/imgui_impl_glfw.cpp "$dst/backends/"
    cp "$src_dir"/backends/imgui_impl_opengl3.h "$dst/backends/"
    cp "$src_dir"/backends/imgui_impl_opengl3.cpp "$dst/backends/"
    cp "$src_dir"/backends/imgui_impl_opengl3_loader.h "$dst/backends/"

    printf "\033[32m[OK]\033[0m imgui exported for %s\n" "$arch"
}

run_build() {
    fetch
    if [ -n "$1" ]; then
        export_arch "$1"
        return 0
    fi
    export_arch "x86_64"
    export_arch "win64"
    export_arch "aarch64"
    export_arch "arm64-v8a"
}

run_build "$1"
