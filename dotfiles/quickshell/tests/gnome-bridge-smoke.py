import dbus, dbus.service, json, subprocess, sys
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
owner = dbus.service.BusName('org.gnome.Shell', bus)
loop = GLib.MainLoop()
commands = []
state = {'ready': True, 'windows': [], 'maximized': {}, 'fullscreen': {}}
class Mock(dbus.service.Object):
    disconnected = False
    @dbus.service.method('org.dotfiles.Quickshell.Desktop', in_signature='s', out_signature='s')
    def Connect(self, hello):
        assert json.loads(hello)['version'] == 1
        return json.dumps(state)
    @dbus.service.method('org.dotfiles.Quickshell.Desktop', in_signature='s', out_signature='')
    def Command(self, payload):
        commands.append(json.loads(payload))
        self.StateChanged(json.dumps({**state, 'windows': [{'id': 'test'}]}))
    @dbus.service.signal('org.dotfiles.Quickshell.Desktop', signature='s')
    def StateChanged(self, state): pass
    @dbus.service.method('org.dotfiles.Quickshell.Desktop', in_signature='', out_signature='')
    def Disconnect(self):
        self.disconnected = True
mock = Mock(owner, '/org/dotfiles/Quickshell')
child = subprocess.Popen(['python3',sys.argv[1]], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
received = []
failed = []
def read(_source, condition):
    line = child.stdout.readline()
    if not line:return False
    received.append(json.loads(line))
    if len(received)==1:
        child.stdin.write('{"activate":"test"}\n');child.stdin.flush()
    else:child.stdin.close()
    return True
def poll():
    if child.poll() is not None:loop.quit();return False
    return True
def timeout():
    failed.append('timeout');child.kill();loop.quit();return False
GLib.io_add_watch(child.stdout, GLib.IO_IN, read)
GLib.timeout_add(50,poll)
GLib.timeout_add_seconds(5,timeout)
try:
    loop.run()
    assert not failed,failed
    assert child.wait()==0,child.stderr.read()
    assert received[0]['ready'] and received[1]['windows']==[{'id':'test'}],received
    assert commands==[{'activate':'test'}],commands
    assert mock.disconnected
    print('GNOME bridge: Connect, command forwarding, state signals and EOF cleanup passed on an isolated D-Bus.')
finally:
    if child.poll() is None:child.kill();child.wait()
