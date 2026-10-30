# Building the MCP fork on Linux (x86_64) — .deb

The upstream RustDeskMCP release ships **Windows binaries only**. The MCP layer
(`src/agent_bridge.rs`) is platform-agnostic (pure `std`, no `#[cfg(windows)]`
gating, wired unconditionally via `pub mod agent_bridge;` in `src/lib.rs`), so it
builds and runs on Linux unchanged. This document captures a verified Ubuntu 24.04
build, including four gaps not covered by the upstream Linux instructions.

The original 1.4.6 build was verified on Ubuntu 24.04, Rust 1.75, Flutter 3.24.5.
The updated 1.5.0 dependency lockfile requires Rust 1.88 or newer; use the
toolchain below. Arch Linux / EndeavourOS instructions are in [BUILD-ARCH.md](BUILD-ARCH.md).
The original MCP HTTP server was
confirmed live on `http://127.0.0.1:59940/mcp` (`initialize` + `tools/list`
returning all 13 tools) from the resulting binary.

## Gaps fixed here (vs upstream build docs)

1. **`libssl-dev` missing from the apt list.** GitHub-hosted runners preinstall it,
   so upstream never lists it. On a clean host, `openssl-sys` fails to find OpenSSL.
2. **`rustfmt` required.** flutter_rust_bridge codegen shells out to `rustfmt`; a
   `--profile minimal` toolchain omits it and the "Generate Rust code" phase fails.
3. **`flutter pub get` must run before codegen.** frb codegen invokes `ffigen`,
   which needs `flutter/.dart_tool/package_config.json`. The old `build.py` comment
   ordering (pub get after codegen) fails with `ffigen failed`.
4. **`mfx-dispatch:x64-linux` fails in vcpkg.** It is only needed for Intel QSV
   hardware codec. Build with `--features flutter` (no `hwcodec`) and install only
   the software codec ports; software VP8/VP9/AV1 + opus is sufficient.

## Prerequisites

```bash
sudo apt-get update
sudo apt-get install -y \
  clang cmake curl gcc-multilib git g++ g++-multilib \
  libayatana-appindicator3-dev libasound2-dev libc6-dev libclang-dev libunwind-dev \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libgtk-3-dev libpulse-dev \
  libva-dev libxcb-randr0-dev libxcb-shape0-dev libxcb-xfixes0-dev libxdo-dev libxfixes-dev \
  llvm-dev nasm ninja-build pkg-config wget libpam0g-dev libssl-dev   # libssl-dev = fix (1)

# Rust 1.88 WITH rustfmt  -- fix (2), updated dependency minimum
rustup toolchain install 1.88.0 --profile minimal --component rustfmt

# Flutter 3.24.5 (stable)
# e.g. download flutter_linux_3.24.5-stable.tar.xz and add flutter/bin to PATH
```

## vcpkg (pinned) + codec libraries

```bash
git clone https://github.com/microsoft/vcpkg "$HOME/vcpkg"
git -C "$HOME/vcpkg" checkout 120deac3062162151622ca4860575a33844ba10b
"$HOME/vcpkg/bootstrap-vcpkg.sh" -disableMetrics
export VCPKG_ROOT="$HOME/vcpkg"

# fix (4): software codecs only; skip ffmpeg/mfx-dispatch
"$VCPKG_ROOT/vcpkg" install --overlay-ports=res/vcpkg \
  libvpx:x64-linux libyuv:x64-linux aom:x64-linux opus:x64-linux libjpeg-turbo:x64-linux
```

## Bridge codegen tools

```bash
cargo install cargo-expand --version 1.0.95 --locked
cargo install flutter_rust_bridge_codegen --version 1.80.1 --features uuid --locked
```

## Build

```bash
(cd flutter && flutter pub get)                      # fix (3): before codegen

flutter_rust_bridge_codegen \
  --rust-input ./src/flutter_ffi.rs \
  --dart-output ./flutter/lib/generated_bridge.dart \
  --c-output ./flutter/macos/Runner/bridge_generated.h

cargo build --features flutter --lib --release       # no hwcodec

sed -i 's/ffi.NativeFunction<ffi.Bool Function(DartPort/ffi.NativeFunction<ffi.Uint8 Function(DartPort/g' \
  flutter/lib/generated_bridge.dart

# runnable bundle:
(cd flutter && flutter build linux --release)
# -> flutter/build/linux/x64/release/bundle/rustdesk

# .deb package (skips cargo, reuses the lib built above):
python3 ./build.py --flutter --skip-cargo
# -> rustdesk-<version>.deb
```

## Run + enable MCP

```bash
# from the bundle, or after `sudo apt install ./rustdesk-<version>.deb`
# enable MCP: Settings -> Security -> Enable MCP server
#   or set in ~/.config/rustdesk/RustDesk_local.toml under [options]:
#   enable-mcp-server = 'Y'
# endpoint: http://127.0.0.1:59940/mcp   (JSON-RPC 2.0 over HTTP POST)
```

## CI

`.github/workflows/linux-deb.yml` reproduces all of the above on `ubuntu-24.04`.
Trigger it via **Actions → build-linux-deb → Run workflow**, or push a tag matching
`v*-linux*` to build and attach the `.deb` to the corresponding release.

## Credits / license

Based on [YaoxinCS/RustdeskMCP](https://github.com/YaoxinCS/RustdeskMCP), itself a
fork of [rustdesk/rustdesk](https://github.com/rustdesk/rustdesk). Licensed under
AGPL-3.0; corresponding source is this repository.
