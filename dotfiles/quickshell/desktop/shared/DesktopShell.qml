//@ pragma UseQApplication
import QtQuick
import "theme"
import "calendar" as CalendarData
import "../platform"
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Wayland

Scope {
    id: root

    property bool sleepRequested: false
    property bool sleepBlocked: false
    property string sleepError: ""
    readonly property color background: "#7020242c"
    readonly property color foreground: "#e6e9ef"
    readonly property color highlight: "#353d4b"
    readonly property var launchers: Backend.launchers

    SystemClock { id: clock; precision: SystemClock.Minutes }
    CalendarData.Service { id: calendarService }
    readonly property int dayPortions: 100
    readonly property real travelPixels: 100
    readonly property string debugPortion: Quickshell.env("QS_DAY_PORTION")
    readonly property real dayPortion: debugPortion !== ""
        ? Math.max(0, Math.min(dayPortions, Number(debugPortion) || 0))
        : (clock.date.getHours() * 60 + clock.date.getMinutes()) / 1440 * dayPortions
    property real drift: travelPixels * (1 - Math.abs(2 * dayPortion / dayPortions - 1))
    Behavior on drift {
        NumberAnimation { duration: root.debugPortion !== "" ? 1000 : 60000; easing.type: Easing.Linear }
    }

    readonly property var windowState: Backend.maximized
    readonly property var fullscreenState: Backend.fullscreen
    readonly property var appWindows: Backend.windows
    property var dockApps: launchers
    function matchesApp(window, app) {
        const id = (window.appId || window.resourceClass).toLowerCase();
        return id === app.appId.toLowerCase()
            || (app.command && window.resourceClass.toLowerCase() === app.command[0]);
    }
    readonly property var desktopApps: DesktopEntries.applications.values
    onDesktopAppsChanged: updateDockApps()
    onAppWindowsChanged: updateDockApps()
    function updateDockApps() {
        const running = [];
        for (const window of appWindows) {
            if (launchers.some(app => matchesApp(window, app))) continue;
            const id = window.appId || window.resourceClass;
            if (!id || running.some(app => app.appId.toLowerCase() === id.toLowerCase())) continue;
            const entry = DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id);
            running.push({appId: id, name: entry ? entry.name : id,
                icon: entry && entry.icon ? entry.icon : "application-x-executable"});
        }
        const retained = dockApps.filter(app => !app.command && running.some(item => item.appId === app.appId))
            .map(app => running.find(item => item.appId === app.appId));
        const added = running.filter(app => !retained.some(item => item.appId === app.appId));
        const next = launchers.concat(retained, added);
        if (JSON.stringify(next) !== JSON.stringify(dockApps))
            dockApps = next;
    }
    function windowsFor(app) {
        return appWindows.filter(window => matchesApp(window, app))
            .sort((a, b) => b.order - a.order);
    }
    function requestWindowClose(ids: var): void { Backend.closeWindows(ids); }
    function activateWindow(id) { Backend.activate(id); }
    IpcHandler {
        target: "desktop"
        function platform(): string { return JSON.stringify({name: Backend.name, ready: Backend.ready, capabilities: Backend.capabilities, error: Backend.error}); }
        function keepAwake(enabled: bool): void { root.sleepRequested = enabled; }
        function awake(): string { return JSON.stringify({active: root.sleepBlocked, requested: root.sleepRequested, error: root.sleepError}); }
        function state(): string { return JSON.stringify(root.windowState); }
        function fullscreen(): string { return JSON.stringify(root.fullscreenState); }
        function windows(): string { return JSON.stringify(root.appWindows); }
        function apps(): string { return JSON.stringify(root.dockApps); }
        function activate(id: string): void { root.activateWindow(id); }
        function closeWindows(ids: string): void { root.requestWindowClose(ids.split(",")); }
        function groups(): string { return JSON.stringify(windowGroups.groups); }
        function groupStyle(key: string, label: string, accent: string): void { windowGroups.editGroup(key, label, accent); }
        function group(id: string): void { windowGroups.groupApp(id); }
        function groupAdd(key: string, id: string): void { windowGroups.addWindow(key, id); }
        function groupSelect(key: string, id: string): void { windowGroups.select(key, id); }
        function groupSplit(key: string, id: string, left: bool): void { windowGroups.split(key, id, left); }
        function groupUnsplit(key: string): void { windowGroups.unsplit(key); }
        function groupSwap(key: string): void { windowGroups.swapPanes(key); }
        function groupResize(key: string, ratio: real): void { windowGroups.resizeSplit(key, ratio); }
        function ungroup(key: string): void { windowGroups.ungroup(key); }
    }
    WindowGroups {
        id: windowGroups
        windows: root.appWindows
        fullscreen: root.fullscreenState
        onCommand: command => Backend.send(command)
    }

    Process {
        id: sleepInhibitor
        command: ["python3", Quickshell.shellPath("shared/keep-awake.py")]
        running: root.sleepRequested
        stdinEnabled: true
        onStarted: root.sleepError = ""
        stdout: SplitParser { onRead: data => { if (data === "ready") root.sleepBlocked = true; } }
        stderr: SplitParser { onRead: data => { root.sleepError = data; console.warn(data); } }
        onExited: (code, status) => {
            if (code !== 0 && root.sleepRequested && !root.sleepError)
                root.sleepError = "Keep awake stopped. Try enabling it again.";
            root.sleepBlocked = false;
            root.sleepRequested = false;
        }
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    Variants {
        model: Quickshell.screens

        Scope {
            required property var modelData

            PanelSurface {
                id: topBar
                screen: modelData
                visible: !root.fullscreenState[modelData.name]
                onVisibleChanged: {
                    if (!visible) { controlsOpen = false; calendarOpen = false; openTrayItem = null; }
                }
                edge: "top"
                implicitHeight: 48
                exclusiveZone: visible && root.windowState[screen.name] ? pillHeight : 0
                color: "transparent"
                role: "top"

                readonly property bool joinedTarget: root.windowState[screen.name] ?? false
                readonly property int maximizeDuration: 600
                readonly property int restoreDuration: 620
                property real joinProgress: joinedTarget ? 1 : 0
                readonly property real joined: Math.max(0, Math.min(1, joinProgress))
                property real surfacePhase: 1
                onJoinedTargetChanged: {
                    surfaceMotion.duration = joinedTarget ? maximizeDuration : restoreDuration;
                    surfaceMotion.restart();
                }
                NumberAnimation {
                    id: surfaceMotion
                    target: topBar
                    property: "surfacePhase"
                    from: 0
                    to: 1
                    duration: topBar.restoreDuration
                }
                property var openTrayItem: null
                property bool controlsOpen: false
                property bool calendarOpen: false
                onControlsOpenChanged: if (controlsOpen) calendarOpen = false
                onOpenTrayItemChanged: { if (openTrayItem) { controlsOpen = false; calendarOpen = false; } }

                IpcHandler {
                    target: "desktop-" + topBar.screen.name
                    function layout(): string {
                        return JSON.stringify({ target: topBar.joinedTarget, progress: topBar.joinProgress, joined: topBar.joined, reserved: topBar.exclusiveZone });
                    }
                    function calendar(): void { topBar.openTrayItem = null; topBar.controlsOpen = false; topBar.calendarOpen = true; }
                    function controlLayout(): string { return JSON.stringify({width: controls.width, height: controls.height, tab: controls.tab, section: controls.bubbleSection, bubbleX: controls.bubbleCenter, neckX: controls.neckPosition, neckTarget: controls.neckTarget}); }
                    function audio(): void {
                        topBar.openTrayItem = null;
                        controls.tab = 0; controls.bubbleSection = 0;
                        topBar.controlsOpen = true;
                    }
                    function media(): void { topBar.openTrayItem = null; controls.tab = 2; controls.bubbleSection = 2; topBar.controlsOpen = true; }
                    function bluetooth(): void {
                        topBar.openTrayItem = null;
                        controls.tab = 1; controls.bubbleSection = 1;
                        topBar.controlsOpen = true;
                    }
                    function dismiss(): void {
                        topBar.controlsOpen = false;
                        topBar.openTrayItem = null;
                    }
                }

                CalendarPanel {
                    id: calendarPopup
                    clockLabel: clockText.text
                    clockWidth: clockMouse.width
                    bubbleCenter: clockBox.x + clockMouse.x + clockMouse.width / 2 - anchor.rect.x
                    service: calendarService
                    visible: topBar.calendarOpen
                    anchor.window: topBar.window
                    anchor.rect.x: Math.max(4, Math.min(topBar.width - width - 4,
                        clockBox.x + clockMouse.x + clockMouse.width / 2 - width / 2))
                    anchor.rect.y: topBar.pillY - 4
                    anchor.adjustment: PopupAdjustment.SlideX
                    onDismissed: topBar.calendarOpen = false
                }

                ControlPanel {
                    id: controls
                    keepAwake: root.sleepBlocked
                    awakePending: root.sleepRequested && !root.sleepBlocked
                    awakeError: root.sleepError
                    onKeepAwakeRequested: root.sleepRequested = !root.sleepRequested
                    visible: topBar.controlsOpen
                    anchorHovered: volumeMouse.containsMouse || bluetoothMouse.containsMouse
                    anchor.window: topBar.window
                    anchor.rect.x: Math.max(0, topBar.width - width - 4)
                    topBarButtons: [volume, bluetoothButton, controlCentreButton].map(button =>
                        Qt.rect(trayRow.x + button.x - controls.anchor.rect.x,
                            trayRow.y + button.y - controls.anchor.rect.y, button.width, button.height))
                    bubbleCenter: {
                        const icon = controls.bubbleSection === 0 ? volume : controls.bubbleSection === 1 ? bluetoothButton : controlCentreButton;
                        return trayRow.x + icon.x + icon.width / 2 - anchor.rect.x;
                    }
                    anchor.rect.y: topBar.pillY - 4
                    anchor.adjustment: PopupAdjustment.SlideX
                    onDismissed: topBar.controlsOpen = false
                }
                readonly property real pillY: 8 * (1 - joined)
                readonly property real pillHeight: 34
                readonly property real clockWidth: clockText.implicitWidth + 24
                readonly property real trayWidth: trayRow.implicitWidth + 20
                Behavior on joinProgress {
                    id: joinAnimation
                    NumberAnimation {
                        duration: joinAnimation.targetValue === 1 ? topBar.maximizeDuration : topBar.restoreDuration
                        easing.type: joinAnimation.targetValue === 1 ? Easing.BezierSpline : Easing.OutCubic
                        easing.bezierCurve: [0.22, 0, 0.18, 1, 1, 1]
                    }
                }

                blurRegion: Region {
                    Region { item: desktopBox; radius: desktopBox.radius }
                    Region { item: clockBox; radius: clockBox.radius }
                    Region { item: trayBox; radius: trayBox.radius }
                }

                mask: Region { item: trayRow; Region { item: clockMouse } }

                LiquidSurface {
                    anchors.fill: parent
                    leftBox: Qt.vector4d(desktopBox.x, desktopBox.y, desktopBox.width, desktopBox.height)
                    middleBox: Qt.vector4d(clockBox.x, clockBox.y, clockBox.width, clockBox.height)
                    rightBox: Qt.vector4d(trayBox.x, trayBox.y, trayBox.width, trayBox.height)
                    tint: Qt.vector4d(Theme.topBarGlass.r, Theme.topBarGlass.g, Theme.topBarGlass.b, Theme.topBarGlass.a)
                    joined: topBar.joined
                    phase: topBar.joinedTarget ? topBar.joined : topBar.surfacePhase
                    settling: {
                        if (!topBar.joinedTarget) return 0;
                        const t = Math.max(0, Math.min(1, (topBar.surfacePhase - 0.45) / 0.55));
                        return 2.4 * Math.sin(t * Math.PI * 2) * Math.pow(1 - t, 2);
                    }
                    edgeHighlight: topBar.joinedTarget ? Math.max(0, 1 - topBar.joined / 0.8) : 1
                }

                Rectangle {
                    id: desktopBox
                    x: (12 + root.drift) * (1 - topBar.joined)
                    y: topBar.pillY
                    width: 92 + (topBar.width / 3 - 92) * topBar.joined
                    height: topBar.pillHeight
                    radius: height / 2 * (1 - topBar.joined)
                    color: "transparent"
                    UiText {
                        x: 12 + root.drift * topBar.joined
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Desktop"
                        color: Theme.topBarText
                        font.pixelSize: 13
                    }
                }

                Rectangle {
                    id: clockBox
                    x: (topBar.width - width) / 2 + (root.drift - root.travelPixels / 2) * (1 - topBar.joined)
                    y: topBar.pillY
                    width: topBar.clockWidth + (topBar.width / 3 - topBar.clockWidth) * topBar.joined
                    height: topBar.pillHeight
                    radius: height / 2 * (1 - topBar.joined)
                    color: "transparent"
                    UiText {
                        id: clockText
                        font.weight: Theme.clockWeight
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: (root.drift - root.travelPixels / 2) * topBar.joined
                        text: Qt.formatDateTime(clock.date, "ddd dd MMM  ·  HH:mm")
                        color: Theme.topBarText
                        font.pixelSize: Theme.clockSize
                    }
                    MouseArea {
                        id: clockMouse
                        x: clockText.x - 12; y: 0
                        width: clockText.implicitWidth + 24; height: parent.height
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            topBar.openTrayItem = null; topBar.controlsOpen = false;
                            topBar.calendarOpen = !topBar.calendarOpen;
                        }
                    }
                }

                Rectangle {
                    id: trayBox
                    x: topBar.width - width - (12 + root.travelPixels - root.drift) * (1 - topBar.joined)
                    y: topBar.pillY
                    width: topBar.trayWidth + (topBar.width / 3 - topBar.trayWidth) * topBar.joined
                    height: topBar.pillHeight
                    radius: height / 2 * (1 - topBar.joined)
                    color: "transparent"
                }

                Row {
                    id: trayRow
                    x: trayBox.x + trayBox.width - width - 10 - (12 + root.travelPixels - root.drift) * topBar.joined
                    y: topBar.pillY + (topBar.pillHeight - height) / 2
                    spacing: 6

                    Repeater {
                        model: SystemTray.items
                        delegate: Item {
                            id: trayItem
                            required property var modelData
                            width: 26
                            height: 28

                            ClickFeedback {
                                id: trayFeedback
                                anchors.centerIn: parent
                                width: 32
                                height: 32
                                target: trayVisual
                            }

                            Item {
                                id: trayVisual
                                anchors.centerIn: parent
                                width: 20
                                height: 20

                                TrayIcon {
                                    anchors.fill: parent
                                    itemData: trayItem.modelData
                                    hovered: trayMouse.containsMouse
                                    pixelRatio: topBar.screen.devicePixelRatio
                                }
                            }

                            QsMenuOpener {
                                id: preloadMenu
                                menu: trayItem.modelData.menu
                            }

                            TrayMenu {
                                id: trayMenu
                                menuHandle: trayItem.modelData.menu
                                title: trayItem.modelData.title
                                anchorHovered: trayMouse.containsMouse
                                anchor.window: topBar.window
                                anchor.rect.x: Math.min(topBar.width - width - 8, trayItem.mapToItem(topBar.contentItem, 0, 0).x)
                                anchor.rect.y: topBar.pillY + topBar.pillHeight + 4
                                visible: topBar.openTrayItem === trayItem
                                onDismissed: topBar.openTrayItem = null
                            }

                            MouseArea {
                                id: trayMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onPressed: trayFeedback.play()
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.MiddleButton) {
                                        topBar.openTrayItem = null;
                                        trayItem.modelData.secondaryActivate();
                                    } else if (mouse.button === Qt.RightButton) {
                                        topBar.openTrayItem = null;
                                        if (trayItem.modelData.hasMenu)
                                            trayItem.modelData.display(topBar.window, trayItem.mapToItem(topBar.contentItem, 0, 0).x, topBar.pillY + topBar.pillHeight);
                                    } else if (trayItem.modelData.hasMenu) {
                                        topBar.openTrayItem = topBar.openTrayItem === trayItem ? null : trayItem;
                                    } else {
                                        trayItem.modelData.activate();
                                    }
                                }
                                onDoubleClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton) {
                                        topBar.openTrayItem = null;
                                        trayItem.modelData.activate();
                                    } else {
                                        mouse.accepted = false;
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: volume
                        readonly property var audio: Pipewire.defaultAudioSink?.audio ?? null
                        width: 82
                        height: 28
                        radius: 6
                        color: "transparent"

                        Row {
                            anchors.centerIn: parent; spacing: 6
                            opacity: volumeMouse.containsMouse ? 1 : 0.78
                            scale: volumeMouse.containsMouse ? 1.06 : 1
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                            IconImage {
                                id: volumeIcon
                                source: Qt.resolvedUrl(volume.audio?.muted ? "icons/volume-muted.svg" : "icons/volume.svg")
                                implicitSize: 17
                                layer.enabled: true
                                layer.effect: ColorOverlay { color: Theme.topBarIcon }
                            }
                            UiText { text: volume.audio ? Math.round(volume.audio.volume * 100) + "%" : "—"; color: Theme.topBarText; font.pixelSize: Theme.volumeSize; font.weight: Theme.volumeWeight }
                        }

                        MouseArea {
                            id: volumeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: volume.audio !== null
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    volume.audio.muted = !volume.audio.muted;
                                } else {
                                    topBar.openTrayItem = null;
                                    const wasOpen = topBar.controlsOpen && controls.bubbleSection === 0;
                                    controls.tab = 0; controls.bubbleSection = 0;
                                    topBar.controlsOpen = !wasOpen;
                                }
                            }
                            onWheel: wheel => {
                                volume.audio.volume = Math.max(0, Math.min(1, volume.audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)));
                            }
                        }
                    }
                    Rectangle {
                        id: bluetoothButton
                        width: 34
                        height: 28
                        radius: 6
                        color: "transparent"
                        IconImage {
                            id: bluetoothIcon
                            anchors.centerIn: parent; source: Qt.resolvedUrl("icons/bluetooth.svg")
                            layer.enabled: true
                            layer.effect: ColorOverlay { color: Theme.topBarIcon }
                            implicitSize: 18
                            opacity: bluetoothMouse.containsMouse ? 1 : 0.78
                            scale: bluetoothMouse.containsMouse ? 1.08 : 1
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                        }
                        MouseArea {
                            id: bluetoothMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                topBar.openTrayItem = null;
                                const wasOpen = topBar.controlsOpen && controls.bubbleSection === 1;
                                controls.tab = 1; controls.bubbleSection = 1;
                                topBar.controlsOpen = !wasOpen;
                            }
                        }
                    }
                    PanelButton {
                        id: controlCentreButton
                        iconTint: Theme.topBarIcon
                        width: 30; height: 28
                        flat: true
                        symbol: "configure"
                        Accessible.name: "Control centre"
                        onClicked: { topBar.openTrayItem = null; const close = topBar.controlsOpen && controls.bubbleSection === 2; controls.bubbleSection = 2; topBar.controlsOpen = !close; }
                    }
                }
            }

            PanelSurface {
                id: dock
                visible: !root.fullscreenState[modelData.name]
                onVisibleChanged: {
                    if (!visible) { expanded = false; hoveredLauncher = null; }
                }
                readonly property real glassOpacity: Theme.dockOpacity
                screen: modelData
                edge: "bottom"
                readonly property int runningCount: root.dockApps.length - root.launchers.length
                readonly property real pillGap: runningCount > 0 ? 12 : 0
                readonly property real pinnedWidth: root.launchers.length * 58 + 18
                readonly property real runningWidth: runningCount > 0 ? runningCount * 58 + 18 : 0
                readonly property real contentWidth: pinnedWidth + pillGap + runningWidth
                readonly property int hoverBuffer: 24
                implicitWidth: contentWidth + hoverBuffer * 2
                implicitHeight: 108
                color: "transparent"
                role: "dock"

                IpcHandler {
                    target: "dock-" + dock.screen.name
                    function reveal(): void { hideTimer.stop(); dock.expanded = true; }
                    function conceal(): void { dock.expanded = false; dock.hoveredLauncher = null; }
                    function preview(index: int): void { dock.expanded = true; dock.hoveredLauncher = launcherRepeater.itemAt(index); }
                }
                property var hoveredLauncher: null
                DockWindows {
                    id: windowPicker
                    anchor.window: dock.window
                    anchor.rect.x: dock.hoveredLauncher ? dock.hoveredLauncher.mapToItem(dock.contentItem, 0, 0).x + 26 : dock.width / 2
                    anchor.rect.y: dockBody.y - 6
                    anchor.edges: Edges.Top
                    anchor.gravity: Edges.Top
                    windows: dock.hoveredLauncher ? dock.hoveredLauncher.windows : []
                    anchorHovered: dock.hoveredLauncher ? dock.hoveredLauncher.hovered : false
                    visible: dock.expanded && dock.hoveredLauncher !== null && windows.length > 0
                    onSelected: id => { root.activateWindow(id); dock.hoveredLauncher = null; }
                    onCloseRequested: ids => root.requestWindowClose(ids)
                    onGroupRequested: (id, label, accent) => { windowGroups.groupNamed(id, label, accent); dock.hoveredLauncher = null; }
                    onDismissed: { dock.hoveredLauncher = null; hideTimer.restart(); }
                }
                property bool expanded: false
                property real reveal: expanded ? 1 : 0
                readonly property real amount: Math.max(0, Math.min(1, reveal))
                Behavior on reveal {
                    NumberAnimation {
                        duration: dock.expanded ? Theme.dockShowDuration : Theme.dockHideDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.32, 0, 0.25, 1, 1, 1]
                    }
                }
                blurRegion: dock.amount > 0.01 ? dockBubble.blurRegion : null
                DockBubble {
                    id: dockBubble
                    anchors.fill: parent
                    progress: dock.amount
                    rising: dock.expanded
                    pinnedWidth: dock.pinnedWidth
                    runningWidth: dock.runningWidth
                    gap: dock.pillGap
                }
                mask: Region {
                    x: dock.expanded ? 0 : dockBody.x
                    y: dock.expanded ? 0 : dockBody.y
                    width: dock.expanded ? dock.width : dockBody.width
                    height: dock.expanded ? dock.height : dockBody.height
                    Region { x: dock.hoverBuffer; y: dock.height - 3; width: dock.contentWidth; height: 3 }
                }

                Timer {
                    id: hideTimer
                    interval: Theme.dockHideDelay
                    onTriggered: { if (!windowPicker.visible && !dockMouse.containsMouse) dock.expanded = false; }
                }

                MouseArea {
                    id: dockMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: {
                        hideTimer.stop();
                        dock.expanded = true;
                    }
                    onExited: hideTimer.restart()

                    Item {
                        id: dockBody
                        x: (dock.width - width) / 2
                        y: dockBubble.bodyY
                        width: dock.contentWidth
                        height: 68

                        Item {
                            id: launcherRow
                            anchors.centerIn: parent
                            width: dock.contentWidth - 24
                            height: 52
                            opacity: dockBubble.smooth(0.28, 0.42, dock.amount)
                            enabled: dock.expanded && dock.amount > 0.8

                            Repeater {
                                id: launcherRepeater
                                model: root.dockApps
                                delegate: Rectangle {
                                    id: launcher
                                    required property var modelData
                                    required property int index
                                    x: index < root.launchers.length ? index * 58
                                        : dock.pinnedWidth + dock.pillGap + (index - root.launchers.length) * 58
                                    readonly property var windows: root.windowsFor(modelData)
                                    readonly property bool hovered: launcherMouse.containsMouse
                                    opacity: dockBubble.smooth(6, 24, -dockBubble.distance(
                                        dockBody.x + launcherRow.x + x + width / 2,
                                        dockBody.y + launcherRow.y + height / 2))
                                    scale: 0.82 + 0.18 * dockBubble.spread
                                    width: 52
                                    height: 52
                                    radius: 10
                                    color: "transparent"

                                    ClickFeedback {
                                        id: launcherFeedback
                                        anchors.centerIn: parent
                                        width: 48
                                        height: 48
                                        target: launcherIcon
                                    }

                                    Image {
                                        id: launcherIcon
                                        property real hoverZoom: launcher.hovered ? 1.18 : 1
                                        Behavior on hoverZoom {
                                            NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
                                        }
                                        transform: Scale {
                                            origin.x: launcherIcon.width / 2
                                            origin.y: launcherIcon.height / 2
                                            xScale: launcherIcon.hoverZoom
                                            yScale: launcherIcon.hoverZoom
                                        }
                                        anchors.centerIn: parent
                                        width: 32
                                        height: 32
                                        source: Quickshell.iconPath(launcher.modelData.icon)
                                        sourceSize.width: 64
                                        sourceSize.height: 64
                                        smooth: true
                                        mipmap: true
                                    }

                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 1
                                        width: 4; height: 4; radius: 2
                                        color: Theme.text
                                        visible: launcher.windows.length > 0
                                    }
                                    Timer {
                                        id: pickerDelay
                                        interval: 180
                                        onTriggered: dock.hoveredLauncher = launcher
                                    }
                                    MouseArea {
                                        id: launcherMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onPressed: launcherFeedback.play()
                                        onEntered: { dock.hoveredLauncher = null; pickerDelay.restart(); }
                                        onExited: pickerDelay.stop()
                                        onClicked: {
                                            if (launcher.windows.length) root.activateWindow(launcher.windows[0].id);
                                            else if (launcher.modelData.command) Quickshell.execDetached(launcher.modelData.command);
                                            dock.hoveredLauncher = null;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
