//! The wire format shared with `plugins/host.ts` and `plugins/api.ts`.
//! Change both sides together; `host.rs` tests round-trip through the real host.

use std::fmt;
use std::str::FromStr;

use serde::{Deserialize, Deserializer, Serialize, Serializer};

/// What the host tells a plugin on every render.
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PluginState {
    pub active_tab: usize,
    pub tabs: Vec<TabInfo>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TabInfo {
    pub id: u64,
    pub title: String,
}

/// What a plugin may ask the app to do. This is also the wire format the
/// future control socket will speak, one JSON object per line.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "camelCase")]
pub enum HostCommand {
    WriteToTerminal { text: String },
    NewTab,
    SelectTab { index: usize },
    Log { message: String },
    /// Show a markdown document in the sidebar (LSP hover from Neovim, docs from a plugin).
    ShowMarkdown {
        #[serde(default)]
        title: Option<String>,
        markdown: String,
    },
}

/// The widget tree a plugin returns from `render()`.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "camelCase")]
pub enum WidgetNode {
    Column {
        #[serde(default)]
        children: Vec<WidgetNode>,
        #[serde(default)]
        gap: Option<f32>,
    },
    Row {
        #[serde(default)]
        children: Vec<WidgetNode>,
        #[serde(default)]
        gap: Option<f32>,
    },
    Text {
        text: String,
        #[serde(default)]
        color: Option<HexColor>,
        #[serde(default)]
        size: Option<f32>,
    },
    Button {
        label: String,
        /// Passed back to the plugin's `onAction` when clicked.
        action: String,
    },
}

/// App → host. One line each.
#[derive(Clone, Debug, PartialEq, Serialize)]
#[serde(tag = "type", rename_all = "camelCase")]
pub enum HostRequest<'a> {
    Render { id: u64, state: &'a PluginState },
    Action { id: u64, plugin: &'a str, action: &'a str, state: &'a PluginState },
    Reload,
}

/// Host → app. `id` echoes the request it answers.
#[derive(Clone, Debug, PartialEq, Deserialize)]
#[serde(tag = "type", rename_all = "camelCase")]
pub enum HostMessage {
    Ready { plugins: Vec<String> },
    Rendered { id: u64, views: Vec<PluginView> },
    Actions { id: u64, commands: Vec<HostCommand> },
    Failed { id: u64, message: String },
    /// Files under `plugins/` changed and were reloaded.
    Changed { plugins: Vec<String> },
    /// `console.log` from a plugin.
    Log { message: String },
}

/// One plugin's output for a render.
#[derive(Clone, Debug, PartialEq, Deserialize)]
#[serde(tag = "status", rename_all = "camelCase")]
pub enum PluginView {
    Ok { name: String, widget: WidgetNode },
    Error { name: String, error: String },
}

impl PluginView {
    pub fn name(&self) -> &str {
        match self {
            Self::Ok { name, .. } | Self::Error { name, .. } => name,
        }
    }
}

/// A colour written as `#rrggbb`. Parsed once here so the UI never sees the string.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct HexColor(pub u32);

impl FromStr for HexColor {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let digits = s.strip_prefix('#').ok_or_else(|| format!("colour {s:?} must start with '#'"))?;
        if digits.len() != 6 {
            return Err(format!("colour {s:?} must be #rrggbb"));
        }
        u32::from_str_radix(digits, 16)
            .map(Self)
            .map_err(|e| format!("colour {s:?}: {e}"))
    }
}

impl fmt::Display for HexColor {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "#{:06x}", self.0)
    }
}

impl Serialize for HexColor {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        serializer.collect_str(self)
    }
}

impl<'de> Deserialize<'de> for HexColor {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let raw = String::deserialize(deserializer)?;
        raw.parse().map_err(serde::de::Error::custom)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn should_round_trip_a_widget_tree_through_json() {
        let tree = WidgetNode::Column {
            gap: Some(8.0),
            children: vec![
                WidgetNode::Text { text: "hi".into(), color: Some(HexColor(0x7aa2f7)), size: None },
                WidgetNode::Button { label: "Go".into(), action: "go".into() },
            ],
        };
        let json = serde_json::to_string(&tree).unwrap();
        assert!(json.contains(r##""type":"column""##));
        assert!(json.contains(r##""color":"#7aa2f7""##));
        assert_eq!(serde_json::from_str::<WidgetNode>(&json).unwrap(), tree);
    }

    #[test]
    fn should_parse_host_messages_by_their_type_tag() {
        let rendered: HostMessage = serde_json::from_str(
            r##"{"type":"rendered","id":3,"views":[{"status":"ok","name":"a","widget":{"type":"text","text":"x"}},{"status":"error","name":"b","error":"boom"}]}"##,
        )
        .unwrap();
        assert_eq!(
            rendered,
            HostMessage::Rendered {
                id: 3,
                views: vec![
                    PluginView::Ok { name: "a".into(), widget: WidgetNode::Text { text: "x".into(), color: None, size: None } },
                    PluginView::Error { name: "b".into(), error: "boom".into() },
                ],
            }
        );
        let actions: HostMessage =
            serde_json::from_str(r#"{"type":"actions","id":4,"commands":[{"type":"writeToTerminal","text":"ls\n"},{"type":"newTab"}]}"#)
                .unwrap();
        assert_eq!(
            actions,
            HostMessage::Actions {
                id: 4,
                commands: vec![HostCommand::WriteToTerminal { text: "ls\n".into() }, HostCommand::NewTab],
            }
        );
    }

    #[test]
    fn should_serialise_requests_with_a_type_tag() {
        let state = PluginState { active_tab: 0, tabs: vec![] };
        let json = serde_json::to_string(&HostRequest::Action { id: 1, plugin: "hello", action: "hi", state: &state }).unwrap();
        assert_eq!(json, r#"{"type":"action","id":1,"plugin":"hello","action":"hi","state":{"activeTab":0,"tabs":[]}}"#);
    }

    #[test]
    fn should_reject_a_colour_that_is_not_rrggbb() {
        assert!("#fff".parse::<HexColor>().is_err());
        assert!("7aa2f7".parse::<HexColor>().is_err());
        assert_eq!("#7AA2F7".parse::<HexColor>().unwrap(), HexColor(0x7aa2f7));
    }
}
