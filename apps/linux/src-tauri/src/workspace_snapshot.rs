use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
pub struct WorkspaceSnapshotRequest {
    path: String,
}

#[derive(Serialize)]
pub struct WorkspaceSnapshot {
    files: Vec<WorkspaceSnapshotFile>,
}

#[derive(Serialize)]
struct WorkspaceSnapshotFile {
    path: String,
    status: String,
    additions: u32,
    deletions: u32,
    fingerprint: String,
}

#[tauri::command]
pub fn workspace_snapshot(request: WorkspaceSnapshotRequest) -> Result<WorkspaceSnapshot, String> {
    let root = PathBuf::from(request.path);
    if !root.is_dir() {
        return Err("workspace path is not a directory".to_string());
    }

    let statuses = git_statuses(&root)?;
    let stats = git_stats(&root)?;
    let mut paths = statuses.keys().cloned().collect::<Vec<_>>();
    for path in stats.keys() {
        if !paths.contains(path) {
            paths.push(path.clone());
        }
    }
    paths.sort();

    Ok(WorkspaceSnapshot {
        files: paths
            .into_iter()
            .map(|path| snapshot_file(&root, &statuses, &stats, path))
            .collect(),
    })
}

fn snapshot_file(
    root: &Path,
    statuses: &HashMap<String, String>,
    stats: &HashMap<String, (u32, u32)>,
    path: String,
) -> WorkspaceSnapshotFile {
    let status = statuses
        .get(&path)
        .cloned()
        .unwrap_or_else(|| "Modified".to_string());
    let stat = stats
        .get(&path)
        .cloned()
        .unwrap_or_else(|| added_file_stat(root, &path, &status));
    WorkspaceSnapshotFile {
        fingerprint: fingerprint(root, &path),
        path,
        status,
        additions: stat.0,
        deletions: stat.1,
    }
}

fn git_statuses(root: &Path) -> Result<HashMap<String, String>, String> {
    let output = run_git(root, &["status", "--porcelain=v1"])?;
    let mut statuses = HashMap::new();
    for line in output.lines() {
        if line.len() >= 4 {
            statuses.insert(line[3..].to_string(), status_label(&line[0..2]).to_string());
        }
    }
    Ok(statuses)
}

fn git_stats(root: &Path) -> Result<HashMap<String, (u32, u32)>, String> {
    let output = run_git(root, &["diff", "--numstat", "HEAD", "--"])?;
    let mut stats = HashMap::new();
    for line in output.lines() {
        let parts = line.split('\t').collect::<Vec<_>>();
        if parts.len() == 3 {
            stats.insert(
                parts[2].to_string(),
                (parts[0].parse().unwrap_or(0), parts[1].parse().unwrap_or(0)),
            );
        }
    }
    Ok(stats)
}

fn run_git(root: &Path, arguments: &[&str]) -> Result<String, String> {
    let output = Command::new("git")
        .arg("-C")
        .arg(root)
        .args(arguments)
        .output()
        .map_err(|error| error.to_string())?;
    if !output.status.success() {
        return Err(String::from_utf8_lossy(&output.stderr).trim().to_string());
    }
    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}

fn status_label(code: &str) -> &str {
    if code.contains('A') || code.contains('?') {
        return "Added";
    }
    if code.contains('D') {
        return "Deleted";
    }
    if code.contains('R') {
        return "Renamed";
    }
    if code.contains('M') {
        return "Modified";
    }
    "Changed"
}

fn added_file_stat(root: &Path, path: &str, status: &str) -> (u32, u32) {
    if status != "Added" {
        return (0, 0);
    }
    let Ok(text) = fs::read_to_string(root.join(path)) else {
        return (0, 0);
    };
    (text.lines().count() as u32, 0)
}

fn fingerprint(root: &Path, path: &str) -> String {
    let Ok(metadata) = fs::metadata(root.join(path)) else {
        return "missing".to_string();
    };
    let modified = metadata
        .modified()
        .ok()
        .and_then(|time| time.duration_since(std::time::UNIX_EPOCH).ok())
        .map(|duration| duration.as_secs())
        .unwrap_or(0);
    format!("{}:{modified}", metadata.len())
}
