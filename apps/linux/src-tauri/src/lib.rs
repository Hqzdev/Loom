mod proxy_paths;
mod proxy_process;
mod proxy_request;
mod workspace_snapshot;

use proxy_process::{proxy_health, start_proxy, stop_proxy, ProxyProcessState};
use proxy_request::proxy_request;
use workspace_snapshot::workspace_snapshot;

pub fn run() {
    tauri::Builder::default()
        .manage(ProxyProcessState::default())
        .invoke_handler(tauri::generate_handler![
            proxy_health,
            start_proxy,
            stop_proxy,
            proxy_request,
            workspace_snapshot
        ])
        .run(tauri::generate_context!())
        .expect("failed to run Tether Linux app");
}
