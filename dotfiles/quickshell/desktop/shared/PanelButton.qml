import "theme"
import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
Button {
    id: button
    property string symbol: ""
    property color iconTint: Theme.icon
    readonly property string customIcon: ({"ungroup-all": "ungroup-all", "unsplit": "unsplit", "swap-panes": "swap-panes", "configure": "controls", "preferences-system-bluetooth": "bluetooth", "audio-volume-high": "volume", "audio-volume-muted": "volume-muted"})[symbol] || ""
    property bool accent: false
    property int labelElide: Text.ElideRight
    implicitHeight: 38
    implicitWidth: Math.max(38, body.implicitWidth + leftPadding + rightPadding + 2)
    leftPadding: flat ? 6 : 14
    rightPadding: flat ? 6 : 14
    hoverEnabled: true
    scale: down ? 0.95 : flat && hovered ? 1.08 : 1
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
    background: Rectangle {
        radius: height / 2
        color: button.flat ? "transparent" : button.accent ? (button.hovered ? Theme.buttonActiveHover : Theme.buttonActive) : button.hovered ? Theme.buttonHover : Theme.button
        Behavior on color { ColorAnimation { duration: 130 } }
        border.width: button.visualFocus ? 1 : 0
        border.color: Theme.focus
        opacity: button.enabled ? 1 : 0.45
    }
    contentItem: Item {
        id: body
        implicitWidth: (button.symbol ? 18 : 0) + (button.symbol && button.text ? 8 : 0) + caption.implicitWidth
        implicitHeight: 18
        opacity: !button.enabled ? 0.45 : button.flat && !button.hovered ? 0.78 : 1
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Row {
            anchors.centerIn: parent
            spacing: button.symbol && button.text ? 8 : 0
            IconImage {
                visible: button.symbol !== ""
                width: 18; height: 18
                layer.enabled: button.iconTint.a > 0
                layer.effect: MultiEffect { colorization: 1; colorizationColor: button.iconTint }
                source: button.customIcon ? Qt.resolvedUrl("icons/" + button.customIcon + ".svg") : button.symbol ? Quickshell.iconPath(button.symbol) : ""
            }
            Text {
                id: caption
                visible: button.text !== ""
                text: button.text; color: Theme.text; font.pixelSize: 12
                width: Math.max(0, Math.min(implicitWidth, body.width - (button.symbol ? 26 : 0)))
                height: 18
                verticalAlignment: Text.AlignVCenter
                elide: button.labelElide
            }
        }
    }
}
