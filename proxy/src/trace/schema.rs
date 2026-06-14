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
    ensure_current_session(conn)?;
    backfill_missing_session_ids(conn)
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
