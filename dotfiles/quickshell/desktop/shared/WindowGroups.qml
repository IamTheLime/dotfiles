import "theme"
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

Scope {
    id: manager
    required property var windows
    required property var fullscreen
    property var groups: []
    property var suppressed: []
    property var knownWindowIds: []

    signal command(var command)

    function appId(window) { return (window.appId || window.resourceClass || "").toLowerCase(); }
    function project(window) {
        return appId(window) === "org.kicad.kicad"
            ? window.title.split(" — ")[0].replace(/^\*\s*/, "") : "";
    }
    function keyFor(window) { return appId(window) + ":" + project(window); }
    function destination(window) {
        const parent = groups.find(group => group.ids.indexOf(window.parentId) >= 0);
        if (parent) return parent;
        return groups.filter(group => group.appId === appId(window))
            .sort((a, b) => (b.lastActive || 0) - (a.lastActive || 0))[0];
    }
    function members(group) {
        return windows.filter(window => group.ids.indexOf(window.id) >= 0
            || (!window.dialog && knownWindowIds.indexOf(window.id) < 0
                && destination(window) && destination(window).key === group.key));
    }
    function addWindow(key, id) {
        const group = get(key);
        const window = windows.find(w => w.id === id);
        if (!group || !window || window.dialog || groups.some(g => g.key !== key && g.ids.indexOf(id) >= 0)) return;
        if (group.ids.indexOf(id) < 0) replace(Object.assign({}, group, {ids: group.ids.concat([id])}));
        select(key, id);
    }
    function get(key) { return groups.find(g => g.key === key); }
    function replace(group) { groups = groups.map(g => g.key === group.key ? group : g); }
    function arrange(group, focus) {
        command({layout: {key: group.key, ids: group.ids, slots: group.slots, screen: group.screen, ratio: group.ratio === undefined ? 0.5 : group.ratio, focus: focus}});
    }
    function groupApp(id) {
        const window = windows.find(w => w.id === id);
        if (!window || window.fullscreen) return;
        const owner = groups.find(group => group.ids.indexOf(id) >= 0);
        if (owner) { select(owner.key, id); return; }
        const key = keyFor(window);
        const matching = windows.filter(w => !w.dialog && keyFor(w) === key
            && !groups.some(group => group.ids.indexOf(w.id) >= 0));
        if (matching.length < 2) return;
        suppressed = suppressed.filter(value => value !== key);
        const existing = get(key);
        if (existing) { select(key, id); return; }
        matching.sort((a, b) => a.title.localeCompare(b.title));
        const entry = DesktopEntries.heuristicLookup(window.appId || window.resourceClass);
        const group = {key: key, appId: appId(window), lastActive: window.order || 0, name: project(window) || (entry ? entry.name : window.resourceClass),
            ids: matching.map(w => w.id), pairs: [], slots: [id], focusedSlot: 0, ratio: 0.5, screen: window.screen};
        groups = groups.concat([group]);
        knownWindowIds = windows.filter(w => appId(w)).map(w => w.id);
    }
    function editGroup(key, label, accent) {
        const group = get(key);
        if (!group || !label.trim() || !/^#[0-9a-fA-F]{6}$/.test(accent)) return;
        replace(Object.assign({}, group, {name: label.trim().slice(0, 48), accent: accent}));
    }
    function groupNamed(id, label, accent) {
        groupApp(id);
        const group = groups.find(g => g.ids.indexOf(id) >= 0);
        if (group) editGroup(group.key, label, accent);
    }
    function pairFor(group, id) {
        return group ? (group.pairs || []).find(pair => pair.ids.indexOf(id) >= 0) : null;
    }
    function tabOrder(group) {
        if (!group) return [];
        const ordered = [];
        for (const id of group.ids) {
            const pair = pairFor(group, id);
            for (const member of pair ? pair.ids : [id])
                if (ordered.indexOf(member) < 0) ordered.push(member);
        }
        return ordered;
    }
    function tabBlocks(group) {
        if (!group) return [];
        const blocks = [];
        const seen = [];
        for (const id of group.ids) {
            if (seen.indexOf(id) >= 0) continue;
            const pair = pairFor(group, id);
            const ids = pair ? pair.ids.slice() : [id];
            blocks.push(ids);
            seen.push(...ids);
        }
        return blocks;
    }
    function select(key, id) {
        const group = get(key);
        if (!group || group.ids.indexOf(id) < 0) return;
        const pair = pairFor(group, id);
        const slots = pair ? pair.ids.slice() : [id];
        const next = Object.assign({}, group, {slots: slots, focusedSlot: slots.indexOf(id),
            ratio: pair ? pair.ratio : group.ratio});
        replace(next);
        arrange(next, id);
    }
    function nextSplitColor() {
        const palette = Theme.splitPalette;
        const used = [];
        for (const group of groups)
            for (const pair of group.pairs || []) used.push(pair.color);
        return palette.find(color => used.indexOf(color) < 0) || palette[used.length % palette.length];
    }
    function split(key, id, left) {
        const group = get(key);
        if (!group || group.ids.indexOf(id) < 0) return;
        const other = group.slots.find(value => value !== id) || group.ids.find(value => value !== id);
        if (!other) return;
        const previous = pairFor(group, id);
        const pair = {ids: left ? [id, other] : [other, id],
            color: previous && previous.ids.indexOf(other) >= 0 && previous.color ? previous.color : nextSplitColor(),
            ratio: previous && previous.ids.indexOf(other) >= 0 ? previous.ratio : 0.5};
        const pairs = (group.pairs || []).filter(p => p.ids.indexOf(id) < 0 && p.ids.indexOf(other) < 0).concat([pair]);
        const next = Object.assign({}, group, {pairs: pairs, slots: pair.ids.slice(), ratio: pair.ratio, focusedSlot: left ? 0 : 1});
        replace(next);
        arrange(next, id);
    }
    function unsplit(key, memberId) {
        const group = get(key);
        if (!group) return;
        const focused = group.slots[group.focusedSlot || 0];
        const pair = pairFor(group, memberId || focused);
        if (!pair) return;
        const active = pair.ids.indexOf(focused) >= 0;
        const next = Object.assign({}, group, {pairs: group.pairs.filter(p => p !== pair),
            slots: active ? [focused] : group.slots, focusedSlot: active ? 0 : group.focusedSlot});
        replace(next);
        if (active) arrange(next, focused);
    }
    function swapPanes(key) {
        const group = get(key);
        if (!group || group.slots.length !== 2) return;
        const id = group.slots[group.focusedSlot || 0];
        const pair = pairFor(group, id);
        if (!pair) return;
        const swapped = Object.assign({}, pair, {ids: pair.ids.slice().reverse(), ratio: 1 - pair.ratio});
        const next = Object.assign({}, group, {pairs: group.pairs.map(p => p === pair ? swapped : p),
            slots: swapped.ids.slice(), ratio: swapped.ratio, focusedSlot: swapped.ids.indexOf(id)});
        replace(next);
        arrange(next, id);
    }
    function resizeSplit(key, ratio) {
        const group = get(key);
        if (!group || group.slots.length !== 2) return;
        const value = Math.max(0.2, Math.min(0.8, ratio));
        const next = Object.assign({}, group, {ratio: value,
            pairs: (group.pairs || []).map(pair => pair.ids.indexOf(group.slots[0]) >= 0 ? Object.assign({}, pair, {ratio: value}) : pair)});
        replace(next);
        arrange(next, "");
    }
    function ungroup(key) {
        const group = get(key);
        if (!group) return;
        suppressed = suppressed.concat([key]);
        groups = groups.filter(g => g.key !== key);
        command({restore: group.ids});
    }
    function reconcile() {
        for (const group of groups.slice()) {
            const matching = members(group);
            const focused = matching.find(w => w.active);
            const focusedSlot = focused ? group.slots.indexOf(focused.id) : -1;
            const focusState = focused ? {screen: focused.screen,
                focusedSlot: focusedSlot >= 0 ? focusedSlot : group.focusedSlot,
                lastActive: focused.order || group.lastActive || 0} : {};
            if (focused) replace(Object.assign({}, group, focusState));
            const ids = group.ids.filter(id => matching.some(w => w.id === id));
            for (const window of matching) if (ids.indexOf(window.id) < 0) ids.push(window.id);
            if (ids.length === 0) { ungroup(group.key); continue; }
            const active = matching.find(w => w.active && !w.fullscreen);
            if (JSON.stringify(ids) !== JSON.stringify(group.ids)) {
                const removed = group.ids.filter(id => ids.indexOf(id) < 0);
                if (removed.length) command({restore: removed});
                const slots = group.slots.filter(id => ids.indexOf(id) >= 0);
                const next = Object.assign({}, group, focusState, {ids: ids, pairs: (group.pairs || []).filter(pair => pair.ids.every(id => ids.indexOf(id) >= 0)), slots: slots.length ? slots : [ids[0]],
                    focusedSlot: Math.min(group.focusedSlot || 0, Math.max(0, slots.length - 1))});
                replace(next);
                if (!matching.some(w => w.fullscreen)) {
                    if (active) select(group.key, active.id);
                    else arrange(next, "");
                }
            } else if (active && group.slots.indexOf(active.id) < 0) {
                select(group.key, active.id);
            }
        }
        knownWindowIds = windows.filter(w => appId(w)).map(w => w.id);
        const active = windows.find(w => w.active && !w.dialog && !w.fullscreen);
        if (active && appId(active) === "org.kicad.kicad" && suppressed.indexOf(keyFor(active)) < 0 && !groups.some(group => group.ids.indexOf(active.id) >= 0))
            groupApp(active.id);
    }
    function activeGroup(screenName) {
        const active = windows.find(w => w.active);
        return active ? groups.find(g => g.screen === screenName && (g.ids.indexOf(active.id) >= 0 || g.ids.indexOf(active.parentId) >= 0)) || null : null;
    }
    onWindowsChanged: settle.restart()
    Timer { id: settle; interval: 100; onTriggered: manager.reconcile() }

    Variants {
        model: manager.groups.map(group => group.key)
        FloatingWindow {
            id: strip
            required property string modelData
            property var group: manager.get(modelData)
            readonly property string tabOrderSignature: JSON.stringify(manager.tabBlocks(group))
            readonly property bool splitVisible: !!group && group.slots.length === 2
            GroupEditor {
                id: groupEditor
                anchor.window: strip
                anchor.rect.x: 12
                anchor.rect.y: 40
                onSaved: (label, accent) => manager.editGroup(strip.modelData, label, accent)
            }
            property real dragRatio: 0.5
            readonly property real splitRatio: dividerMouse.pressed ? dragRatio
                : group && group.ratio !== undefined ? group.ratio : 0.5
            property bool resizePending: false
            property bool initialFocusPending: false
            function flushResize() {
                if (resizePending) {
                    resizePending = false;
                    manager.resizeSplit(modelData, dragRatio);
                }
            }
            Timer {
                interval: 60
                repeat: true
                running: dividerMouse.pressed
                onTriggered: strip.flushResize()
            }
            title: "Quickshell group: " + modelData
            visible: group !== undefined
            implicitWidth: 1200
            implicitHeight: 800
            minimumSize: Qt.size(900, 500)
            color: "transparent"
            mask: Region {
                width: strip.width; height: strip.height
                Region { x: 4; y: 40; width: strip.width - 8; height: strip.height - 44; intersection: Intersection.Subtract }
                Region { x: divider.x; y: divider.y; width: divider.visible ? divider.width : 0; height: divider.height }
            }
            onClosed: manager.ungroup(modelData)
            onVisibleChanged: { if (visible) frameReady.restart(); }
            Timer {
                id: frameReady
                interval: 150
                onTriggered: {
                    if (!strip.group || !strip.visible) return;
                    manager.arrange(strip.group, strip.initialFocusPending ? strip.group.slots[0] : "");
                    strip.initialFocusPending = false;
                }
            }
            Component.onCompleted: { initialFocusPending = visible; frameReady.start(); }
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 4
                border.color: Theme.groupBorder
            }
            Rectangle {
                id: divider
                x: 4 + Math.floor((strip.width - 16) * strip.splitRatio)
                y: 40
                width: 8; height: strip.height - 44
                color: dividerMouse.containsMouse || dividerMouse.pressed ? Theme.dividerHover : Theme.groupBorder
                visible: strip.group !== undefined && strip.group.slots.length === 2
                MouseArea {
                    id: dividerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.SplitHCursor
                    onPressed: {
                        strip.dragRatio = strip.group.ratio === undefined ? 0.5 : strip.group.ratio;
                    }
                    onPositionChanged: mouse => {
                        if (!pressed) return;
                        const point = mapToItem(strip.contentItem, mouse.x, mouse.y);
                        const minimum = Math.max(0.2, Math.min(0.5, 240 / (strip.width - 16)));
                        strip.dragRatio = Math.max(minimum, Math.min(1 - minimum, (point.x - 8) / (strip.width - 16)));
                        strip.resizePending = true;
                    }
                    onReleased: strip.flushResize()
                    onCanceled: strip.flushResize()
                }
            }
            MouseArea {
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                height: 4; cursorShape: Qt.SizeVerCursor
                onPressed: strip.startSystemResize(Qt.TopEdge)
            }
            MouseArea {
                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                width: 4; cursorShape: Qt.SizeHorCursor
                onPressed: strip.startSystemResize(Qt.LeftEdge)
            }
            MouseArea {
                anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                width: 4; cursorShape: Qt.SizeHorCursor
                onPressed: strip.startSystemResize(Qt.RightEdge)
            }
            MouseArea {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 4; cursorShape: Qt.SizeVerCursor
                onPressed: strip.startSystemResize(Qt.BottomEdge)
            }
            property string draggedId: ""
            property string draggedTitle: ""
            property point dragPosition: Qt.point(0, 0)
            Rectangle {
                x: strip.dragPosition.x < strip.width / 2 ? 4 : strip.width / 2 + 4
                y: 40
                width: (strip.width - 16) / 2
                height: strip.height - 44
                color: Theme.accent
                opacity: strip.draggedId !== "" ? 0.1 : 0
                Behavior on opacity { NumberAnimation { duration: 140 } }
                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }
            Rectangle {
                id: stripBody
                x: 4; y: 4
                width: parent.width - 8
                height: 36
                color: Theme.groupFrame
                MouseArea {
                    anchors.fill: parent
                    onPressed: strip.startSystemMove()
                    onDoubleClicked: strip.maximized = !strip.maximized
                }
                Row {
                    id: groupRow
                    x: 8
                    spacing: 4
                    opacity: 1
                    PanelButton {
                        width: 28; height: 32; y: 2; flat: true
                        symbol: "ungroup-all"
                        Accessible.name: "Ungroup all windows"
                        ToolTip.visible: hovered; ToolTip.delay: 450; ToolTip.text: "Ungroup all windows"
                        onClicked: manager.ungroup(strip.modelData)
                    }
                    Button {
                        id: groupLabel
                        width: 110; height: 36
                        hoverEnabled: true
                        Accessible.name: "Edit group " + (strip.group ? strip.group.name : "")
                        background: Rectangle { radius: 4; color: groupLabel.hovered ? Theme.buttonHover : "transparent" }
                        contentItem: Item {
                            Rectangle { x: 2; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 3; color: strip.group?.accent || Theme.accent }
                            Text {
                                anchors.fill: parent; anchors.leftMargin: 18
                                text: strip.group ? strip.group.name : ""
                                color: strip.group?.accent || Theme.accent
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                        }
                        onClicked: groupEditor.open(strip.group.name, strip.group.accent)
                    }
                    Repeater {
                        model: JSON.parse(strip.tabOrderSignature)
                        Item {
                            id: block
                            required property var modelData
                            readonly property bool paired: modelData.length === 2
                            readonly property color pairColor: manager.pairFor(strip.group, modelData[0])?.color || Theme.splitPalette[0]
                            readonly property real tabWidth: Math.min(190, Math.max(75, (strip.width - 300 - ((strip.group?.pairs || []).length * 44)) / Math.max(1, strip.group?.ids.length || 1)))
                            property real formation: paired ? 0 : 1
                            property bool dissolving: false
                            width: paired ? tabWidth * 2 + 44 : tabWidth
                            height: 36
                            Component.onCompleted: formation = 1
                            Behavior on formation { NumberAnimation { duration: block.dissolving ? 180 : 260; easing.type: Easing.OutCubic } }
                            SplitEnvelope { anchors.fill: parent; visible: block.paired; formation: block.formation; tint: block.pairColor }
                            Rectangle {
                                visible: block.paired
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width * block.formation; height: 2
                                color: block.pairColor
                            }
                            Timer {
                                id: dissolveTimer
                                interval: 180
                                onTriggered: manager.unsplit(strip.modelData, block.modelData[0])
                            }
                            Row {
                                x: block.paired ? 4 : 0
                                y: 3
                                spacing: 4
                                Repeater {
                                    model: block.modelData
                                    Rectangle {
                                        id: tab
                                        required property string modelData
                                        required property int index
                                        readonly property var window: manager.windows.find(w => w.id === modelData)
                                        readonly property bool selected: !!strip.group && strip.group.slots[strip.group.focusedSlot || 0] === modelData
                                        readonly property bool dragging: strip.draggedId === modelData
                                        width: block.tabWidth
                                        height: 28
                                        radius: 3
                                        scale: dragging ? 1.05 : tabClose.down ? 0.97 : 1
                                        opacity: dragging ? 0.35 : 1
                                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                                        Behavior on opacity { NumberAnimation { duration: 120 } }
                                        transform: Translate {
                                            x: block.paired ? (tab.index === 0 ? -5 : 5) * (1 - block.formation) : 0
                                            y: tab.dragging ? -3 : 0
                                            Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                                        }
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0; color: Theme.tabBackground }
                                            GradientStop { position: Math.max(0, 1 - 28 / tab.width); color: Theme.tabBackground }
                                            GradientStop { position: 1; color: tabClose.hovered ? Theme.closeHover : Theme.closeEdge; Behavior on color { ColorAnimation { duration: 80 } } }
                                        }
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: tab.selected ? parent.width : 0
                                            height: 2
                                            color: Theme.tabUnderline
                                            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                        }
                                        Text {
                                            id: tabLabel
                                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 30
                                            text: ((strip.group ? strip.group.ids.indexOf(tab.modelData) : 0) + 1) + "  " + (tab.window ? (manager.project(tab.window) ? tab.window.title.split(" — ").slice(1).join(" — ") : tab.window.title) : "")
                                            color: Theme.text; font.pixelSize: 12
                                            verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                                        }
                                        Button {
                                            id: tabClose
                                            anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                                            width: 28; hoverEnabled: true
                                            Accessible.name: "Close " + (tab.window ? tab.window.title : "window")
                                            background: Item {}
                                            contentItem: Text { text: "×"; color: "white"; font.pixelSize: 19; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                            onClicked: manager.command({close: [tab.modelData]})
                                        }
                            MouseArea {
                                anchors.fill: parent
                                anchors.rightMargin: 30
                                property point start
                                property bool moved: false
                                onPressed: mouse => {
                                    start = mapToItem(strip.contentItem, mouse.x, mouse.y);
                                    moved = false;
                                }
                                onPositionChanged: mouse => {
                                    if (!pressed) return;
                                    const point = mapToItem(strip.contentItem, mouse.x, mouse.y);
                                    if (Math.hypot(point.x - start.x, point.y - start.y) > 14) moved = true;
                                    if (moved) {
                                        strip.dragPosition = point;
                                        strip.draggedTitle = tabLabel.text;
                                        strip.draggedId = tab.modelData;
                                    }
                                }
                                onReleased: mouse => {
                                    const point = mapToItem(strip.contentItem, mouse.x, mouse.y);
                                    const id = tab.modelData;
                                    const key = strip.modelData;
                                    strip.draggedId = "";
                                    if (moved) {
                                        if (point.x >= 0 && point.x <= strip.width && point.y >= 0 && point.y <= strip.height)
                                            manager.split(key, id, point.x < strip.width / 2);
                                    } else manager.select(key, id);
                                }
                                onCanceled: strip.draggedId = ""
                            }
                                    }
                                }
                                PanelButton {
                                    visible: block.paired
                                    width: 28; height: 28
                                    flat: true
                                    symbol: "unsplit"
                                    iconTint: block.pairColor
                                    enabled: !block.dissolving
                                    Accessible.name: "Unsplit these two tabs"
                                    ToolTip.visible: hovered; ToolTip.delay: 450; ToolTip.text: "Unsplit these tabs"
                                    onClicked: { block.dissolving = true; block.formation = 0; dissolveTimer.start(); }
                                }
                            }
                        }
                    }
                }
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 8
                y: 6
                spacing: 2
                Repeater {
                    model: ["−", "□", "×"]
                    Rectangle {
                        required property string modelData
                        required property int index
                        width: 28; height: 28
                        color: controlMouse.containsMouse ? Theme.buttonHover : Theme.groupFrame
                        Text { anchors.centerIn: parent; text: modelData; color: Theme.text; font.pixelSize: 18 }
                        MouseArea {
                            id: controlMouse
                            anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                if (index === 0) strip.minimized = true;
                                else if (index === 1) strip.maximized = !strip.maximized;
                                else manager.ungroup(strip.modelData);
                            }
                        }
                    }
                }
            }
            DraggedTab {
                active: strip.draggedId !== ""
                label: strip.draggedTitle
                side: strip.dragPosition.x < strip.width / 2 ? "Left pane" : "Right pane"
                x: Math.max(0, Math.min(strip.width - width, strip.dragPosition.x - width / 2))
                y: Math.max(0, Math.min(strip.height - height, strip.dragPosition.y - height / 2))
                z: 20
            }
        }
    }
}
