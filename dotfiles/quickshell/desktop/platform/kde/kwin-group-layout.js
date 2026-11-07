let frame = null;
let updating = false;
function members() {
    return workspace.windowList().filter(w => layout.ids.indexOf(w.internalId.toString()) >= 0);
}
function sync() {
    if (!frame || updating || workspace.windowList().indexOf(frame) < 0) return;
    const windows = members();
    if (windows.some(w => w.fullScreen)) return;
    updating = true;
    const area = frame.frameGeometry;
    const gap = 8;
    const available = area.width - 8 - (layout.slots.length - 1) * gap;
    const ratio = layout.ratio === undefined ? 0.5 : Math.max(0.2, Math.min(0.8, layout.ratio));
    const leftWidth = layout.slots.length === 2 ? Math.floor(available * ratio) : available;
    for (const window of windows) {
        const slot = layout.slots.indexOf(window.internalId.toString());
        if (slot < 0 || frame.minimized) {
            window.minimized = true;
            continue;
        }
        window.desktops = frame.desktops;
        window.activities = frame.activities;
        window.noBorder = true;
        window.setMaximize(false, false);
        window.frameGeometry = {x: area.x + 4 + (slot === 1 ? leftWidth + gap : 0), y: area.y + 40,
            width: slot === 1 ? available - leftWidth : leftWidth, height: Math.max(100, area.height - 44)};
        window.minimized = false;
    }
    updating = false;
}
function raiseGroup(window) {
    if (!frame || updating || !window || workspace.windowList().indexOf(frame) < 0 || members().some(w => w.fullScreen)) return;
    if (window !== frame && layout.ids.indexOf(window.internalId.toString()) < 0) return;
    updating = true;
    frame.minimized = false;
    for (const member of members()) {
        if (layout.slots.indexOf(member.internalId.toString()) >= 0) workspace.raiseWindow(member);
    }
    workspace.raiseWindow(frame);
    updating = false;
    sync();
}
function attach() {
    if (frame) return;
    frame = workspace.windowList().find(w => w.caption === "Quickshell group: " + layout.key);
    if (!frame) return;
    frame.noBorder = true;
    frame.skipTaskbar = true;
    frame.skipSwitcher = true;
    if (layout.initial) {
        const output = workspace.screens.find(s => s.name === layout.screen) || frame.output;
        const area = workspace.clientArea(KWin.MaximizeArea, output, workspace.currentDesktop);
        const width = Math.min(1400, area.width - 16);
        const height = Math.min(900, area.height - 64);
        frame.frameGeometry = {x: area.x + (area.width - width) / 2,
            y: Math.max(output.geometry.y + 48, area.y + (area.height - height) / 2), width: width, height: height};
    }
    frame.frameGeometryChanged.connect(sync);
    frame.minimizedChanged.connect(sync);
    frame.desktopsChanged.connect(sync);
    frame.activitiesChanged.connect(sync);
    workspace.windowActivated.connect(raiseGroup);
    sync();
    const selected = members().find(w => w.internalId.toString() === layout.focus);
    if (selected) { raiseGroup(selected); workspace.activeWindow = selected; }
}
workspace.windowAdded.connect(function(window) {
    attach();
    if (!frame) window.captionChanged.connect(attach);
});
attach();
