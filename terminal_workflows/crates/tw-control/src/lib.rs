//! External control over a Unix socket. Any client (Neovim, a Ghostty
//! keybind running a script, `nc -U`) connects, writes one JSON
//! [`HostCommand`] per line, and gets one `{"type":"ok"}` or
//! `{"type":"error","message":..}` line back per command. The same enum the
//! plugins use, so the app has nothing new to dispatch.

use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::{Path, PathBuf};
use std::thread;

use futures::channel::mpsc::{self, UnboundedReceiver, UnboundedSender};
use tw_scripting::HostCommand;

/// What arrives from the socket on the UI thread.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ControlEvent {
    Command(HostCommand),
    /// A client sent a line that is not a `HostCommand`; it was answered with an error.
    BadLine { line: String, error: String },
}

#[derive(Debug, thiserror::Error)]
pub enum ControlError {
    #[error("another terminal_workflows is already listening on {0}")]
    AlreadyRunning(PathBuf),
    #[error("bind {path}: {source}")]
    Bind { path: PathBuf, source: std::io::Error },
}

/// The listening socket. Dropping it removes the socket file.
pub struct ControlServer {
    path: PathBuf,
}

impl ControlServer {
    /// `TW_SOCKET`, else `$TMPDIR/terminal_workflows.sock`, else `/tmp/...`.
    /// Neovim and Ghostty inherit the same `TMPDIR` in a login session.
    pub fn default_path() -> PathBuf {
        if let Some(explicit) = std::env::var_os("TW_SOCKET") {
            return PathBuf::from(explicit);
        }
        let tmp = std::env::var_os("TMPDIR").map(PathBuf::from).unwrap_or_else(|| PathBuf::from("/tmp"));
        tmp.join("terminal_workflows.sock")
    }

    pub fn bind(path: PathBuf) -> Result<(Self, UnboundedReceiver<ControlEvent>), ControlError> {
        if path.exists() {
            // A leftover file from a crashed run is fine to replace; a live one is not.
            if UnixStream::connect(&path).is_ok() {
                return Err(ControlError::AlreadyRunning(path));
            }
            let _ = std::fs::remove_file(&path);
        }
        let listener = UnixListener::bind(&path).map_err(|source| ControlError::Bind { path: path.clone(), source })?;
        let (tx, rx) = mpsc::unbounded();
        thread::Builder::new()
            .name("control-accept".to_owned())
            .spawn(move || accept_loop(listener, tx))
            .map_err(|source| ControlError::Bind { path: path.clone(), source })?;
        log::info!("control socket: {}", path.display());
        Ok((Self { path }, rx))
    }

    pub fn path(&self) -> &Path {
        &self.path
    }
}

impl Drop for ControlServer {
    fn drop(&mut self) {
        let _ = std::fs::remove_file(&self.path);
    }
}

fn accept_loop(listener: UnixListener, tx: UnboundedSender<ControlEvent>) {
    for stream in listener.incoming() {
        let Ok(stream) = stream else { continue };
        let tx = tx.clone();
        if thread::Builder::new().name("control-client".to_owned()).spawn(move || serve_client(stream, tx)).is_err() {
            log::warn!("control: could not start a client thread");
        }
    }
}

fn serve_client(stream: UnixStream, tx: UnboundedSender<ControlEvent>) {
    let Ok(mut writer) = stream.try_clone() else { return };
    for line in BufReader::new(stream).lines().map_while(Result::ok) {
        if line.trim().is_empty() {
            continue;
        }
        let (event, reply) = match serde_json::from_str::<HostCommand>(&line) {
            Ok(command) => (ControlEvent::Command(command), "{\"type\":\"ok\"}\n".to_owned()),
            Err(error) => {
                let reply = serde_json::json!({ "type": "error", "message": error.to_string() }).to_string() + "\n";
                (ControlEvent::BadLine { line, error: error.to_string() }, reply)
            }
        };
        if tx.unbounded_send(event).is_err() {
            return;
        }
        // The client may hang up before reading the reply; that is not an error worth logging.
        let _ = writer.write_all(reply.as_bytes());
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use futures::StreamExt;

    fn temp_socket(name: &str) -> PathBuf {
        std::env::temp_dir().join(format!("tw-control-{name}-{}.sock", std::process::id()))
    }

    #[test]
    fn should_turn_json_lines_into_commands_and_ack_them() {
        let path = temp_socket("ok");
        let (server, mut events) = ControlServer::bind(path.clone()).unwrap();

        let mut client = UnixStream::connect(&path).unwrap();
        client
            .write_all(b"{\"type\":\"showMarkdown\",\"title\":\"K\",\"markdown\":\"# hi\"}\n{\"type\":\"newTab\"}\nnot json\n")
            .unwrap();
        let mut replies = BufReader::new(client.try_clone().unwrap()).lines();

        let first = futures::executor::block_on(events.next()).unwrap();
        assert_eq!(
            first,
            ControlEvent::Command(HostCommand::ShowMarkdown { title: Some("K".into()), markdown: "# hi".into() })
        );
        assert_eq!(replies.next().unwrap().unwrap(), r#"{"type":"ok"}"#);
        assert_eq!(futures::executor::block_on(events.next()).unwrap(), ControlEvent::Command(HostCommand::NewTab));
        assert_eq!(replies.next().unwrap().unwrap(), r#"{"type":"ok"}"#);
        assert!(matches!(futures::executor::block_on(events.next()).unwrap(), ControlEvent::BadLine { .. }));
        // Key order depends on whether some crate in the build enabled serde_json's
        // `preserve_order`, so compare the parsed value, not the text.
        let reply: serde_json::Value = serde_json::from_str(&replies.next().unwrap().unwrap()).unwrap();
        assert_eq!(reply["type"], "error");
        assert!(!reply["message"].as_str().unwrap().is_empty(), "the parse error is passed on");

        drop(server);
        assert!(!path.exists(), "the socket file is removed on drop");
    }

    #[test]
    fn should_refuse_to_bind_when_another_instance_is_listening() {
        let path = temp_socket("busy");
        let (_server, _events) = ControlServer::bind(path.clone()).unwrap();
        assert!(matches!(ControlServer::bind(path), Err(ControlError::AlreadyRunning(_))));
    }
}
