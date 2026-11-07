const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { test } = require('node:test');

function signal() {
    const handlers = [];
    return { connect: handler => handlers.push(handler), emit: value => handlers.forEach(handler => handler(value)) };
}
function window(id, extra = {}) {
    const result = { internalId: id, caption: id, desktopFileName: 'org.kde.dolphin',
        resourceClass: 'org.kde.dolphin', normalWindow: true, output: { name: 'screen' },
        desktops: ['current'], activities: [], ...extra };
    for (const name of ['captionChanged', 'fullScreenChanged', 'maximizedChanged', 'minimizedChanged',
        'hiddenChanged', 'outputChanged', 'desktopsChanged', 'activitiesChanged']) result[name] = signal();
    return result;
}
function observe(windows) {
    let snapshot;
    const workspace = { stackingOrder: windows, currentDesktop: 'current', currentActivity: 'activity',
        windowList: () => windows, activeWindow: windows[0] };
    for (const name of ['windowAdded', 'windowRemoved', 'windowActivated', 'currentDesktopChanged',
        'currentActivityChanged', 'screensChanged']) workspace[name] = signal();
    vm.runInNewContext(fs.readFileSync(`${__dirname}/../desktop/platform/kde/kwin-state.js`, 'utf8'), {
        workspace, callDBus: (...args) => { snapshot = JSON.parse(args.at(-1)); }
    });
    return { workspace, snapshot: () => snapshot };
}

test('should retain every candidate behind an overlay and include minimised windows only in the dock', () => {
    const observed = observe([window('base'), window('minimised', { minimized: true }),
        window('other-desktop', { desktops: ['other'] }), window('overlay'),
        window('panel', { resourceClass: 'quickshell', caption: '' })]);
    assert.deepEqual(observed.snapshot().maximized.screen, ['overlay', 'base']);
    assert.deepEqual(observed.snapshot().windows.map(w => w.id), ['overlay', 'other-desktop', 'minimised', 'base']);
});

test('should publish activation order and updated window titles', () => {
    const first = window('first');
    const second = window('second');
    const observed = observe([first, second]);
    observed.workspace.windowActivated.emit(second);
    observed.workspace.windowActivated.emit(first);
    first.caption = 'Updated title';
    first.captionChanged.emit();
    const windows = observed.snapshot().windows.sort((a, b) => b.order - a.order);
    assert.equal(windows[0].id, 'first');
    assert.equal(windows[0].title, 'Updated title');
    assert.ok(windows[0].order > windows[1].order);
});


test('should track group frames for the top bar without adding them to the dock', () => {
    for (const resourceClass of ['quickshell', 'org.quickshell']) {
        const frame = window('frame', {resourceClass, caption: 'Quickshell group: test'});
        const observed = observe([window('app'), frame]);
        assert.deepEqual(observed.snapshot().maximized.screen, ['frame', 'app']);
        assert.deepEqual(observed.snapshot().windows.map(w => w.id), ['app']);
        frame.minimized = true;
        frame.minimizedChanged.emit();
        assert.deepEqual(observed.snapshot().maximized.screen, ['app']);
    }
});

test('should omit a closed window even while its animation remains in stacking order', () => {
    const closed = window('closed');
    const state = observe([closed, window('open')]);
    state.workspace.windowRemoved.emit(closed);
    assert.deepEqual(Array.from(state.snapshot().windows, w => w.id), ['open']);
});
