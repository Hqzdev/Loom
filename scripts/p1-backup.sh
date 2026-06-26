#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${TETHER_BACKUP_DIR:-$ROOT/.tether-backups}"
RETENTION_DAYS="${TETHER_BACKUP_RETENTION_DAYS:-30}"
TIMESTAMP="$(date -u +"%Y%m%d-%H%M%S")"
DB_PATH="${TETHER_DB:-$ROOT/tether-cache.sqlite}"
DB_BACKUP="$BACKUP_DIR/sqlite-$TIMESTAMP.db"

mkdir -p "$BACKUP_DIR"

if [[ -f "$DB_PATH" ]]; then
  cp "$DB_PATH" "$DB_BACKUP"
  gzip -f "$DB_BACKUP"
else
  echo "warn sqlite_db_missing path=$DB_PATH" >&2
fi

if [[ -n "${DATABASE_URL:-}" ]]; then
  if command -v pg_dump >/dev/null 2>&1; then
    pg_dump "$DATABASE_URL" >"$BACKUP_DIR/postgres-$TIMESTAMP.sql"
    gzip -f "$BACKUP_DIR/postgres-$TIMESTAMP.sql"
  else
    echo "warn pg_dump_missing database_url_set=true" >&2
  fi
fi

find "$BACKUP_DIR" -type f -name '*.gz' -mtime +"$RETENTION_DAYS" -delete
echo "backup_complete backup_dir=$BACKUP_DIR timestamp=$TIMESTAMP" >&2
