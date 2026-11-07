const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const {test} = require('node:test');
const base = `${__dirname}/../desktop/platform/gnome/extension`;
const protocol = import('data:text/javascript;base64,' + Buffer.from(fs.readFileSync(`${base}/protocol.js`, 'utf8')).toString('base64'));

function extension(api) {
    const source = fs.readFileSync(`${base}/extension.js`, 'utf8').replace(/^import .*;\n/gm, '')
        .replace('export default class QuickshellBridge extends Extension', 'globalThis.Bridge = class QuickshellBridge extends Extension');
    const context = vm.createContext({...api, console, Extension: class {},
        Meta: {MaximizeFlags: {BOTH: 3}, WindowType: {NORMAL: 0, DIALOG: 1, MODAL_DIALOG: 2}},
        global: {get_current_time: () => 1}, Main: {activateWindow: () => {}},
        GLib: {Variant: class {constructor(type, value) {this.value = value;}}}});
    vm.runInContext(source, context);
    return new context.Bridge();
}

test('should reject malformed layouts and preserve a shared two-pane geometry', async () => {
    const api = await protocol;
    const layout = {key: 'group', ids: ['a', 'b'], slots: ['a', 'b'], screen: 'DP-1', focus: 'a', ratio: 0.6};
    assert.equal(api.validateCommand({layout}).layout, layout);
    assert.throws(() => api.validateCommand({layout: {...layout, slots: ['a', 'missing']}}));
    assert.throws(() => api.validateCommand({layout: {...layout, ratio: NaN}}));
    assert.throws(() => api.validateCommand({activate: 'a', close: ['b']}));
    assert.throws(() => api.validateCommand({eval: 'anything'}));
    const slots = api.slotsFor({x: 10, y: 20, width: 1000, height: 700}, layout);
    assert.equal(slots[1].x - slots[0].x - slots[0].width, 8);
    assert.equal(slots[1].x + slots[1].width, 1006);
    assert.equal(slots[0].y, 60);
    assert.equal(slots[0].height, 656);
});

test('should accept bounded panel placement and reject non-panel titles', async () => {
    const {validateCommand} = await protocol;
    const panel = {title: 'Quickshell panel: top:DP-1', screen: 'DP-1', edge: 'top', x: 0, y: 0,
        width: 1920, height: 48, screenWidth: 1920, screenHeight: 1080, reserve: 34};
    assert.equal(validateCommand({panel}).panel, panel);
    assert.throws(() => validateCommand({panel: {...panel, title: 'Browser'}}));
    assert.throws(() => validateCommand({panel: {...panel, reserve: 999}}));
});

test('should reject commands from an unconnected D-Bus caller', async () => {
    const bridge = extension(await protocol);
    bridge._owner = ':1.100';
    let error;
    bridge.CommandAsync([JSON.stringify({close: ['a']})], {
        get_sender: () => ':1.200', return_dbus_error: (_name, message) => {error = message;},
    });
    assert.match(error, /Connect before/);
});

test('should restore grouped windows without closing apps and forget saved state', async () => {
    const bridge = extension(await protocol);
    const calls = [];
    const window = {unmaximize: value => calls.push(['unmaximize', value]),
        change_workspace: value => calls.push(['workspace', value]),
        maximize: value => calls.push(['maximize', value]), minimize: () => calls.push(['minimize']),
        unminimize: () => calls.push(['unminimize'])};
    const rect = {x: 25, y: 30, width: 500, height: 400};
    bridge._groups = new Map([['g', {ids: ['a', 'gone']}]]);
    bridge._originals = new Map([['a', {rect, minimized: false, maximized: 3}], ['gone', {rect}]]);
    bridge._find = id => id === 'a' ? window : null;
    bridge._move = (actual, bounds) => {assert.equal(actual, window); assert.equal(bounds, rect);};
    bridge._restore(['a', 'gone']);
    assert.deepEqual(calls, [['unmaximize', 3], ['maximize', 3], ['unminimize']]);
    assert.equal(bridge._groups.size, 0);
    assert.equal(bridge._originals.size, 0);
});
