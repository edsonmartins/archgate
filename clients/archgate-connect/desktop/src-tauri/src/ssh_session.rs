//! Embedded SSH sessions via local PTY + system `ssh` client.
//! Auth (password/agent/key) is interactive in the terminal — no secret storage here.

use portable_pty::{native_pty_system, CommandBuilder, MasterPty, PtySize};
use serde::Serialize;
use std::collections::HashMap;
use std::io::{Read, Write};
use std::sync::Mutex;
use std::thread;
use tauri::{AppHandle, Emitter, State};

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
    if session_id.is_empty() || host.is_empty() || user.is_empty() {
        return Err("session_id, host e user são obrigatórios".into());
    }
    // Bastion-only guard: refuse empty/odd hosts; identity comes from print-ssh.
    if host.contains(' ') || host.contains('\n') || user.contains(' ') {
        return Err("host/user inválidos".into());
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

    let mut cmd = CommandBuilder::new("ssh");
    cmd.arg("-tt");
    cmd.arg("-p");
    cmd.arg(port.to_string());
    cmd.arg("-o");
    cmd.arg("StrictHostKeyChecking=accept-new");
    cmd.arg("-o");
    cmd.arg("PreferredAuthentications=publickey,keyboard-interactive,password");
    cmd.arg(format!("{user}@{host}"));

    let child = pair
        .slave
        .spawn_command(cmd)
        .map_err(|e| format!("ssh spawn: {e}"))?;
    // Drop slave so the master is the only end (child holds its fd).
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
