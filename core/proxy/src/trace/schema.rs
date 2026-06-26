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
            request_target    TEXT,
            is_replay         INTEGER NOT NULL DEFAULT 0,
            replay_source_id  TEXT,
            replay_provider   TEXT,
            workspace_id      TEXT NOT NULL DEFAULT 'local-default'
        );

        CREATE INDEX IF NOT EXISTS idx_trace_calls_created_at
            ON trace_calls(created_at);

        CREATE TABLE IF NOT EXISTS provider_settings (
            key   TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS repair_actions (
            id          TEXT PRIMARY KEY,
            session_id  TEXT NOT NULL,
            caused_by   TEXT NOT NULL,
            action_type TEXT NOT NULL,
            payload     TEXT NOT NULL,
            status      TEXT NOT NULL,
            result      TEXT,
            created_at  INTEGER NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_repair_actions_session_id
            ON repair_actions(session_id);

        CREATE INDEX IF NOT EXISTS idx_repair_actions_caused_by
            ON repair_actions(caused_by);",
    )?;
    add_column_if_missing(conn, "trace_calls", "trace_id", "TEXT")?;
    add_column_if_missing(conn, "trace_calls", "parent_span_id", "TEXT")?;
    add_column_if_missing(conn, "trace_calls", "tool_use_ids", "TEXT")?;
    add_column_if_missing(conn, "trace_calls", "context_inputs", "TEXT")?;
    add_column_if_missing(conn, "trace_calls", "input_hash", "TEXT")?;
    add_column_if_missing(conn, "trace_calls", "stale", "INTEGER NOT NULL DEFAULT 0")?;
    add_column_if_missing(conn, "trace_calls", "request_body", "BLOB")?;
    add_column_if_missing(conn, "trace_calls", "request_target", "TEXT")?;
    add_column_if_missing(
        conn,
        "trace_calls",
        "is_replay",
        "INTEGER NOT NULL DEFAULT 0",
    )?;
    add_column_if_missing(conn, "trace_calls", "replay_source_id", "TEXT")?;
    add_column_if_missing(conn, "trace_calls", "replay_provider", "TEXT")?;
    add_column_if_missing(
        conn,
        "trace_calls",
        "workspace_id",
        "TEXT NOT NULL DEFAULT 'local-default'",
    )?;
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn init_schema_creates_repair_actions_storage() {
        let conn = Connection::open_in_memory().unwrap();

        init_schema(&conn).unwrap();
        init_schema(&conn).unwrap();

        let columns = table_columns(&conn, "repair_actions");
        let indexes = table_indexes(&conn, "repair_actions");

        assert_eq!(
            columns,
            vec![
                "id",
                "session_id",
                "caused_by",
                "action_type",
                "payload",
                "status",
                "result",
                "created_at"
            ]
        );
        assert!(indexes.contains(&"idx_repair_actions_session_id".to_string()));
        assert!(indexes.contains(&"idx_repair_actions_caused_by".to_string()));
    }

    fn table_columns(conn: &Connection, table: &str) -> Vec<String> {
        let mut stmt = conn
            .prepare(&format!("PRAGMA table_info({table})"))
            .unwrap();
        stmt.query_map([], |row| row.get::<_, String>(1))
            .unwrap()
            .map(Result::unwrap)
            .collect()
    }

    fn table_indexes(conn: &Connection, table: &str) -> Vec<String> {
        let mut stmt = conn
            .prepare("SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = ?1")
            .unwrap();
        stmt.query_map([table], |row| row.get::<_, String>(0))
            .unwrap()
            .map(Result::unwrap)
            .collect()
    }
}
