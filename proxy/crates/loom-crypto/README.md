# loom-crypto

`loom-crypto` contains small cryptographic helpers shared by proxy services.

## Responsibility

- Derive an AES-GCM key from `AGENTTRACE_KEYS_SECRET`.
- Encrypt provider API keys before storage.
- Decrypt stored provider API keys when needed.

## Public interface

- `KeyCipher::from_secret(secret)`
- `KeyCipher::encrypt(plaintext)`
- `KeyCipher::decrypt(encoded)`
- `CryptoError::message()`

## Tests

Run from `proxy/`:

```bash
cargo test -p loom-crypto
```
