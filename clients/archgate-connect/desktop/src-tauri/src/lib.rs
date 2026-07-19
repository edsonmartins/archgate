use serde::Serialize;
use std::process::Command;
use tauri::Manager;

/// Structured result from the bundled archgate CLI.
/// Always returned (including non-zero exit) so the UI can show stdout/stderr.
#[derive(Debug, Clone, Serialize)]
pub struct RunResult {
    pub code: i32,
    pub stdout: String,
    pub stderr: String,
}

/// Path to sibling CLI binary Contents/MacOS/archgate (Tauri externalBin).
fn sibling_archgate(app: &tauri::AppHandle) -> Option<std::path::PathBuf> {
    let exe = app.path().executable_dir().ok()?;
    let p = exe.join("archgate");
    if p.is_file() {
        Some(p)
    } else {
        None
    }
}

fn which_archgate() -> Option<std::path::PathBuf> {
    let path = std::env::var_os("PATH")?;
    for dir in std::env::split_paths(&path) {
        let p = dir.join("archgate");
        if p.is_file() {
            return Some(p);
        }
    }
    None
}

/// Run bundled archgate CLI. Identity and bastion come only from the CLI/config —
/// this wrapper does not hardcode Warpgate user/host.
#[tauri::command]
fn run_cli(app: tauri::AppHandle, args: Vec<String>) -> Result<RunResult, String> {
    let bin = sibling_archgate(&app)
        .or_else(which_archgate)
        .ok_or_else(|| "binário archgate não encontrado".to_string())?;

    let out = Command::new(&bin)
        .args(&args)
        .env("ARCHGATE_MOCK", "0")
        .output()
        .map_err(|e| format!("exec {:?}: {e}", bin))?;

    let code = out.status.code().unwrap_or(1);
    Ok(RunResult {
        code,
        stdout: String::from_utf8_lossy(&out.stdout).to_string(),
        stderr: String::from_utf8_lossy(&out.stderr).to_string(),
    })
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![run_cli])
        .run(tauri::generate_context!())
        .expect("error while running ArchGate Connect");
}
