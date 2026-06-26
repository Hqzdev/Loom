use std::sync::{Arc, Mutex};
use std::time::Duration;

use rusqlite::{Connection, params};

const DEFAULT_RETENTION_DAYS: u64 = 7;
const MAX_RETENTION_DAYS: u64 = 3_650;
const MILLIS_PER_DAY: i64 = 86_400_000;
const CLEANUP_INTERVAL_SECS: u64 = 21_600;

#[derive(Clone, Copy)]
pub(crate) struct TraceRetention {
    days: Option<u64>,
}

impl TraceRetention {
    pub(crate) fn from_env() -> Result<Self, String> {
        let raw = std::env::var("TETHER_TRACE_RETENTION_DAYS").unwrap_or_default();
        let value = raw.trim();
        if value.is_empty() {
            return Ok(Self {
                days: Some(DEFAULT_RETENTION_DAYS),
            });
        }
        if matches!(value, "0" | "off" | "false" | "none" | "disabled") {
            return Ok(Self { days: None });
        }
        let days = value
            .parse::<u64>()
            .map_err(|_| "TETHER_TRACE_RETENTION_DAYS must be a day count or off".to_string())?;
        if days == 0 || days > MAX_RETENTION_DAYS {
            return Err(format!(
                "TETHER_TRACE_RETENTION_DAYS must be between 1 and {MAX_RETENTION_DAYS}, or off"
            ));
        }
        Ok(Self { days: Some(days) })
    }

    pub(crate) fn label(self) -> String {
        match self.days {
            Some(days) => format!("{days}d"),
            None => "off".to_string(),
        }
    }

    fn cutoff_millis(self, now_millis: i64) -> Option<i64> {
        self.days
            .map(|days| now_millis - (days as i64 * MILLIS_PER_DAY))
    }
}

pub(crate) fn cleanup_expired_traces(
    conn: &Connection,
    retention: TraceRetention,
    now_millis: i64,
) -> rusqlite::Result<usize> {
    let Some(cutoff) = retention.cutoff_millis(now_millis) else {
        return Ok(0);
    };
    conn.execute(
        "DELETE FROM trace_calls WHERE created_at < ?1",
        params![cutoff],
    )
}

pub(crate) fn spawn_retention_worker(db: Arc<Mutex<Connection>>, retention: TraceRetention) {
    if retention.days.is_none() {
        return;
    }
    tokio::spawn(async move {
        run_cleanup(&db, retention);
        let mut timer = tokio::time::interval(Duration::from_secs(CLEANUP_INTERVAL_SECS));
        loop {
            timer.tick().await;
            run_cleanup(&db, retention);
        }
    });
}

fn run_cleanup(db: &Arc<Mutex<Connection>>, retention: TraceRetention) {
    let deleted = db
        .lock()
        .map_err(|_| "trace database lock poisoned".to_string())
        .and_then(|conn| {
            cleanup_expired_traces(&conn, retention, super::text::now_millis())
                .map_err(|error| error.to_string())
        });

    match deleted {
        Ok(count) if count > 0 => println!("  trace retention deleted {count} expired nodes"),
        Ok(_) => {}
        Err(error) => eprintln!("trace retention cleanup failed: {error}"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cleanup_expired_traces_deletes_only_rows_before_cutoff() {
        let conn = Connection::open_in_memory().unwrap();
        conn.execute(
            "CREATE TABLE trace_calls (id TEXT PRIMARY KEY, created_at INTEGER NOT NULL)",
            [],
        )
        .unwrap();
        conn.execute(
            "INSERT INTO trace_calls (id, created_at) VALUES ('old', ?1), ('fresh', ?2)",
            params![1_000_i64, 691_201_000_i64],
        )
        .unwrap();

        let deleted =
            cleanup_expired_traces(&conn, TraceRetention { days: Some(7) }, 691_201_001).unwrap();
        let remaining: Vec<String> = {
            let mut stmt = conn
                .prepare("SELECT id FROM trace_calls ORDER BY id ASC")
                .unwrap();
            stmt.query_map([], |row| row.get::<_, String>(0))
                .unwrap()
                .collect::<rusqlite::Result<Vec<_>>>()
                .unwrap()
        };

        assert_eq!(deleted, 1);
        assert_eq!(remaining, vec!["fresh".to_string()]);
    }

    #[test]
    fn cleanup_expired_traces_keeps_rows_when_retention_is_disabled() {
        let conn = Connection::open_in_memory().unwrap();
        conn.execute(
            "CREATE TABLE trace_calls (id TEXT PRIMARY KEY, created_at INTEGER NOT NULL)",
            [],
        )
        .unwrap();
        conn.execute(
            "INSERT INTO trace_calls (id, created_at) VALUES ('old', ?1)",
            params![1_000_i64],
        )
        .unwrap();

        let deleted =
            cleanup_expired_traces(&conn, TraceRetention { days: None }, 691_201_001).unwrap();
        let count: i64 = conn
            .query_row("SELECT COUNT(*) FROM trace_calls", [], |row| row.get(0))
            .unwrap();

        assert_eq!(deleted, 0);
        assert_eq!(count, 1);
    }
}
