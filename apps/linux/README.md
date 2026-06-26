# Tether Linux

Status: alpha.

The Linux app is a Tauri desktop client for Tether's local execution debugger. It uses the shared Rust proxy from `core/proxy` and renders traces with a React graph UI.

## Structure

| Path | Purpose |
| --- | --- |
| `src/app` | App state, proxy polling, node selection, replay, and workspace attribution. |
| `src/features` | Graph canvas, inspector, replay footer, settings, and call list surfaces. |
| `src/infrastructure` | Tauri bridge clients for proxy HTTP, proxy process control, and workspace snapshots. |
| `src-tauri/src` | Rust desktop commands, proxy sidecar lookup, process control, and workspace diff reads. |

## Development

```bash
npm --prefix apps/linux ci
npm --prefix apps/linux run tauri:dev
```

The browser preview can render the UI, but proxy start and stop commands only work in the Tauri desktop window.

## Verification

```bash
npm --prefix apps/linux run build
cargo check --manifest-path apps/linux/src-tauri/Cargo.toml
```

## Packaging

```bash
./scripts/package-linux.sh
```

The script builds `core/proxy` in release mode, copies `tether-proxy` as a Tauri sidecar, builds the Linux desktop app, and collects `.AppImage` or `.deb` files into `dist/linux`.

Linux artifacts are also produced by the `Linux App` GitHub Actions workflow on Ubuntu.
