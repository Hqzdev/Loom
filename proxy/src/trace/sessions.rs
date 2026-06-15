//! Session lifecycle: resolve the current session, look sessions up, create them.

use rusqlite::{Connection, OptionalExtension, params};
use uuid::Uuid;

use loom_domain::TraceSessionDto;

use super::text::{format_time_for_name, format_timestamp, now_millis};

/// Returns the most recent session, creating a "Live Session" if none exist.
pub(super) fn ensure_current_session(conn: &Connection) -> rusqlite::Result<TraceSessionDto> {
    if let Some(session) = latest_session(conn)? {
        return Ok(session);
    }

    create_session(conn, Some("Live Session"))
}

/// The newest session by creation time, or `None` when the table is empty.
pub(super) fn latest_session(conn: &Connection) -> rusqlite::Result<Option<TraceSessionDto>> {
    conn.query_row(
        "SELECT id, created_at, name
         FROM sessions
         ORDER BY created_at DESC
         LIMIT 1",
        [],
        |row| {
            Ok(session_to_dto(
                row.get::<_, String>(0)?,
                row.get::<_, i64>(1)?,
                row.get::<_, String>(2)?,
            ))
        },
    )
    .optional()
}

/// Looks up a session by id.
pub(super) fn find_session(
    conn: &Connection,
    id: &str,
) -> rusqlite::Result<Option<TraceSessionDto>> {
    conn.query_row(
        "SELECT id, created_at, name
         FROM sessions
         WHERE id = ?1",
        [id],
        |row| {
            Ok(session_to_dto(
                row.get::<_, String>(0)?,
                row.get::<_, i64>(1)?,
                row.get::<_, String>(2)?,
            ))
        },
    )
    .optional()
}

/// Creates a new session, defaulting its name to the current `HH:MM` time.
pub(super) fn create_session(
    conn: &Connection,
    name: Option<&str>,
) -> rusqlite::Result<TraceSessionDto> {
    let created_at = now_millis();
    let id = Uuid::new_v4().to_string();
    let name = name
        .map(ToOwned::to_owned)
        .unwrap_or_else(|| format!("Session {}", format_time_for_name(created_at)));

    conn.execute(
        "INSERT INTO sessions (id, created_at, name)
         VALUES (?1, ?2, ?3)",
        params![id, created_at, name],
    )?;

    Ok(session_to_dto(id, created_at, name))
}

/// Assigns the current session to any legacy rows missing a `session_id`.
pub(super) fn backfill_missing_session_ids(conn: &Connection) -> rusqlite::Result<()> {
    let session = ensure_current_session(conn)?;
    conn.execute(
        "UPDATE trace_calls
         SET session_id = ?1
         WHERE session_id IS NULL OR session_id = ''",
        [session.id],
    )?;
    Ok(())
}

/// Converts a persisted session row into the UI-facing session DTO.
pub(super) fn session_to_dto(id: String, created_at: i64, name: String) -> TraceSessionDto {
    TraceSessionDto {
        id,
        title: name,
        trigger: "AgentTrace proxy".to_string(),
        started_at: format_timestamp(created_at),
    }
}
