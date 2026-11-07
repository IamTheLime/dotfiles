import json
import hashlib
import os
import re
from pathlib import Path
import signal
import sys
import tempfile
import uuid

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib


class State(dbus.service.Object):
    @dbus.service.method("org.dotfiles.Quickshell.State", in_signature="ss")
    def ActionFinished(self, token, error):
        callback = self.actions.get(str(token))
        if callback:
            callback(str(error))

    @dbus.service.method("org.dotfiles.Quickshell.State", in_signature="s")
    def Update(self, payload):
        snapshot = json.loads(payload)
        windows = snapshot["maximized"]
        kwin = dbus.Interface(self.connection.get_object("org.kde.KWin", "/KWin"), "org.kde.KWin")
        state = {}
        fullscreen = {}
        for output, window_ids in windows.items():
            state[output] = False
            fullscreen[output] = False
            for window_id in window_ids:
                info = kwin.getWindowInfo(window_id)
                if info.get("fullscreen"):
                    fullscreen[output] = True
                if info.get("maximizeHorizontal") and info.get("maximizeVertical") and not info.get("fullscreen"):
                    state[output] = True
        print(json.dumps({"maximized": state, "fullscreen": fullscreen, "windows": snapshot["windows"]}), flush=True)


def main():
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    name = f"org.dotfiles.Quickshell.State.p{os.getpid()}"
    owner = dbus.service.BusName(name, bus=bus, do_not_queue=True)
    state = State(owner, "/State")
    state.actions = {}
    scripting = dbus.Interface(bus.get_object("org.kde.KWin", "/Scripting"), "org.kde.kwin.Scripting")
    runtime_dir = Path(os.environ["XDG_RUNTIME_DIR"])
    for previous in runtime_dir.glob("quickshell-kwin-*.js"):
        names = set(re.findall(r"org\.dotfiles\.Quickshell\.State\.p\d+", previous.read_text()))
        if len(names) == 1:
            previous_name = names.pop()
            if not bus.name_has_owner(previous_name):
                scripting.unloadScript(previous_name)
                previous.unlink(missing_ok=True)
    for previous in runtime_dir.glob("quickshell-groups-*.json"):
        try:
            record = json.loads(previous.read_text())
        except (OSError, ValueError) as error:
            print(f"Quickshell group cleanup: {error}", file=sys.stderr)
            continue
        previous_owner = record.get("owner", "")
        if re.fullmatch(r"org\.dotfiles\.Quickshell\.State\.p\d+", previous_owner) and not bus.name_has_owner(previous_owner):
            for script_name in record.get("scripts", []):
                if script_name.startswith(previous_owner + ".group"):
                    scripting.unloadScript(script_name)
            previous.unlink(missing_ok=True)
    loop = GLib.MainLoop()
    signal.signal(signal.SIGTERM, lambda *_: loop.quit())
    signal.signal(signal.SIGINT, lambda *_: loop.quit())
    pending = ""

    originals = {}
    group_scripts = {}
    manifest = runtime_dir / f"quickshell-groups-{os.getpid()}.json"

    def save_groups():
        with tempfile.NamedTemporaryFile(mode="w", dir=runtime_dir, delete=False) as record:
            json.dump({"owner": name, "scripts": [group["name"] for group in group_scripts.values()]}, record)
            temporary = Path(record.name)
        temporary.replace(manifest)

    def run_action(source, persistent_name=None):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".js", dir=runtime_dir) as script:
            token = uuid.uuid4().hex
            acknowledgement = "callDBus(%s, '/State', 'org.dotfiles.Quickshell.State', 'ActionFinished', %s, actionError);" % (json.dumps(name), json.dumps(token))
            script.write("let actionError = ''; try {\n" + source + "\n} catch (error) { actionError = String(error); }\n" + acknowledgement)
            script.flush()
            activation_name = persistent_name or name + ".activate"
            script_id = bus.call_blocking("org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", "loadScript", "ss", (script.name, activation_name))
            if script_id < 0:
                raise RuntimeError("KWin could not load window activation")
            action_loop = GLib.MainLoop()
            result = []
            def finished(error):
                result.append(error)
                action_loop.quit()
            state.actions[token] = finished
            timeout = GLib.timeout_add(3000, lambda: (action_loop.quit(), False)[1])
            try:
                # KWin 6.7 assigns script IDs from list size, so IDs can collide after unloading.
                # start() reaches pending scripts directly; acknowledge before removing their files.
                scripting.start()
                action_loop.run()
                if not result:
                    raise RuntimeError("KWin window action timed out")
                if result[0]:
                    raise RuntimeError(result[0])
            finally:
                if result:
                    GLib.source_remove(timeout)
                state.actions.pop(token, None)
                if not persistent_name:
                    scripting.unloadScript(activation_name)

    def activate(window_id):
        source = """const window = workspace.windowList().find(w => w.internalId.toString() === %s);
if (window) {
    if (!window.onAllDesktops && window.desktops.length) workspace.currentDesktop = window.desktops[0];
    if (window.activities.length && window.activities.indexOf(workspace.currentActivity) < 0)
        workspace.currentActivity = window.activities[0];
    window.minimized = false;
    workspace.activeWindow = window;
}""" % json.dumps(window_id)
        run_action(source)

    def close_windows(ids):
        if not all(isinstance(value, str) for value in ids):
            raise ValueError("Close window IDs must be strings")
        source = "const ids = " + json.dumps(ids) + ";\n" + Path(__file__).with_name("kwin-close.js").read_text()
        run_action(source)

    def group_layout(layout):
        ids = layout["ids"]
        if not ids or not all(isinstance(value, str) for value in ids):
            raise ValueError("Group window IDs must be nonempty strings")
        slots = layout["slots"]
        if len(slots) not in (1, 2) or len(set(slots)) != len(slots) or any(value not in ids for value in slots):
            raise ValueError("A group must show one or two of its windows")
        kwin = dbus.Interface(bus.get_object("org.kde.KWin", "/KWin"), "org.kde.KWin")
        for window_id in ids:
            if window_id not in originals:
                info = kwin.getWindowInfo(window_id)
                if info:
                    originals[window_id] = dict(info)
        key = layout["key"]
        previous = group_scripts.get(key)
        layout["initial"] = previous is None
        script_name = name + ".group" + hashlib.sha256(key.encode()).hexdigest()[:12]
        if previous:
            scripting.unloadScript(previous["name"])
        source = Path(__file__).with_name("kwin-group-layout.js").read_text()
        group_scripts[key] = {"name": script_name, "ids": ids}
        save_groups()
        run_action("const layout = " + json.dumps(layout) + ";\n" + source, script_name)

    def restore_windows(ids):
        for key, group in list(group_scripts.items()):
            if any(window_id in ids for window_id in group["ids"]):
                scripting.unloadScript(group["name"])
                del group_scripts[key]
        save_groups()
        saved = {window_id: originals.get(window_id) for window_id in ids}
        if saved:
            source = Path(__file__).with_name("kwin-group-restore.js").read_text()
            run_action("const saved = " + json.dumps(saved) + ";\n" + source)
            for window_id in saved:
                originals.pop(window_id, None)

    def read_command(_source, condition):
        nonlocal pending
        if condition & GLib.IO_HUP:
            loop.quit()
            return False
        pending += os.read(sys.stdin.fileno(), 65536).decode()
        while "\n" in pending:
            line, pending = pending.split("\n", 1)
            try:
                command = json.loads(line)
                if isinstance(command.get("activate"), str):
                    activate(command["activate"])
                elif isinstance(command.get("close"), list):
                    close_windows(command["close"])
                elif isinstance(command.get("layout"), dict):
                    group_layout(command["layout"])
                elif isinstance(command.get("restore"), list):
                    restore_windows(command["restore"])
            except (dbus.DBusException, OSError, ValueError, RuntimeError, KeyError, TypeError) as error:
                print(f"Quickshell window activation: {error}", file=sys.stderr)
        return True

    GLib.io_add_watch(sys.stdin, GLib.IO_IN | GLib.IO_HUP, read_command)
    source = Path(__file__).with_suffix(".js").read_text().replace("__BUS_NAME__", name)
    with tempfile.NamedTemporaryFile(mode="w", suffix=".js", prefix="quickshell-kwin-", dir=os.environ["XDG_RUNTIME_DIR"]) as script:
        script.write(source)
        script.flush()
        script_id = bus.call_blocking("org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", "loadScript", "ss", (script.name, name))
        if script_id < 0:
            raise RuntimeError("KWin could not load the Quickshell window-state helper")
        try:
            scripting.start()
            loop.run()
        finally:
            try:
                restore_windows(list(originals))
            finally:
                for group in group_scripts.values():
                    scripting.unloadScript(group["name"])
                manifest.unlink(missing_ok=True)
                scripting.unloadScript(name)
                state.remove_from_connection()


if __name__ == "__main__":
    try:
        main()
    except (dbus.DBusException, OSError, ValueError, RuntimeError) as error:
        print(f"Quickshell KWin helper: {error}", file=sys.stderr)
        sys.exit(1)
