//! Trace schema bootstrap: apply migrations and reconcile legacy databases.

use rusqlite::Connection;

use super::sessions::{backfill_missing_session_ids, ensure_current_session};

/// Initializes the sessions/trace schema and migrates older databases:
/// adds a missing `session_id` column and backfills it to the current session.
///
/// # Errors
/// Returns any `rusqlite` error from the migration or backfill steps.
pub(crate) fn init_schema(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute_batch(include_str!(
        "../../sqlite_migrations/20260601000000_sessions.sql"
    ))?;
    if !table_has_column(conn, "trace_calls", "session_id")? {
        conn.execute("ALTER TABLE trace_calls ADD COLUMN session_id TEXT", [])?;
    }
    add_column_if_missing(conn, "trace_calls", "trace_id", "TEXT")?;
    add_column_if_missing(conn, "trace_calls", "parent_span_id", "TEXT")?;
    add_column_if_missing(conn, "trace_calls", "tool_use_ids", "TEXT")?;
    add_column_if_missing(conn, "trace_calls", "context_inputs", "TEXT")?;
    add_column_if_missing(conn, "trace_calls", "input_hash", "TEXT")?;
    add_column_if_missing(conn, "trace_calls", "stale", "INTEGER NOT NULL DEFAULT 0")?;
    add_column_if_missing(conn, "trace_calls", "request_body", "BLOB")?;
    add_column_if_missing(conn, "trace_calls", "request_target", "TEXT")?;
    conn.execute_batch(
        "CREATE INDEX IF NOT EXISTS idx_trace_calls_trace_id
             ON trace_calls(trace_id);",
    )?;
    ensure_current_session(conn)?;
    backfill_missing_session_ids(conn)
}

/// Adds `column` with `decl_type` to `table` if the column is not already present.
fn add_column_if_missing(
    conn: &Connection,
    table: &str,
    column: &str,
    decl_type: &str,
) -> rusqlite::Result<()> {
    if !table_has_column(conn, table, column)? {
        conn.execute(
            &format!("ALTER TABLE {table} ADD COLUMN {column} {decl_type}"),
            [],
        )?;
    }
    Ok(())
}

/// Returns whether `table` already has a column named `column`.
fn table_has_column(conn: &Connection, table: &str, column: &str) -> rusqlite::Result<bool> {
    let mut stmt = conn.prepare(&format!("PRAGMA table_info({table})"))?;
    let mut rows = stmt.query([])?;

    while let Some(row) = rows.next()? {
        let name: String = row.get(1)?;
        if name == column {
            return Ok(true);
        }
    }

    Ok(false)
}
