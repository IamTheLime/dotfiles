//! The window has no native title bar: gpui draws our tab strip in that area
//! (`TitlebarOptions::appears_transparent`). Two AppKit behaviours have to be
//! switched off for that to work on macOS:
//!
//! - the three traffic-light buttons are hidden, so the strip's own minimize
//!   and close buttons are the only ones;
//! - AppKit drags the window on any mouse-down in the title-bar region when
//!   the view under the mouse answers YES to `mouseDownCanMoveWindow`
//!   (NSView's default for non-opaque views). That swallowed tab drags, and
//!   gpui 0.2.2's `Window::start_window_move` is a no-op on macOS, so the
//!   answer is set to NO on gpui's view class and the window drag is started
//!   explicitly from the title label with `performWindowDragWithEvent:`.

use gpui::Window;

#[cfg(target_os = "macos")]
mod mac {
    use gpui::Window;
    use objc::runtime::{BOOL, Class, Imp, NO, Object, Sel, class_addMethod, object_getClass};
    use objc::{class, msg_send, sel, sel_impl};
    use raw_window_handle::{HasWindowHandle, RawWindowHandle};

    fn ns_view(window: &Window) -> Option<*mut Object> {
        let handle = HasWindowHandle::window_handle(window).ok()?;
        let RawWindowHandle::AppKit(appkit) = handle.as_raw() else { return None };
        Some(appkit.ns_view.as_ptr() as *mut Object)
    }

    fn ns_window(window: &Window) -> Option<*mut Object> {
        let view = ns_view(window)?;
        let ns_window: *mut Object = unsafe { msg_send![view, window] };
        (!ns_window.is_null()).then_some(ns_window)
    }

    pub fn hide_traffic_lights(window: &Window) {
        let Some(ns_window) = ns_window(window) else { return };
        // NSWindowCloseButton = 0, NSWindowMiniaturizeButton = 1, NSWindowZoomButton = 2.
        for kind in 0u64..3 {
            unsafe {
                let button: *mut Object = msg_send![ns_window, standardWindowButton: kind];
                if !button.is_null() {
                    let _: () = msg_send![button, setHidden: objc::runtime::YES];
                }
            }
        }
    }

    extern "C" fn mouse_down_can_move_window(_this: &Object, _cmd: Sel) -> BOOL {
        NO
    }

    /// Make gpui's view class answer NO to `mouseDownCanMoveWindow`, once.
    pub fn disable_native_titlebar_drag(window: &Window) {
        let Some(view) = ns_view(window) else { return };
        unsafe {
            let class = object_getClass(view) as *mut Class;
            let imp: Imp = std::mem::transmute(mouse_down_can_move_window as extern "C" fn(&Object, Sel) -> BOOL);
            // Type encoding: BOOL return, then self and _cmd. BOOL is `bool` on arm64, `signed char` on x86_64.
            let types = if cfg!(target_arch = "aarch64") { c"B@:" } else { c"c@:" };
            let added = class_addMethod(class, sel!(mouseDownCanMoveWindow), imp, types.as_ptr());
            if added == NO {
                log::warn!("mouseDownCanMoveWindow already defined on gpui's view class; tab drags may move the window");
            } else {
                log::info!("native title-bar drag disabled; the window moves from the title label only");
            }
        }
    }

    /// Let AppKit move the window with the mouse-down being dispatched right now.
    pub fn start_window_move(window: &Window) {
        let Some(ns_window) = ns_window(window) else { return };
        unsafe {
            let app: *mut Object = msg_send![class!(NSApplication), sharedApplication];
            let event: *mut Object = msg_send![app, currentEvent];
            if !event.is_null() {
                let _: () = msg_send![ns_window, performWindowDragWithEvent: event];
            }
        }
    }
}

/// Called once, right after the window is created.
pub fn prepare(window: &Window) {
    #[cfg(target_os = "macos")]
    {
        mac::hide_traffic_lights(window);
        mac::disable_native_titlebar_drag(window);
    }
    #[cfg(not(target_os = "macos"))]
    let _ = window;
}

/// Start dragging the window from the mouse-down currently being handled.
pub fn start_window_move(window: &Window) {
    #[cfg(target_os = "macos")]
    mac::start_window_move(window);
    #[cfg(not(target_os = "macos"))]
    window.start_window_move();
}
