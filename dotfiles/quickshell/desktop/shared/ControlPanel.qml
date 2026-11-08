import "theme"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../platform"
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Bluetooth

PopupWindow {
    id: panel
    grabFocus: true
    required property bool anchorHovered
    property int tab: 0
    property int bubbleSection: 2
    property real bubbleCenter: width - 48
    readonly property real neckHeight: 34
    required property bool keepAwake
    required property bool awakePending
    required property string awakeError
    signal keepAwakeRequested()
    signal dismissed()
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var outputs: Pipewire.nodes.values.filter(node => node.audio && node.isSink && !node.isStream)
    readonly property var streams: Pipewire.nodes.values.filter(node => node.type === PwNodeType.AudioOutStream)
    readonly property var adapter: Bluetooth.defaultAdapter
    onTabChanged: { bubbleSection = tab; if (scroll.contentItem) scroll.contentItem.contentY = 0; }
    BackgroundEffect.blurRegion: Backend.capabilities.blur ? nativeBlur : null
    Region { id: nativeBlur;
        item: glassBody; radius: 26
        Region { item: glassNeck; radius: 18 }
    }
    mask: Region {
        item: glassBody; radius: 26
        Region { item: glassNeck; radius: 18 }
    }
    color: "transparent"
    implicitWidth: 440
    implicitHeight: Math.min((panel.screen?.height ?? 900) - 100, 640)
    PwObjectTracker { objects: panel.visible ? Pipewire.nodes.values : [] }
    onVisibleChanged: {
        if (visible) opening.restart();
        else dismissed();
    }
    NumberAnimation { id: opening; target: body; property: "scale"; from: 0.96; to: 1; duration: 190; easing.type: Easing.OutBack; easing.overshoot: 0.6 }
    component Heading: Text { color: Theme.text; font.pixelSize: 13; font.weight: Font.DemiBold }
    component Note: Text { color: Theme.secondaryText; font.pixelSize: 12; wrapMode: Text.Wrap }
    component Card: Rectangle {
        default property alias contents: stack.data
        implicitHeight: stack.implicitHeight + 28
        radius: 22; color: Theme.card
        ColumnLayout { id: stack; anchors.fill: parent; anchors.margins: 14; spacing: 10 }
    }
    Item {
        id: surface
        anchors.fill: parent
        anchors.margins: 4
        property real neckWidth: panel.bubbleSection === 0 ? 82 : 36
        Behavior on neckWidth {
            enabled: panel.visible
            NumberAnimation { duration: 170; easing.type: Easing.OutBack; easing.overshoot: 0.35 }
        }
        readonly property real targetNeckX: Math.max(neckWidth / 2 + 4, Math.min(width - neckWidth / 2 - 4, panel.bubbleCenter - x))
        property real neckX: targetNeckX
        Behavior on neckX {
            enabled: panel.visible
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        property real tailX: targetNeckX
        Behavior on tailX {
            enabled: panel.visible
            SequentialAnimation {
                PauseAnimation { duration: 30 }
                NumberAnimation { duration: 230; easing.type: Easing.OutCubic }
            }
        }
        readonly property real tailOffset: Math.max(-24, Math.min(24, tailX - neckX))
        Item {
            id: glassBody
            anchors.fill: parent
            anchors.topMargin: panel.neckHeight
        }
        Item {
            id: glassNeck
            x: surface.neckX - width / 2; y: 0
            width: surface.neckWidth; height: panel.neckHeight + 12
        }
        Canvas {
            id: glassPaint
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections { target: surface; function onNeckXChanged() { glassPaint.requestPaint(); } function onNeckWidthChanged() { glassPaint.requestPaint(); } function onTailOffsetChanged() { glassPaint.requestPaint(); } }
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const inset = Theme.rimWidth / 2;
                const top = panel.neckHeight + inset;
                const r = 26 - inset;
                const right = width - inset;
                const bottom = height - inset;
                const neck = surface.neckX;
                const half = surface.neckWidth / 2;
                const leftTail = Math.min(0, surface.tailOffset);
                const rightTail = Math.max(0, surface.tailOffset);
                const leftRadius = Math.min(r, Math.max(0, (neck - half - inset) / 2));
                const rightRadius = Math.min(r, Math.max(0, (right - neck - half) / 2));
                const leftShoulder = Math.max(inset + leftRadius, neck - half - 16 + leftTail);
                const rightShoulder = Math.min(right - rightRadius, neck + half + 16 + rightTail);
                const tint = ctx.createLinearGradient(0, 0, 0, height);
                tint.addColorStop(0, Theme.rimTop);
                tint.addColorStop(0.45, Theme.rimMiddle);
                tint.addColorStop(1, Theme.rimBottom);
                ctx.beginPath();
                ctx.moveTo(inset + leftRadius, top);
                ctx.lineTo(leftShoulder, top);
                ctx.bezierCurveTo(Math.max(leftShoulder, neck - half + leftTail), top, neck - half, top - 8, neck - half, inset + 18);
                ctx.arcTo(neck - half, inset, neck - half + 18, inset, 18);
                ctx.lineTo(neck + half - 18, inset);
                ctx.arcTo(neck + half, inset, neck + half, inset + 18, 18);
                ctx.bezierCurveTo(neck + half, top - 8, Math.min(rightShoulder, neck + half + rightTail), top, rightShoulder, top);
                ctx.lineTo(right - rightRadius, top);
                ctx.arcTo(right, top, right, top + rightRadius, rightRadius);
                ctx.lineTo(right, bottom - r);
                ctx.arcTo(right, bottom, right - r, bottom, r);
                ctx.lineTo(inset + r, bottom);
                ctx.arcTo(inset, bottom, inset, bottom - r, r);
                ctx.lineTo(inset, top + leftRadius);
                ctx.arcTo(inset, top, inset + leftRadius, top, leftRadius);
                ctx.closePath();
                ctx.fillStyle = Theme.glass;
                ctx.fill();
                ctx.lineWidth = Theme.rimWidth;
                ctx.strokeStyle = tint;
                ctx.stroke();
            }
        }
        PanelButton {
            x: surface.neckX - width / 2; y: 3
            width: surface.neckWidth - 4; height: 28
            text: panel.bubbleSection === 0 ? Math.round((panel.sink?.audio?.volume ?? 0) * 100) + "%" : ""
            flat: true; symbol: panel.bubbleSection === 0 ? (panel.sink?.audio?.muted ? "audio-volume-muted" : "audio-volume-high") : panel.bubbleSection === 1 ? "preferences-system-bluetooth" : "configure"; iconTint: Theme.topBarIcon
            Accessible.name: "Close control centre"
            onClicked: panel.dismissed()
        }
        Item {
            id: body
            anchors.fill: parent
            anchors.topMargin: panel.neckHeight
            transformOrigin: Item.Center
        ColumnLayout {
            id: header
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            anchors.margins: 16; spacing: 12
            RowLayout {
                Layout.fillWidth: true
                IconImage { source: Qt.resolvedUrl("icons/controls.svg"); implicitSize: 21 }
                Text { text: "Control centre"; color: Theme.text; font.pixelSize: 18; font.weight: Font.DemiBold; Layout.fillWidth: true }
                PanelButton { symbol: "window-close"; Accessible.name: "Close control centre"; onClicked: panel.dismissed() }
            }
            RowLayout {
                spacing: 7; Layout.fillWidth: true
                Repeater {
                    model: [{name: "Audio", icon: "audio-volume-high"}, {name: "Bluetooth", icon: "preferences-system-bluetooth"}, {name: "Media", icon: "media-playback-start"}]
                    PanelButton {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        text: modelData.name; symbol: modelData.icon; accent: panel.tab === index
                        onClicked: panel.tab = index
                    }
                }
            }
        }
        ScrollView {
            id: scroll
            anchors.top: header.bottom; anchors.topMargin: 14
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.leftMargin: 16; anchors.rightMargin: 16; anchors.bottomMargin: 16
            leftPadding: 0; rightPadding: 0; topPadding: 0; bottomPadding: 0
            contentWidth: availableWidth
            contentHeight: content.implicitHeight
            clip: true
            ScrollBar.vertical: ScrollBar {
                parent: scroll
                x: scroll.width + 5; y: 0
                width: 4; height: scroll.height
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    color: Theme.scrollbar
                }
            }
            ColumnLayout {
                id: content
                width: scroll.availableWidth
                spacing: 12
                PanelButton {
                    Layout.fillWidth: true; implicitHeight: 46
                    symbol: "computer"
                    text: panel.awakePending ? "Starting…" : "Keep awake · " + (panel.keepAwake ? "On" : "Off")
                    accent: panel.keepAwake; enabled: !panel.awakePending
                    Accessible.checkable: true; Accessible.checked: panel.keepAwake
                    onClicked: panel.keepAwakeRequested()
                }
                Note { text: "Screen blanking and locking remain enabled."; Layout.fillWidth: true }
                Note { visible: panel.awakeError.length > 0; text: panel.awakeError; color: Theme.error; Layout.fillWidth: true }
                Card {
                    visible: panel.tab === 0; Layout.fillWidth: true
                    Heading { text: "Output volume" }
                    RowLayout {
                        Layout.fillWidth: true
                        PanelButton { symbol: panel.sink?.audio?.muted ? "audio-volume-muted" : "audio-volume-high"; Accessible.name: "Toggle mute"; enabled: !!panel.sink?.audio; onClicked: panel.sink.audio.muted = !panel.sink.audio.muted }
                        PanelSlider { Layout.fillWidth: true; enabled: !!panel.sink?.audio; value: panel.sink?.audio?.volume ?? 0; onMoved: panel.sink.audio.volume = value }
                        Heading { text: Math.round((panel.sink?.audio?.volume ?? 0) * 100) + "%"; Layout.preferredWidth: 40 }
                    }
                    Heading { text: "Output device" }
                    Note { visible: panel.outputs.length === 0; text: "No audio output available" }
                    Repeater {
                        model: panel.outputs
                        PanelButton {
                            required property var modelData
                            Layout.fillWidth: true
                            text: modelData.description || modelData.name
                            labelElide: Text.ElideMiddle
                            ToolTip.visible: hovered
                            ToolTip.delay: 600
                            ToolTip.text: text
                            symbol: modelData === panel.sink ? "emblem-ok-symbolic" : "audio-card"
                            accent: modelData === panel.sink
                            onClicked: Pipewire.preferredDefaultAudioSink = modelData
                        }
                    }
                }
                Card {
                    visible: panel.tab === 0; Layout.fillWidth: true
                    Heading { text: "Application mixer" }
                    Note { visible: panel.streams.length === 0; text: "Apps playing audio appear here." }
                    Repeater {
                        model: panel.streams
                        ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            RowLayout {
                                Layout.fillWidth: true
                                IconImage {
                                    implicitSize: 22
                                    source: Quickshell.iconPath(modelData.properties["application.icon-name"] || "audio-x-generic")
                                }
                                Heading { text: modelData.properties["application.name"] || modelData.description || modelData.name; Layout.fillWidth: true; elide: Text.ElideRight }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                PanelSlider { Layout.fillWidth: true; value: modelData.audio.volume; onMoved: modelData.audio.volume = value }
                                Heading { text: Math.round(modelData.audio.volume * 100) + "%"; Layout.preferredWidth: 40 }
                                PanelButton { symbol: modelData.audio.muted ? "audio-volume-muted" : "audio-volume-high"; Accessible.name: "Toggle application mute"; onClicked: modelData.audio.muted = !modelData.audio.muted }
                            }
                        }
                    }
                    PanelButton { text: "All audio settings"; symbol: "configure"; Layout.fillWidth: true; onClicked: Backend.openSettings("audio") }
                }
                Card {
                    visible: panel.tab === 1; Layout.fillWidth: true
                    RowLayout {
                        Layout.fillWidth: true
                        Heading { text: "Bluetooth"; Layout.fillWidth: true }
                        PanelButton { text: panel.adapter?.enabled ? "On" : "Off"; accent: panel.adapter?.enabled ?? false; enabled: !!panel.adapter; onClicked: panel.adapter.enabled = !panel.adapter.enabled }
                        PanelButton { symbol: "view-refresh"; text: panel.adapter?.discovering ? "Stop" : "Scan"; enabled: panel.adapter?.enabled ?? false; onClicked: panel.adapter.discovering = !panel.adapter.discovering }
                    }
                    Note { visible: !panel.adapter || !panel.adapter.enabled; text: panel.adapter ? "Turn Bluetooth on to connect a device." : "No Bluetooth adapter found."; Layout.fillWidth: true }
                    Repeater {
                        model: panel.adapter?.devices ?? null
                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            IconImage { source: Qt.resolvedUrl("icons/bluetooth.svg"); implicitSize: 20 }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 3
                                Heading { text: modelData.name; Layout.fillWidth: true; elide: Text.ElideRight }
                                Note { text: (modelData.connected ? "Connected" : modelData.paired ? "Paired" : "Available") + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + "%" : "") }
                            }
                            PanelButton {
                                text: modelData.pairing ? "Pairing…" : modelData.connected ? "Disconnect" : modelData.paired ? "Connect" : "Pair"
                                enabled: !modelData.pairing && (panel.adapter?.enabled ?? false)
                                onClicked: { if (modelData.connected) modelData.disconnect(); else if (modelData.paired) modelData.connect(); else modelData.pair(); }
                            }
                        }
                    }
                    PanelButton { text: "All Bluetooth settings"; symbol: "configure"; Layout.fillWidth: true; onClicked: Backend.openSettings("bluetooth") }
                }
                Note { visible: panel.tab === 2 && Mpris.players.values.length === 0; text: "Play music or a video to see its controls here."; Layout.fillWidth: true }
                Repeater {
                    model: Mpris.players
                    Card {
                        required property var modelData
                        visible: panel.tab === 2; Layout.fillWidth: true
                        RowLayout {
                            Layout.fillWidth: true
                            Rectangle {
                                width: 64; height: 64; radius: 12; color: Theme.artworkBackground; clip: true
                                IconImage { anchors.centerIn: parent; source: Quickshell.iconPath("audio-x-generic"); implicitSize: 30 }
                                Image { anchors.fill: parent; source: modelData.trackArtUrl; fillMode: Image.PreserveAspectCrop }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 4
                                Note { text: modelData.identity; Layout.fillWidth: true; elide: Text.ElideRight }
                                Heading { text: modelData.trackTitle || "Untitled track"; Layout.fillWidth: true; wrapMode: Text.Wrap }
                                Note { text: modelData.trackArtist || ""; Layout.fillWidth: true; elide: Text.ElideRight }
                            }
                        }
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            PanelButton { symbol: "media-skip-backward"; Accessible.name: "Previous track"; enabled: modelData.canGoPrevious; onClicked: modelData.previous() }
                            PanelButton { symbol: modelData.isPlaying ? "media-playback-pause" : "media-playback-start"; text: modelData.isPlaying ? "Pause" : "Play"; accent: true; enabled: modelData.canTogglePlaying; onClicked: modelData.togglePlaying() }
                            PanelButton { symbol: "media-skip-forward"; Accessible.name: "Next track"; enabled: modelData.canGoNext; onClicked: modelData.next() }
                        }
                    }
                }
            }
        }
        }
    }
}
