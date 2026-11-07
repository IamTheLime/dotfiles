import os
import sys

import dbus

try:
    manager = dbus.Interface(dbus.SystemBus().get_object("org.freedesktop.login1", "/org/freedesktop/login1"), "org.freedesktop.login1.Manager")
    descriptor = manager.Inhibit("sleep", "Quickshell Keep awake", "Remote access while the screen may turn off", "block").take()
except dbus.DBusException as error:
    print(f"Could not prevent sleep: {error.get_dbus_message()}", file=sys.stderr)
    sys.exit(1)

try:
    print("ready", flush=True)
    sys.stdin.read()
finally:
    os.close(descriptor)
