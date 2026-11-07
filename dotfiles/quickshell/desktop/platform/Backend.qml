pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "kde" as Kde
import "gnome" as Gnome

Scope {
    id: backend
    readonly property string requested: (Quickshell.env("QS_PLATFORM") || "").toLowerCase()
    readonly property string name: requested || ((Quickshell.env("XDG_CURRENT_DESKTOP") || "").toLowerCase().indexOf("gnome") >= 0 ? "gnome" : "kde")
    readonly property bool supported: name === "kde" || name === "gnome"
    readonly property var profile: profileLoader.item
    readonly property var launchers: profile ? profile.launchers : []
    readonly property var capabilities: profile ? profile.capabilities : ({})
    property var maximized: ({})
    property var fullscreen: ({})
    property var windows: []
    property bool ready: false
    property string error: supported ? "" : "Unsupported QS_PLATFORM: " + name

    LazyLoader {
        id: profileLoader
        active: backend.supported
        component: backend.name === "gnome" ? gnomeProfile : kdeProfile
    }
    Component { id: kdeProfile; Kde.Profile {} }
    Component { id: gnomeProfile; Gnome.Profile {} }

    function send(command) {
        if (!ready) { error = "Desktop bridge is not ready"; console.warn(error); return; }
        bridge.write(JSON.stringify(command) + "\n");
    }
    function activate(id) { send({activate: id}); }
    function closeWindows(ids) { send({close: ids}); }
    function openSettings(section) { if (profile) Quickshell.execDetached(profile.settingsCommand(section)); }

    Timer {
        id: reconnect
        interval: 5000
        onTriggered: bridge.running = true
    }
    Process {
        id: bridge
        command: backend.profile ? ["python3", backend.profile.bridgePath] : []
        running: backend.supported && backend.profile !== null
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const state = JSON.parse(data);
                    backend.maximized = state.maximized || {};
                    backend.fullscreen = state.fullscreen || {};
                    backend.windows = state.windows || [];
                    backend.ready = state.ready !== false;
                    backend.error = state.error || "";
                } catch (error) { backend.error = "Invalid desktop state: " + error; console.warn(backend.error); }
            }
        }
        stderr: SplitParser { onRead: data => { backend.error = data; console.warn(data); } }
        onExited: (code, status) => {
            backend.ready = false;
            backend.windows = []; backend.maximized = {}; backend.fullscreen = {};
            if (code !== 0) { backend.error = backend.name + " bridge exited: " + code; console.warn(backend.error); }
            if (backend.name === "gnome") reconnect.restart();
        }
    }
}
