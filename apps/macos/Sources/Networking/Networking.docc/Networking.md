# Networking

@Metadata {
    @TitleHeading("Framework")
}

Networking owns local process integration for the Tether desktop app: proxy API
requests, proxy helper lifecycle, persisted settings, Keychain access, and the
local terminal log observer.

## Overview

This target is intentionally local-first. It talks to `127.0.0.1`, macOS
Keychain, bundled helper binaries, and local SQLite files; it must not
persist provider secrets in plain text.

## Topics

### Local Proxy API

- ``TraceAPIClient``

### Local Observers

- ``CodexLogObserver``

### Desktop Helper

- ``LocalProxyLauncher``
- ``ProxySettingsStore``
- ``KeychainStore``
