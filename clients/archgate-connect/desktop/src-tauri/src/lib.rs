use serde::Serialize;
use std::process::Command;
use tauri::{
    menu::{Menu, MenuItem, PredefinedMenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    Manager, WindowEvent,
};

/// Structured result from the bundled archgate CLI.
#[derive(Debug, Clone, Serialize)]
pub struct RunResult {
    pub code: i32,
    pub stdout: String,
    pub stderr: String,
}

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

fn archgate_bin(app: &tauri::AppHandle) -> Option<std::path::PathBuf> {
    sibling_archgate(app).or_else(which_archgate)
}

/// Run bundled archgate CLI. Identity/bastion resolved only by the CLI.
#[tauri::command]
fn run_cli(app: tauri::AppHandle, args: Vec<String>) -> Result<RunResult, String> {
    let bin = archgate_bin(&app).ok_or_else(|| "binário archgate não encontrado".to_string())?;

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

fn show_main(app: &tauri::AppHandle) {
    if let Some(w) = app.get_webview_window("main") {
        let _ = w.show();
        let _ = w.unminimize();
        let _ = w.set_focus();
    }
}

fn run_status_notify(app: &tauri::AppHandle) {
    let Some(bin) = archgate_bin(app) else {
        eprintln!("archgate: binary not found for tray status");
        return;
    };
    let out = Command::new(&bin)
        .args(["status", "--json"])
        .env("ARCHGATE_MOCK", "0")
        .output();
    match out {
        Ok(o) => {
            let stdout = String::from_utf8_lossy(&o.stdout);
            // Compact one-line summary for logs; UI shows full status on open.
            if let Ok(v) = serde_json::from_str::<serde_json::Value>(&stdout) {
                let session = v.get("session").and_then(|x| x.as_bool()).unwrap_or(false);
                let user = v
                    .get("user")
                    .and_then(|x| x.as_str())
                    .unwrap_or("—");
                let auth = v.get("auth").and_then(|x| x.as_str()).unwrap_or("—");
                let n = v
                    .get("connections")
                    .and_then(|x| x.as_u64())
                    .unwrap_or(0);
                eprintln!(
                    "archgate tray status: session={session} user={user} auth={auth} connections={n}"
                );
            } else {
                eprintln!("archgate tray status raw: {}", stdout.trim());
            }
        }
        Err(e) => eprintln!("archgate tray status error: {e}"),
    }
    show_main(app);
}

fn setup_tray(app: &tauri::App) -> Result<(), Box<dyn std::error::Error>> {
    let show_i = MenuItem::with_id(app, "show", "Abrir Connect", true, None::<&str>)?;
    let status_i = MenuItem::with_id(app, "status", "Atualizar status…", true, None::<&str>)?;
    let sep = PredefinedMenuItem::separator(app)?;
    let quit_i = MenuItem::with_id(app, "quit", "Sair", true, None::<&str>)?;
    let menu = Menu::with_items(app, &[&show_i, &status_i, &sep, &quit_i])?;

    let icon = app
        .default_window_icon()
        .cloned()
        .ok_or("default window icon missing (check tauri.conf icons)")?;

    let _tray = TrayIconBuilder::with_id("main-tray")
        .icon(icon)
        .menu(&menu)
        .tooltip("ArchGate Connect — bastion, not VPN")
        .show_menu_on_left_click(false)
        .on_menu_event(|app, event| match event.id.as_ref() {
            "show" => show_main(app),
            "status" => run_status_notify(app),
            "quit" => {
                app.exit(0);
            }
            _ => {}
        })
        .on_tray_icon_event(|tray, event| {
            if let TrayIconEvent::Click {
                button: MouseButton::Left,
                button_state: MouseButtonState::Up,
                ..
            } = event
            {
                show_main(tray.app_handle());
            }
        })
        .build(app)?;

    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![run_cli])
        .setup(|app| {
            setup_tray(app)?;
            Ok(())
        })
        .on_window_event(|window, event| {
            // Close → hide to tray (macOS menu bar remains).
            if let WindowEvent::CloseRequested { api, .. } = event {
                let _ = window.hide();
                api.prevent_close();
            }
        })
        .run(tauri::generate_context!())
        .expect("error while running ArchGate Connect");
}
