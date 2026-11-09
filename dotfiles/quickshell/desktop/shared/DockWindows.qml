import "theme"
import QtQuick
import QtQuick.Controls
import Quickshell
import "../platform"
import Quickshell.Wayland

PopupWindow {
    id: popup
    required property var windows
    required property bool anchorHovered
    signal selected(string id)
    signal closeRequested(var ids)
    signal groupRequested(string id, string label, string accent)
    signal dismissed()
    BackgroundEffect.blurRegion: Backend.capabilities.blur ? nativeBlur : null
    Region { id: nativeBlur; item: surface; radius: surface.radius }
    color: "transparent"
    implicitWidth: 330
    implicitHeight: Math.min(380, windowList.implicitHeight + 20)

    component ActionPill: Button {
        font.family: Theme.fontFamily; font.weight: Theme.bodyWeight
        id: action
        property bool destructive: false
        height: 34
        hoverEnabled: true
        scale: down ? 0.97 : 1
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
        contentItem: UiText {
            text: action.text
            color: action.destructive ? Theme.closeText : Theme.secondaryText
            font.pixelSize: 12
            font.weight: Theme.bodyWeight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: action.hovered ? Theme.buttonHover : Theme.tabBackground; Behavior on color { ColorAnimation { duration: 130 } } }
                GradientStop { position: 0.65; color: action.destructive ? Theme.closeSoft : action.hovered ? Theme.buttonHover : Theme.tabBackground; Behavior on color { ColorAnimation { duration: 130 } } }
                GradientStop { position: 1; color: action.destructive ? (action.hovered ? Theme.closeHover : Theme.closeEdge) : action.hovered ? Theme.buttonHover : Theme.tabBackground; Behavior on color { ColorAnimation { duration: 130 } } }
            }
            border.width: action.visualFocus ? 1 : 0
            border.color: Theme.focus
        }
    }

    GroupEditor {
        id: groupEditor
        heading: "Create group"
        confirmText: "Create group"
        anchor.window: popup
        anchor.rect.x: 0
        anchor.rect.y: 0
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        onSaved: (label, accent) => { if (popup.windows.length) popup.groupRequested(popup.windows[0].id, label, accent); }
    }
    onVisibleChanged: if (!visible) groupEditor.visible = false

    Timer {
        interval: Theme.menuHoverGrace
        running: popup.visible && !groupEditor.visible && !popup.anchorHovered && !popupHover.hovered
        onTriggered: popup.dismissed()
    }
    GlassSurface {
        id: surface
        anchors.fill: parent
        radius: 24
        scale: popup.visible ? 1 : 0.96
        opacity: popup.visible ? 1 : 0
        transformOrigin: Item.Bottom
        Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutBack; easing.overshoot: 0.7 } }
        Behavior on opacity { NumberAnimation { duration: 100 } }
        HoverHandler { id: popupHover }
        ScrollView {
            anchors.fill: parent
            anchors.margins: 10
            contentWidth: availableWidth
            clip: true
            Column {
                id: windowList
                width: parent.width
                spacing: 7
                move: Transition { NumberAnimation { properties: "y"; duration: 150; easing.type: Easing.OutCubic } }
                ActionPill {
                    width: parent.width
                    height: visible ? 32 : 0
                    visible: popup.windows.length > 1
                    text: "Group as tabs"
                    onClicked: {
                        const window = popup.windows[0];
                        const label = window.appId.toLowerCase() === "org.kicad.kicad" ? window.title.split(" — ")[0].replace(/^\*\s*/, "") : window.resourceClass || window.appId;
                        groupEditor.open(label, Theme.accent.toString());
                    }
                }
                Repeater {
                    model: popup.windows
                    delegate: Rectangle {
                        id: entry
                        required property var modelData
                        readonly property bool hovered: selectButton.hovered || closeButton.hovered
                        width: windowList.width
                        height: 44
                        radius: height / 2
                        scale: selectButton.down || closeButton.down ? 0.97 : 1
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: entry.hovered ? Theme.buttonHover : Theme.button; Behavior on color { ColorAnimation { duration: 130 } } }
                            GradientStop { position: 0.68; color: entry.hovered ? Theme.buttonHover : Theme.button; Behavior on color { ColorAnimation { duration: 130 } } }
                            GradientStop { position: 0.86; color: closeButton.hovered ? Theme.closeEdge : Theme.closeSoft; Behavior on color { ColorAnimation { duration: 130 } } }
                            GradientStop { position: 1; color: closeButton.down ? Theme.closePressed : closeButton.hovered ? Theme.closeHover : Theme.closeEdge; Behavior on color { ColorAnimation { duration: 130 } } }
                        }
                        Button {
                            font.family: Theme.fontFamily; font.weight: Theme.bodyWeight
                            id: selectButton
                            anchors.fill: parent
                            anchors.rightMargin: 44
                            hoverEnabled: true
                            leftPadding: 15
                            rightPadding: 6
                            text: entry.modelData.title || entry.modelData.appId
                            background: Item {}
                            contentItem: UiText {
                                text: selectButton.text
                                verticalAlignment: Text.AlignVCenter
                                color: Theme.text
                                font.pixelSize: 13
                                font.weight: entry.modelData.active ? Theme.headingWeight : Theme.bodyWeight
                                elide: Text.ElideRight
                                opacity: selectButton.visualFocus || entry.hovered ? 1 : 0.9
                            }
                            onClicked: popup.selected(entry.modelData.id)
                        }
                        Button {
                            font.family: Theme.fontFamily; font.weight: Theme.bodyWeight
                            id: closeButton
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 44
                            hoverEnabled: true
                            Accessible.name: "Close " + (entry.modelData.title || entry.modelData.appId)
                            background: Item {}
                            contentItem: UiText {
                                text: "×"
                                color: "white"
                                font.pixelSize: 23
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                scale: closeButton.down ? 0.85 : closeButton.hovered ? 1.12 : 1
                                opacity: closeButton.hovered || closeButton.visualFocus ? 1 : 0.86
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                Behavior on opacity { NumberAnimation { duration: 100 } }
                            }
                            onClicked: popup.closeRequested([entry.modelData.id])
                        }
                    }
                }
                ActionPill {
                    width: parent.width
                    destructive: true
                    text: "Close all windows"
                    onClicked: popup.closeRequested(popup.windows.map(window => window.id))
                }
            }
        }
    }
}
