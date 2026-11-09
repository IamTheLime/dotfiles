import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Headless calendar service. Reads upcoming events from khal once a minute,
// sends a desktop notification shortly before each timed event, and can run a
// sync command (vdirsyncer by default) on its own interval. The bar widget
// reads `events` from here and pushes its settings in through configure();
// the panel asks for other months through loadMonth().
Item {
  id: root

  property bool syncConfigured: false
  FileView {
    id: connectionFile
    path: root.stateDir + "/connected"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      root.syncConfigured = text().trim() === "google"
      if (root.syncConfigured) {
        root.syncCommand = 'vdirsyncer -c "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell-calendar/vdirsyncer.conf" sync google'
        root.syncIntervalMinutes = 15
      }
    }
  }

  // Settings. The bar widget's shell.json entry overrides these; without the
  // widget in the bar, the defaults apply.
  property int leadMinutes: 10
  property bool notifications: false
  property int agendaDays: 7
  property int syncIntervalMinutes: 0
  property string syncCommand: ""
  property string timeFormat: "Match khal"
  property string mapsProvider: "Google Maps"

  property var formats: null
  property var events: []
  property bool khalAvailable: true
  property bool syncAvailable: true
  property bool syncing: false
  property string syncError: ""
  // Held false for the first seconds so the bar widget can deliver the
  // user's settings before anything is notified or synced.
  property bool settled: true
  property string lastError: ""
  property double lastRefresh: 0
  property double lastSync: 0
  property var notified: ({})

  // Parsed .ics details keyed by event UID, filled on demand when an event is
  // expanded in the agenda. `null` marks a lookup that found nothing.
  property var icsDetails: ({})
  property var _detailQueue: []
  property string _detailUid: ""

  // Events for months browsed in the panel, keyed "yyyy-MM", each stored as
  // { generation, events }. Bumping rangeGeneration marks every month stale
  // without dropping it, so the grid keeps its dots while a month reloads.
  property var monthEvents: ({})
  property int rangeGeneration: 0
  property string _pendingRange: ""

  readonly property bool use24h: Model.resolveUse24h(timeFormat, formats ? formats.use24h : true)
  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell-calendar"

  function configure(settings) {
    var s = settings || {}
    leadMinutes = Model.clampInt(s.leadMinutes, 10, 0, 240)
    notifications = s.notifications === undefined ? true : !!s.notifications
    agendaDays = Model.clampInt(s.agendaDays, 7, 1, 60)
    syncIntervalMinutes = Model.clampInt(s.syncIntervalMinutes, 15, 0, 1440)
    timeFormat = String(s.timeFormat || "Match khal")
    mapsProvider = String(s.mapsProvider || "Google Maps")
    syncCommand = s.syncCommand === undefined || s.syncCommand === null ? "vdirsyncer sync" : String(s.syncCommand)
    // Nothing syncs or notifies until the user's settings are in.
    if (!settled) {
      settled = true
      Qt.callLater(checkNotifications)
    }
  }

  onAgendaDaysChanged: Qt.callLater(refresh)

  function refresh() {
    if (!formats) {
      if (!formatsProc.running) formatsProc.running = true
      return
    }
    if (listProc.running) return
    listProc.command = Model.khalListArgs(agendaDays)
    listProc.running = true
  }

  // A refresh the user asked for: re-read khal for browsed months too.
  function reload() {
    invalidateMonths()
    refresh()
  }

  function invalidateMonths() {
    rangeGeneration++
  }

  // Only the newest request waits: stepping quickly through months should
  // not queue a khal run for every month passed on the way.
  function loadMonth(year, month) {
    var key = Model.monthKey(year, month)
    var entry = monthEvents[key]
    if (entry && entry.generation === rangeGeneration) return
    if (key === rangeProc.key && rangeProc.running && rangeProc.generation === rangeGeneration) return
    _pendingRange = key
    _nextRange()
  }

  function _nextRange() {
    if (rangeProc.running || !_pendingRange || !formats) return
    var parts = _pendingRange.split("-")
    var range = Model.monthRange(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1)
    rangeProc.key = _pendingRange
    rangeProc.generation = rangeGeneration
    _pendingRange = ""
    rangeProc.command = Model.khalRangeArgs(range.start, range.days, formats)
    rangeProc.running = true
  }

  function sync() {
    if (syncing || syncCommand.trim() === "") return
    syncing = true
    syncWatchdog.fired = false
    syncProc.command = ["sh", "-c", syncCommand]
    syncProc.running = true
  }

  function hasDetails(uid) {
    return Object.prototype.hasOwnProperty.call(icsDetails, uid)
  }

  function loadDetails(uid) {
    uid = String(uid || "")
    if (!uid || hasDetails(uid) || uid === _detailUid || _detailQueue.indexOf(uid) !== -1) return
    _detailQueue = _detailQueue.concat([uid])
    _nextDetail()
  }

  function _nextDetail() {
    if (detailProc.running || _detailQueue.length === 0) return
    _detailUid = _detailQueue[0]
    _detailQueue = _detailQueue.slice(1)
    detailProc.command = ["bash", "-c", Model.ICS_LOOKUP_SCRIPT, "calendar-ics-lookup", _detailUid]
    detailProc.running = true
  }

  function _storeDetails(uid, value) {
    var next = ({})
    for (var k in icsDetails) next[k] = icsDetails[k]
    next[uid] = value
    icsDetails = next
  }

  function details(ev) {
    if (!ev) return null
    return Model.eventDetails(ev, hasDetails(ev.uid) ? icsDetails[ev.uid] : null, mapsProvider)
  }

  function openUrl(url) {
    if (Model.isOpenableUrl(url)) Quickshell.execDetached(["xdg-open", String(url)])
  }

  function copyText(text) {
    if (text) Quickshell.execDetached(["wl-copy", "--", String(text)])
  }

  function checkNotifications() {
    if (!settled || !notifications) return
    var now = Date.now()
    var due = Model.dueNotifications(events, now, leadMinutes, notified)
    if (due.length === 0) return
    var next = Model.pruneNotified(notified, now)
    for (var i = 0; i < due.length; i++) {
      var ev = due[i]
      Quickshell.execDetached(["notify-send", "--app-name", "Calendar", "-u", "normal", Model.notificationTitle(ev), Model.notificationBody(ev, now, root.use24h)])
      next[ev.key] = ev.start
    }
    notified = next
    notifiedFile.setText(JSON.stringify(next) + "\n")
  }

  // Remember notified events across shell restarts so a reload inside the
  // lead window does not repeat a notification. Loaded keys are merged in,
  // never replacing ones this session has already sent.
  FileView {
    id: notifiedFile
    path: root.stateDir + "/notified.json"
    atomicWrites: true
    printErrors: false
    onLoaded: {
      var parsed = {}
      try { parsed = JSON.parse(text()) || {} } catch (e) { parsed = {} }
      var next = ({})
      for (var k in parsed) next[k] = parsed[k]
      for (var j in root.notified) next[j] = root.notified[j]
      root.notified = next
    }
  }

  Process {
    id: stateDirProc
    command: ["mkdir", "-p", root.stateDir]
    running: true
    onExited: notifiedFile.reload()
  }

  Process {
    id: formatsProc
    command: Model.khalArgs(["printformats"])
    property string output: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: formatsProc.output = text
    }
    onExited: function(exitCode) {
      var text = formatsProc.output
      formatsProc.output = ""
      if (exitCode !== 0) {
        root.formats = null
        root.khalAvailable = exitCode !== 127
        root.lastError = exitCode === 127 ? "" : "khal printformats failed (exit " + exitCode + ")"
        return
      }
      root.khalAvailable = true
      var parsed = Model.parseFormats(text)
      if (!parsed || parsed.error) {
        root.formats = null
        root.lastError = parsed ? parsed.error : "Could not read khal's date formats"
        return
      }
      root.formats = parsed
      root.lastError = ""
      Qt.callLater(root.refresh)
      Qt.callLater(root._nextRange)
    }
  }

  Process {
    id: listProc
    property string output: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: listProc.output = text
    }
    // stdout finishes before exit, even on failure, so events are replaced
    // here and only on success: a transient khal error keeps the last agenda.
    onExited: function(exitCode) {
      var text = listProc.output
      listProc.output = ""
      if (exitCode !== 0) {
        root.lastError = exitCode === 127 ? "" : "khal list failed (exit " + exitCode + ")"
        if (exitCode === 127) root.khalAvailable = false
        return
      }
      // The shell outlives timezone changes; khal prints times in the
      // current zone, so the JS engine must use it too.
      if (typeof Date.timeZoneUpdated === "function") Date.timeZoneUpdated()
      root.events = Model.parseEvents(text, root.formats)
      root.lastRefresh = Date.now()
      root.lastError = ""
      root.checkNotifications()
    }
  }

  Process {
    id: rangeProc
    property string key: ""
    property int generation: 0
    property string output: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: rangeProc.output = text
    }
    onExited: function(exitCode) {
      var text = rangeProc.output
      rangeProc.output = ""
      if (exitCode === 0) {
        if (typeof Date.timeZoneUpdated === "function") Date.timeZoneUpdated()
        var next = ({})
        for (var k in root.monthEvents) next[k] = root.monthEvents[k]
        next[rangeProc.key] = { generation: rangeProc.generation, events: Model.parseEvents(text, root.formats) }
        root.monthEvents = next
      }
      // Invalidated while it ran: read this month again.
      if (rangeProc.generation !== root.rangeGeneration && root._pendingRange === "")
        root._pendingRange = rangeProc.key
      Qt.callLater(root._nextRange)
    }
  }

  Process {
    id: detailProc
    property string output: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: detailProc.output = text
    }
    onExited: function(exitCode) {
      var uid = root._detailUid
      root._storeDetails(uid, Model.parseIcsDetails(detailProc.output, uid))
      detailProc.output = ""
      root._detailUid = ""
      Qt.callLater(root._nextDetail)
    }
  }

  Process {
    id: syncProc
    onExited: function(exitCode) {
      syncWatchdog.stop()
      root.syncing = false
      if (exitCode === 127) {
        // The sync tool is not installed; stop trying until settings change.
        root.syncAvailable = false
        return
      }
      root.syncAvailable = true
      if (exitCode !== 0) {
        root.syncError = syncWatchdog.fired ? "Sync timed out" : "Sync failed (exit " + exitCode + ")"
        syncWatchdog.fired = false
        return
      }
      root.syncError = ""
      root.lastSync = Date.now()
      root.icsDetails = ({})
      root.invalidateMonths()
      // Re-read formats too, so a changed khal [locale] applies without a restart.
      if (!formatsProc.running) formatsProc.running = true
    }
  }

  // A sync that hangs (network stall, an OAuth prompt nobody answers) would
  // otherwise block every later sync.
  Timer {
    id: syncWatchdog
    property bool fired: false
    interval: 5 * 60000
    running: root.syncing
    onTriggered: {
      fired = true
      syncProc.running = false
    }
  }

  onSyncCommandChanged: {
    syncAvailable = true
    syncError = ""
  }

  // Aligned to the top of each minute so notifications land on time.
  Timer {
    id: minuteTimer
    interval: 60000 - (Date.now() % 60000) + 1000
    running: true
    repeat: true
    onTriggered: {
      interval = 60000 - (Date.now() % 60000) + 1000
      connectionFile.reload()
      root.refresh()
    }
  }

  // Fallback for a service running without its bar widget (defaults apply).
  Timer {
    interval: 30000
    running: !root.settled
    onTriggered: {
      root.settled = true
      root.checkNotifications()
    }
  }

  Timer {
    interval: Math.max(1, root.syncIntervalMinutes) * 60000
    running: root.settled && root.syncIntervalMinutes > 0 && root.syncAvailable && root.syncCommand.trim() !== ""
    repeat: true
    triggeredOnStart: true
    onTriggered: root.sync()
  }

  IpcHandler {
    target: "calendar"

    function refresh(): void { root.reload() }
    function sync(): void { root.sync() }
    function status(): string {
      return JSON.stringify({
        khal: root.khalAvailable,
        events: root.events.length,
        months: Object.keys(root.monthEvents).sort(),
        syncing: root.syncing,
        lastSync: root.lastSync,
        lastRefresh: root.lastRefresh,
        error: root.lastError,
        syncError: root.syncError
      })
    }
  }

  Component.onCompleted: formatsProc.running = true
}
