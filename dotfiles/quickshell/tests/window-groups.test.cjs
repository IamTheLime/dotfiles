const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { test } = require('node:test');
const base = `${__dirname}/../desktop/shared`;
const qml = fs.readFileSync(`${base}/WindowGroups.qml`, 'utf8');
const theme = fs.readFileSync(`${base}/theme/Theme.qml`, 'utf8');
const splitPalette = JSON.parse(theme.match(/property var splitPalette: (\[[^\n]+\])/)[1]);
function method(name) {
    const start = qml.indexOf(`function ${name}(`);
    let depth = 0;
    for (let i = qml.indexOf('{', start); i < qml.length; ++i) {
        if (qml[i] === '{') ++depth;
        if (qml[i] === '}' && --depth === 0) return qml.slice(start, i + 1);
    }
    throw new Error(`Missing function ${name}`);
}
function controller(windows) {
    const context = vm.createContext({ windows, groups: [], suppressed: [], knownWindowIds: [], command: () => {},
        Theme: { splitPalette }, DesktopEntries: { heuristicLookup: () => null } });
    vm.runInContext(['appId', 'project', 'keyFor', 'destination', 'members', 'addWindow', 'get', 'replace', 'arrange',
        'groupApp', 'editGroup', 'groupNamed', 'pairFor', 'tabOrder', 'tabBlocks', 'select', 'nextSplitColor', 'split', 'unsplit', 'swapPanes', 'resizeSplit', 'ungroup', 'reconcile', 'activeGroup'].map(method).join('\n'), context);
    return context;
}
function window(id, title, extra = {}) {
    return { id, title, appId: 'org.kicad.KiCad', resourceClass: 'KiCad', screen: 'screen', ...extra };
}
test('should keep KiCad projects separate and exclude child dialogs', () => {
    const state = controller([window('pcb', 'keyboard — PCB'), window('schema', 'keyboard — Schematic'),
        window('other', 'other — PCB'), window('dialog', 'keyboard — Settings', {parentId: 'pcb', dialog: true})]);
    state.groupApp('pcb');
    assert.deepEqual(Array.from(state.groups[0].ids).sort(), ['pcb', 'schema']);
    assert.equal(state.groups[0].name, 'keyboard');
});
test('should select a new editor, split without duplicate panes, and honour Ungroup', () => {
    const state = controller([window('pcb', 'keyboard — PCB'), window('schema', 'keyboard — Schematic')]);
    state.groupApp('pcb');
    const key = state.groups[0].key;
    state.windows.push(window('3d', 'keyboard — 3D', {active: true}));
    state.reconcile();
    assert.deepEqual(Array.from(state.groups[0].slots), ['3d']);
    state.split(key, 'schema', true);
    assert.deepEqual(Array.from(state.groups[0].slots), ['schema', '3d']);
    state.select(key, 'pcb');
    assert.deepEqual(Array.from(state.groups[0].slots), ['pcb']);
    state.select(key, '3d');
    assert.deepEqual(Array.from(state.groups[0].slots), ['schema', '3d']);
    state.select(key, 'schema');
    assert.deepEqual(Array.from(state.groups[0].slots), ['schema', '3d']);
    state.ungroup(key);
    state.reconcile();
    assert.equal(state.groups.length, 0);
});
test('should allow opt-in grouping for other multi-window apps', () => {
    const state = controller([window('one', 'Terminal A', {appId: 'ghostty'}), window('two', 'Terminal B', {appId: 'ghostty'})]);
    state.reconcile();
    assert.equal(state.groups.length, 0);
    state.groupApp('one');
    assert.equal(state.groups[0].ids.length, 2);
});
test('should keep panes aligned when their frame moves and resizes', () => {
    function signal() { let handler; return {connect: value => { handler = value; }, emit: () => handler()}; }
    const windows = ['one', 'two', 'other'].map(id => ({internalId: id, activities: [], setMaximize: () => {}}));
    const frame = {internalId: 'frame', caption: 'Quickshell group: test', frameGeometry: {x: 100, y: 200, width: 1000, height: 800},
        desktops: ['desktop'], activities: [], frameGeometryChanged: signal(), minimizedChanged: signal(),
        desktopsChanged: signal(), activitiesChanged: signal()};
    const workspace = {windowList: () => [...windows, frame], raiseWindow: () => {},
        windowAdded: signal(), windowActivated: signal()};
    vm.runInNewContext(fs.readFileSync(`${base}/../platform/kde/kwin-group-layout.js`, 'utf8'), {
        layout: {key: 'test', ids: ['one', 'two'], slots: ['one', 'two'], focus: 'two', initial: false}, workspace
    });
    assert.equal(windows[0].frameGeometry.y, 240);
    assert.ok(windows[0].frameGeometry.x + windows[0].frameGeometry.width < windows[1].frameGeometry.x);
    assert.equal(windows[2].frameGeometry, undefined);
    assert.equal(workspace.activeWindow, windows[1]);
    frame.frameGeometry = {x: 200, y: 300, width: 1200, height: 900};
    frame.frameGeometryChanged.emit();
    assert.equal(windows[0].frameGeometry.x, 204);
    assert.equal(windows[1].frameGeometry.y, 340);
    assert.equal(windows[1].frameGeometry.width, 592);
    assert.equal(windows[1].frameGeometry.height, 856);
    frame.minimized = true;
    frame.minimizedChanged.emit();
    assert.equal(windows[0].minimized, true);
    assert.equal(windows[1].minimized, true);
});

test('should restore the split when returning from an independent tab', () => {
    const state = controller([window('pcb', 'keyboard — PCB'), window('schema', 'keyboard — Schematic'), window('3d', 'keyboard — 3D')]);
    state.groupApp('pcb');
    const key = state.groups[0].key;
    state.split(key, 'schema', true);
    state.windows[0].active = true;
    state.reconcile();
    state.select(key, '3d');
    assert.deepEqual(Array.from(state.groups[0].slots), ['3d']);
    state.select(key, 'pcb');
    assert.deepEqual(Array.from(state.groups[0].slots), ['schema', 'pcb']);
});

test('should retain the divider ratio when changing tabs and clamp extreme widths', () => {
    const state = controller([window('pcb', 'keyboard — PCB'), window('schema', 'keyboard — Schematic'), window('3d', 'keyboard — 3D')]);
    state.groupApp('pcb');
    const key = state.groups[0].key;
    state.split(key, 'schema', true);
    state.resizeSplit(key, 0.65);
    state.select(key, '3d');
    assert.equal(state.groups[0].ratio, 0.65);
    state.select(key, 'schema');
    state.resizeSplit(key, 0.99);
    assert.equal(state.groups[0].ratio, 0.8);
});

test('should retain membership when an editor changes title and adopt new app windows', () => {
    const state = controller([window('pcb', 'keyboard — PCB'), window('schema', 'keyboard — Schematic')]);
    state.groupApp('pcb');
    state.windows[1].title = 'left [keyboard/Left] — Schematic Editor';
    state.windows[1].active = true;
    state.reconcile();
    assert.deepEqual(Array.from(state.groups[0].ids).sort(), ['pcb', 'schema']);
    state.windows.push(window('new', 'Unrelated title'), window('dialog', 'Settings', {dialog: true, parentId: 'pcb'}));
    state.reconcile();
    assert.deepEqual(Array.from(state.groups[0].ids).sort(), ['new', 'pcb', 'schema']);
});
test('should route new windows to their parent group before the last active app group', () => {
    const state = controller([window('a', 'A — PCB'), window('b', 'A — Schema'),
        window('c', 'B — PCB', {order: 10}), window('d', 'B — Schema')]);
    state.groupApp('a');
    state.groupApp('c');
    state.windows.push(window('child', 'New document', {parentId: 'a'}), window('recent', 'New editor'));
    state.reconcile();
    assert.ok(state.groups[0].ids.includes('child'));
    assert.ok(!state.groups[0].ids.includes('recent'));
    assert.ok(state.groups[1].ids.includes('recent'));
    assert.ok(!state.groups[1].ids.includes('child'));
});
test('should retain a single member and adopt a later generic app window', () => {
    const state = controller([window('one', 'A', {appId: 'ghostty'}), window('two', 'B', {appId: 'ghostty'})]);
    state.groupApp('one');
    state.windows = [state.windows[0]];
    state.reconcile();
    assert.equal(state.groups.length, 1);
    state.windows.push(window('three', 'C', {appId: 'ghostty'}));
    state.reconcile();
    assert.deepEqual(Array.from(state.groups[0].ids), ['one', 'three']);
});
test('should restore controls even with stale or missing saved decorations', () => {
    const windows = ['stale', 'missing', 'unrelated'].map(id => ({internalId: id, noBorder: true, setMaximize: () => {}}));
    const saved = {stale: {noBorder: true, desktops: [], activities: [], x: 10, y: 20, width: 800, height: 600}, missing: null};
    vm.runInNewContext(fs.readFileSync(`${base}/../platform/kde/kwin-group-restore.js`, 'utf8'), {
        saved, workspace: {windowList: () => windows, desktops: []}
    });
    assert.equal(windows[0].noBorder, false);
    assert.equal(windows[1].noBorder, false);
    assert.equal(windows[2].noBorder, true);
    assert.equal(windows[0].frameGeometry.width, 800);
});

test('should rename and recolour a group without changing its identity or split', () => {
    const state = controller([window('pcb', 'keyboard — PCB'), window('schema', 'keyboard — Schematic')]);
    state.groupNamed('pcb', '  Keyboard design  ', '#9edbbb');
    const key = state.groups[0].key;
    state.split(key, 'schema', true);
    state.resizeSplit(key, 0.65);
    state.editGroup(key, 'Electronics', '#c6b0ef');
    state.windows[1].title = 'Other sheet — Schematic';
    state.reconcile();
    const group = state.groups[0];
    assert.equal(group.key, key);
    assert.equal(group.name, 'Electronics');
    assert.equal(group.accent, '#c6b0ef');
    assert.equal(group.ratio, 0.65);
    assert.deepEqual(Array.from(group.slots), ['schema', 'pcb']);
    state.editGroup(key, '   ', '#9edbbb');
    state.editGroup(key, 'Invalid', 'not-a-colour');
    assert.equal(state.groups[0].name, 'Electronics');
});

test('should remember separate pairs and ratios, swap panes, and explicitly unsplit', () => {
    const state = controller(['a', 'b', 'c', 'd'].map(id => window(id, id, {appId: 'test'})));
    state.groupApp('a');
    const key = state.groups[0].key;
    state.split(key, 'b', false);
    state.resizeSplit(key, 0.6);
    state.select(key, 'c');
    state.split(key, 'd', false);
    state.resizeSplit(key, 0.3);
    state.select(key, 'a');
    assert.deepEqual(Array.from(state.groups[0].slots), ['a', 'b']);
    assert.equal(state.groups[0].ratio, 0.6);
    state.swapPanes(key);
    assert.deepEqual(Array.from(state.groups[0].slots), ['b', 'a']);
    assert.equal(state.groups[0].ratio, 0.4);
    assert.equal(state.groups[0].focusedSlot, 1);
    state.select(key, 'd');
    assert.deepEqual(Array.from(state.groups[0].slots), ['c', 'd']);
    assert.equal(state.groups[0].ratio, 0.3);
    state.unsplit(key);
    assert.deepEqual(Array.from(state.groups[0].slots), ['d']);
    assert.equal(state.groups[0].ids.length, 4);
    state.select(key, 'c');
    assert.deepEqual(Array.from(state.groups[0].slots), ['c']);
    state.select(key, 'b');
    assert.deepEqual(Array.from(state.groups[0].slots), ['b', 'a']);
});
test('should remove pair memory when a member closes and avoid overlapping pairs', () => {
    const state = controller(['a', 'b', 'c'].map(id => window(id, id, {appId: 'test'})));
    state.groupApp('a');
    const key = state.groups[0].key;
    state.split(key, 'b', false);
    state.select(key, 'c');
    state.split(key, 'b', false);
    assert.equal(state.groups[0].pairs.length, 1);
    assert.deepEqual(Array.from(state.groups[0].pairs[0].ids), ['c', 'b']);
    state.windows = state.windows.filter(w => w.id !== 'b');
    state.reconcile();
    assert.equal(state.groups[0].pairs.length, 0);
    assert.deepEqual(Array.from(state.groups[0].slots), ['c']);
});

test('should keep split tabs in one block and unpair an inactive block without switching views', () => {
    const state = controller(['a', 'b', 'c'].map(id => window(id, id, {appId: 'test'})));
    state.groupApp('a');
    const key = state.groups[0].key;
    state.split(key, 'b', false);
    assert.equal(JSON.stringify(state.tabBlocks(state.groups[0])), JSON.stringify([['a', 'b'], ['c']]));
    state.select(key, 'c');
    state.unsplit(key, 'a');
    assert.deepEqual(Array.from(state.groups[0].slots), ['c']);
    assert.equal(JSON.stringify(state.tabBlocks(state.groups[0])), JSON.stringify([['a'], ['b'], ['c']]));
    assert.equal(state.groups[0].ids.length, 3);
});

test('should give split pairs distinct stable colours across selection, resizing and swapping', () => {
    const state = controller(['a', 'b', 'c', 'd'].map(id => window(id, id, {appId: 'test'})));
    state.groupApp('a');
    const key = state.groups[0].key;
    state.split(key, 'b', false);
    const firstColor = state.groups[0].pairs[0].color;
    state.select(key, 'c');
    state.split(key, 'd', false);
    const secondColor = state.pairFor(state.groups[0], 'c').color;
    assert.notEqual(firstColor, secondColor);
    state.select(key, 'a');
    state.resizeSplit(key, 0.7);
    state.swapPanes(key);
    state.editGroup(key, 'Design', '#eeae94');
    assert.equal(state.pairFor(state.groups[0], 'a').color, firstColor);
    assert.equal(state.pairFor(state.groups[0], 'c').color, secondColor);
    state.unsplit(key);
    assert.equal(state.pairFor(state.groups[0], 'c').color, secondColor);
});
