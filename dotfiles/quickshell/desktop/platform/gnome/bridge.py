"""Translate the shared JSON-lines interface to the GNOME Shell extension."""
import json
import os
import signal
import sys

import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

BUS = "org.gnome.Shell"
PATH = "/org/dotfiles/Quickshell"
IFACE = "org.dotfiles.Quickshell.Desktop"


def main():
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    api = dbus.Interface(bus.get_object(BUS, PATH), IFACE)
    loop = GLib.MainLoop()
    pending = ""

    def publish(payload):
        state = json.loads(str(payload))
        print(json.dumps(state), flush=True)
        if state.get("ready") is False:
            loop.quit()

    def read_command(_source, condition):
        nonlocal pending
        if condition & GLib.IO_HUP:
            loop.quit()
            return False
        chunk = os.read(sys.stdin.fileno(), 65536).decode()
        if not chunk:
            loop.quit()
            return False
        pending += chunk
        while "\n" in pending:
            line, pending = pending.split("\n", 1)
            try:
                command = json.loads(line)
                if not isinstance(command, dict):
                    raise ValueError("Command must be an object")
                api.Command(json.dumps(command), timeout=5)
            except (ValueError, dbus.DBusException) as error:
                print(f"GNOME desktop command: {error}", file=sys.stderr, flush=True)
        return True

    def owner_changed(name, _old_owner, new_owner):
        if name == BUS and not new_owner:
            print(json.dumps({"ready": False, "error": "GNOME Shell disconnected"}), flush=True)
            loop.quit()

    updates = api.connect_to_signal("StateChanged", publish)
    owner_watch = bus.add_signal_receiver(owner_changed, signal_name="NameOwnerChanged",
                                          dbus_interface="org.freedesktop.DBus", arg0=BUS)
    connected = False
    try:
        publish(api.Connect(json.dumps({"version": 1}), timeout=5))
        connected = True
        GLib.io_add_watch(sys.stdin, GLib.IO_IN | GLib.IO_HUP, read_command)
        signal.signal(signal.SIGTERM, lambda *_: loop.quit())
        signal.signal(signal.SIGINT, lambda *_: loop.quit())
        loop.run()
    finally:
        updates.remove()
        owner_watch.remove()
        if connected:
            try:
                api.Disconnect(timeout=3)
            except dbus.DBusException as error:
                print(f"GNOME bridge cleanup: {error}", file=sys.stderr)


if __name__ == "__main__":
    try:
        main()
    except (dbus.DBusException, OSError, ValueError) as error:
        print("GNOME bridge unavailable. Install and enable the dotfiles Quickshell extension: " + str(error), file=sys.stderr)
        sys.exit(1)
