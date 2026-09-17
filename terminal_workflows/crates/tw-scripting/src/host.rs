//! Spawns `plugins/host.ts` under Node and exchanges JSON lines with it.

use std::collections::VecDeque;
use std::io::{BufRead, BufReader, Write};
use std::path::{Path, PathBuf};
use std::process::{Child, ChildStdin, Command, Stdio};
use std::sync::{Arc, Mutex};
use std::thread;

use futures::channel::mpsc::{self, UnboundedReceiver, UnboundedSender};

use crate::protocol::{HostMessage, HostRequest, PluginState};

/// What the reader threads deliver to the UI thread.
#[derive(Clone, Debug, PartialEq)]
pub enum HostEvent {
    Message(HostMessage),
    /// The child is gone; the string is its exit status plus the last stderr lines.
    Exited(String),
}

#[derive(Debug, thiserror::Error)]
pub enum HostError {
    #[error("node not found: set TW_NODE or put `node` (>= 22.18, for type stripping) on PATH")]
    NodeNotFound,
    #[error("start node host in {dir}: {source}")]
    Spawn { dir: PathBuf, source: std::io::Error },
    #[error("write to node host: {0}")]
    Write(#[from] std::io::Error),
    #[error("encode request: {0}")]
    Encode(#[from] serde_json::Error),
}

/// The running `host.ts` process. Requests are fire-and-forget; answers
/// arrive as [`HostEvent`]s tagged with the request id. Dropping it kills Node.
pub struct NodeHost {
    child: Child,
    stdin: ChildStdin,
    next_id: u64,
}

const STDERR_TAIL: usize = 12;

impl NodeHost {
    pub fn spawn(dir: &Path) -> Result<(Self, UnboundedReceiver<HostEvent>), HostError> {
        let node = find_node().ok_or(HostError::NodeNotFound)?;
        let mut child = Command::new(&node)
            .args(["--no-warnings", "--experimental-strip-types", "host.ts"])
            .current_dir(dir)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .map_err(|source| HostError::Spawn { dir: dir.to_path_buf(), source })?;
        log::info!("node host: {} in {}", node.display(), dir.display());

        let stdin = child.stdin.take().expect("stdin was piped");
        let stdout = child.stdout.take().expect("stdout was piped");
        let stderr = child.stderr.take().expect("stderr was piped");
        let (tx, rx) = mpsc::unbounded();
        let tail: Arc<Mutex<VecDeque<String>>> = Arc::default();

        let tail_writer = tail.clone();
        thread::Builder::new()
            .name("node-host-stderr".to_owned())
            .spawn(move || {
                for line in BufReader::new(stderr).lines().map_while(Result::ok) {
                    log::warn!("node host: {line}");
                    let mut tail = tail_writer.lock().unwrap_or_else(|e| e.into_inner());
                    if tail.len() == STDERR_TAIL {
                        tail.pop_front();
                    }
                    tail.push_back(line);
                }
            })?;
        thread::Builder::new()
            .name("node-host-stdout".to_owned())
            .spawn(move || forward_messages(stdout, tx, tail))?;

        Ok((Self { child, stdin, next_id: 1 }, rx))
    }

    /// Ask every plugin for its widget tree; the answer is `Rendered { id, .. }`.
    pub fn render(&mut self, state: &PluginState) -> Result<u64, HostError> {
        let id = self.take_id();
        self.send(&HostRequest::Render { id, state })?;
        Ok(id)
    }

    /// Tell one plugin a button was pressed; the answer is `Actions { id, .. }`.
    pub fn action(&mut self, plugin: &str, action: &str, state: &PluginState) -> Result<u64, HostError> {
        let id = self.take_id();
        self.send(&HostRequest::Action { id, plugin, action, state })?;
        Ok(id)
    }

    /// Re-import every plugin file; the host answers with `Changed`.
    pub fn reload(&mut self) -> Result<(), HostError> {
        self.send(&HostRequest::Reload)
    }

    fn take_id(&mut self) -> u64 {
        let id = self.next_id;
        self.next_id += 1;
        id
    }

    fn send(&mut self, request: &HostRequest<'_>) -> Result<(), HostError> {
        let mut line = serde_json::to_string(request)?;
        line.push('\n');
        self.stdin.write_all(line.as_bytes())?;
        self.stdin.flush()?;
        Ok(())
    }
}

impl Drop for NodeHost {
    fn drop(&mut self) {
        if let Err(e) = self.child.kill() {
            log::debug!("kill node host: {e}");
        }
        let _ = self.child.wait();
    }
}

fn forward_messages(
    stdout: std::process::ChildStdout,
    tx: UnboundedSender<HostEvent>,
    stderr_tail: Arc<Mutex<VecDeque<String>>>,
) {
    for line in BufReader::new(stdout).lines().map_while(Result::ok) {
        if line.trim().is_empty() {
            continue;
        }
        match serde_json::from_str::<HostMessage>(&line) {
            Ok(message) => {
                if tx.unbounded_send(HostEvent::Message(message)).is_err() {
                    return;
                }
            }
            Err(error) => log::warn!("node host sent something that is not a HostMessage: {error}: {line}"),
        }
    }
    let tail = stderr_tail.lock().unwrap_or_else(|e| e.into_inner());
    let reason = if tail.is_empty() {
        "node host exited".to_owned()
    } else {
        format!("node host exited:\n{}", tail.iter().cloned().collect::<Vec<_>>().join("\n"))
    };
    let _ = tx.unbounded_send(HostEvent::Exited(reason));
}

/// `TW_NODE`, then PATH, then the usual version-manager locations. The app
/// may be launched from Finder with a minimal PATH, hence the fallbacks.
fn find_node() -> Option<PathBuf> {
    if let Some(explicit) = std::env::var_os("TW_NODE") {
        return Some(PathBuf::from(explicit));
    }
    let on_path = std::env::var_os("PATH").and_then(|path| {
        std::env::split_paths(&path).map(|dir| dir.join("node")).find(|candidate| candidate.is_file())
    });
    if on_path.is_some() {
        return on_path;
    }
    let home = std::env::var_os("HOME").map(PathBuf::from)?;
    let mut nvm: Vec<PathBuf> = std::fs::read_dir(home.join(".nvm/versions/node"))
        .into_iter()
        .flatten()
        .filter_map(|entry| entry.ok().map(|e| e.path().join("bin/node")))
        .filter(|candidate| candidate.is_file())
        .collect();
    nvm.sort();
    [home.join(".asdf/shims/node"), PathBuf::from("/opt/homebrew/bin/node"), PathBuf::from("/usr/local/bin/node")]
        .into_iter()
        .chain(nvm.into_iter().rev())
        .find(|candidate| candidate.is_file())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::protocol::{HexColor, HostCommand, PluginView, TabInfo, WidgetNode};
    use futures::StreamExt;
    use std::time::Duration;

    /// The real `plugins/` folder next to the workspace, with `host.ts` and `hello.ts`.
    fn plugins_dir() -> PathBuf {
        Path::new(env!("CARGO_MANIFEST_DIR")).join("../../plugins").canonicalize().unwrap()
    }

    fn state() -> PluginState {
        PluginState { active_tab: 0, tabs: vec![TabInfo { id: 1, title: "zsh".into() }] }
    }

    async fn next_message(rx: &mut UnboundedReceiver<HostEvent>) -> HostMessage {
        let timeout = futures::future::FutureExt::fuse(async_timeout(Duration::from_secs(20)));
        futures::pin_mut!(timeout);
        loop {
            futures::select! {
                event = rx.next() => match event.expect("host channel closed") {
                    HostEvent::Message(HostMessage::Log { message }) => eprintln!("plugin log: {message}"),
                    HostEvent::Message(message) => return message,
                    HostEvent::Exited(reason) => panic!("{reason}"),
                },
                () = timeout => panic!("no answer from the node host within 20s"),
            }
        }
    }

    async fn async_timeout(duration: Duration) {
        let (tx, rx) = futures::channel::oneshot::channel::<()>();
        thread::spawn(move || {
            thread::sleep(duration);
            let _ = tx.send(());
        });
        let _ = rx.await;
    }

    #[test]
    fn should_render_hello_ts_and_dispatch_its_actions_through_node() {
        if find_node().is_none() {
            eprintln!("skipping: node not installed");
            return;
        }
        let (mut host, mut rx) = NodeHost::spawn(&plugins_dir()).unwrap();
        futures::executor::block_on(async {
            assert_eq!(next_message(&mut rx).await, HostMessage::Ready { plugins: vec!["hello".into()] });

            let id = host.render(&state()).unwrap();
            let HostMessage::Rendered { id: got, views } = next_message(&mut rx).await else { panic!("expected Rendered") };
            assert_eq!(got, id);
            assert_eq!(views.len(), 1);
            let PluginView::Ok { name, widget } = &views[0] else { panic!("hello.ts failed: {views:?}") };
            assert_eq!(name, "hello");
            let WidgetNode::Column { children, .. } = widget else { panic!("expected a column") };
            assert!(matches!(&children[0], WidgetNode::Text { text, .. } if text.contains("1 tab")));
            assert!(matches!(&children[1], WidgetNode::Text { color: Some(HexColor(0x8a90a0)), .. }));

            let id = host.action("hello", "hi", &state()).unwrap();
            assert_eq!(
                next_message(&mut rx).await,
                HostMessage::Actions { id, commands: vec![HostCommand::WriteToTerminal { text: "echo hi from plugins/hello.ts\n".into() }] }
            );

            let id = host.action("hello", "nope", &state()).unwrap();
            let HostMessage::Actions { commands, .. } = next_message(&mut rx).await else { panic!("expected Actions") };
            assert!(matches!(&commands[..], [HostCommand::Log { .. }]));
            let _ = id;
        });
    }
}
