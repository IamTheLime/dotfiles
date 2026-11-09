.pragma library

// Pure parsing and scheduling for the calendar plugin. No QML types, so the
// test suite can load this file under node.
//
// khal renders dates with the user's own [locale] formats and has no
// machine-readable timestamp field. `khal printformats` shows how those
// formats render one fixed moment (Saturday 2013-12-21 21:45), which is enough
// to turn each format back into a parser.

var MONTHS = ["january", "february", "march", "april", "may", "june", "july",
  "august", "september", "october", "november", "december"]

var SAMPLE_DATE_TOKENS = [
  ["2013", "(\\d{4})", "Y"],
  ["December", "([A-Za-z]+)", "B"],
  ["Saturday", "[A-Za-z]+", ""],
  ["Dec", "([A-Za-z]+)", "B"],
  ["Sat", "[A-Za-z]+", ""],
  ["12", "(\\d{1,2})", "m"],
  ["21", "(\\d{1,2})", "d"],
  ["13", "(\\d{2})", "y"]
]

var SAMPLE_TIME_TOKENS = [
  ["21", "(\\d{1,2})", "H"],
  ["09", "(\\d{1,2})", "I"],
  ["9", "(\\d{1,2})", "I"],
  ["45", "(\\d{2})", "M"],
  ["00", "(\\d{2})", "S"],
  ["PM", "([AaPp][Mm])", "p"],
  ["pm", "([AaPp][Mm])", "p"]
]

function escapeRegex(text) {
  return text.replace(/[.*+?^${}()|[\]\\\/]/g, "\\$&")
}

// Turn a rendered sample into { regex, fields }. Tokens are matched longest
// first at each position so "2013" wins over "13" and "December" over "Dec".
function compileSample(sample, tokens) {
  var pattern = ""
  var fields = []
  var i = 0
  while (i < sample.length) {
    var matched = null
    for (var t = 0; t < tokens.length; t++) {
      var tok = tokens[t][0]
      if (sample.substr(i, tok.length) !== tok) continue
      if (!matched || tok.length > matched[0].length) matched = tokens[t]
    }
    if (matched) {
      pattern += matched[1]
      if (matched[2]) fields.push(matched[2])
      i += matched[0].length
    } else {
      var ch = sample.charAt(i)
      pattern += /\s/.test(ch) ? "\\s*" : escapeRegex(ch)
      i++
    }
  }
  return { regex: new RegExp("^\\s*" + pattern + "\\s*$"), fields: fields }
}

function parseFormats(text) {
  var lines = String(text || "").split("\n")
  var samples = {}
  for (var i = 0; i < lines.length; i++) {
    var m = lines[i].match(/^\s*([a-z]+):\s?(.*)$/)
    if (m) samples[m[1]] = m[2]
  }
  if (!samples.longdateformat || !samples.timeformat) return null
  var time = compileSample(samples.timeformat, SAMPLE_TIME_TOKENS)
  var date = compileSample(samples.longdateformat, SAMPLE_DATE_TOKENS)
  var result = {
    date: date,
    time: time,
    // Kept to write dates back in the same format; see formatKhalDate.
    longdate: samples.longdateformat,
    // Show times the way the user's khal shows them.
    use24h: time.fields.indexOf("p") === -1,
    error: ""
  }
  // The parsers must read khal's own sample back as 2013-12-21 21:45. A
  // format they cannot follow (non-English month names, localized AM/PM
  // markers) fails here, loudly, rather than dropping events or shifting
  // them by twelve hours.
  var d = parseDate(samples.longdateformat, date, new Date(2013, 11, 21).getTime())
  var t = parseTime(samples.timeformat, time)
  if (!d || d.year !== 2013 || d.month !== 12 || d.day !== 21)
    result.error = "Unsupported khal date format \"" + samples.longdateformat + "\". Set longdateformat = %Y-%m-%d in khal's [locale] section."
  else if (!t || t.hour !== 21 || t.minute !== 45)
    result.error = "Unsupported khal time format \"" + samples.timeformat + "\". Set timeformat = %H:%M in khal's [locale] section."
  return result
}

var MONTH_NAMES = ["January", "February", "March", "April", "May", "June", "July",
  "August", "September", "October", "November", "December"]

// The reverse of parseDate: render a day the way khal's longdateformat would,
// by swapping each field of the sample for the same field of `ms`. khal only
// reads dates on the command line in the user's own formats, so this is how
// a range starting on an arbitrary day gets asked for.
function formatKhalDate(ms, sample) {
  var d = new Date(ms)
  var values = {
    "2013": String(d.getFullYear()),
    "December": MONTH_NAMES[d.getMonth()],
    "Saturday": WEEKDAYS[d.getDay()],
    "Dec": MONTH_NAMES[d.getMonth()].substr(0, 3),
    "Sat": WEEKDAYS[d.getDay()].substr(0, 3),
    "12": pad(d.getMonth() + 1),
    "21": pad(d.getDate()),
    "13": pad(d.getFullYear() % 100)
  }
  var text = String(sample || "")
  var out = ""
  var i = 0
  while (i < text.length) {
    var matched = ""
    for (var t = 0; t < SAMPLE_DATE_TOKENS.length; t++) {
      var tok = SAMPLE_DATE_TOKENS[t][0]
      if (text.substr(i, tok.length) === tok && tok.length > matched.length) matched = tok
    }
    if (matched) {
      out += values[matched]
      i += matched.length
    } else {
      out += text.charAt(i)
      i++
    }
  }
  return out
}

function monthFromName(name) {
  var n = String(name).toLowerCase()
  for (var i = 0; i < MONTHS.length; i++) {
    if (MONTHS[i] === n || MONTHS[i].substr(0, 3) === n.substr(0, 3)) return i + 1
  }
  return 0
}

// `reference` (ms) picks the year for formats that leave it out: the one that
// puts the date nearest to it.
function parseDate(text, compiled, reference) {
  var m = String(text || "").match(compiled.regex)
  if (!m) return null
  var y = 0, mo = 0, d = 0
  for (var i = 0; i < compiled.fields.length; i++) {
    var v = m[i + 1]
    switch (compiled.fields[i]) {
    case "Y": y = parseInt(v, 10); break
    case "y": y = 2000 + parseInt(v, 10); break
    case "m": mo = parseInt(v, 10); break
    case "B": mo = monthFromName(v); break
    case "d": d = parseInt(v, 10); break
    }
  }
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null
  if (!y) {
    var ref = new Date(reference || Date.now())
    y = ref.getFullYear()
    var gap = new Date(y, mo - 1, d).getTime() - ref.getTime()
    if (gap > 182 * 86400000) y--
    else if (gap < -182 * 86400000) y++
  }
  return { year: y, month: mo, day: d }
}

function parseTime(text, compiled) {
  var m = String(text || "").match(compiled.regex)
  if (!m) return null
  var h = -1, min = 0, pm = null
  for (var i = 0; i < compiled.fields.length; i++) {
    var v = m[i + 1]
    switch (compiled.fields[i]) {
    case "H": case "I": h = parseInt(v, 10); break
    case "M": min = parseInt(v, 10); break
    case "S": break
    case "p": pm = v.toLowerCase() === "pm"; break
    }
  }
  if (h < 0) return null
  if (pm !== null) h = (h % 12) + (pm ? 12 : 0)
  if (h > 23 || min > 59) return null
  return { hour: h, minute: min }
}

function toMs(date, time) {
  return new Date(date.year, date.month - 1, date.day,
    time ? time.hour : 0, time ? time.minute : 0, 0, 0).getTime()
}

// Fields requested from `khal list --json`.
var JSON_FIELDS = ["uid", "title", "calendar", "calendar-color", "location",
  "all-day", "start-date-long", "start-time", "end-date-long", "end-time",
  "description", "url", "organizer", "status", "repeat-pattern"]

// Run khal through sh: Quickshell's Process never reports an exit when the
// binary itself is missing, but sh exits 127, which the service can show.
var KHAL_WRAPPER = ["sh", "-c", "command -v khal >/dev/null 2>&1 || exit 127; exec khal \"$@\"", "khal"]

function khalArgs(args) {
  return KHAL_WRAPPER.concat(args)
}

function khalListArgs(days) {
  var args = KHAL_WRAPPER.concat(["list"])
  for (var i = 0; i < JSON_FIELDS.length; i++) args.push("--json", JSON_FIELDS[i])
  args.push("--day-format", "", "today", Math.max(1, days) + "d")
  return args
}

// Events from `startMs` for `days` days, for browsing months other than the
// one the agenda covers.
function khalRangeArgs(startMs, days, formats) {
  var args = KHAL_WRAPPER.concat(["list"])
  for (var i = 0; i < JSON_FIELDS.length; i++) args.push("--json", JSON_FIELDS[i])
  args.push("--day-format", "", formatKhalDate(startMs, formats.longdate), Math.max(1, days) + "d")
  return args
}

// The span fetched for a month: from six days before the 1st to 41 days
// after it, which covers the six-week grid whatever day the week starts on.
function monthRange(year, month) {
  return { start: new Date(year, month, -5).getTime(), days: 48 }
}

function monthKey(year, month) {
  return year + "-" + pad(month + 1)
}

// khal prints one JSON array per day that has events. Multi-day events repeat
// on every day they touch, so dedupe on uid + start.
function parseEvents(text, formats) {
  if (!formats) return []
  var out = []
  var seen = {}
  var lines = String(text || "").split("\n")
  for (var l = 0; l < lines.length; l++) {
    var line = lines[l].trim()
    if (line.charAt(0) !== "[") continue
    var rows
    try { rows = JSON.parse(line) } catch (e) { continue }
    for (var r = 0; r < rows.length; r++) {
      var ev = normalizeEvent(rows[r], formats)
      if (!ev || seen[ev.key]) continue
      seen[ev.key] = true
      out.push(ev)
    }
  }
  out.sort(function(a, b) {
    return a.start - b.start || (b.allDay ? 1 : 0) - (a.allDay ? 1 : 0) || a.title.localeCompare(b.title)
  })
  return out
}

function normalizeEvent(row, formats) {
  if (!row) return null
  var allDay = String(row["all-day"]) === "True"
  var sd = parseDate(row["start-date-long"], formats.date)
  if (!sd) return null
  var st = allDay ? null : parseTime(row["start-time"], formats.time)
  if (!allDay && !st) return null
  var ed = parseDate(row["end-date-long"], formats.date) || sd
  var et = allDay ? null : parseTime(row["end-time"], formats.time)
  var start = toMs(sd, st)
  // khal reports an all-day event's last day inclusively; end at midnight after it.
  var end = allDay ? toMs(ed, null) + 86400000 : (et ? toMs(ed, et) : start)
  if (end < start) end = start
  var uid = String(row.uid || "")
  var calendar = String(row.calendar || "")
  var title = String(row.title || "(untitled)")
  return {
    // Events without a UID are told apart by what they show.
    key: calendar + "|" + (uid || title + "|" + end) + "|" + start,
    uid: uid,
    title: title,
    calendar: calendar,
    color: qmlColor(row["calendar-color"]),
    location: String(row.location || ""),
    description: cleanDescription(row.description),
    url: String(row.url || "").trim(),
    organizer: parseOrganizer(row.organizer),
    status: String(row.status || "").toUpperCase(),
    repeating: String(row["repeat-pattern"] || "").trim() !== "",
    allDay: allDay,
    start: start,
    end: end
  }
}

// Timed events that start within the lead window and have not been notified.
// Events that started in the last GRACE_MS still count, so a lead time of 0,
// timer drift, or a wake from suspend just after the start still notifies.
var GRACE_MS = 120000

function dueNotifications(events, now, leadMinutes, notified) {
  var horizon = now + leadMinutes * 60000
  var due = []
  for (var i = 0; i < events.length; i++) {
    var ev = events[i]
    if (ev.allDay || ev.status === "CANCELLED") continue
    if (ev.start < now - GRACE_MS || ev.start > horizon) continue
    if (notified && notified[ev.key]) continue
    due.push(ev)
  }
  return due
}

// Drop notified keys whose event started more than a day ago.
function pruneNotified(notified, now) {
  var next = {}
  for (var key in notified) {
    if (notified[key] >= now - 86400000) next[key] = notified[key]
  }
  return next
}

function isSameDay(a, b) {
  var x = new Date(a), y = new Date(b)
  return x.getFullYear() === y.getFullYear() && x.getMonth() === y.getMonth() && x.getDate() === y.getDate()
}

function pad(n) { return n < 10 ? "0" + n : String(n) }

function formatClock(ms, use24h) {
  var d = new Date(ms)
  if (use24h) return pad(d.getHours()) + ":" + pad(d.getMinutes())
  var h = d.getHours() % 12 || 12
  return h + ":" + pad(d.getMinutes()) + (d.getHours() < 12 ? " AM" : " PM")
}

function formatUntil(ms, now) {
  var minutes = Math.ceil((ms - now) / 60000)
  if (minutes <= 0) return "now"
  if (minutes < 60) return "in " + minutes + "m"
  var h = Math.floor(minutes / 60), m = minutes % 60
  return "in " + h + "h" + (m ? " " + m + "m" : "")
}

// omarchy-notification-send reads leading "-x" arguments as options.
function notificationTitle(ev) {
  var title = String(ev.title || "Event")
  return /^-/.test(title) ? "\u2060" + title : title
}

function notificationBody(ev, now, use24h) {
  var body = "Starts at " + formatClock(ev.start, use24h) + " (" + formatUntil(ev.start, now) + ")"
  // The notification server renders body markup; invite text is not markup.
  if (ev.location) body += "\n" + escapeHtml(ev.location)
  return body
}

function timeRange(ev, use24h) {
  if (ev.allDay) return "All day"
  if (ev.end <= ev.start) return formatClock(ev.start, use24h)
  return formatClock(ev.start, use24h) + " – " + formatClock(ev.end, use24h)
}

var WEEKDAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
var MONTH_SHORT = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

function dayHeading(ms, now) {
  var d = new Date(ms)
  var label = WEEKDAYS[d.getDay()] + ", " + MONTH_SHORT[d.getMonth()] + " " + d.getDate()
  if (isSameDay(ms, now)) return "Today · " + label
  if (isSameDay(ms, now + 86400000)) return "Tomorrow · " + label
  return label
}

// Agenda rows for the panel: a heading per day, then that day's events.
// Events already over are left out; an all-day event shows on its first
// remaining day.
function agendaRows(events, now) {
  var rows = []
  var lastDay = ""
  for (var i = 0; i < events.length; i++) {
    var ev = events[i]
    if (ev.end <= now) continue
    var anchor = Math.max(ev.start, startOfDay(now))
    var dayKey = new Date(anchor).toDateString()
    if (dayKey !== lastDay) {
      rows.push({ kind: "day", label: dayHeading(anchor, now) })
      lastDay = dayKey
    }
    rows.push({ kind: "event", event: ev })
  }
  return rows
}

// Rows for one chosen day: its heading, then every event that touches it.
function dayAgendaRows(events, dayMs, now) {
  var from = startOfDay(dayMs)
  var to = new Date(from)
  to.setDate(to.getDate() + 1)
  var rows = [{ kind: "day", label: dayHeading(from, now) }]
  for (var i = 0; i < events.length; i++) {
    var ev = events[i]
    if (ev.start < to.getTime() && Math.max(ev.end, ev.start + 1) > from) rows.push({ kind: "event", event: ev })
  }
  return rows
}

// Calendar colors of the events on each day, keyed like the month grid
// ("yyyy-MM-dd"), at most three per day. An event ending exactly at
// midnight does not mark the day after.
function eventsByDay(events) {
  var out = {}
  for (var i = 0; i < events.length; i++) {
    var ev = events[i]
    var cursor = new Date(startOfDay(ev.start))
    for (var n = 0; n < 62; n++) {
      if (n > 0 && cursor.getTime() >= ev.end) break
      var key = cursor.getFullYear() + "-" + pad(cursor.getMonth() + 1) + "-" + pad(cursor.getDate())
      var colors = out[key] || (out[key] = [])
      var color = ev.color || ""
      if (colors.length < 3 && colors.indexOf(color) === -1) colors.push(color)
      cursor.setDate(cursor.getDate() + 1)
    }
  }
  return out
}

function startOfDay(ms) {
  var d = new Date(ms)
  d.setHours(0, 0, 0, 0)
  return d.getTime()
}

// khal reports colors as #RRGGBB or #RRGGBBAA; QML reads 8 digits as #AARRGGBB.
function qmlColor(value) {
  var c = String(value || "").trim()
  if (/^#[0-9A-Fa-f]{6}$/.test(c)) return c
  if (/^#[0-9A-Fa-f]{8}$/.test(c)) return "#" + c.substr(7, 2) + c.substr(1, 6)
  return ""
}

// The timeFormat setting: "12-hour", "24-hour", or anything else to follow khal.
function resolveUse24h(setting, khalUse24h) {
  if (setting === "12-hour") return false
  if (setting === "24-hour") return true
  return khalUse24h !== false
}

function clampInt(value, fallback, min, max) {
  var n = parseInt(value, 10)
  if (isNaN(n)) n = fallback
  return Math.max(min, Math.min(max, n))
}

// ---------------------------------------------------------------- details
//
// khal's JSON covers title, time, location, description and URL. Meeting
// links Google stores only in X-GOOGLE-CONFERENCE, and attendees are not in
// the JSON at all, so the expanded view also reads the event's .ics file.

var URL_PATTERN = /\b(?:https?:\/\/|zoommtg:\/\/|msteams:\/\/)[^\s<>"'`]+/gi

function decodeEntities(text) {
  return String(text)
    .replace(/&nbsp;/gi, " ")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&quot;/gi, "\"")
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/&#(\d+);/g, function(_, n) { return String.fromCharCode(parseInt(n, 10)) })
    .replace(/&amp;/gi, "&")
}

// Plain text from a description that may be HTML (Google Calendar often
// stores it that way) or carry literal "\n" escapes. Anchor targets are kept
// in the text so the links survive.
function cleanDescription(value) {
  var text = String(value || "").replace(/\r\n?/g, "\n").replace(/\\n/g, "\n").replace(/\\,/g, ",")
  if (/<\/?[a-z][^>]*>/i.test(text)) {
    text = text
      .replace(/<a\b[^>]*href\s*=\s*["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi, function(_, href, label) {
        var plain = label.replace(/<[^>]+>/g, "").trim()
        return !plain || decodeEntities(plain) === decodeEntities(href) ? href : plain + " (" + href + ")"
      })
      .replace(/<br\s*\/?>/gi, "\n")
      .replace(/<\/(p|div|li|h[1-6]|tr)>/gi, "\n")
      .replace(/<li[^>]*>/gi, "• ")
      .replace(/<[^>]+>/g, "")
    text = decodeEntities(text)
  }
  return text.replace(/[ \t]+\n/g, "\n").replace(/\n{3,}/g, "\n\n").trim()
}

function trimUrl(url) {
  // Sentence punctuation and unbalanced closing brackets are not part of a link.
  url = url.replace(/[.,;:!?]+$/, "")
  while (/[)\]]$/.test(url)) {
    var close = url.charAt(url.length - 1), open = close === ")" ? "(" : "["
    if (url.split(open).length >= url.split(close).length) break
    url = url.slice(0, -1)
  }
  return url
}

function extractUrls(text) {
  var found = String(text || "").match(URL_PATTERN) || []
  var out = []
  for (var i = 0; i < found.length; i++) {
    var url = trimUrl(found[i])
    if (url && out.indexOf(url) === -1) out.push(url)
  }
  return out
}

var MEETING_SERVICES = [
  { label: "Google Meet", pattern: /^https:\/\/meet\.google\.com\/[a-z]{3,}-[a-z]{3,}-[a-z]{3,}/i },
  { label: "Zoom", pattern: /^(?:https:\/\/(?:[\w-]+\.)?zoom\.us\/(?:j|s|w|my|wc\/join)\/|zoommtg:\/\/)/i },
  { label: "Microsoft Teams", pattern: /^(?:https:\/\/teams\.(?:microsoft|live)\.com\/(?:l\/meetup-join|meet)\/|msteams:\/\/)/i },
  { label: "Jitsi", pattern: /^https:\/\/meet\.jit\.si\/[^\/?#]+/i },
  { label: "Webex", pattern: /^https:\/\/[\w-]+\.webex\.com\/(?:meet|join|[\w-]+\/j\.php)/i },
  { label: "Whereby", pattern: /^https:\/\/whereby\.com\/[^\/?#]+/i },
  { label: "Signal", pattern: /^https:\/\/signal\.group\/call\//i },
  { label: "Discord", pattern: /^https:\/\/discord\.(?:gg|com\/invite)\//i }
]

function meetingService(url) {
  for (var i = 0; i < MEETING_SERVICES.length; i++) {
    if (MEETING_SERVICES[i].pattern.test(url)) return MEETING_SERVICES[i].label
  }
  return ""
}

// Links in invites come from whoever sent them; only web and meeting-app
// links are offered, never file://, smb:// or arbitrary app handlers.
function isOpenableUrl(url) {
  return /^(?:https?|zoommtg|zoomus|msteams):\/\/[^\s]/i.test(String(url || ""))
}

function linkLabel(url) {
  var m = String(url).match(/^([a-z]+):\/\/(?:www\.)?([^\/?#]+)/i)
  if (!m) return url
  return /^https?$/i.test(m[1]) ? m[2] : m[1].toLowerCase() + "://" + m[2]
}

// RFC 5545: lines folded with CRLF + one space/tab; values escape , ; \ and n.
function unfoldIcs(text) {
  return String(text || "").replace(/\r\n?/g, "\n").replace(/\n[ \t]/g, "").split("\n")
}

function unescapeIcsValue(value) {
  return String(value).replace(/\\([\;,nN])/g, function(_, c) { return c === "n" || c === "N" ? "\n" : c })
}

function parseIcsLine(line) {
  // NAME;PARAM=VALUE;PARAM="quoted:value":VALUE
  var i = 0, inQuote = false
  for (; i < line.length; i++) {
    var ch = line.charAt(i)
    if (ch === "\"") inQuote = !inQuote
    else if (ch === ":" && !inQuote) break
  }
  var head = line.substr(0, i), value = line.substr(i + 1)
  // Split parameters on ";" outside quotes; CN="Smith; Jr" is one parameter.
  var parts = [], part = "", quoted = false
  for (var h = 0; h < head.length; h++) {
    var hc = head.charAt(h)
    if (hc === "\"") quoted = !quoted
    if (hc === ";" && !quoted) { parts.push(part); part = "" }
    else part += hc
  }
  parts.push(part)
  var params = {}
  for (var p = 1; p < parts.length; p++) {
    var eq = parts[p].indexOf("=")
    if (eq > 0) params[parts[p].substr(0, eq).toUpperCase()] = parts[p].substr(eq + 1).replace(/^"|"$/g, "")
  }
  return { name: parts[0].toUpperCase(), params: params, value: value }
}

function mailtoAddress(value) {
  return String(value || "").replace(/^mailto:/i, "").trim()
}

// Details for one UID from the text of one or more .ics files. Recurring
// events share a UID; the master VEVENT (no RECURRENCE-ID) wins over an
// override so the result does not depend on file order.
function parseIcsDetails(text, uid) {
  var lines = unfoldIcs(text)
  var best = null, current = null, depth = 0
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (/^BEGIN:VEVENT$/i.test(line)) { current = { props: [] }; depth = 1; continue }
    if (!current) continue
    if (/^BEGIN:/i.test(line)) { depth++; continue }
    if (/^END:/i.test(line)) {
      depth--
      if (depth === 0) {
        if (current.uid === uid && (!best || (best.override && !current.override))) best = current
        current = null
      }
      continue
    }
    if (depth !== 1) continue // skip VALARM and other nested components
    var prop = parseIcsLine(line)
    if (prop.name === "UID") current.uid = prop.value.trim()
    if (prop.name === "RECURRENCE-ID") current.override = true
    current.props.push(prop)
  }
  if (!best) return null

  var out = { conference: "", url: "", description: "", organizer: null, attendees: [] }
  for (var j = 0; j < best.props.length; j++) {
    var pr = best.props[j]
    switch (pr.name) {
    case "X-GOOGLE-CONFERENCE":
    case "X-MICROSOFT-SKYPETEAMSMEETINGURL":
      if (!out.conference) out.conference = pr.value.trim()
      break
    case "URL": out.url = pr.value.trim(); break
    case "DESCRIPTION": out.description = cleanDescription(unescapeIcsValue(pr.value)); break
    case "ORGANIZER":
      out.organizer = { name: pr.params.CN || "", email: mailtoAddress(pr.value) }
      break
    case "ATTENDEE":
      if ((pr.params.CUTYPE || "INDIVIDUAL").toUpperCase() !== "INDIVIDUAL") break
      out.attendees.push({
        name: pr.params.CN || "",
        email: mailtoAddress(pr.value),
        status: (pr.params.PARTSTAT || "NEEDS-ACTION").toUpperCase(),
        organizer: false
      })
      break
    }
  }
  if (out.organizer) {
    for (var a = 0; a < out.attendees.length; a++) {
      if (out.attendees[a].email.toLowerCase() === out.organizer.email.toLowerCase()) out.attendees[a].organizer = true
    }
  }
  return out
}

// khal renders ORGANIZER as "Name (email)" or just "email".
function parseOrganizer(value) {
  var text = String(value || "").trim()
  if (!text) return null
  var m = text.match(/^(.*?)\s*\(([^()]+@[^()]+)\)$/)
  var person = m ? { name: m[1].trim(), email: m[2].trim() } : { name: "", email: text }
  if (person.name === person.email) person.name = ""
  return person
}

function isPlaceholderOrganizer(person) {
  // Google uses these for birthdays, holidays and shared-calendar events.
  return !person || /^unknownorganizer@|@group\.calendar\.google\.com$|@group\.v\.calendar\.google\.com$|@virtual$/i.test(person.email)
}

function personLabel(person) {
  if (!person) return ""
  return person.name && person.name !== person.email ? person.name : person.email
}

var MAP_PROVIDERS = {
  "Google Maps": "https://www.google.com/maps/search/?api=1&query=",
  "OpenStreetMap": "https://www.openstreetmap.org/search?query=",
  "Apple Maps": "https://maps.apple.com/?q="
}

function directionsUrl(location, provider) {
  var text = String(location || "").trim()
  if (!text) return ""
  var urls = extractUrls(text)
  if (urls.length > 0 && text === urls[0]) return urls[0]
  return (MAP_PROVIDERS[provider] || MAP_PROVIDERS["Google Maps"]) + encodeURIComponent(text)
}

// Everything the expanded view shows, from the khal event plus (optionally)
// the parsed .ics details.
function eventDetails(ev, ics, mapsProvider) {
  ics = ics || null
  var description = ev.description || (ics ? ics.description : "")
  var candidates = []
  function add(url) {
    url = trimUrl(String(url || "").trim())
    if (isOpenableUrl(url) && candidates.indexOf(url) === -1) candidates.push(url)
  }
  if (ics && ics.conference) add(ics.conference)
  add(ev.url)
  if (ics) add(ics.url)
  var fromLocation = extractUrls(ev.location)
  for (var i = 0; i < fromLocation.length; i++) add(fromLocation[i])
  var fromDescription = extractUrls(description)
  for (var d = 0; d < fromDescription.length; d++) add(fromDescription[d])

  var meeting = null
  var links = []
  for (var c = 0; c < candidates.length; c++) {
    var service = meetingService(candidates[c])
    if (service && !meeting) meeting = { label: service, url: candidates[c] }
    else links.push({ label: linkLabel(candidates[c]), url: candidates[c] })
  }

  // A location that is only a meeting link is not a place to get directions to.
  var location = ev.location
  var locationIsLink = fromLocation.length > 0 && location.trim() === fromLocation[0]
  var organizer = (ics && ics.organizer) || ev.organizer
  if (isPlaceholderOrganizer(organizer)) organizer = null

  return {
    meeting: meeting,
    links: links,
    location: locationIsLink ? "" : location,
    directions: locationIsLink ? "" : directionsUrl(location, mapsProvider),
    description: description,
    organizer: organizer,
    attendees: ics ? ics.attendees : [],
    repeating: ev.repeating,
    status: ev.status
  }
}

function escapeHtml(text) {
  return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
}

// Description as StyledText with clickable links; everything else escaped.
function linkifiedHtml(text) {
  var source = String(text || "")
  var out = ""
  var last = 0
  var re = new RegExp(URL_PATTERN.source, "gi")
  var m
  while ((m = re.exec(source)) !== null) {
    var url = trimUrl(m[0])
    out += escapeHtml(source.substring(last, m.index))
    out += "<a href=\"" + escapeHtml(url) + "\">" + escapeHtml(url) + "</a>"
    last = m.index + url.length
    re.lastIndex = last
  }
  out += escapeHtml(source.substring(last))
  return out.replace(/\n/g, "<br>")
}

var ATTENDEE_STATUS = {
  "ACCEPTED": { glyph: "󰄬", label: "Going" },
  "DECLINED": { glyph: "󰅖", label: "Declined" },
  "TENTATIVE": { glyph: "󰋗", label: "Maybe" },
  "DELEGATED": { glyph: "󰁔", label: "Delegated" },
  "NEEDS-ACTION": { glyph: "󰇘", label: "Awaiting reply" }
}

function attendeeStatus(status) {
  return ATTENDEE_STATUS[status] || ATTENDEE_STATUS["NEEDS-ACTION"]
}

function attendeeSummary(attendees) {
  var counts = { going: 0, maybe: 0, declined: 0, waiting: 0 }
  for (var i = 0; i < attendees.length; i++) {
    var s = attendees[i].status
    if (s === "ACCEPTED") counts.going++
    else if (s === "TENTATIVE") counts.maybe++
    else if (s === "DECLINED") counts.declined++
    else counts.waiting++
  }
  var parts = []
  if (counts.going) parts.push(counts.going + " going")
  if (counts.maybe) parts.push(counts.maybe + " maybe")
  if (counts.declined) parts.push(counts.declined + " declined")
  if (counts.waiting) parts.push(counts.waiting + " awaiting")
  return attendees.length + (attendees.length === 1 ? " guest" : " guests") + (parts.length ? " · " + parts.join(", ") : "")
}

// Bash that prints the .ics files that may hold `$1` (a UID). Calendar folders
// come from the `path =` lines of khal's config; khal itself has no command
// that reveals where an event lives. Files are matched on the first 60 UID
// characters so a folded UID line still matches; parseIcsDetails then
// checks the full UID.
var ICS_LOOKUP_SCRIPT = [
  "cfg=\"${XDG_CONFIG_HOME:-$HOME/.config}/khal/config\"",
  "[ -f \"$cfg\" ] || cfg=\"$HOME/.khal/khal.conf\"",
  "[ -f \"$cfg\" ] || exit 3",
  "shopt -s nullglob",
  "IFS=$'\\n'",
  "dirs=()",
  "while IFS= read -r p; do",
  "  p=\"${p%%#*}\"; p=\"${p%\"${p##*[![:space:]]}\"}\"; p=\"${p#[\\\"\\']}\"; p=\"${p%[\\\"\\']}\"",
  "  p=\"${p/#\\~/$HOME}\"",
  "  for d in $p; do [ -d \"$d\" ] && dirs+=(\"$d\"); done",
  "done < <(sed -n 's/^[[:space:]]*path[[:space:]]*=[[:space:]]*//p' \"$cfg\")",
  "[ ${#dirs[@]} -gt 0 ] || exit 3",
  // Match UID as a property at the start of a line (not inside a description),
  // on its first 60 characters since long lines are folded. The file named
  // after the UID goes first; each file is read up to 256 KiB.
  "re=$(printf '%s' \"${1:0:60}\" | sed 's/[][\\\\.*^$/+?(){}|]/\\\\&/g')",
  "files=$(grep -rlE --include='*.ics' -e \"^UID:$re\" \"${dirs[@]}\" 2>/dev/null | head -n 8)",
  "for f in $files; do [ \"${f##*/}\" = \"$1.ics\" ] && { head -c 262144 \"$f\"; echo; }; done",
  "for f in $files; do [ \"${f##*/}\" = \"$1.ics\" ] || { head -c 262144 \"$f\"; echo; }; done"
].join("\n")
