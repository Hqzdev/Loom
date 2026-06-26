use std::env;
use std::fs;
use std::path::PathBuf;

use tauri::{AppHandle, Manager};

pub struct RuntimePaths {
    pub database_path: PathBuf,
    pub log_path: PathBuf,
}

pub fn find_proxy_binary(app: &AppHandle) -> Result<PathBuf, String> {
    if let Ok(path) = env::var("TETHER_PROXY_BINARY") {
        let candidate = PathBuf::from(path);
        if candidate.is_file() {
            return Ok(candidate);
        }
    }

    proxy_binary_candidates(app)
        .into_iter()
        .find(|candidate| candidate.is_file())
        .ok_or_else(|| "cannot find tether-proxy binary; build core/proxy first".to_string())
}

pub fn runtime_paths() -> Result<RuntimePaths, String> {
    let data = app_data_dir()?;
    let logs = app_log_dir()?;
    fs::create_dir_all(&data).map_err(|error| error.to_string())?;
    fs::create_dir_all(&logs).map_err(|error| error.to_string())?;
    Ok(RuntimePaths {
        database_path: data.join("tether-cache.sqlite"),
        log_path: logs.join("proxy.log"),
    })
}

pub fn upstream(name: &str, fallback: &str) -> String {
    env::var(name).unwrap_or_else(|_| fallback.to_string())
}

fn proxy_binary_candidates(app: &AppHandle) -> Vec<PathBuf> {
    let mut candidates = Vec::new();
    if let Ok(resource_dir) = app.path().resource_dir() {
        candidates.extend(resource_candidates(resource_dir));
    }
    if let Some(repo_root) = repo_root() {
        candidates.push(repo_root.join("core/proxy/target/debug/tether-proxy"));
        candidates.push(repo_root.join("core/proxy/target/release/tether-proxy"));
    }
    if let Ok(current_exe) = env::current_exe() {
        if let Some(directory) = current_exe.parent() {
            candidates.push(directory.join("tether-proxy"));
            candidates.push(directory.join("../Resources/tether-proxy"));
        }
    }
    candidates
}

fn resource_candidates(resource_dir: PathBuf) -> Vec<PathBuf> {
    vec![
        resource_dir.join("tether-proxy"),
        resource_dir.join("tether-proxy-x86_64-unknown-linux-gnu"),
        resource_dir.join("binaries/tether-proxy"),
        resource_dir.join("binaries/tether-proxy-x86_64-unknown-linux-gnu"),
    ]
}

fn repo_root() -> Option<PathBuf> {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .and_then(|path| path.parent())
        .and_then(|path| path.parent())
        .map(PathBuf::from)
}

fn app_data_dir() -> Result<PathBuf, String> {
    let home = home_dir()?;
    #[cfg(target_os = "linux")]
    {
        Ok(env::var_os("XDG_DATA_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| home.join(".local/share"))
            .join("Tether"))
    }
    #[cfg(target_os = "macos")]
    {
        Ok(home.join("Library/Application Support/Tether"))
    }
    #[cfg(not(any(target_os = "linux", target_os = "macos")))]
    {
        Ok(home.join(".tether"))
    }
}

fn app_log_dir() -> Result<PathBuf, String> {
    let home = home_dir()?;
    #[cfg(target_os = "linux")]
    {
        Ok(env::var_os("XDG_CACHE_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| home.join(".cache"))
            .join("Tether"))
    }
    #[cfg(target_os = "macos")]
    {
        Ok(home.join("Library/Caches/Tether"))
    }
    #[cfg(not(any(target_os = "linux", target_os = "macos")))]
    {
        Ok(home.join(".tether/logs"))
    }
}

fn home_dir() -> Result<PathBuf, String> {
    env::var_os("HOME")
        .map(PathBuf::from)
        .ok_or_else(|| "HOME is not set".to_string())
}
