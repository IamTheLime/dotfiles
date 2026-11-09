import QtQuick
import QtQuick.Controls
import Quickshell
import "../platform"
import "theme"
import Quickshell.Wayland

PopupWindow {
    id: popup
    required property QsMenuHandle menuHandle
    required property string title
    required property bool anchorHovered
    property var path: []
    property real navigationHeight: 0
    property bool browsingSubmenus: false
    property bool filterOpen: false
    property string filterText: ""
    readonly property string query: filterText.trim().toLocaleLowerCase()
    readonly property var entries: currentOpener.children.values.filter(entry =>
        !query || (!entry.isSeparator && entry.text.replace(/&(.)/g, "$1").toLocaleLowerCase().includes(query)))
    readonly property real entriesHeight: entries.length
        ? entries.reduce((height, entry) => height + (entry.isSeparator ? 8 : 32) + 2, -2) : 40
    readonly property real menuHeight: Math.min(implicitHeight,
        Math.max(navigationHeight, 44 + (filterOpen ? 36 : 0) + entriesHeight))

    function resetFilter() {
        filterText = "";
        filterOpen = false;
    }
    readonly property var currentOpener: path.length ? path[path.length - 1] : opener

    function openSubmenu(entry) {
        navigationHeight = Math.max(navigationHeight, surface.height);
        browsingSubmenus = true;
        navigationGuard.restart();
        const child = submenuOpener.createObject(popup, {menu: entry});
        if (child) path = path.concat([child]);
    }
    function goBack() {
        if (!path.length) return;
        navigationGuard.restart();
        const child = path[path.length - 1];
        path = path.slice(0, -1);
        child.destroy();
    }
    function resetNavigation() {
        const previous = path;
        path = [];
        for (let i = previous.length - 1; i >= 0; --i) previous[i].destroy();
        resetFilter();
        navigationHeight = 0;
        browsingSubmenus = false;
        navigationGuard.stop();
    }
    signal dismissed()
    BackgroundEffect.blurRegion: Backend.capabilities.blur ? nativeBlur : null
    Region { id: nativeBlur; item: surface; radius: surface.radius }
    color: "transparent"
    implicitWidth: 280
    // Keep the native buffer stable while submenu content and blur bounds change.
    implicitHeight: 560
    mask: Region { item: surface }
    grabFocus: true

    onVisibleChanged: if (!visible) resetNavigation()
    onMenuHandleChanged: resetNavigation()
    onCurrentOpenerChanged: {
        resetFilter();
        Qt.callLater(() => menuScroll.contentItem.contentY = 0);
    }
    onQueryChanged: Qt.callLater(() => menuScroll.contentItem.contentY = 0)

    QsMenuOpener {
        id: opener
        menu: popup.menuHandle
    }

    Component { id: submenuOpener; QsMenuOpener {} }
    Timer { id: navigationGuard; interval: 400 }

    Timer {
        interval: Theme.menuHoverGrace
        running: popup.visible && !popup.browsingSubmenus && !popup.filterOpen && !navigationGuard.running && !menuHover.hovered && !popup.anchorHovered
        onTriggered: popup.dismissed()
    }

    GlassSurface {
        id: surface
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: popup.menuHeight
        radius: 12
        HoverHandler { id: menuHover }

        Row {
            id: menuHeader
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 6 }
            height: 30
            ToolButton {
                font.family: Theme.fontFamily; font.weight: Theme.bodyWeight
                width: 32
                height: 30
                text: "‹"
                enabled: popup.path.length > 0
                onClicked: popup.goBack()
            }
            UiText {
                width: parent.width - 96
                height: 30
                verticalAlignment: Text.AlignVCenter
                text: popup.title
                color: "#e6e9ef"
                elide: Text.ElideRight
            }
            ToolButton {
                font.family: Theme.fontFamily; font.weight: Theme.bodyWeight
                id: filterButton
                width: 32
                height: 30
                Accessible.name: "Filter menu by name"
                checked: popup.filterOpen
                contentItem: Canvas {
                    property color ink: filterButton.checked ? Theme.accent : Theme.foreground
                    onInkChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.strokeStyle = ink;
                        ctx.lineWidth = 1.5;
                        ctx.lineJoin = "round";
                        const x = (width - 16) / 2, y = (height - 16) / 2;
                        ctx.beginPath();
                        ctx.moveTo(x + 1, y + 2); ctx.lineTo(x + 15, y + 2);
                        ctx.lineTo(x + 10, y + 8); ctx.lineTo(x + 10, y + 13);
                        ctx.lineTo(x + 6, y + 15); ctx.lineTo(x + 6, y + 8);
                        ctx.closePath(); ctx.stroke();
                    }
                }
                onClicked: {
                    popup.filterOpen = !popup.filterOpen;
                    popup.filterText = "";
                    if (popup.filterOpen) searchField.forceActiveFocus();
                }
            }
            ToolButton {
                font.family: Theme.fontFamily; font.weight: Theme.bodyWeight
                width: 32
                height: 30
                text: "×"
                onClicked: popup.dismissed()
            }
        }

        TextField {
            font.family: Theme.fontFamily; font.weight: Theme.bodyWeight
            id: searchField
            anchors { top: menuHeader.bottom; left: parent.left; right: parent.right; margins: 6; topMargin: 2 }
            height: popup.filterOpen ? 34 : 0
            visible: popup.filterOpen
            placeholderText: "Filter names…"
            text: popup.filterText
            onTextEdited: popup.filterText = text
            color: Theme.foreground
            placeholderTextColor: Theme.muted
            selectionColor: Theme.accent
            font.pixelSize: 13
            background: Rectangle { radius: 6; color: Theme.button }
            Keys.onEscapePressed: popup.resetFilter()
        }

        ScrollView {
            id: menuScroll
            anchors { top: searchField.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; margins: 6; topMargin: 2 }
            contentWidth: availableWidth
            contentHeight: popup.entriesHeight
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            clip: true

            Column {
                id: menuColumn
                width: menuScroll.availableWidth
                spacing: 2

                Repeater {
                    model: popup.entries
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

                            UiText {
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: menuRow.modelData.checkState === Qt.Checked ? "✓" : ""
                                color: "#e6e9ef"
                            }
                            UiText {
                                x: 30
                                width: parent.width - 56
                                anchors.verticalCenter: parent.verticalCenter
                                text: menuRow.modelData.text.replace(/&(.)/g, "$1")
                                color: "#e6e9ef"
                                elide: Text.ElideRight
                                font.pixelSize: 13
                            }
                            UiText {
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
                                        popup.openSubmenu(menuRow.modelData);
                                    } else {
                                        menuRow.modelData.triggered();
                                        popup.dismissed();
                                    }
                                }
                            }
                        }
                    }
                }
                UiText {
                    visible: popup.entries.length === 0
                    text: popup.query ? "No matching entries" : "No entries"
                    color: "#e6e9ef"
                    padding: 12
                }
            }
        }
    }
}
