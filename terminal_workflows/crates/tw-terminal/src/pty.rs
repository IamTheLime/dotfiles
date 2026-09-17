use std::io::{self, Read, Write};
use std::path::PathBuf;
use std::thread;

use futures::channel::mpsc::{self, UnboundedReceiver, UnboundedSender};
use portable_pty::{Child, CommandBuilder, ExitStatus, MasterPty, PtySize, native_pty_system};

/// What the reader thread sends to the UI thread.
#[derive(Debug)]
pub enum PtyRead {
    Data(Vec<u8>),
    /// The child closed its side; nothing more will arrive.
    Eof,
}

impl PtyRead {
    pub fn len(&self) -> usize {
        match self {
            Self::Data(bytes) => bytes.len(),
            Self::Eof => 0,
        }
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }
}

/// How to start the child process.
#[derive(Clone, Debug)]
pub struct PtySpec {
    pub program: String,
    pub args: Vec<String>,
    pub cwd: Option<PathBuf>,
    pub cols: u16,
    pub rows: u16,
}

impl PtySpec {
    /// The user's login shell (`$SHELL`, else zsh), started as a login shell in `$HOME`.
    pub fn login_shell(cols: u16, rows: u16) -> Self {
        Self {
            program: std::env::var("SHELL").unwrap_or_else(|_| "/bin/zsh".to_owned()),
            args: vec!["-l".to_owned()],
            cwd: std::env::var_os("HOME").map(PathBuf::from),
            cols,
            rows,
        }
    }
}

#[derive(Debug, thiserror::Error)]
pub enum PtyError {
    #[error("pty: {0}")]
    Pty(#[from] anyhow::Error),
    #[error("spawn {program}: {source}")]
    Spawn { program: String, source: anyhow::Error },
    #[error("pty io: {0}")]
    Io(#[from] io::Error),
}

/// The master side of a PTY plus the child running on the slave side.
/// Dropping it kills the child.
pub struct Pty {
    master: Box<dyn MasterPty + Send>,
    writer: Box<dyn Write + Send>,
    child: Box<dyn Child + Send + Sync>,
}

impl Pty {
    /// Open the PTY, start the child, and start a thread that forwards its output.
    pub fn spawn(spec: &PtySpec) -> Result<(Self, UnboundedReceiver<PtyRead>), PtyError> {
        let pair = native_pty_system().openpty(PtySize {
            rows: spec.rows,
            cols: spec.cols,
            pixel_width: 0,
            pixel_height: 0,
        })?;

        let mut cmd = CommandBuilder::new(&spec.program);
        cmd.args(&spec.args);
        if let Some(cwd) = &spec.cwd {
            cmd.cwd(cwd);
        }
        cmd.env("TERM", "xterm-256color");
        cmd.env("COLORTERM", "truecolor");
        cmd.env("TERM_PROGRAM", "terminal_workflows");
        let child = pair
            .slave
            .spawn_command(cmd)
            .map_err(|source| PtyError::Spawn { program: spec.program.clone(), source })?;
        drop(pair.slave);

        let reader = pair.master.try_clone_reader()?;
        let writer = pair.master.take_writer()?;
        let (tx, rx) = mpsc::unbounded();
        thread::Builder::new()
            .name("pty-reader".to_owned())
            .spawn(move || forward_output(reader, tx))?;

        Ok((Self { master: pair.master, writer, child }, rx))
    }

    pub fn write(&mut self, bytes: &[u8]) -> io::Result<()> {
        self.writer.write_all(bytes)?;
        self.writer.flush()
    }

    pub fn resize(&self, cols: u16, rows: u16, cell_width: u16, cell_height: u16) -> Result<(), PtyError> {
        self.master.resize(PtySize {
            rows,
            cols,
            pixel_width: cols.saturating_mul(cell_width),
            pixel_height: rows.saturating_mul(cell_height),
        })?;
        Ok(())
    }

    pub fn try_wait(&mut self) -> io::Result<Option<ExitStatus>> {
        self.child.try_wait()
    }
}

impl Drop for Pty {
    fn drop(&mut self) {
        if let Err(e) = self.child.kill() {
            log::debug!("kill shell: {e}");
        }
    }
}

fn forward_output(mut reader: Box<dyn Read + Send>, tx: UnboundedSender<PtyRead>) {
    let mut buf = [0u8; 16 * 1024];
    loop {
        let read = match reader.read(&mut buf) {
            Ok(0) => PtyRead::Eof,
            Ok(n) => PtyRead::Data(buf[..n].to_vec()),
            Err(e) if e.kind() == io::ErrorKind::Interrupted => continue,
            // macOS reports EIO once the child closes its side; that is the normal end of stream.
            Err(_) => PtyRead::Eof,
        };
        let is_eof = matches!(read, PtyRead::Eof);
        if tx.unbounded_send(read).is_err() || is_eof {
            break;
        }
    }
}
