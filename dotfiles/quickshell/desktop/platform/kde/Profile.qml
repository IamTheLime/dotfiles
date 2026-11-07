import QtQuick
import Quickshell
QtObject {
    readonly property string bridgePath: Quickshell.shellPath("platform/kde/kwin-state.py")
    readonly property var capabilities: ({panels: true, blur: true, grouping: true, decorationRemoval: true, nativePanelReservation: true})
    readonly property var launchers: [
        {name: "Files", appId: "org.kde.dolphin", icon: "system-file-manager", command: ["dolphin"]},
        {name: "Terminal", appId: "org.kde.konsole", icon: "utilities-terminal", command: ["konsole"]},
        {name: "Steam", appId: "steam", icon: "steam", command: ["steam"]},
        {name: "Settings", appId: "systemsettings", icon: "preferences-system", command: ["systemsettings"]}
    ]
    function settingsCommand(section) { return section === "audio" ? ["systemsettings", "kcm_pulseaudio"] : ["systemsettings", "kcm_bluetooth"]; }
}
