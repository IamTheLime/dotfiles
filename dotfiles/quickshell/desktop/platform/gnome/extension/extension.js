import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';
import St from 'gi://St';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {VERSION, PANEL_PREFIX, GROUP_PREFIX, validateCommand, slotsFor} from './protocol.js';

const INTERFACE = `<node><interface name="org.dotfiles.Quickshell.Desktop">
<method name="Connect"><arg name="hello" type="s" direction="in"/><arg name="state" type="s" direction="out"/></method>
<method name="Command"><arg name="command" type="s" direction="in"/></method>
<method name="Disconnect"/>
<signal name="StateChanged"><arg type="s"/></signal>
</interface></node>`;
const idOf = window => String(window.get_stable_sequence());
const maxFlags = window => window.get_maximize_flags?.() ?? window.get_maximized?.()
    ?? (window.is_maximized() ? Meta.MaximizeFlags.BOTH : 0);
const unmaximize = window => window.set_unmaximize_flags
    ? window.set_unmaximize_flags(Meta.MaximizeFlags.BOTH) : window.unmaximize(Meta.MaximizeFlags.BOTH);
const maximize = (window, flags) => window.set_maximize_flags
    ? window.set_maximize_flags(flags) : window.maximize(flags);

export default class QuickshellBridge extends Extension {
    enable() {
        this._signals = [];
        this._tracked = new Map();
        this._orders = new Map();
        this._serial = 0;
        this._owner = null;
        this._panels = new Map();
        this._groups = new Map();
        this._originals = new Map();
        this._struts = new Map();
        this._idle = 0;
        this._busy = false;
        this._panelWasVisible = Main.layoutManager.panelBox.visible;
        this._tracker = Shell.WindowTracker.get_default();
        this._object = Gio.DBusExportedObject.wrapJSObject(INTERFACE, this);
        this._object.export(Gio.DBus.session, '/org/dotfiles/Quickshell');
        this._ownerWatch = Gio.DBus.session.signal_subscribe('org.freedesktop.DBus', 'org.freedesktop.DBus',
            'NameOwnerChanged', '/org/freedesktop/DBus', null, Gio.DBusSignalFlags.NONE,
            (_connection, _sender, _path, _iface, _signal, params) => {
                const [name, , owner] = params.deep_unpack();
                if (name === this._owner && !owner) this._release();
            });
        this._connect(global.display, 'window-created', (_display, window) => this._track(window));
        this._connect(global.display, 'notify::focus-window', () => {
            const window = global.display.focus_window;
            if (window) this._orders.set(idOf(window), ++this._serial);
            this._raiseGroup(window);
            this._queue();
        });
        this._connect(global.workspace_manager, 'active-workspace-changed', () => this._queue());
        this._connect(Main.layoutManager, 'monitors-changed', () => this._queue());
        this._connect(Main.overview, 'showing', () => this._queue());
        this._connect(Main.overview, 'hidden', () => this._queue());
        for (const window of this._windows()) this._track(window);
    }

    _connect(object, signal, callback) { this._signals.push([object, object.connect(signal, callback)]); }
    _windows() { return global.get_window_actors().map(actor => actor.meta_window); }
    _find(id) { return this._windows().find(window => idOf(window) === id); }
    _track(window) {
        if (this._tracked.has(window)) return;
        const ids = [];
        const listen = signal => ids.push(window.connect(signal, () => this._queue()));
        for (const signal of ['notify::title', 'notify::minimized', 'notify::fullscreen', 'position-changed', 'size-changed', 'workspace-changed']) listen(signal);
        ids.push(window.connect('unmanaged', () => {
            this._tracked.delete(window);
            this._orders.delete(idOf(window));
            this._queue();
        }));
        this._tracked.set(window, ids);
        this._queue();
    }
    _queue() {
        if (this._idle || !this._owner) return;
        this._idle = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
            this._idle = 0;
            try {
                this._syncPanels();
                for (const group of this._groups.values()) this._syncGroup(group);
                this._object.emit_signal('StateChanged', new GLib.Variant('(s)', [JSON.stringify(this._snapshot())]));
            } catch (error) { console.error('Quickshell bridge update:', error); }
            return GLib.SOURCE_REMOVE;
        });
    }
    _monitorName(index) {
        const monitor = Main.layoutManager.monitors[index];
        for (const spec of this._panels.values())
            if (monitor && monitor.x === spec.x && monitor.y === spec.y) return spec.screen;
        return `monitor-${index}`;
    }
    _isShell(window) {
        const title = window.get_title() || '';
        return title.startsWith(PANEL_PREFIX) || title.startsWith(GROUP_PREFIX);
    }
    _snapshot() {
        const windows = [], maximized = {}, fullscreen = {};
        const workspace = global.workspace_manager.get_active_workspace();
        for (const monitor of Main.layoutManager.monitors) {
            maximized[this._monitorName(monitor.index)] = false;
            fullscreen[this._monitorName(monitor.index)] = false;
        }
        for (const window of this._windows()) {
            const title = window.get_title() || '';
            const type = window.get_window_type();
            const normal = type === Meta.WindowType.NORMAL;
            const dialog = type === Meta.WindowType.DIALOG || type === Meta.WindowType.MODAL_DIALOG;
            if (!normal && !dialog) continue;
            const screen = this._monitorName(window.get_monitor());
            if (!window.minimized && window.located_on_workspace(workspace) && !title.startsWith(PANEL_PREFIX)) {
                if (window.is_fullscreen()) fullscreen[screen] = true;
                if (maxFlags(window) === Meta.MaximizeFlags.BOTH && !window.is_fullscreen()) maximized[screen] = true;
            }
            if (this._isShell(window) || window.is_skip_taskbar()) continue;
            const app = this._tracker.get_window_app(window);
            const parent = window.get_transient_for();
            windows.push({id: idOf(window), title, appId: (app?.get_id() || '').replace(/\.desktop$/, ''),
                resourceClass: window.get_wm_class() || '', active: window === global.display.focus_window,
                minimized: window.minimized, order: this._orders.get(idOf(window)) || 0, screen,
                fullscreen: window.is_fullscreen(), dialog, parentId: parent ? idOf(parent) : ''});
        }
        return {version: VERSION, ready: true, windows, maximized, fullscreen};
    }

    ConnectAsync([hello], invocation) {
        try {
            if (JSON.parse(hello).version !== VERSION) throw new Error('Desktop protocol version mismatch');
            if (this._owner && this._owner !== invocation.get_sender()) throw new Error('Another Quickshell bridge is connected');
            this._owner = invocation.get_sender();
            invocation.return_value(new GLib.Variant('(s)', [JSON.stringify(this._snapshot())]));
            this._queue();
        } catch (error) { invocation.return_dbus_error('org.dotfiles.Quickshell.Error', String(error)); }
    }
    CommandAsync([json], invocation) {
        try {
            if (invocation.get_sender() !== this._owner) throw new Error('Connect before sending commands');
            const command = validateCommand(JSON.parse(json));
            if ('activate' in command) {
                const window = this._find(command.activate);
                if (window) Main.activateWindow(window);
            } else if ('close' in command) {
                for (const id of command.close) {
                    const window = this._find(id);
                    if (window && !this._isShell(window) && window.can_close()) window.delete(global.get_current_time());
                }
            } else if ('layout' in command) this._layout(command.layout);
            else if ('restore' in command) this._restore(command.restore);
            else if ('panel' in command) this._panels.set(command.panel.title, command.panel);
            this._queue();
            invocation.return_value(null);
        } catch (error) { invocation.return_dbus_error('org.dotfiles.Quickshell.Error', String(error)); }
    }
    DisconnectAsync(_params, invocation) {
        if (invocation.get_sender() !== this._owner) {
            invocation.return_dbus_error('org.dotfiles.Quickshell.Error', 'Not the connected bridge');
            return;
        }
        this._release();
        invocation.return_value(null);
    }
    _rect(window) {
        const rect = window.get_frame_rect();
        return {x: rect.x, y: rect.y, width: rect.width, height: rect.height};
    }
    _move(window, rect) {
        const current = window.get_frame_rect();
        if (['x', 'y', 'width', 'height'].some(key => Math.abs(current[key] - rect[key]) > 1))
            window.move_resize_frame(false, Math.round(rect.x), Math.round(rect.y), Math.round(rect.width), Math.round(rect.height));
    }
    _syncPanels() {
        let topVisible = false;
        for (const [title, spec] of this._panels) {
            const window = this._windows().find(w => w.get_title() === title);
            if (!window) {
                this._struts.get(title)?.destroy(); this._struts.delete(title);
                continue;
            }
            window.hide_from_window_list?.();
            if (!window.is_above()) window.make_above();
            if (!window.is_on_all_workspaces()) window.stick();
            const width = spec.edge === 'top' ? spec.screenWidth : spec.width;
            this._move(window, {x: spec.x + (spec.screenWidth - width) / 2,
                y: spec.edge === 'top' ? spec.y : spec.y + spec.screenHeight - spec.height,
                width, height: spec.height});
            if (spec.edge === 'top') topVisible = true;
            let strut = this._struts.get(title);
            if (spec.reserve > 0) {
                if (!strut) {
                    strut = new St.Widget({reactive: false, opacity: 0});
                    Main.layoutManager.addChrome(strut, {affectsStruts: true, affectsInputRegion: false, trackFullscreen: true});
                    this._struts.set(title, strut);
                }
                strut.set_position(spec.x, spec.y);
                strut.set_size(spec.screenWidth, spec.reserve);
            } else if (strut) { strut.destroy(); this._struts.delete(title); }
        }
        if (topVisible && !Main.overview.visible) Main.layoutManager.panelBox.hide();
        else if (this._panelWasVisible) Main.layoutManager.panelBox.show();
    }
    _layout(layout) {
        for (const id of layout.ids) {
            const window = this._find(id);
            if (!window || this._isShell(window)) throw new Error('Unknown group member: ' + id);
            if (!this._originals.has(id)) this._originals.set(id, {
                rect: this._rect(window), minimized: window.minimized,
                maximized: maxFlags(window), workspace: window.get_workspace(),
            });
        }
        const previous = this._groups.get(layout.key);
        this._groups.set(layout.key, {...layout, initialized: previous?.initialized ?? false});
        this._syncGroup(this._groups.get(layout.key));
        if (layout.focus) {
            const selected = this._find(layout.focus);
            if (selected) Main.activateWindow(selected);
        }
    }
    _syncGroup(group) {
        if (this._busy) return;
        const frame = this._windows().find(w => w.get_title() === GROUP_PREFIX + group.key);
        if (!frame) return;
        frame.hide_from_window_list?.();
        const members = group.ids.map(id => this._find(id)).filter(Boolean);
        if (members.some(window => window.is_fullscreen())) return;
        this._busy = true;
        try {
            if (!group.initialized) {
                const monitor = Main.layoutManager.monitors.find(item => this._monitorName(item.index) === group.screen);
                if (monitor && frame.get_monitor() !== monitor.index) frame.move_to_monitor(monitor.index);
                const area = frame.get_work_area_current_monitor();
                const width = Math.min(1400, area.width - 16), height = Math.min(900, area.height - 64);
                this._move(frame, {x: area.x + (area.width - width) / 2, y: area.y + 48, width, height});
                group.initialized = true;
            }
            const slots = slotsFor(frame.get_frame_rect(), group);
            for (const window of members) {
                const slot = slots.find(item => item.id === idOf(window));
                if (!slot || frame.minimized) { if (!window.minimized) window.minimize(); continue; }
                if (window.get_workspace() !== frame.get_workspace()) window.change_workspace(frame.get_workspace());
                if (maxFlags(window)) unmaximize(window);
                this._move(window, slot);
                if (window.minimized) window.unminimize();
            }
        } finally { this._busy = false; }
    }
    _raiseGroup(window) {
        if (this._busy || !window) return;
        for (const group of this._groups.values()) {
            const frame = this._windows().find(w => w.get_title() === GROUP_PREFIX + group.key);
            if (!frame || (window !== frame && !group.ids.includes(idOf(window)))) continue;
            if (group.ids.some(id => this._find(id)?.is_fullscreen())) return;
            this._busy = true;
            try {
                if (frame.minimized) frame.unminimize();
                for (const id of group.slots) this._find(id)?.raise();
                frame.raise();
            } finally { this._busy = false; }
        }
    }
    _restore(ids) {
        for (const [key, group] of this._groups)
            if (group.ids.some(id => ids.includes(id))) this._groups.delete(key);
        for (const id of ids) {
            const saved = this._originals.get(id), window = this._find(id);
            try {
                if (saved && window) {
                    unmaximize(window);
                    if (saved.workspace?.index() >= 0) window.change_workspace(saved.workspace);
                    this._move(window, saved.rect);
                    if (saved.maximized) maximize(window, saved.maximized);
                    if (saved.minimized) window.minimize(); else window.unminimize();
                }
            } catch (error) { console.error('Quickshell window restore:', id, error); }
            finally { this._originals.delete(id); }
        }
    }
    _release() {
        this._owner = null;
        this._busy = true;
        if (this._idle) { GLib.source_remove(this._idle); this._idle = 0; }
        try { this._restore([...this._originals.keys()]); }
        finally {
            this._busy = false;
            this._object.emit_signal('StateChanged', new GLib.Variant('(s)', [JSON.stringify({ready: false,
                windows: [], maximized: {}, fullscreen: {}, error: 'GNOME bridge disconnected'})]));
            this._groups.clear(); this._panels.clear();
            for (const strut of this._struts.values()) strut.destroy();
            this._struts.clear();
            if (this._panelWasVisible) Main.layoutManager.panelBox.show();
        }
    }
    disable() {
        this._release();
        this._object.unexport();
        Gio.DBus.session.signal_unsubscribe(this._ownerWatch);
        for (const [object, id] of this._signals) object.disconnect(id);
        for (const [window, ids] of this._tracked) for (const id of ids) window.disconnect(id);
        this._tracked.clear();
        this._object = null;
    }
}
