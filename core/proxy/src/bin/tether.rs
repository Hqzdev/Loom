use std::{
    env,
    net::TcpStream,
    path::{Path, PathBuf},
    process::{Command, ExitCode, Stdio},
    thread,
    time::{Duration, SystemTime, UNIX_EPOCH},
};

use serde::Serialize;
use uuid::Uuid;

const PROXY_ADDR: &str = "127.0.0.1:8080";

#[derive(Serialize)]
struct CaptureEvent {
    event_id: String,
    event_type: String,
    session_id: String,
    command: Vec<String>,
    command_line: String,
    cwd: String,
    started_at_ms: i64,
    ended_at_ms: i64,
    exit_code: Option<i32>,
    stdout: String,
    stderr: String,
    git_base_revision: Option<String>,
    git_diff_before: String,
    git_diff_after: String,
}

fn main() -> ExitCode {
    match run() {
        Ok(code) => ExitCode::from(code),
        Err(error) => {
            eprintln!("tether: {error}");
            ExitCode::from(1)
        }
    }
}

fn run() -> Result<u8, String> {
    let mut args = env::args().skip(1).collect::<Vec<_>>();
    if args.first().map(String::as_str) != Some("capture") {
        return Err("usage: tether capture -- <command>".to_string());
    }
    args.remove(0);
    if args.first().map(String::as_str) == Some("--") {
        args.remove(0);
    }
    if args.is_empty() {
        return Err("usage: tether capture -- <command>".to_string());
    }

    ensure_proxy()?;

    let cwd = env::current_dir().map_err(|error| format!("cannot read cwd: {error}"))?;
    let session_id = Uuid::new_v4().to_string();
    let event_id = Uuid::new_v4().to_string();
    let git_base_revision = git_output(&cwd, &["rev-parse", "HEAD"]).ok();
    let git_diff_before = git_output(&cwd, &["diff"]).unwrap_or_default();
    let started_at_ms = now_ms();
    let output = Command::new(&args[0])
        .args(&args[1..])
        .current_dir(&cwd)
        .output()
        .map_err(|error| format!("cannot run command: {error}"))?;
    let ended_at_ms = now_ms();
    let git_diff_after = git_output(&cwd, &["diff"]).unwrap_or_default();
    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).to_string();
    let exit_code = output.status.code();

    print!("{stdout}");
    eprint!("{stderr}");

    let event = CaptureEvent {
        event_id,
        event_type: "shell.command".to_string(),
        session_id,
        command: args.clone(),
        command_line: shell_join(&args),
        cwd: cwd.display().to_string(),
        started_at_ms,
        ended_at_ms,
        exit_code,
        stdout,
        stderr,
        git_base_revision,
        git_diff_before,
        git_diff_after,
    };
    post_event(&event)?;

    Ok(exit_code.unwrap_or(1).clamp(0, 255) as u8)
}

fn ensure_proxy() -> Result<(), String> {
    if events_ready() {
        return Ok(());
    }
    if port_open() {
        return Err(
            "local proxy is running without /api/events; restart Tether or tether-proxy"
                .to_string(),
        );
    }

    let proxy = proxy_binary()?;
    let db = default_database_path()?;
    Command::new(proxy)
        .env("TETHER_ADDR", PROXY_ADDR)
        .env("TETHER_DB", db)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|error| format!("cannot start tether-proxy: {error}"))?;

    for _ in 0..20 {
        thread::sleep(Duration::from_millis(100));
        if events_ready() {
            return Ok(());
        }
    }

    Err("local proxy did not become ready on 127.0.0.1:8080".to_string())
}

fn proxy_binary() -> Result<PathBuf, String> {
    let current = env::current_exe().map_err(|error| format!("cannot locate tether: {error}"))?;
    let candidate = current
        .parent()
        .unwrap_or_else(|| Path::new("."))
        .join("tether-proxy");
    if candidate.is_file() {
        Ok(candidate)
    } else {
        Err(format!(
            "cannot find tether-proxy next to {}",
            current.display()
        ))
    }
}

fn default_database_path() -> Result<PathBuf, String> {
    let home = env::var("HOME").map_err(|_| "HOME is not set".to_string())?;
    let directory = Path::new(&home)
        .join("Library")
        .join("Application Support")
        .join("Tether");
    std::fs::create_dir_all(&directory)
        .map_err(|error| format!("cannot create Tether support directory: {error}"))?;
    Ok(directory.join("tether-cache.sqlite"))
}

fn events_ready() -> bool {
    request("GET", "/api/events/health", "").is_ok()
}

fn port_open() -> bool {
    TcpStream::connect(PROXY_ADDR).is_ok()
}

fn post_event(event: &CaptureEvent) -> Result<(), String> {
    let body =
        serde_json::to_string(event).map_err(|error| format!("cannot encode event: {error}"))?;
    request("POST", "/api/events", &body)
        .map(|_| ())
        .map_err(|error| format!("cannot send capture event: {error}"))
}

fn request(method: &str, path: &str, body: &str) -> Result<String, String> {
    let url = format!("http://{PROXY_ADDR}{path}");
    let client = reqwest::blocking::Client::builder()
        .timeout(Duration::from_secs(2))
        .build()
        .map_err(|error| error.to_string())?;
    let request = match method {
        "GET" => client.get(&url),
        "POST" => client.post(&url).body(body.to_string()),
        _ => return Err(format!("unsupported method {method}")),
    };
    let response = request
        .header("content-type", "application/json")
        .send()
        .map_err(|error| error.to_string())?;
    let status = response.status();
    let text = response.text().unwrap_or_default();
    if status.is_success() {
        Ok(text)
    } else {
        Err(format!("HTTP {status}: {text}"))
    }
}

fn git_output(cwd: &Path, args: &[&str]) -> Result<String, String> {
    let output = Command::new("git")
        .args(args)
        .current_dir(cwd)
        .output()
        .map_err(|error| error.to_string())?;
    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout)
            .trim_end()
            .to_string())
    } else {
        Err(String::from_utf8_lossy(&output.stderr)
            .trim_end()
            .to_string())
    }
}

fn shell_join(args: &[String]) -> String {
    args.iter()
        .map(|arg| {
            if arg
                .bytes()
                .all(|byte| byte.is_ascii_alphanumeric() || b"-_./:=+".contains(&byte))
            {
                arg.clone()
            } else {
                format!("'{}'", arg.replace('\'', "'\\''"))
            }
        })
        .collect::<Vec<_>>()
        .join(" ")
}

fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64
}
