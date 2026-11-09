import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "theme"
import "../platform"
import "calendar/ClockModel.js" as Dates
import "calendar/Model.js" as Events

PopupWindow {
    id: panel
    required property var service
    property real bubbleCenter: width / 2
    property real clockWidth: 190
    property string clockLabel: ""
    signal dismissed()
    grabFocus: true
    color: "transparent"
    implicitWidth: 392
    implicitHeight: Math.min(690, (screen?.height ?? 900) - 90)
    SystemClock { id: clock; precision: SystemClock.Minutes }
    property int viewYear: clock.date.getFullYear()
    property int viewMonth: clock.date.getMonth()
    property string selectedKey: Dates.keyForDate(clock.date)
    property string expandedEvent: ""
    readonly property var weeks: Dates.monthGrid(viewYear, viewMonth, 1, Dates.keyForDate(clock.date))
    readonly property var monthEvents: service.monthEvents[Events.monthKey(viewYear, viewMonth)]?.events ?? []
    readonly property var dots: Events.eventsByDay(monthEvents)
    readonly property var selectedDate: {
        const parts = selectedKey.split("-");
        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
    }
    readonly property var agenda: Events.dayAgendaRows(monthEvents, selectedDate.getTime(), clock.date.getTime()).filter(row => row.kind === "event")
    function moveMonth(delta) {
        const next = Dates.stepMonth(viewYear, viewMonth, delta);
        viewYear = next.year; viewMonth = next.month;
        selectedKey = Dates.dateKey(viewYear, viewMonth, 1);
        service.loadMonth(viewYear, viewMonth);
    }
    function today() {
        viewYear = clock.date.getFullYear(); viewMonth = clock.date.getMonth();
        selectedKey = Dates.keyForDate(clock.date);
        service.loadMonth(viewYear, viewMonth);
    }
    onSelectedKeyChanged: expandedEvent = ""
    onVisibleChanged: {
        if (visible) { service.reload(); service.loadMonth(viewYear, viewMonth); content.forceActiveFocus(); }
        else dismissed();
    }
    Connections {
        target: service
        function onRangeGenerationChanged() { if (panel.visible) service.loadMonth(panel.viewYear, panel.viewMonth); }
    }
    BackgroundEffect.blurRegion: Backend.capabilities.blur ? glass.blurRegion : null
    mask: Region { regions: [glass.blurRegion] }
    GlassBubble {
        id: glass
        neckCenter: panel.bubbleCenter
        neckWidth: panel.clockWidth
        UiText {
            x: glass.neckX - width / 2; y: 3
            width: glass.neckWidth - 16; height: 28
            text: panel.clockLabel
            color: Theme.topBarText; font.pixelSize: Theme.clockSize; font.weight: Theme.clockWeight
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
        MouseArea {
            x: glass.neckX - glass.neckWidth / 2; y: 0
            width: glass.neckWidth; height: glass.neckHeight
            onClicked: panel.dismissed()
        }
        Item {
            id: content
            anchors.fill: parent; anchors.margins: 18
            anchors.topMargin: glass.neckHeight + 18
            focus: true
            Keys.onEscapePressed: panel.dismissed()
            Keys.onLeftPressed: panel.moveMonth(-1)
            Keys.onRightPressed: panel.moveMonth(1)
            ColumnLayout {
                anchors.fill: parent; spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    UiText { text: "Calendar"; font.pixelSize: 18; font.weight: Theme.headingWeight; color: Theme.text; Layout.fillWidth: true }
                    PanelButton { text: "Today"; onClicked: panel.today() }
                    PanelButton { text: "×"; Accessible.name: "Close calendar"; onClicked: panel.dismissed() }
                }
                RowLayout {
                    Layout.fillWidth: true
                    PanelButton { text: "‹"; Accessible.name: "Previous month"; onClicked: panel.moveMonth(-1) }
                    UiText { text: Qt.formatDateTime(new Date(panel.viewYear, panel.viewMonth, 1), "MMMM yyyy"); color: Theme.text; font.pixelSize: 16; font.weight: Theme.headingWeight; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
                    PanelButton { text: "›"; Accessible.name: "Next month"; onClicked: panel.moveMonth(1) }
                }
                Row {
                    Layout.fillWidth: true
                    Repeater {
                        model: ["M", "T", "W", "T", "F", "S", "S"]
                        UiText { required property string modelData; width: parent.width / 7; text: modelData; horizontalAlignment: Text.AlignHCenter; color: Theme.muted; font.pixelSize: 12 }
                    }
                }
                Column {
                    Layout.fillWidth: true; spacing: 3
                    Repeater {
                        model: panel.weeks
                        Row {
                            required property var modelData
                            width: parent.width
                            Repeater {
                                model: parent.modelData.days
                                delegate: Item {
                                    id: day
                                    required property var modelData
                                    width: parent.width / 7; height: 36
                                    Rectangle {
                                        anchors.fill: parent; anchors.margins: 2; radius: 10
                                        color: panel.selectedKey === day.modelData.key ? Theme.buttonActive : dayMouse.containsMouse ? Theme.buttonHover : "transparent"
                                        border.width: day.modelData.today ? 1 : 0; border.color: Theme.accent
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                    }
                                    UiText { anchors.centerIn: parent; text: day.modelData.day; color: day.modelData.inMonth ? Theme.text : Theme.muted; opacity: day.modelData.inMonth ? 1 : 0.5; font.pixelSize: 13 }
                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 3; spacing: 2
                                        Repeater {
                                            model: panel.dots[day.modelData.key] ?? []
                                            Rectangle { required property string modelData; width: 3; height: 3; radius: 1.5; color: modelData || Theme.accent }
                                        }
                                    }
                                    MouseArea {
                                        id: dayMouse; anchors.fill: parent; hoverEnabled: true
                                        onClicked: {
                                            panel.viewYear = day.modelData.year; panel.viewMonth = day.modelData.month;
                                            panel.selectedKey = day.modelData.key;
                                            service.loadMonth(panel.viewYear, panel.viewMonth);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                UiText { text: Qt.formatDateTime(panel.selectedDate, "dddd, d MMMM"); font.pixelSize: 13; font.weight: Theme.headingWeight; color: Theme.text }
                ScrollView {
                    id: agendaScroll
                    Layout.fillWidth: true; Layout.fillHeight: true
                    contentWidth: availableWidth; contentHeight: agendaColumn.implicitHeight
                    clip: true; ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    Column {
                        id: agendaColumn; width: agendaScroll.availableWidth; spacing: 8
                        UiText {
                            width: parent.width; wrapMode: Text.Wrap; color: Theme.muted; font.pixelSize: 12
                            visible: !service.syncConfigured || service.lastError !== "" || service.syncError !== "" || panel.agenda.length === 0
                            text: !service.syncConfigured ? "Connect Google Calendar to see your events here." : service.syncError || service.lastError || "No events on this day."
                        }
                        Repeater {
                            model: panel.agenda
                            Rectangle {
                                id: eventCard
                                required property var modelData
                                readonly property var event: modelData.event
                                width: parent.width; height: eventColumn.implicitHeight + 20
                                radius: 14; color: Theme.card
                                Column {
                                    id: eventColumn; anchors { top: parent.top; left: parent.left; right: parent.right; margins: 10 }
                                    spacing: 5
                                    UiText { width: parent.width; text: eventCard.event.title; textFormat: Text.PlainText; wrapMode: Text.Wrap; color: Theme.text; font.weight: Theme.headingWeight; font.pixelSize: 13 }
                                    UiText { width: parent.width; text: Events.timeRange(eventCard.event, service.use24h); color: Theme.accent; font.pixelSize: 12 }
                                    UiText { width: parent.width; text: eventCard.event.location; textFormat: Text.PlainText; wrapMode: Text.Wrap; visible: text !== ""; color: Theme.muted; font.pixelSize: 12 }
                                    UiText { width: parent.width; text: eventCard.event.description; textFormat: Text.PlainText; wrapMode: Text.Wrap; visible: panel.expandedEvent === eventCard.event.key && text !== ""; color: Theme.text; font.pixelSize: 12 }
                                }
                                MouseArea { anchors.fill: parent; onClicked: panel.expandedEvent = panel.expandedEvent === eventCard.event.key ? "" : eventCard.event.key }
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    UiText { Layout.fillWidth: true; font.pixelSize: 11; color: Theme.muted; text: service.syncing ? "Syncing…" : service.lastSync ? "Synced " + Qt.formatTime(new Date(service.lastSync), "HH:mm") : "Google Calendar" }
                    PanelButton { text: "Refresh"; onClicked: { if (service.syncConfigured) service.sync(); else service.reload(); } }
                }
            }
        }
    }
}
