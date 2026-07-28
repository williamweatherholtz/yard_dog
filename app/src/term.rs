//! Interactive terminal sessions backed by a real pseudo-terminal (PTY).
//!
//! Each session spawns a command (an interactive `docker compose exec … sh`, or a
//! streaming `docker compose logs -f`) attached to a PTY, so full-screen TTY apps
//! (top, vi) and live log follow both work. Output is buffered and drained by a
//! long-poll read; input and resize are ordinary requests. This keeps the whole
//! thing on the existing request/response server — no websockets.
//!
//! Lifecycle is bounded so an abandoned browser tab can't leak forever: the output
//! buffer is capped (drop-oldest), the number of concurrent sessions is capped, and
//! a background sweeper closes sessions that have not been read from recently
//! (killing AND reaping the child). Locks are poison-resilient so one panicking
//! session thread cannot cascade into the server.

use portable_pty::{native_pty_system, CommandBuilder, MasterPty, PtySize};
use std::collections::HashMap;
use std::io::{self, Read, Write};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Condvar, Mutex, MutexGuard, OnceLock};
use std::time::{Duration, Instant};

/// Cap on buffered-but-undrained output per session (drop-oldest beyond this).
const MAX_BUFFER: usize = 256 * 1024;
/// Cap on concurrent sessions (a crude anti-exhaustion bound).
const MAX_SESSIONS: usize = 24;
/// Sessions not read from for this long are swept closed.
const IDLE_TIMEOUT: Duration = Duration::from_secs(300);

struct Session {
    writer: Mutex<Box<dyn Write + Send>>,
    master: Mutex<Box<dyn MasterPty + Send>>,
    child: Mutex<Box<dyn portable_pty::Child + Send + Sync>>,
    out: Mutex<Vec<u8>>,
    cv: Condvar,
    alive: AtomicBool,
    last_touch: Mutex<Instant>,
}

/// Lock a mutex, recovering the guard even if a holder panicked (no cascade).
fn lock<T>(m: &Mutex<T>) -> MutexGuard<'_, T> {
    m.lock().unwrap_or_else(|e| e.into_inner())
}

fn registry() -> &'static Mutex<HashMap<String, Arc<Session>>> {
    static R: OnceLock<Mutex<HashMap<String, Arc<Session>>>> = OnceLock::new();
    R.get_or_init(|| Mutex::new(HashMap::new()))
}

fn next_id() -> String {
    static N: AtomicU64 = AtomicU64::new(1);
    format!("t{}", N.fetch_add(1, Ordering::SeqCst))
}

fn oops<E: std::fmt::Display>(e: E) -> io::Error {
    io::Error::new(io::ErrorKind::Other, e.to_string())
}

/// Resolve a bare program name to a full path via PATH (and PATHEXT on Windows).
/// portable-pty's CommandBuilder does not do PATHEXT resolution, so on Windows a
/// bare `docker` fails to spawn (error 193) without this.
fn resolve_program(name: &str) -> String {
    let p = std::path::Path::new(name);
    if p.is_absolute() || name.contains('/') || name.contains('\\') {
        return name.to_string();
    }
    let path_var = std::env::var_os("PATH").unwrap_or_default();
    let exts: Vec<String> = if cfg!(windows) {
        let mut e: Vec<String> = std::env::var("PATHEXT")
            .unwrap_or_else(|_| ".EXE;.CMD;.BAT".into())
            .split(';')
            .filter(|s| !s.is_empty())
            .map(str::to_string)
            .collect();
        e.push(String::new());
        e
    } else {
        vec![String::new()]
    };
    for dir in std::env::split_paths(&path_var) {
        for ext in &exts {
            let cand = dir.join(format!("{name}{ext}"));
            if cand.is_file() {
                return cand.to_string_lossy().into_owned();
            }
        }
    }
    name.to_string()
}

/// Background sweeper: every 30s, close sessions idle past IDLE_TIMEOUT. Started
/// once, on the first `open`.
fn ensure_sweeper() {
    static STARTED: OnceLock<()> = OnceLock::new();
    STARTED.get_or_init(|| {
        std::thread::spawn(|| loop {
            std::thread::sleep(Duration::from_secs(30));
            let stale: Vec<String> = {
                let reg = lock(registry());
                reg.iter()
                    .filter(|(_, s)| lock(&s.last_touch).elapsed() > IDLE_TIMEOUT)
                    .map(|(id, _)| id.clone())
                    .collect()
            };
            for id in stale {
                close(&id);
            }
        });
    });
}

/// Open a PTY session running `argv`. Returns an opaque session id.
pub fn open(argv: &[String], rows: u16, cols: u16) -> io::Result<String> {
    if argv.is_empty() {
        return Err(io::Error::new(io::ErrorKind::InvalidInput, "empty command"));
    }
    ensure_sweeper();
    if lock(registry()).len() >= MAX_SESSIONS {
        return Err(io::Error::new(
            io::ErrorKind::Other,
            "too many terminal sessions open — close one and retry",
        ));
    }
    let pair = native_pty_system()
        .openpty(PtySize { rows, cols, pixel_width: 0, pixel_height: 0 })
        .map_err(oops)?;
    let mut cmd = CommandBuilder::new(resolve_program(&argv[0]));
    for a in &argv[1..] {
        cmd.arg(a);
    }
    cmd.env("TERM", "xterm-256color");
    let child = pair.slave.spawn_command(cmd).map_err(oops)?;
    drop(pair.slave); // parent closes its handle to the slave

    let mut reader = pair.master.try_clone_reader().map_err(oops)?;
    let writer = pair.master.take_writer().map_err(oops)?;

    let sess = Arc::new(Session {
        writer: Mutex::new(writer),
        master: Mutex::new(pair.master),
        child: Mutex::new(child),
        out: Mutex::new(Vec::new()),
        cv: Condvar::new(),
        alive: AtomicBool::new(true),
        last_touch: Mutex::new(Instant::now()),
    });
    let id = next_id();
    lock(registry()).insert(id.clone(), sess.clone());

    // Reader thread: pump PTY output into the session buffer (capped), waking pollers.
    std::thread::spawn(move || {
        let mut buf = [0u8; 8192];
        loop {
            match reader.read(&mut buf) {
                Ok(0) => break,
                Ok(n) => {
                    {
                        let mut out = lock(&sess.out);
                        out.extend_from_slice(&buf[..n]);
                        if out.len() > MAX_BUFFER {
                            // Drop oldest so an un-polled session can't grow without bound.
                            let drop = out.len() - MAX_BUFFER;
                            out.drain(0..drop);
                        }
                    }
                    sess.cv.notify_all();
                }
                Err(_) => break,
            }
        }
        sess.alive.store(false, Ordering::SeqCst);
        sess.cv.notify_all();
    });
    Ok(id)
}

/// Drain any buffered output, blocking up to `timeout_ms` for the first bytes.
/// Returns `(bytes, alive)`; `None` if the session id is unknown.
pub fn read(id: &str, timeout_ms: u64) -> Option<(Vec<u8>, bool)> {
    let sess = lock(registry()).get(id)?.clone();
    *lock(&sess.last_touch) = Instant::now();
    let mut out = lock(&sess.out);
    if out.is_empty() && sess.alive.load(Ordering::SeqCst) {
        let (g, _) = sess
            .cv
            .wait_timeout(out, Duration::from_millis(timeout_ms))
            .unwrap_or_else(|e| e.into_inner());
        out = g;
    }
    let data = std::mem::take(&mut *out);
    Some((data, sess.alive.load(Ordering::SeqCst)))
}

/// Write bytes (keystrokes) to the session's PTY.
pub fn write(id: &str, data: &[u8]) -> io::Result<()> {
    let sess = lock(registry())
        .get(id)
        .cloned()
        .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, "no such session"))?;
    *lock(&sess.last_touch) = Instant::now();
    let mut w = lock(&sess.writer);
    w.write_all(data)?;
    w.flush()
}

/// Resize the session's PTY (SIGWINCH).
pub fn resize(id: &str, rows: u16, cols: u16) -> io::Result<()> {
    let sess = lock(registry())
        .get(id)
        .cloned()
        .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, "no such session"))?;
    let master = lock(&sess.master);
    let r = master.resize(PtySize { rows, cols, pixel_width: 0, pixel_height: 0 });
    r.map_err(oops)
}

/// Kill, reap, and forget a session. The kill+reap runs on a detached thread so a
/// slow `wait()` can never stall the caller — notably the single sweeper thread,
/// which would otherwise stop reaping every other abandoned session. Reaping
/// (`wait`) avoids a `<defunct>` zombie on Unix (portable-pty's child is a plain
/// std Child).
pub fn close(id: &str) {
    if let Some(sess) = lock(registry()).remove(id) {
        sess.alive.store(false, Ordering::SeqCst);
        sess.cv.notify_all();
        std::thread::spawn(move || {
            let mut child = lock(&sess.child);
            let _ = child.kill();
            let _ = child.wait();
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // A trivial cross-platform command exercises the PTY plumbing without Docker.
    fn echo_argv() -> Vec<String> {
        if cfg!(windows) {
            vec!["cmd".into(), "/C".into(), "echo hello-pty".into()]
        } else {
            vec!["/bin/sh".into(), "-c".into(), "echo hello-pty".into()]
        }
    }

    #[test]
    fn open_read_streams_output_then_ends() {
        let id = open(&echo_argv(), 24, 80).expect("open pty");
        let mut got = Vec::new();
        for _ in 0..50 {
            let (data, alive) = read(&id, 200).expect("session exists");
            got.extend_from_slice(&data);
            if !alive && data.is_empty() {
                break;
            }
        }
        let text = String::from_utf8_lossy(&got);
        assert!(text.contains("hello-pty"), "pty output was: {text:?}");
        close(&id);
        assert!(read(&id, 10).is_none(), "closed session is gone from the registry");
    }

    #[test]
    fn read_unknown_session_is_none() {
        assert!(read("nope", 10).is_none());
        assert!(write("nope", b"x").is_err());
    }
}
