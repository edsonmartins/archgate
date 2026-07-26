//! Embedded interactive sessions via local PTY (SSH, psql, mysql, …).
//! Auth (password/agent/key) is interactive in the terminal — no secret storage here.

use portable_pty::{native_pty_system, CommandBuilder, MasterPty, PtySize};
use serde::Serialize;
use std::collections::HashMap;
use std::io::{Read, Write};
use std::path::PathBuf;
use std::sync::Mutex;
use std::thread;
use tauri::{AppHandle, Emitter, State};

/// Resolve a client binary for GUI apps (Homebrew paths not always on PATH).
fn resolve_program(program: &str) -> String {
    if program.contains('/') {
        return program.to_string();
    }
    let candidates: &[&str] = match program {
        "mysql" => &[
            "/opt/homebrew/opt/mysql-client/bin/mysql",
            "/opt/homebrew/bin/mysql",
            "/usr/local/opt/mysql-client/bin/mysql",
            "/usr/local/bin/mysql",
            "/usr/bin/mysql",
        ],
        "mariadb" => &[
            "/opt/homebrew/bin/mariadb",
            "/usr/local/bin/mariadb",
            "/usr/bin/mariadb",
        ],
        "psql" => &[
            "/opt/homebrew/opt/libpq/bin/psql",
            "/opt/homebrew/bin/psql",
            "/usr/local/opt/libpq/bin/psql",
            "/usr/local/bin/psql",
            "/usr/bin/psql",
        ],
        "ssh" => &["/usr/bin/ssh", "/opt/homebrew/bin/ssh"],
        _ => &[],
    };
    for c in candidates {
        if PathBuf::from(c).is_file() {
            return (*c).to_string();
        }
    }
    // Fall back to bare name (PATH / later env PATH enrichment).
    program.to_string()
}

pub struct SshSessions {
    inner: Mutex<HashMap<String, LiveSession>>,
}

struct LiveSession {
    master: Box<dyn MasterPty + Send>,
    writer: Box<dyn Write + Send>,
    child: Box<dyn portable_pty::Child + Send + Sync>,
}

impl Default for SshSessions {
    fn default() -> Self {
        Self {
            inner: Mutex::new(HashMap::new()),
        }
    }
}

#[derive(Clone, Serialize)]
struct SshDataEvent {
    session_id: String,
    data: String,
}

#[derive(Clone, Serialize)]
struct SshExitEvent {
    session_id: String,
    code: Option<u32>,
}

fn spawn_pty(
    app: AppHandle,
    sessions: &SshSessions,
    session_id: String,
    program: &str,
    args: &[String],
    cols: u16,
    rows: u16,
) -> Result<(), String> {
    if session_id.is_empty() || program.is_empty() {
        return Err("session_id e program são obrigatórios".into());
    }
    // Refuse shell metacharacters in program/args (bastion-only commands).
    for a in std::iter::once(program).chain(args.iter().map(String::as_str)) {
        if a.contains('\n') || a.contains('\0') {
            return Err("argumento inválido".into());
        }
    }

    let mut map = sessions.inner.lock().map_err(|e| e.to_string())?;
    if map.contains_key(&session_id) {
        return Err("sessão já aberta".into());
    }

    let pty_system = native_pty_system();
    let pair = pty_system
        .openpty(PtySize {
            rows: rows.max(8),
            cols: cols.max(20),
            pixel_width: 0,
            pixel_height: 0,
        })
        .map_err(|e| format!("PTY: {e}"))?;

    // Prefer resolved path so GUI apps find Homebrew clients (mysql/psql/ssh).
    let program_path = resolve_program(program);
    let mut cmd = CommandBuilder::new(&program_path);
    // Ensure Homebrew paths for nested lookups (macOS GUI has minimal PATH).
    if let Ok(path) = std::env::var("PATH") {
        let extra = "/opt/homebrew/bin:/opt/homebrew/opt/mysql-client/bin:/opt/homebrew/opt/libpq/bin:/usr/local/bin";
        if !path.contains("mysql-client") {
            cmd.env("PATH", format!("{extra}:{path}"));
        }
    } else {
        cmd.env(
            "PATH",
            "/opt/homebrew/bin:/opt/homebrew/opt/mysql-client/bin:/opt/homebrew/opt/libpq/bin:/usr/local/bin:/usr/bin:/bin",
        );
    }
    // Warpgate MySQL uses mysql_clear_password; some clients need this env as well.
    if program == "mysql" || program == "mariadb" {
        cmd.env("LIBMYSQL_ENABLE_CLEARTEXT_PLUGIN", "1");
    }
    for a in args {
        cmd.arg(a);
    }

    let child = pair
        .slave
        .spawn_command(cmd)
        .map_err(|e| format!("{program} spawn ({program_path}): {e}"))?;
    drop(pair.slave);

    let mut reader = pair
        .master
        .try_clone_reader()
        .map_err(|e| format!("PTY reader: {e}"))?;
    let writer = pair
        .master
        .take_writer()
        .map_err(|e| format!("PTY writer: {e}"))?;

    let sid = session_id.clone();
    let app_read = app.clone();
    thread::spawn(move || {
        let mut buf = [0u8; 4096];
        loop {
            match reader.read(&mut buf) {
                Ok(0) => break,
                Ok(n) => {
                    let data = String::from_utf8_lossy(&buf[..n]).to_string();
                    let _ = app_read.emit(
                        "ssh-session-data",
                        SshDataEvent {
                            session_id: sid.clone(),
                            data,
                        },
                    );
                }
                Err(_) => break,
            }
        }
        let _ = app_read.emit(
            "ssh-session-exit",
            SshExitEvent {
                session_id: sid,
                code: None,
            },
        );
    });

    map.insert(
        session_id,
        LiveSession {
            master: pair.master,
            writer,
            child,
        },
    );
    Ok(())
}

/// Open an interactive SSH session to host:port as user (Warpgate: operator:target@bastion).
#[tauri::command]
pub fn ssh_session_open(
    app: AppHandle,
    sessions: State<'_, SshSessions>,
    session_id: String,
    host: String,
    port: u16,
    user: String,
    cols: u16,
    rows: u16,
) -> Result<(), String> {
    if host.is_empty() || user.is_empty() {
        return Err("host e user são obrigatórios".into());
    }
    if host.contains(' ') || host.contains('\n') || user.contains(' ') {
        return Err("host/user inválidos".into());
    }
    let args = vec![
        "-tt".into(),
        "-p".into(),
        port.to_string(),
        "-o".into(),
        "StrictHostKeyChecking=accept-new".into(),
        "-o".into(),
        "PreferredAuthentications=publickey,keyboard-interactive,password".into(),
        format!("{user}@{host}"),
    ];
    spawn_pty(app, &sessions, session_id, "ssh", &args, cols, rows)
}

/// Generic PTY (e.g. psql against Warpgate PG proxy).
#[tauri::command]
pub fn pty_session_open(
    app: AppHandle,
    sessions: State<'_, SshSessions>,
    session_id: String,
    program: String,
    args: Vec<String>,
    cols: u16,
    rows: u16,
) -> Result<(), String> {
    // Allow-list client programs (bastion clients only).
    match program.as_str() {
        "ssh" | "psql" | "mysql" | "mariadb" => {}
        _ => return Err(format!("program not allowed: {program}")),
    }
    spawn_pty(app, &sessions, session_id, &program, &args, cols, rows)
}

#[tauri::command]
pub fn ssh_session_write(
    sessions: State<'_, SshSessions>,
    session_id: String,
    data: String,
) -> Result<(), String> {
    let mut map = sessions.inner.lock().map_err(|e| e.to_string())?;
    let sess = map
        .get_mut(&session_id)
        .ok_or_else(|| "sessão SSH não encontrada".to_string())?;
    sess.writer
        .write_all(data.as_bytes())
        .map_err(|e| format!("write: {e}"))?;
    sess.writer.flush().map_err(|e| format!("flush: {e}"))?;
    Ok(())
}

#[tauri::command]
pub fn ssh_session_resize(
    sessions: State<'_, SshSessions>,
    session_id: String,
    cols: u16,
    rows: u16,
) -> Result<(), String> {
    let map = sessions.inner.lock().map_err(|e| e.to_string())?;
    let sess = map
        .get(&session_id)
        .ok_or_else(|| "sessão SSH não encontrada".to_string())?;
    sess.master
        .resize(PtySize {
            rows: rows.max(8),
            cols: cols.max(20),
            pixel_width: 0,
            pixel_height: 0,
        })
        .map_err(|e| format!("resize: {e}"))?;
    Ok(())
}

#[tauri::command]
pub fn ssh_session_close(
    sessions: State<'_, SshSessions>,
    session_id: String,
) -> Result<(), String> {
    let mut map = sessions.inner.lock().map_err(|e| e.to_string())?;
    if let Some(mut sess) = map.remove(&session_id) {
        let _ = sess.child.kill();
        let _ = sess.child.wait();
    }
    Ok(())
}
