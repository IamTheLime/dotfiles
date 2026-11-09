import QtQuick
import Quickshell.Io
import Quickshell.Services.SystemTray
import "theme"
import "TrayIcons.js" as TrayIcons

Item {
    id: icon
    required property var itemData
    property bool hovered: false
    property real pixelRatio: 1
    readonly property string customName: TrayIcons.name(itemData)
    readonly property bool retainedTint: !customName && TrayIcons.keepTint(itemData)
    property string svg: ""
    FileView {
        path: icon.customName ? Qt.resolvedUrl("icons/tray/" + icon.customName + ".svg").toString().replace("file://", "") : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: icon.svg = text()
        onLoadFailed: error => { icon.svg = ""; console.warn("Tray SVG unavailable:", icon.customName, error); }
    }
    Image {
        id: artwork
        anchors.fill: parent
        source: icon.customName && icon.svg
            ? "data:image/svg+xml," + encodeURIComponent(icon.svg.replace(/#c0caf5/g, Theme.trayIconBright.toString()).replace(/#283457/g, Theme.trayIconDark.toString()))
            : icon.itemData.icon
        sourceSize: Qt.size(40 * icon.pixelRatio, 40 * icon.pixelRatio)
        smooth: true
        mipmap: true
        visible: !icon.retainedTint
    }
    PaletteIcon {
        anchors.fill: parent
        source: artwork
        hovered: icon.hovered
        visible: icon.retainedTint
    }
    Rectangle {
        visible: !!icon.customName && icon.itemData.status === Status.NeedsAttention
        anchors.right: parent.right; anchors.top: parent.top
        width: 5; height: 5; radius: 2.5
        color: Theme.accent
    }
}
