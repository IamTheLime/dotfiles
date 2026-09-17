//! The plugin runtime. Plugins are `.ts` files in `plugins/`, run by Node
//! (native type stripping, real `tsconfig`, npm packages, async, `fetch`).
//!
//! The app spawns `plugins/host.ts` as a child process and talks to it over
//! stdin/stdout, one JSON object per line. Every message is a serde enum here
//! ([`HostRequest`] out, [`HostMessage`] in), so the Rust side never parses
//! anything by hand. Nothing here knows about gpui.

mod host;
mod protocol;

pub use host::{HostError, HostEvent, NodeHost};
pub use protocol::{HexColor, HostCommand, HostMessage, HostRequest, PluginState, PluginView, TabInfo, WidgetNode};
