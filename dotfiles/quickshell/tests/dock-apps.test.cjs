const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { test } = require('node:test');

const qml = fs.readFileSync(`${__dirname}/../desktop/shared/DesktopShell.qml`, 'utf8');
function source(name) {
    const start = qml.indexOf(`function ${name}(`);
    let depth = 0;
    for (let i = qml.indexOf('{', start); i < qml.length; i++) {
        if (qml[i] === '{') depth++;
        if (qml[i] === '}' && --depth === 0) return qml.slice(start, i + 1);
    }
    throw new Error(`Missing function ${name}`);
}
test('should group running apps after pins, retain their order, and remove closed apps', () => {
    const files = { appId: 'org.kde.dolphin', command: ['dolphin'] };
    const ghostty = { appId: 'com.mitchellh.ghostty', resourceClass: 'ghostty', order: 2 };
    const chrome = { appId: 'google-chrome', resourceClass: 'google-chrome', order: 1 };
    const context = vm.createContext({ launchers: [files], dockApps: [files],
        appWindows: [{ appId: files.appId, resourceClass: 'dolphin' }, ghostty, { ...ghostty, order: 3 }, chrome],
        DesktopEntries: { byId: id => ({ name: id, icon: id }), heuristicLookup: () => null } });
    vm.runInContext(['matchesApp', 'updateDockApps', 'windowsFor'].map(source).join('\n'), context);
    const ids = () => Array.from(context.dockApps, app => app.appId);
    context.updateDockApps();
    assert.deepEqual(ids(), [files.appId, ghostty.appId, chrome.appId]);
    assert.deepEqual(Array.from(context.windowsFor(context.dockApps[1]), window => window.order), [3, 2]);
    context.appWindows.reverse();
    context.updateDockApps();
    assert.deepEqual(ids(), [files.appId, ghostty.appId, chrome.appId]);
    context.appWindows = [chrome];
    context.updateDockApps();
    assert.deepEqual(ids(), [files.appId, chrome.appId]);
});
