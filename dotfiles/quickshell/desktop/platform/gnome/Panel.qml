import QtQuick
import Quickshell
import ".."
FloatingWindow {
    id: panel
    required property var spec
    screen: spec.screen
    visible: spec.visible && Backend.ready
    implicitWidth: spec.implicitWidth
    implicitHeight: spec.implicitHeight
    color: spec.color
    mask: spec.mask
    title: "Quickshell panel: " + spec.role + ":" + spec.screen.name
    function sync() {
        if (Backend.ready) Backend.send({panel: {title: title, screen: spec.screen.name,
            x: spec.screen.x, y: spec.screen.y, screenWidth: spec.screen.width, screenHeight: spec.screen.height,
            width: width, height: height, edge: spec.edge, reserve: spec.visible ? spec.exclusiveZone : 0}});
    }
    Timer { id: layoutTimer; interval: 40; onTriggered: panel.sync() }
    onVisibleChanged: layoutTimer.restart()
    onWidthChanged: layoutTimer.restart()
    onHeightChanged: layoutTimer.restart()
    onTitleChanged: layoutTimer.restart()
    Connections { target: spec; function onExclusiveZoneChanged() { layoutTimer.restart(); } }
    Connections { target: Backend; function onReadyChanged() { layoutTimer.restart(); } }
    Connections { target: spec.screen; function onGeometryChanged() { layoutTimer.restart(); } }
    Component.onCompleted: layoutTimer.start()
}
