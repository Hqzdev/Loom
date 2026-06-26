use std::fs::OpenOptions;
use std::io::{Read, Write};
use std::net::{SocketAddr, TcpStream};
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::sync::Mutex;
use std::time::Duration;

use serde::Serialize;
use tauri::{AppHandle, State};

use crate::proxy_paths::{find_proxy_binary, runtime_paths, upstream};

#[derive(Default)]
pub struct ProxyProcessState {
    child: Mutex<Option<Child>>,
}

#[derive(Serialize)]
pub struct ProxyStartResult {
    started: bool,
    already_running: bool,
    binary_path: Option<String>,
}

#[tauri::command]
pub fn proxy_health(port: u16) -> Result<bool, String> {
    Ok(proxy_is_healthy(port))
}

#[tauri::command]
pub fn start_proxy(
    port: u16,
    app: AppHandle,
    state: State<ProxyProcessState>,
) -> Result<ProxyStartResult, String> {
    if proxy_is_healthy(port) {
        return Ok(already_running());
    }
    clear_finished_child(&state)?;

    let binary = find_proxy_binary(&app)?;
    let runtime = runtime_paths()?;
    let log = OpenOptions::new()
        .create(true)
        .append(true)
        .open(&runtime.log_path)
        .map_err(|error| error.to_string())?;
    let stderr = log.try_clone().map_err(|error| error.to_string())?;

    let child_process = Command::new(&binary)
        .env("TETHER_ADDR", format!("127.0.0.1:{port}"))
        .env("TETHER_CACHE", "on")
        .env("TETHER_DB", runtime.database_path)
        .env(
            "OPENAI_UPSTREAM",
            upstream("OPENAI_UPSTREAM", "https://api.openai.com"),
        )
        .env(
            "ANTHROPIC_UPSTREAM",
            upstream("ANTHROPIC_UPSTREAM", "https://api.anthropic.com"),
        )
        .stdout(Stdio::from(log))
        .stderr(Stdio::from(stderr))
        .spawn()
        .map_err(|error| error.to_string())?;

    let mut child = state
        .child
        .lock()
        .map_err(|_| "proxy process lock failed".to_string())?;
    *child = Some(child_process);
    drop(child);

    wait_for_proxy(port, binary)
}

#[tauri::command]
pub fn stop_proxy(state: State<ProxyProcessState>) -> Result<bool, String> {
    let mut child = state
        .child
        .lock()
        .map_err(|_| "proxy process lock failed".to_string())?;
    let Some(mut process) = child.take() else {
        return Ok(false);
    };
    if process
        .try_wait()
        .map_err(|error| error.to_string())?
        .is_none()
    {
        process.kill().map_err(|error| error.to_string())?;
        process.wait().map_err(|error| error.to_string())?;
        return Ok(true);
    }
    Ok(false)
}

fn clear_finished_child(state: &State<ProxyProcessState>) -> Result<(), String> {
    let mut child = state
        .child
        .lock()
        .map_err(|_| "proxy process lock failed".to_string())?;
    if let Some(process) = child.as_mut() {
        if process
            .try_wait()
            .map_err(|error| error.to_string())?
            .is_none()
        {
            return Err("proxy process is already starting".to_string());
        }
        *child = None;
    }
    Ok(())
}

fn wait_for_proxy(port: u16, binary: PathBuf) -> Result<ProxyStartResult, String> {
    for _ in 0..20 {
        if proxy_is_healthy(port) {
            return Ok(ProxyStartResult {
                started: true,
                already_running: false,
                binary_path: Some(binary.display().to_string()),
            });
        }
        std::thread::sleep(Duration::from_millis(150));
    }
    Err("local proxy did not become ready".to_string())
}

fn already_running() -> ProxyStartResult {
    ProxyStartResult {
        started: false,
        already_running: true,
        binary_path: None,
    }
}

fn proxy_is_healthy(port: u16) -> bool {
    let address = SocketAddr::from(([127, 0, 0, 1], port));
    let Ok(mut stream) = TcpStream::connect_timeout(&address, Duration::from_millis(700)) else {
        return false;
    };
    if stream
        .set_read_timeout(Some(Duration::from_millis(700)))
        .is_err()
    {
        return false;
    }
    if stream
        .set_write_timeout(Some(Duration::from_millis(700)))
        .is_err()
    {
        return false;
    }
    if stream
        .write_all(
            b"GET /api/events/health HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n",
        )
        .is_err()
    {
        return false;
    }
    let mut response = String::new();
    stream.read_to_string(&mut response).is_ok()
        && (response.starts_with("HTTP/1.1 204") || response.starts_with("HTTP/1.1 200"))
}
