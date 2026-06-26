# Tether Windows

Status: in development.

Target readiness window: 53 days.

The Windows app is not shipped yet. This folder reserves the platform boundary so the repository structure stays stable while the Windows client is designed.

Planned scope:

- Windows desktop shell for the local execution debugger.
- Local proxy startup and health checks.
- Trace graph with draggable nodes, connections, inspector, and replay controls.
- Shared protocol compatibility with `core/proxy`.
- Packaging path for installer artifacts.

Current rule:

- Do not add placeholder runtime code here until the app can build.
- Keep shared behavior in `core/proxy`.
- Keep platform-specific UI code inside this folder once Windows work starts.
