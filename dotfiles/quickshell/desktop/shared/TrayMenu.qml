import QtQuick
import QtQuick.Controls
import Quickshell
import "../platform"
import Quickshell.Wayland

PopupWindow {
    id: popup
    required property QsMenuHandle menuHandle
    required property string title
    required property bool anchorHovered
    property var path: []
    signal dismissed()
    BackgroundEffect.blurRegion: Backend.capabilities.blur ? nativeBlur : null
    Region { id: nativeBlur; item: surface; radius: surface.radius }
    color: "transparent"
    implicitWidth: 280
    implicitHeight: Math.min(560, menuColumn.implicitHeight + 12)

    onVisibleChanged: {
        if (!visible)
            path = [];
    }

    QsMenuOpener {
        id: opener
        menu: popup.path.length ? popup.path[popup.path.length - 1] : popup.menuHandle
    }

    Timer {
        interval: 450
        running: popup.visible && !menuHover.hovered && !popup.anchorHovered
        onTriggered: popup.dismissed()
    }

    GlassSurface {
        id: surface
        anchors.fill: parent
        radius: 12
        HoverHandler { id: menuHover }

        ScrollView {
            anchors.fill: parent
            anchors.margins: 6
            contentWidth: availableWidth
            clip: true

            Column {
                id: menuColumn
                width: parent.width
                spacing: 2

                Row {
                    width: parent.width
                    height: 30
                    ToolButton {
                        width: 32
                        height: 30
                        text: "‹"
                        enabled: popup.path.length > 0
                        onClicked: popup.path = popup.path.slice(0, -1)
                    }
                    Text {
                        width: parent.width - 64
                        height: 30
                        verticalAlignment: Text.AlignVCenter
                        text: popup.title
                        color: "#e6e9ef"
                        elide: Text.ElideRight
                    }
                    ToolButton {
                        width: 32
                        height: 30
                        text: "×"
                        onClicked: popup.dismissed()
                    }
                }

                Repeater {
                    model: opener.children
                    delegate: Item {
                        id: menuRow
                        required property var modelData
                        width: menuColumn.width
                        height: modelData.isSeparator ? 8 : 32

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width - 12
                            height: 1
                            color: "#30ffffff"
                            visible: menuRow.modelData.isSeparator
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: entryMouse.containsMouse ? "#353d4b" : "transparent"
                            visible: !menuRow.modelData.isSeparator
                            opacity: menuRow.modelData.enabled ? 1 : 0.45

                            Text {
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: menuRow.modelData.checkState === Qt.Checked ? "✓" : ""
                                color: "#e6e9ef"
                            }
                            Text {
                                x: 30
                                width: parent.width - 56
                                anchors.verticalCenter: parent.verticalCenter
                                text: menuRow.modelData.text.replace(/&(.)/g, "$1")
                                color: "#e6e9ef"
                                elide: Text.ElideRight
                                font.pixelSize: 13
                            }
                            Text {
                                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                text: menuRow.modelData.hasChildren ? "›" : ""
                                color: "#e6e9ef"
                            }
                            MouseArea {
                                id: entryMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: menuRow.modelData.enabled
                                onClicked: {
                                    if (menuRow.modelData.hasChildren) {
                                        popup.path = popup.path.concat([menuRow.modelData]);
                                    } else {
                                        menuRow.modelData.triggered();
                                        popup.dismissed();
                                    }
                                }
                            }
                        }
                    }
                }
                Text {
                    visible: opener.children.values.length === 0
                    text: "Loading…"
                    color: "#e6e9ef"
                    padding: 12
                }
            }
        }
    }
}
