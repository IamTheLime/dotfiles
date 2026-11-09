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
    property var topBarButtons: []
    property real bubbleCenter: width - 48
    readonly property real neckPosition: surface.neckX
    readonly property real neckTarget: surface.targetNeckX
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
    BackgroundEffect.blurRegion: Backend.capabilities.blur ? surface.blurRegion : null
    Region { id: audioHit; item: audioAnchor }
    Region { id: bluetoothHit; item: bluetoothAnchor }
    Region { id: settingsHit; item: settingsAnchor }
    mask: Region { regions: [surface.blurRegion, audioHit, bluetoothHit, settingsHit] }
    component AnchorButton: MouseArea {
        required property int section
        readonly property rect buttonRect: panel.topBarButtons[section] ?? Qt.rect(0, 0, 0, 0)
        x: buttonRect.x; y: buttonRect.y
        width: buttonRect.width; height: buttonRect.height
        onClicked: {
            if (panel.bubbleSection === section) panel.dismissed();
            else {
                if (section !== 2) panel.tab = section;
                panel.bubbleSection = section;
            }
        }
    }
    AnchorButton { id: audioAnchor; section: 0; z: 10 }
    AnchorButton { id: bluetoothAnchor; section: 1; z: 10 }
    AnchorButton { id: settingsAnchor; section: 2; z: 10 }
    color: "transparent"
    implicitWidth: 440
    implicitHeight: Math.min((panel.screen?.height ?? 900) - 100, 640)
    PwObjectTracker { objects: panel.visible ? Pipewire.nodes.values : [] }
    onVisibleChanged: {
        if (visible) opening.restart();
        else dismissed();
    }
    NumberAnimation { id: opening; target: body; property: "scale"; from: 0.96; to: 1; duration: 190; easing.type: Easing.OutBack; easing.overshoot: 0.6 }
    component Heading: UiText { color: Theme.text; font.pixelSize: 13; font.weight: Theme.headingWeight }
    component Note: UiText { color: Theme.secondaryText; font.pixelSize: 12; wrapMode: Text.Wrap }
    component Card: Rectangle {
        default property alias contents: stack.data
        implicitHeight: stack.implicitHeight + 28
        radius: 22; color: Theme.card
        ColumnLayout { id: stack; anchors.fill: parent; anchors.margins: 14; spacing: 10 }
    }
    GlassBubble {
        id: surface
        neckWidth: panel.bubbleSection === 0 ? 82 : 36
        neckCenter: panel.bubbleCenter
        neckHeight: panel.neckHeight
        PanelButton {
            x: surface.neckX - width / 2; y: 3
            width: surface.neckWidth - 4; height: 28
            text: panel.bubbleSection === 0 ? Math.round((panel.sink?.audio?.volume ?? 0) * 100) + "%" : ""
            flat: true; symbol: panel.bubbleSection === 0 ? (panel.sink?.audio?.muted ? "audio-volume-muted" : "audio-volume-high") : panel.bubbleSection === 1 ? "preferences-system-bluetooth" : "configure"; iconTint: Theme.topBarIcon
            textSize: Theme.volumeSize
            textWeight: Theme.volumeWeight
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
                UiText { text: "Control centre"; color: Theme.text; font.pixelSize: 18; font.weight: Theme.headingWeight; Layout.fillWidth: true }
                PanelButton { symbol: "window-close"; textSize: Theme.volumeSize
            textWeight: Theme.volumeWeight
            Accessible.name: "Close control centre"; onClicked: panel.dismissed() }
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
                        onClicked: { panel.tab = index; panel.bubbleSection = index; }
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
