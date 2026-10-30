# Build RustDeskMCP on Arch Linux / EndeavourOS

This fork uses RustDesk 1.5.0 with the existing desktop and terminal MCP API.
The package name remains `rustdesk`, so upgrading preserves the existing
`~/.config/rustdesk` configuration and system service.

## Prerequisites

```sh
sudo pacman -S --needed base-devel clang18 cmake ninja pkgconf unzip curl \
  gtk3 xdotool libxcb libxfixes alsa-lib libva libappindicator pam \
  gst-plugins-base gst-plugin-pipewire libyuv libvpx aom opus libpulse openssl
git submodule update --init --recursive
```

Use Rust 1.88 or newer with `rustfmt`, Flutter 3.24.5 (Dart 3.5.4), and these
bridge tools on `PATH`:

```sh
cargo install cargo-expand --version 1.0.95 --locked
cargo install flutter_rust_bridge_codegen --version 1.80.1 --features uuid --locked
```

The local build uses Rust 1.98.1. Flutter and the bridge remain on the upstream
versions; dependency security updates raise the Rust minimum from 1.75 to 1.88.

## Build and package

```sh
./res/build-arch.sh
```

The script builds the Rust core with `flutter,linux-pkg-config`, builds the
Flutter bundle, then packages it with `res/PKGBUILD`. Hardware codecs and the
optional DRM backend are not enabled in this build.

Arch-specific build adjustments:

- System codec libraries are linked with `linux-pkg-config`. The local
  `res/pkgconfig/libyuv.pc` supplies metadata missing from Arch's libyuv package.
- Clang 18 and its explicit resource-header directory keep ffigen 8 compatible
  with the generated C header. A broken header search can otherwise generate a
  Dart typedef named `bool` instead of proper native boolean bindings.
- `CXXFLAGS=-include cstdint` supplies a header missing in the pinned libwebm
  sources when compiling with recent GCC.
- `CMAKE_POLICY_VERSION_MINIMUM=3.5` supports older Flutter plugin build files
  under CMake 4.

## Install and verify

Back up the existing package, user configuration, and service configuration
before replacement. Install the generated package:

```sh
sudo pacman -U res/rustdesk-1.5.0-1-x86_64.pkg.tar.zst
rustdesk --version
systemctl status rustdesk --no-pager
```

Restart any running GUI instance as well: an existing process keeps using the
old library even after package replacement. MCP uses the existing GUI toggle
under Settings → Security and listens on `http://127.0.0.1:59940/mcp`.

When launching from an AppImage-based development environment, remove its
private library overrides from the RustDesk child process:

```sh
env -u LD_LIBRARY_PATH -u LD_PRELOAD /usr/bin/rustdesk
```

Close any leftover staging GUI (including `--no-server` instances) before
starting the installed GUI; otherwise session IPC can be routed to a different
process than the MCP listener.

Verify `initialize`, the 13-tool `tools/list`, remote frame capture, input lock
and unlock, and terminal command output on an authorized test peer.

## Regression tests

With the same native-library environment as `res/build-arch.sh`:

```sh
PKG_CONFIG_PATH="$PWD/res/pkgconfig" LIBCLANG_PATH=/usr/lib/llvm18/lib \
  CXXFLAGS='-include cstdint' CARGO_BUILD_JOBS=3 \
  cargo test --locked --release --features flutter,linux-pkg-config \
    --lib agent_bridge::tests -- --test-threads=1
```

For rollback, reinstall the saved old pacman package, stop the new GUI, and
restart the service and GUI. Restore configuration from the backup only if
needed; keep configuration archives private because they contain credentials.
