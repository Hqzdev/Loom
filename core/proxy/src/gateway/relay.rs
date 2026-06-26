//! Stream relay helpers for the proxy gateway.

use bytes::Bytes;

use crate::trace;

/// Relays one upstream chunk to the client and appends trace/cache bytes.
pub(super) async fn chunk(
    item: Result<Bytes, reqwest::Error>,
    tx: &tokio::sync::mpsc::Sender<Result<Bytes, reqwest::Error>>,
    store: bool,
    acc: &mut Vec<u8>,
) -> Result<(), Option<String>> {
    match item {
        Ok(chunk) => {
            append_capture_bytes(store, acc, &chunk);
            tx.send(Ok(chunk)).await.map_err(|_| None)
        }
        Err(error) => {
            let message = error.to_string();
            let _ = tx.send(Err(error)).await;
            Err(Some(message))
        }
    }
}

/// Appends either full cache bytes or capped trace-preview bytes.
fn append_capture_bytes(store: bool, acc: &mut Vec<u8>, chunk: &[u8]) {
    if store {
        acc.extend_from_slice(chunk);
    } else if acc.len() < trace::MAX_CAPTURE_BYTES {
        let remaining = trace::MAX_CAPTURE_BYTES - acc.len();
        acc.extend_from_slice(&chunk[..chunk.len().min(remaining)]);
    }
}
