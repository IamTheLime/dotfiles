//! Maps a plugin's `WidgetNode` tree to gpui elements.

use std::rc::Rc;

use gpui::{AnyElement, App, SharedString, Window, div, prelude::*, px};
use tw_scripting::{PluginView, WidgetNode};

use crate::theme;

/// Called with `(plugin name, action name)` when a plugin button is clicked.
pub type Dispatch = Rc<dyn Fn(&str, &str, &mut Window, &mut App)>;

pub fn plugin_card(view: PluginView, dispatch: Dispatch) -> impl IntoElement {
    let mut ids = 0;
    let name = view.name().to_owned();
    let body = match &view {
        PluginView::Ok { widget, .. } => render_node(widget, &name, &dispatch, &mut ids),
        PluginView::Error { error, .. } => div()
            .text_sm()
            .text_color(theme::error())
            .child(error.clone())
            .into_any_element(),
    };
    div()
        .flex()
        .flex_col()
        .gap_2()
        .p_2()
        .rounded_md()
        .bg(theme::panel())
        .child(div().text_xs().text_color(theme::muted()).child(name))
        .child(body)
}

fn render_node(node: &WidgetNode, plugin: &str, dispatch: &Dispatch, ids: &mut usize) -> AnyElement {
    match node {
        WidgetNode::Column { children, gap } => div()
            .flex()
            .flex_col()
            .gap(px(gap.unwrap_or(4.0)))
            .children(children.iter().map(|child| render_node(child, plugin, dispatch, ids)))
            .into_any_element(),
        WidgetNode::Row { children, gap } => div()
            .flex()
            .flex_row()
            .items_center()
            .gap(px(gap.unwrap_or(4.0)))
            .children(children.iter().map(|child| render_node(child, plugin, dispatch, ids)))
            .into_any_element(),
        WidgetNode::Text { text, color, size } => div()
            .text_size(px(size.unwrap_or(13.0)))
            .text_color(color.map(theme::plugin).unwrap_or_else(theme::text))
            .child(text.clone())
            .into_any_element(),
        WidgetNode::Button { label, action } => {
            *ids += 1;
            let id = SharedString::from(format!("{plugin}:{action}:{ids}"));
            let dispatch = dispatch.clone();
            let plugin = plugin.to_owned();
            let action = action.clone();
            div()
                .id(id)
                .px_2()
                .py_1()
                .rounded_md()
                .bg(theme::button())
                .hover(|style| style.bg(theme::button_hover()))
                .cursor_pointer()
                .text_sm()
                .child(label.clone())
                .on_click(move |_, window, cx| dispatch(&plugin, &action, window, cx))
                .into_any_element()
        }
    }
}
