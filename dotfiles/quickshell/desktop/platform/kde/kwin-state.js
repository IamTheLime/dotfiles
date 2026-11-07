var activationOrder = {};
var removedWindows = new Set();
var activationSerial = 0;

function sendState() {
    const state = {};
    const apps = [];
    const windows = workspace.stackingOrder;
    for (let i = windows.length - 1; i >= 0; --i) {
        const window = windows[i];
        if (removedWindows.has(window.internalId.toString())) continue;
        const shellWindow = window.resourceClass === "quickshell" || window.resourceClass === "org.quickshell";
        const groupFrame = shellWindow && window.caption.indexOf("Quickshell group: ") === 0;
        if (shellWindow && !window.caption)
            continue;
        if (!window.normalWindow || !window.output)
            continue;
        const id = window.internalId.toString();
        if (!window.skipTaskbar && !groupFrame) {
            apps.push({id: id, title: window.caption, appId: window.desktopFileName,
                resourceClass: window.resourceClass, active: window.active,
                minimized: window.minimized, order: activationOrder[id] || 0,
                screen: window.output.name, fullscreen: window.fullScreen, dialog: !!window.dialog || !!window.modal,
                parentId: window.transientFor ? window.transientFor.internalId.toString() : ""});
        }
        if (window.minimized || window.hidden)
            continue;
        if (!window.onAllDesktops && window.desktops.indexOf(workspace.currentDesktop) < 0)
            continue;
        if (window.activities.length && window.activities.indexOf(workspace.currentActivity) < 0)
            continue;
        const output = window.output.name;
        if (state[output] === undefined)
            state[output] = [];
        state[output].push(window.internalId.toString());
    }
    const payload = JSON.stringify({maximized: state, windows: apps});
    callDBus("__BUS_NAME__", "/State", "org.dotfiles.Quickshell.State", "Update", payload);
}

function publish() {
    sendState();
}

function track(window) {
    window.captionChanged.connect(publish);
    window.fullScreenChanged.connect(publish);
    window.maximizedChanged.connect(publish);
    window.minimizedChanged.connect(publish);
    window.hiddenChanged.connect(publish);
    window.outputChanged.connect(publish);
    window.desktopsChanged.connect(publish);
    window.activitiesChanged.connect(publish);
}

workspace.windowList().forEach(track);
if (workspace.activeWindow) activationOrder[workspace.activeWindow.internalId.toString()] = ++activationSerial;
workspace.windowAdded.connect(function(window) { track(window); publish(); });
workspace.windowRemoved.connect(function(window) {
    removedWindows.add(window.internalId.toString());
    delete activationOrder[window.internalId.toString()];
    publish();
});
workspace.windowActivated.connect(function(window) {
    if (window) activationOrder[window.internalId.toString()] = ++activationSerial;
    publish();
});
workspace.currentDesktopChanged.connect(publish);
workspace.currentActivityChanged.connect(publish);
workspace.screensChanged.connect(publish);
publish();
