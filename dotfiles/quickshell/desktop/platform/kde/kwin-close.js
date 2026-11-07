for (const id of ids) {
    const window = workspace.windowList().find(w => w.internalId.toString() === id);
    if (window && window.closeable) window.closeWindow();
}
