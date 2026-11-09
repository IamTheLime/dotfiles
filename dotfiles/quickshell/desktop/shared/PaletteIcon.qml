import QtQuick
import "theme"

ShaderEffect {
    required property var source
    property bool hovered: false
    property color darkColor: Theme.trayIconDark
    property color brightColor: Theme.trayIconBright
    property real contrast: Theme.trayIconContrast
    property real hoverBoost: hovered ? Theme.trayIconHoverBoost : 0
    Behavior on hoverBoost { NumberAnimation { duration: 120 } }
    fragmentShader: Qt.resolvedUrl("shaders/tray-palette.frag.qsb")
}
