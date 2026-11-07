import QtQuick
import Quickshell
import "../platform"
import "../platform/kde" as Kde
import "../platform/gnome" as Gnome

Scope {
    id: surface
    default property alias contents: content.data
    required property var screen
    required property string role
    required property string edge
    property bool visible: true
    property real implicitWidth: screen ? screen.width : 1
    property real implicitHeight: 48
    property int exclusiveZone: 0
    property color color: "transparent"
    property Region mask: null
    property Region blurRegion: null
    readonly property var window: host.item
    readonly property Item contentItem: content
    readonly property real width: window ? window.width : implicitWidth
    readonly property real height: window ? window.height : implicitHeight

    property Item content: Item {
        id: content
        parent: surface.window ? surface.window.contentItem : null
        width: surface.width; height: surface.height
    }
    property LazyLoader host: LazyLoader {
        id: host
        active: Backend.supported
        component: Backend.name === "gnome" ? gnomeWindow : kdeWindow
    }
    property Component kdeWindow: Component { id: kdeWindow; Kde.Panel { spec: surface } }
    property Component gnomeWindow: Component { id: gnomeWindow; Gnome.Panel { spec: surface } }
}
