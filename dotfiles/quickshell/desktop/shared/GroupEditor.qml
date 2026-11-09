import "theme"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../platform"
import Quickshell.Wayland

PopupWindow {
    id: editor
    property string heading: "Edit group"
    property string confirmText: "Save"
    property string draftColor: Theme.accent.toString()
    signal saved(string label, string accent)
    implicitWidth: 300
    implicitHeight: 208
    BackgroundEffect.blurRegion: Backend.capabilities.blur ? nativeBlur : null
    Region { id: nativeBlur; item: surface; radius: surface.radius }
    color: "transparent"
    grabFocus: true
    function open(label, accent) {
        labelInput.text = label;
        draftColor = accent || Theme.accent.toString();
        visible = true;
        focusTimer.restart();
    }
    function save() {
        if (!labelInput.text.trim()) return;
        saved(labelInput.text.trim(), draftColor);
        visible = false;
    }
    Timer { id: focusTimer; interval: 60; onTriggered: { labelInput.forceActiveFocus(); labelInput.selectAll(); } }
    GlassSurface {
        id: surface
        anchors.fill: parent
        radius: 16
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 16; spacing: 12
            UiText { text: editor.heading; color: Theme.text; font.pixelSize: 14; font.weight: Theme.headingWeight }
            TextField {
                font.family: Theme.fontFamily; font.weight: Theme.bodyWeight
                id: labelInput
                Layout.fillWidth: true; Layout.preferredHeight: 38
                placeholderText: "Group label"
                maximumLength: 48
                color: Theme.text; selectionColor: Theme.selection
                leftPadding: 12; rightPadding: 12
                background: Rectangle { radius: 7; color: Theme.button }
                Accessible.name: "Group label"
                onAccepted: editor.save()
                Keys.onEscapePressed: editor.visible = false
            }
            RowLayout {
                spacing: 9
                Repeater {
                    model: Theme.splitPalette
                    Button {
                        font.family: Theme.fontFamily; font.weight: Theme.bodyWeight
                        required property string modelData
                        Layout.preferredWidth: 32; Layout.preferredHeight: 32
                        hoverEnabled: true
                        Accessible.name: "Group colour " + modelData
                        Accessible.checkable: true
                        Accessible.checked: editor.draftColor === modelData
                        background: Rectangle { radius: 7; color: parent.modelData; scale: parent.hovered ? 1.08 : 1; Behavior on scale { NumberAnimation { duration: 120 } } }
                        contentItem: UiText { text: editor.draftColor === parent.modelData ? "✓" : ""; color: Theme.background; font.pixelSize: 18; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: editor.draftColor = modelData
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                PanelButton { text: "Cancel"; Layout.fillWidth: true; onClicked: editor.visible = false }
                PanelButton { text: editor.confirmText; accent: true; enabled: labelInput.text.trim().length > 0; Layout.fillWidth: true; onClicked: editor.save() }
            }
        }
    }
}
