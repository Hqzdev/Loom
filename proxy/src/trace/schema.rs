//! Trace schema bootstrap.

use rusqlite::Connection;

/// Initializes the trace schema and reconciles older databases.
///
/// # Errors
/// Returns any `rusqlite` error from the schema or migration steps.
pub(crate) fn init_schema(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS trace_calls (
            id                TEXT PRIMARY KEY,
            created_at        INTEGER NOT NULL,
            provider          TEXT NOT NULL,
            method            TEXT NOT NULL,
            path              TEXT NOT NULL,
            model             TEXT NOT NULL DEFAULT '-',
            status_code       INTEGER NOT NULL,
            cache_status      TEXT NOT NULL,
            latency_ms        INTEGER NOT NULL,
            request_id        TEXT NOT NULL DEFAULT '-',
            prompt_system     TEXT NOT NULL DEFAULT '',
            prompt_user       TEXT NOT NULL DEFAULT '',
            response_text     TEXT NOT NULL DEFAULT '',
            response_language TEXT NOT NULL DEFAULT 'text',
            error_code        TEXT,
            error_message     TEXT,
            error_detail      TEXT,
            tokens_in         INTEGER NOT NULL DEFAULT 0,
            tokens_out        INTEGER NOT NULL DEFAULT 0,
            cost              TEXT NOT NULL DEFAULT '$0.0000',
            temperature       REAL,
            trace_id          TEXT,
            parent_span_id    TEXT,
            tool_use_ids      TEXT,
            context_inputs    TEXT,
            input_hash        TEXT,
            stale             INTEGER NOT NULL DEFAULT 0,
            request_body      BLOB,
            request_target    TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_trace_calls_created_at
            ON trace_calls(created_at);",
    )?;
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
    )
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
