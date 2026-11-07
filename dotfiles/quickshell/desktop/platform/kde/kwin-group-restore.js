for (const window of workspace.windowList()) {
    const id = window.internalId.toString();
    if (!Object.prototype.hasOwnProperty.call(saved, id)) continue;
    window.noBorder = false;
    const original = saved[id];
    if (!original) continue;
    window.fullScreen = false;
    window.setMaximize(false, false);
    window.desktops = workspace.desktops.filter(d => original.desktops.indexOf(d.id) >= 0);
    window.activities = original.activities;
    window.frameGeometry = {x: original.x, y: original.y, width: original.width, height: original.height};
    window.setMaximize(!!original.maximizeVertical, !!original.maximizeHorizontal);
    window.fullScreen = original.fullscreen;
    window.minimized = original.minimized;
}
