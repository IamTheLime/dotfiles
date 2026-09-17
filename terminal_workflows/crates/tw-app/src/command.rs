use tw_scripting::HostCommand;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct TabId(pub u64);

/// The single way anything changes the workspace. Keyboard actions, plugin
/// commands and (later) socket clients all convert into this and meet in
/// `Workspace::execute`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum AppCommand {
    NewTab,
    CloseTab(TabId),
    CloseActiveTab,
    SelectTab(usize),
    NextTab,
    PrevTab,
    /// `tab: None` targets the active tab.
    WriteToTerminal { tab: Option<TabId>, text: String },
    /// Reorder: move the active tab one slot, or drop a dragged tab onto another.
    MoveActiveTab(Direction),
    MoveTab { from: usize, to: usize },
    ReloadPlugins,
    Log(String),
    /// Show a markdown document in the sidebar (Neovim hover, plugin docs).
    ShowDocument { title: String, markdown: String },
    CloseDocument,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Direction {
    Left,
    Right,
}

impl From<HostCommand> for AppCommand {
    fn from(command: HostCommand) -> Self {
        match command {
            HostCommand::WriteToTerminal { text } => Self::WriteToTerminal { tab: None, text },
            HostCommand::NewTab => Self::NewTab,
            HostCommand::SelectTab { index } => Self::SelectTab(index),
            HostCommand::Log { message } => Self::Log(message),
            HostCommand::ShowMarkdown { title, markdown } => {
                Self::ShowDocument { title: title.unwrap_or_else(|| "document".to_owned()), markdown }
            }
        }
    }
}
