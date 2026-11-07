# Quickshell desktop: KDE and experimental GNOME

The QML UI and theme live in `desktop/shared/`. Desktop-specific code lives in
`desktop/platform/kde/` and `desktop/platform/gnome/`. The shared interface is
[documented here](desktop/platform/README.md).

## Try on GNOME

This is an **experimental port**, code-checked on KDE but not exercised inside
GNOME Shell. The extension declares GNOME 45–51 for testing; that is a version
allow-list, not a claim that every version has been tested. It requires a
Wayland session, Quickshell 0.3.2+, Python dbus-python and PyGObject, and `gdbus`.

From this directory on your GNOME computer:

```sh
./desktop/platform/gnome/install.sh
# Log out and back in so GNOME discovers the extension, then:
gnome-extensions enable quickshell-bridge@dotfiles.local
./run.sh
```

`run.sh` selects the desktop and sets Qt's no-decoration option for GNOME.
Use `QS_PLATFORM=gnome ./run.sh` to override detection. Do not launch a second
copy alongside the existing shell. No autostart or global GNOME preference is
installed. Installing the dotfiles config through setup_environment.sh still
works; use this launcher on GNOME instead of plain `qs -c desktop`.

The GNOME port provides the shared bar/dock, audio/Bluetooth/media UI,
window activation/closing, and experimental native-window grouping. Its
extension handles panel placement and a strut for maximised windows. The stock
GNOME top panel hides while Quickshell's top panel is present and returns when
the bridge disconnects. It is restored in Overview.

Known GNOME differences:

- Native background blur is unavailable; the tint and transparency remain.
- Grouped application windows keep their own decorations, including client-side
  titlebars. Split resizing includes those decorations.
- Quickshell panel/group windows may appear in GNOME Overview or the switcher.
- Panel placement, scaling, fullscreen transitions and grouped-window stacking
  need live testing on your GNOME version. This does not replace Mutter.
- The Terminal pin uses GNOME Console (`kgx`); edit the GNOME profile if your
  distribution uses a different terminal.

Inspect adapter health with `qs ipc -p desktop call desktop platform` (from this
directory) or `qs ipc -c desktop call desktop platform` when using the symlink.
For extension errors use `journalctl --user -b -o cat` and look for Quickshell.
Stop Quickshell before disabling the bridge:

```sh
qs kill -p ./desktop
gnome-extensions disable quickshell-bridge@dotfiles.local
```

Disabling/disconnecting restores remembered app geometry and the GNOME top
panel. A complete GNOME Shell crash cannot run extension cleanup; app windows
retain native decorations in this port, so remain independently usable.

## KDE setup and behaviour


A manually launched top bar and bottom launcher dock on each monitor.
Configuration changes reload automatically. KDE panels, locking and session
management stay in place; no autostart is installed.

## Install and run

Requires Quickshell 0.3.2 or newer and a compositor supporting
`ext-background-effect-v1` for native background blur. The top-bar and dock
blur regions follow their pill geometry; the invisible dock hover buffer is
excluded. Top-bar glass uses `#7020242c`; dock glass uses the same colour at 15% opacity.
Dock glass fades over the inner 6 pixels of its edge. This feathers the tint;
KWin’s native blur region still has a hard boundary. Blur strength is controlled by KWin.

On Nobara, use the existing repositories:

```sh
sudo dnf install quickshell python3-dbus python3-gobject-base
```

From the repository root, select Quickshell in `./setup_environment.sh`, or
link only this configuration (the destination must not already exist):

```sh
mkdir -p "$HOME/.config/quickshell"
ln -s "$PWD/dotfiles/quickshell/desktop" "$HOME/.config/quickshell/desktop"
quickshell -c desktop
```

Press Ctrl+C to stop a foreground instance. To run detached or stop it later:

```sh
quickshell -c desktop -n -d
quickshell kill -c desktop
```

Without a symlink, run `quickshell -p ./dotfiles/quickshell/desktop` from the
repository root.

## Window behaviour

With restored windows, the top pills are separate and reserve no space;
windows can move behind them and pointer input passes through the gaps.
When any visible normal window on the current desktop and activity is maximized
on a monitor, the bar reserves
34 pixels so that window sits directly beneath it. The pills join edge to
edge over 160 ms with an elastic settle, with square top corners flush to the screen and 12-pixel inward-curving
overhangs beneath the outer edges, wrapping around the window below. Restoring the window removes
the reservation and separates the pills again over 620 ms. Exclusive fullscreen (such as
F11 or a game) hides both bars on that monitor and releases the top reservation.
Leaving fullscreen restores the usual maximised or floating layout.

`desktop/platform/kde/kwin-state.py` starts a KWin observer and reports window state
through the session D-Bus. It observes changes rather than polling. Its script
unloads on normal shutdown; stale observers from a killed helper are removed
on the next launch, separately from window-state event forwarding.

The dock marks apps with open windows with a dot. Running apps without a pinned
launcher appear in a separate glass pill after the pinned icons, with a 12-pixel gap.
The running-app pill disappears when its last window closes. Both pills use capsule
corners and an 18% icon zoom on hover. While open, the dock keeps a 24-pixel
side buffer and 32 pixels above it, with a 320 ms hide delay after leaving. Hover an app to select from
its window titles, including minimised windows and windows on other desktops.
Click an app to restore its most recently active window; apps without windows
launch normally. Selecting a window switches to its desktop/activity if needed.
Window activation uses a short-lived KWin script; the observer remains event-driven.

### Window groups (prototype)

Hover an app in the dock and choose **Group as tabs** above its window list.
KiCad projects group automatically when one of their editors is active; the
project prefix in the window title separates projects when first creating a group.
Other applications opt in per group. Membership follows window IDs, so changing
a document title does not release it. Newly opened app windows join their
parent’s group, or the most recently active group for that app. Dialogs stay
separate; existing unrelated windows are not swept into a group.

Each group has a rectangular, movable and resizable frame:

- Click a tab to show its window or restore its remembered split pair. Independent
  tabs open alone; returning to either member restores both panes and their ratio.
- Paired tabs stay adjacent with matching colour and left/right labels. The liquid
  split control unmerges the pair while keeping the focused window; the swap icon
  exchanges sides. Neither action closes windows. Pair memory lasts for this shell
  session and is removed if either member closes.
- Click the group label or colour swatch to edit its name and accent. The same
  editor is shown when choosing **Group as tabs** in the dock.
- Drag a tab toward the left or right half and release to show two panes. Tabs
  lift and settle, the destination pane fades in, and a pulsing amoeba follows
  the pointer with the tab number/title. Releasing outside the frame cancels.
- Drag the project name or empty header space to move the whole group.
- Drag the frame edges to resize both panes together. Drag the centre divider
  to adjust their widths; the split ratio is retained when switching tabs.
- Use the header controls to minimise or maximise the group.
- **Ungroup**, the × button, or closing the frame restores the original window
  geometry and minimised/maximised state, and enables native window controls; it does not close apps.

This coordinates native windows through KWin; it does not embed foreign
Wayland surfaces. Group membership is temporary and resets on shell restart.
Normal helper shutdown restores managed windows. Initial KiCad matching uses
project titles; identical project names cannot be distinguished.
The divider supports splits between 20/80 and 80/20. Application minimum sizes
can constrain very narrow layouts. The main bars still hide for fullscreen.

Run the focused checks with `node --test dotfiles/quickshell/tests/*.test.cjs`.

To allow dragging to the top edge without KDE maximizing the window:

```sh
./dotfiles/quickshell/desktop/platform/kde/configure.sh
```

This changes only `Windows/ElectricBorderMaximize` in `~/.config/kwinrc`.
Restore KDE's default with:

```sh
kwriteconfig6 --file kwinrc --group Windows --key ElectricBorderMaximize true
busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure
```

## Controls

- Tray left-click opens a menu immediately; double-click activates the app.
- Right-click opens the app's native menu; middle-click invokes its secondary action.
- Tray menus close after leaving their icon and menu, or with the close button.
- Click volume for a bouncing panel with output selection, master volume and
  per-application playback sliders. Right-click mutes; scrolling adjusts volume.
- Click BT for Bluetooth power, scanning, pairing and connection controls.
  Pairing prompts are handled by KDE's existing Bluetooth agent.
- Dock launchers appear at the bottom-centre edge and hide 120 ms after leaving.
  Their commands are editable in `desktop/shell.qml`.

Audio and Bluetooth panels appear beneath the bar, not over its buttons. No
hover tooltip covers the volume control. Tray and dock icons bounce on press.
Tray images are desaturated at rest and coloured on hover; low-resolution images
supplied by an app can still limit sharpness.

## Appearance and OLED movement

Backgrounds are 44% opaque with no outlines. Local time is divided into 100
portions (14.4 minutes each). Content travels 100 pixels: 0 at midnight, 100
at noon, then back to 0 at midnight. Minute updates use 60-second linear
transitions. The clock remains in the central area. This is not a guarantee
against OLED burn-in.

Inspect positions without waiting:

```sh
quickshell kill -c desktop
QS_DAY_PORTION=50 quickshell -c desktop
```

Use 0, 25, 50, 75 or 100. Stop the preview and launch without the variable to
restore daytime movement. `dayPortions` and `travelPixels` live in `shell.qml`.

Inspect the current per-monitor maximize state:

```sh
quickshell ipc -c desktop call desktop state
```

Panels can also be opened with `quickshell ipc -c desktop call desktop-DP-2 audio`
or `bluetooth`; replace DP-2 with your screen name. `dismiss` closes them.

Existing Plasma panels can obscure the dock activation edge. Verify your games
and frame times before enabling this shell at login. Qt or Quickshell upgrades
may require changes; the configuration currently targets Nobara's Quickshell 0.2.1.

## Liquid animation

The top-bar surface blends rounded shapes with a moving highlight during the
merge. This suggests refraction within the bar; it does not sample or distort
other applications. The dock rises over 180 ms with a gentle overshoot and
contracts into a droplet while sinking over 140 ms. When hidden, only an
invisible three-pixel activation strip accepts input.

The shader source and compiled Qt shader are both included. After editing
`desktop/shaders/liquid.frag`, rebuild it with Qt's Shader Baker:

```sh
qsb --qt6 -o desktop/shaders/liquid.frag.qsb desktop/shaders/liquid.frag
```

Run from this directory; on Nobara the tool is `/usr/lib64/qt6/bin/qsb`.
The animation settings live in `desktop/shell.qml`. To inspect the dock,
use `quickshell ipc -c desktop call dock-DP-2 reveal` or `conceal`, substituting
your screen name.

### Keep awake

Open the top-bar audio or Bluetooth panel and toggle **Keep awake**. It blocks
sleep through logind while allowing screen blanking and locking normally.
The toggle is shared across monitors, starts off, and releases its inhibitor
when disabled or when Quickshell exits. It resets on configuration reload.

### Glass surfaces and split colours

Control centre, dock window menus, tray menus and the group editor share
`GlassSurface.qml`: a translucent charcoal surface with native KWin blur,
clipped to rounded corners. Foreground text and controls remain sharp.
Split pairs draw from a muted six-colour palette. Colours stay with their pair
through selection, resizing and swapping; only the subtle 5% tint, bottom band
and unsplit icon use the accent. Colours can repeat beyond six concurrent pairs.

## Shared theme

Edit `desktop/shared/theme/Theme.qml` for the Tokyo Night palette and semantic colour tokens.
New components should add `import "theme"` and reference `Theme.text`, `Theme.card`, `Theme.button`,
`Theme.accent`, and the other named roles instead of adding literal colours.
`glassTint` controls hue; `glassOpacity` controls transparency independently.
`cardOpacity` and the rim opacity settings are separate. KWin controls the
native blur strength; changing colours does not disable blur.

The top bar, dock and previews, control centre, grouped-window frame and tabs,
split markers, group editor, shared buttons and sliders use these tokens.
`splitPalette` controls new split colours; existing groups keep their assigned
colours. `dockOpacity` stays independent of the control-centre glass.
Audio and Bluetooth bubbles wrap their respective top-bar icons; switching
sections slides the bubble neck while keeping the panel body in place.

## Validation

```sh
node --test tests/*.test.cjs
dbus-run-session -- python3 tests/gnome-bridge-smoke.py desktop/platform/gnome/bridge.py
```

The second check uses a private D-Bus and a mock extension, not a running GNOME
session. The GNOME bridge reconnects after an extension/session restart; grouped
layouts are restored on disconnect and must be regrouped afterwards.

The platform split was checked with live KDE panels, popup anchors, theme hot
reload and disposable grouped windows. GNOME rendering, input regions, scaling,
Overview and client-specific minimum window sizes still require testing on the
target machine. If GNOME Console is absent, change its launcher in
`desktop/platform/gnome/Profile.qml`.
