#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$project_root"

# clang18 includes the resource headers needed by the pinned ffigen generator.
export LIBCLANG_PATH=${LIBCLANG_PATH:-/usr/lib/llvm18/lib}
export CARGO_BUILD_JOBS=${CARGO_BUILD_JOBS:-3}
export CMAKE_POLICY_VERSION_MINIMUM=${CMAKE_POLICY_VERSION_MINIMUM:-3.5}
# Older libwebm relies on a transitive cstdint include removed in recent GCC.
export CXXFLAGS="${CXXFLAGS:-} -include cstdint"
if ! pkg-config --exists libyuv; then
    export PKG_CONFIG_PATH="$project_root/res/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
fi

(cd flutter && flutter pub get)
flutter_rust_bridge_codegen \
    --rust-input ./src/flutter_ffi.rs \
    --dart-output ./flutter/lib/generated_bridge.dart \
    --c-output ./flutter/macos/Runner/bridge_generated.h \
    --llvm-path /usr/lib/llvm18 \
    --llvm-compiler-opts=-I/usr/lib/llvm18/lib/clang/18/include
cargo build --locked --features flutter,linux-pkg-config --lib --release
(cd flutter && flutter build linux --release --no-pub)
(cd res && HBB="$project_root" FLUTTER=1 makepkg --force)
