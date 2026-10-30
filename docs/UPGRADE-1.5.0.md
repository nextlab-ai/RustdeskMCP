# RustDeskMCP 1.5.0 integration

## Source basis

- Upstream: `rustdesk/rustdesk`, tag `1.5.0`, commit
  `fada664df7a294d1d1a9ca3e7cd3637069122f17`.
- Upstream `libs/hbb_common` submodule:
  `229b904508364c8997aad0fb5af57effac859f60`.
- Previous local baseline: `b25d647fbbe4155f92ccb21ccf197ff6c6f51acc`.
- The old repository imported the source as a single initial commit. Its MCP
  edits were isolated against upstream commit
  `47e4c65d8e888b9d27e33bd596f6e8ca4d69e451` and merged into the 1.5.0 source.
  Unrelated differences from that comparison were not treated as MCP changes.

## Preserved fork behavior

- All 13 desktop/terminal MCP tools and their public schemas.
- GUI-controlled MCP enablement and localhost endpoint on port 59940.
- Normal RustDesk connection and authentication paths, cached remote frames,
  terminal output, explicit local input lock and agent input bypass.
- Windows fork app-name initialization, fork licensing notices, and the public
  Firebase configuration template.
- Linux package identity `rustdesk` and its existing user configuration path.

The upstream message types moved from `hbb_common` into `libs/base`; the MCP
bridge imports the new types. Frame recording follows the updated Flutter
render callbacks. Input-lock hooks are gated to desktop Flutter builds so that
other configurations do not reference the desktop-only MCP module.

## Dependency and build changes

Selected security updates in the committed lockfile include:

| Package | Version |
| --- | --- |
| bytes | 1.11.1 |
| crossbeam-channel | 0.5.17 |
| openssl | 0.10.81 |
| rustls | 0.23.46 |
| rustls-webpki | 0.103.16 |
| time | 0.3.55 |
| tokio | 1.54.1 |

Rust 1.88 is the new minimum because the patched `time` dependency requires it.
Flutter remains at 3.24.5 and flutter_rust_bridge at 1.80.1.

See [BUILD-ARCH.md](BUILD-ARCH.md) for the native package build and
[BUILD-LINUX.md](BUILD-LINUX.md) for the Ubuntu build workflow.

This integration is validated for the current x86_64 EndeavourOS host. Other
platforms and the legacy Sciter frontend require separate validation. In
particular, the upstream legacy Sciter CI still pins Rust 1.75 for ABI reasons
and needs a separate toolchain/ABI migration before it can use this lockfile.

The dependency advisory check covers the active Linux normal/build graph, not
every target or runtime reachability. Maintenance notices and other inherited
advisory matches remain, including dependencies in the GTK/zbus and sodiumoxide
stacks. This update does not claim a clean repository-wide security audit.

## Validation

MCP regression tests cover initialization/version reporting, nested agent input
bypass and lock clearing, display-specific frame caching, and terminal data
using the new upstream protobuf types. Runtime installation verification must
also check the installed version, service health, MCP tool schemas, remote
frames, input lock/unlock, and read-only terminal output on an authorized peer.

Completed on 2026-10-30 on the current x86_64 EndeavourOS host:

- Release Rust core and Flutter Linux bundle built successfully.
- Four MCP regression tests passed (324 unrelated tests filtered out).
- Native `rustdesk-1.5.0-1-x86_64.pkg.tar.zst` built and installed with pacman.
- Installed CLI and MCP initialization both report `1.5.0`; systemd service is
  active and the pre-upgrade host ID is preserved.
- Installed GUI maps `/usr/share/rustdesk/lib/librustdesk.so`, with no staging
  libraries loaded. The MCP listener is bound to `127.0.0.1:59940`.
- All 13 tool schemas match the saved pre-upgrade schema exactly.
- Authorized remote desktop capture returned a valid 2560×1080 PNG. Display
  selection, pointer movement, a neutral Shift key event, and explicit local
  input lock/unlock succeeded.
- The remote Windows terminal executed a read-only PowerShell command and
  returned a marker assembled from two strings, distinguishing execution from
  a command merely echoed by the shell.
- A pacman-installable rollback snapshot of `1.4.6-0` and private user/root
  configuration backups were saved before installation. Package metadata and
  compression integrity of the rollback package were checked; a live downgrade
  was not performed after successful installation.

The host required the versioned `llvm22-libs` runtime alongside the new build
toolchain to keep its existing Mesa driver working. GUI verification was run
without the parent AppImage application's `LD_LIBRARY_PATH`/`LD_PRELOAD` values.
After the service restart, all leftover staging GUI instances were closed before
launching the installed GUI, so session IPC and the MCP listener belong to the
same process.
