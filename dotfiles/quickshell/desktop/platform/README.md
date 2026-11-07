# QML desktop interface

Import this directory and use the `Backend` singleton. Selection is automatic
from `XDG_CURRENT_DESKTOP`, or explicit with `QS_PLATFORM=kde|gnome`.

- `name`, `ready`, `error`: selected adapter and bridge health.
- `capabilities`: panels, blur, grouping, decorationRemoval,
  nativePanelReservation, plus experimental on GNOME.
- `windows`: stable window IDs, titles, app IDs, resource class, focus/minimised
  state, activation order, screen name, fullscreen, dialog and parent ID.
- `maximized`, `fullscreen`: booleans indexed by QML screen connector name.
- `activate(id)`, `closeWindows(ids)`, `openSettings("audio"|"bluetooth")`.
- `send({layout: {key, ids, slots, screen, ratio, focus}})` coordinates a group;
  `send({restore: ids})` releases it. Closing always requests a normal app close.
- `launchers`: desktop-specific defaults, separate from shared dock rendering.

`shared/PanelSurface.qml` is the surface adapter. It provides `screen`, `role`,
`edge`, implicit dimensions, `visible`, `exclusiveZone`, `mask`, `blurRegion`,
`contentItem`, and the actual native `window` for popup anchors. Shared children
are reparented into the selected native panel without duplicating the UI.

KDE uses layer-shell panels and the KWin Python/JavaScript bridge. GNOME uses
ordinary transparent Quickshell windows and a GNOME Shell extension to place
and raise them. GNOME needs `QT_WAYLAND_DISABLE_WINDOWDECORATION=1`; use run.sh.

Bridges read one JSON command per stdin line and emit snapshots on stdout.
Errors go to stderr. GNOME forwards the same protocol through a versioned D-Bus
interface owned by GNOME Shell. One unique D-Bus client is admitted; commands
from other callers are rejected. Disconnect restores window layouts and GNOME's
panel, including when the client disappears without sending Disconnect.
