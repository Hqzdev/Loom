#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${TETHER_BACKUP_DIR:-$ROOT/.tether-backups}"
TMP_DIR="${TMPDIR:-/tmp}/tether-restore-$(date -u +%s)"
mkdir -p "$TMP_DIR"

need_cmd() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "warn command_missing command=$command_name" >&2
    return 1
  fi
  return 0
}

LATEST_SQLITE="$(find "$BACKUP_DIR" -maxdepth 1 -name 'sqlite-*.db.gz' -type f -print | sort | tail -n 1)"
if [[ -z "${LATEST_SQLITE:-}" ]]; then
  echo "err restore_no_sqlite_backup dir=$BACKUP_DIR" >&2
  exit 1
fi

RESTORED_SQLITE="$TMP_DIR/restored.sqlite"
need_cmd sqlite3
need_cmd gunzip
gunzip -c "$LATEST_SQLITE" >"$RESTORED_SQLITE"
sqlite3 "$RESTORED_SQLITE" "PRAGMA integrity_check;"
sqlite3 "$RESTORED_SQLITE" "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('trace_calls', 'request_cache');"
echo "sqlite_restore_ok db=$RESTORED_SQLITE" >&2

if [[ -n "${DATABASE_URL:-}" ]] && command -v pg_restore >/dev/null 2>&1; then
  LATEST_PG="$(find "$BACKUP_DIR" -maxdepth 1 -name 'postgres-*.sql.gz' -type f -print | sort | tail -n 1)"
  if [[ -n "${LATEST_PG:-}" ]]; then
    echo "postgres_backup_available path=$LATEST_PG" >&2
  else
    echo "postgres_backup_missing path=$BACKUP_DIR" >&2
  fi
fi

if [[ -n "${TETHER_PG_RESTORE_DSN:-}" ]]; then
  if need_cmd psql; then
    LATEST_PG="$(find "$BACKUP_DIR" -maxdepth 1 -name 'postgres-*.sql.gz' -type f -print | sort | tail -n 1)"
    if [[ -z "${LATEST_PG:-}" ]]; then
      echo "err restore_no_postgres_backup dir=$BACKUP_DIR" >&2
      exit 1
    fi
    RESTORED_SQL="$TMP_DIR/postgres.sql"
    gunzip -c "$LATEST_PG" >"$RESTORED_SQL"
    psql "$TETHER_PG_RESTORE_DSN" -v ON_ERROR_STOP=1 <"$RESTORED_SQL"
    psql "$TETHER_PG_RESTORE_DSN" -v ON_ERROR_STOP=1 <<'SQL'
SELECT 1;
SELECT to_regclass('public.roles') IS NOT NULL;
SELECT to_regclass('public.permissions') IS NOT NULL;
SELECT to_regclass('public.user_roles') IS NOT NULL;
SELECT to_regclass('public.role_permissions') IS NOT NULL;
SQL
    echo "postgres_restore_ok dsn=$TETHER_PG_RESTORE_DSN" >&2
  else
    echo "warn skip_postgres_restore_restoretool_missing dsn=$TETHER_PG_RESTORE_DSN" >&2
  fi
fi

echo "restore_drill_ok sqlite_backup=$LATEST_SQLITE restored=$RESTORED_SQLITE" >&2
