import QtQuick
import Quickshell
QtObject {
    readonly property string bridgePath: Quickshell.shellPath("platform/gnome/bridge.py")
    readonly property var capabilities: ({panels: true, blur: false, grouping: true, decorationRemoval: false, nativePanelReservation: false, experimental: true})
    readonly property var launchers: [
        {name: "Files", appId: "org.gnome.Nautilus", icon: "system-file-manager", command: ["nautilus"]},
        {name: "Terminal", appId: "org.gnome.Console", icon: "utilities-terminal", command: ["kgx"]},
        {name: "Steam", appId: "steam", icon: "steam", command: ["steam"]},
        {name: "Settings", appId: "org.gnome.Settings", icon: "preferences-system", command: ["gnome-control-center"]}
    ]
    function settingsCommand(section) { return ["gnome-control-center", section === "audio" ? "sound" : "bluetooth"]; }
}
