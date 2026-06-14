# loom-cache

`loom-cache` owns the local SQLite response cache used by the proxy.

## Responsibility

- Create and maintain the `cache` table.
- Compute stable SHA-256 cache keys from `method`, `path_and_query`, and request body.
- Read cached responses and increment hit counters.
- Store successful upstream responses on a best-effort basis.

## Public interface

- `init_schema(conn)`
- `cache_key(method, path_and_query, body)`
- `get(db, key)`
- `put(db, key, provider, model, preview, status, content_type, body)`

## Tests

Run from `proxy/`:

```bash
cargo test -p loom-cache
```
