//! The window has no native title bar: gpui draws our tab strip in that area
//! (`TitlebarOptions::appears_transparent`), the macOS traffic lights are
//! hidden, and AppKit's own title-region dragging is switched off with
//! `WindowOptions::is_movable = false`, because it swallowed tab drags and
//! ignored every view-level override. Moving the window is done by hand:
//! a mouse-down on the title label records the pointer and frame origin in
//! screen space, and each mouse-move sets the frame origin to follow it.

use gpui::Window;

#[cfg(target_os = "macos")]
mod mac {
    use cocoa::appkit::NSWindow;
    use cocoa::base::id;
    use cocoa::foundation::NSPoint;
    use gpui::Window;
    use objc::runtime::{Object, YES};
    use objc::{class, msg_send, sel, sel_impl};
    use raw_window_handle::{HasWindowHandle, RawWindowHandle};

    fn ns_window(window: &Window) -> Option<id> {
        let handle = HasWindowHandle::window_handle(window).ok()?;
        let RawWindowHandle::AppKit(appkit) = handle.as_raw() else { return None };
        let view = appkit.ns_view.as_ptr() as *mut Object;
        let ns_window: id = unsafe { msg_send![view, window] };
        (!ns_window.is_null()).then_some(ns_window)
    }

    pub fn hide_traffic_lights(window: &Window) {
        let Some(ns_window) = ns_window(window) else { return };
        // NSWindowCloseButton = 0, NSWindowMiniaturizeButton = 1, NSWindowZoomButton = 2.
        for kind in 0u64..3 {
            unsafe {
                let button: id = msg_send![ns_window, standardWindowButton: kind];
                if !button.is_null() {
                    let _: () = msg_send![button, setHidden: YES];
                }
            }
        }
    }

    /// Pointer position in screen space (origin bottom-left, like window frames).
    fn mouse_location() -> NSPoint {
        unsafe { msg_send![class!(NSEvent), mouseLocation] }
    }

    /// A window move in progress; lives in the view that started it.
    pub struct WindowDrag {
        ns_window: id,
        mouse_start: NSPoint,
        origin_start: NSPoint,
    }

    impl WindowDrag {
        pub fn begin(window: &Window) -> Option<Self> {
            let ns_window = ns_window(window)?;
            let origin_start = unsafe { ns_window.frame() }.origin;
            Some(Self { ns_window, mouse_start: mouse_location(), origin_start })
        }

        /// Move the window by however far the pointer travelled since `begin`.
        pub fn follow_pointer(&self) {
            let mouse = mouse_location();
            let origin = NSPoint::new(
                self.origin_start.x + (mouse.x - self.mouse_start.x),
                self.origin_start.y + (mouse.y - self.mouse_start.y),
            );
            unsafe { self.ns_window.setFrameOrigin_(origin) };
        }
    }
}

#[cfg(target_os = "macos")]
pub use mac::WindowDrag;

#[cfg(not(target_os = "macos"))]
pub struct WindowDrag;

#[cfg(not(target_os = "macos"))]
impl WindowDrag {
    pub fn begin(window: &Window) -> Option<Self> {
        window.start_window_move();
        None
    }

    pub fn follow_pointer(&self) {}
}

/// Called once, right after the window is created.
pub fn prepare(window: &Window) {
    #[cfg(target_os = "macos")]
    mac::hide_traffic_lights(window);
    #[cfg(not(target_os = "macos"))]
    let _ = window;
}
