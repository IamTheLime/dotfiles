// Run with: node --test tests/
const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

function loadModel() {
  const source = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8")
    .replace(/^\.pragma library\s*$/m, "")
  const ctx = {}
  vm.createContext(ctx)
  vm.runInContext(source, ctx)
  return ctx
}

const M = loadModel()

// Values from the vm context have foreign prototypes; compare as plain JSON.
const same = (actual, expected, msg) =>
  assert.deepEqual(JSON.parse(JSON.stringify(actual)), expected, ...(msg ? [msg] : []))

function formats(longdate, time) {
  return M.parseFormats(
    `longdatetimeformat: x\ndatetimeformat: x\nlongdateformat: ${longdate}\ndateformat: x\ntimeformat: ${time}\n`)
}

test("parses ISO, European, US and long-name locales", () => {
  const cases = [
    ["2013-12-21", "2026-09-24", { year: 2026, month: 9, day: 24 }],
    ["21.12.2013", "05.03.2027", { year: 2027, month: 3, day: 5 }],
    ["12/21/2013", "03/05/2027", { year: 2027, month: 3, day: 5 }],
    ["12/21/13", "03/05/27", { year: 2027, month: 3, day: 5 }],
    ["Saturday, December 21, 2013", "Friday, March 5, 2027", { year: 2027, month: 3, day: 5 }],
    ["21 Dec 2013", "5 Mar 2027", { year: 2027, month: 3, day: 5 }]
  ]
  for (const [sample, input, expected] of cases) {
    const f = formats(sample, "21:45")
    same(M.parseDate(input, f.date), expected, sample)
  }
})

test("parses 24h and 12h times", () => {
  same(M.parseTime("07:05", formats("2013-12-21", "21:45").time), { hour: 7, minute: 5 })
  assert.equal(formats("2013-12-21", "21:45").use24h, true)
  assert.equal(formats("2013-12-21", "9:45 PM").use24h, false)
  const twelve = formats("2013-12-21", "9:45 PM").time
  same(M.parseTime("12:30 AM", twelve), { hour: 0, minute: 30 })
  same(M.parseTime("12:30 PM", twelve), { hour: 12, minute: 30 })
  same(M.parseTime("6:00 PM", twelve), { hour: 18, minute: 0 })
})

test("builds the khal list command", () => {
  const args = M.khalListArgs(7)
  same(args.slice(-4), ["--day-format", "", "today", "7d"])
})

const ISO = formats("2013-12-21", "21:45")
const row = (o) => ({ uid: "u", title: "T", calendar: "c", "calendar-color": "", location: "",
  "all-day": "False", "start-date-long": "2026-09-24", "start-time": "18:00",
  "end-date-long": "2026-09-24", "end-time": "19:00", ...o })

test("parses khal JSON, dedupes multi-day repeats, sorts all-day first", () => {
  const day1 = JSON.stringify([
    row({ uid: "b", title: "Soccer" }),
    row({ uid: "a", title: "Trip", "all-day": "True", "start-time": "", "end-time": "", "end-date-long": "2026-09-25" })
  ])
  const day2 = JSON.stringify([
    row({ uid: "a", title: "Trip", "all-day": "True", "start-time": "", "end-time": "", "end-date-long": "2026-09-25" })
  ])
  const events = M.parseEvents(`${day1}\n${day2}\nwarning: noise\n`, ISO)
  assert.equal(events.length, 2)
  assert.equal(events[0].title, "Trip")
  assert.equal(events[0].end - events[0].start, 2 * 86400000)
  assert.equal(events[1].title, "Soccer")
  assert.equal(new Date(events[1].start).getHours(), 18)
})

test("notifies once, inside the lead window, never for all-day", () => {
  const events = M.parseEvents(JSON.stringify([
    row({ uid: "soon", "start-time": "18:00" }),
    row({ uid: "later", "start-time": "19:00" }),
    row({ uid: "day", "all-day": "True", "start-time": "", "end-time": "" })
  ]), ISO)
  const now = new Date(2026, 8, 24, 17, 52).getTime()
  const due = M.dueNotifications(events, now, 10, {})
  same(due.map(e => e.uid), ["soon"])
  const notified = { [due[0].key]: due[0].start }
  assert.equal(M.dueNotifications(events, now, 10, notified).length, 0)
  same(Object.keys(M.pruneNotified(notified, now + 3 * 86400000)), [])
})

test("formats the time until an event", () => {
  const at = (h, m) => new Date(2026, 8, 24, h, m).getTime()
  assert.equal(M.formatUntil(at(18, 0), at(16, 50)), "in 1h 10m")
  assert.equal(M.formatUntil(at(18, 0), at(18, 0)), "now")
})

test("agenda groups by day and hides finished events", () => {
  const events = M.parseEvents(JSON.stringify([
    row({ uid: "past", "start-time": "09:00", "end-time": "10:00" }),
    row({ uid: "evening" }),
    row({ uid: "tomorrow", "start-date-long": "2026-09-25", "end-date-long": "2026-09-25" })
  ]), ISO)
  const rows = M.agendaRows(events, new Date(2026, 8, 24, 12, 0).getTime())
  same(rows.map(r => r.kind === "day" ? r.label : r.event.uid), [
    "Today · Thursday, Sep 24", "evening", "Tomorrow · Friday, Sep 25", "tomorrow"
  ])
})

test("converts khal colors and resolves the time format", () => {
  assert.equal(M.qmlColor("#9FE1E7FF"), "#FF9FE1E7")
  assert.equal(M.qmlColor("#039be5"), "#039be5")
  assert.equal(M.qmlColor("blue"), "")
  assert.equal(M.resolveUse24h("12-hour", true), false)
  assert.equal(M.resolveUse24h("24-hour", false), true)
  assert.equal(M.resolveUse24h("Match khal", false), false)
})

const ICS = [
  "BEGIN:VCALENDAR",
  "BEGIN:VEVENT",
  "UID:abc123@google.com",
  "RECURRENCE-ID:20260930T140000Z",
  "X-GOOGLE-CONFERENCE:https://meet.google.com/zzz-zzzz-zzz",
  "END:VEVENT",
  "BEGIN:VEVENT",
  "UID:abc123@goo",
  " gle.com",
  "SUMMARY:Standup",
  "X-GOOGLE-CONFERENCE:https://meet.google.com/abc-defg-hij",
  "ORGANIZER;CN=Ana:mailto:ana@example.com",
  "ATTENDEE;CN=Ana;PARTSTAT=ACCEPTED:mailto:ana@example.com",
  "ATTENDEE;CN=\"Bo; Jr\";PARTSTAT=TENTATIVE:mailto:bo@example.com",
  "ATTENDEE;CUTYPE=ROOM;CN=Room 1:mailto:room@example.com",
  "ATTENDEE:mailto:cy@example.com",
  "DESCRIPTION:Agenda\\nNotes at https://docs.example.com/x\\, thanks",
  "BEGIN:VALARM",
  "DESCRIPTION:Reminder",
  "END:VALARM",
  "END:VEVENT",
  "END:VCALENDAR"
].join("\r\n")

test("reads the master VEVENT from .ics: conference, organizer, attendees", () => {
  const ics = M.parseIcsDetails(ICS, "abc123@google.com")
  assert.equal(ics.conference, "https://meet.google.com/abc-defg-hij")
  same(ics.organizer, { name: "Ana", email: "ana@example.com" })
  same(ics.attendees.map(a => [a.name, a.status, a.organizer]), [
    ["Ana", "ACCEPTED", true], ["Bo; Jr", "TENTATIVE", false], ["", "NEEDS-ACTION", false]
  ])
  assert.equal(ics.description, "Agenda\nNotes at https://docs.example.com/x, thanks")
  assert.equal(M.parseIcsDetails(ICS, "other"), null)
  assert.equal(M.attendeeSummary(ics.attendees), "3 guests · 1 going, 1 maybe, 1 awaiting")
})

test("finds the meeting link and separates other links", () => {
  const ics = M.parseIcsDetails(ICS, "abc123@google.com")
  const ev = { description: "", url: "", location: "HQ, 1 Main St", organizer: null, repeating: true, status: "" }
  const d = M.eventDetails(ev, ics, "OpenStreetMap")
  same(d.meeting, { label: "Google Meet", url: "https://meet.google.com/abc-defg-hij" })
  same(d.links, [{ label: "docs.example.com", url: "https://docs.example.com/x" }])
  assert.equal(d.directions, "https://www.openstreetmap.org/search?query=HQ%2C%201%20Main%20St")
  same(d.organizer, { name: "Ana", email: "ana@example.com" })
})

test("recognizes meeting services in descriptions and locations", () => {
  const cases = [
    ["https://us02web.zoom.us/j/12345678901?pwd=x", "Zoom"],
    ["https://teams.microsoft.com/l/meetup-join/19%3ameeting", "Microsoft Teams"],
    ["https://meet.jit.si/ExampleStandup", "Jitsi"],
    ["https://acme.webex.com/meet/bob", "Webex"],
    ["https://applications.zoom.us/addon/calendar", ""],
    ["https://support.google.com/a/users/answer/9282720", ""]
  ]
  for (const [url, label] of cases) assert.equal(M.meetingService(url), label, url)

  const zoomLocation = { description: "", url: "", location: "https://zoom.us/j/123456789", organizer: null }
  const d = M.eventDetails(zoomLocation, null, "Google Maps")
  assert.equal(d.meeting.label, "Zoom")
  assert.equal(d.location, "")
  assert.equal(d.directions, "")
})

test("cleans HTML and escaped descriptions, linkifies safely", () => {
  assert.equal(M.cleanDescription("Hi<br>Join <a href=\"https://zoom.us/j/1\">here</a> &amp; bring <b>notes</b>"),
    "Hi\nJoin here (https://zoom.us/j/1) & bring notes")
  assert.equal(M.cleanDescription("Line one\\nLine two"), "Line one\nLine two")
  assert.equal(M.extractUrls("See (https://example.com/a_(b)) and https://x.io.")[0], "https://example.com/a_(b)")
  assert.equal(M.extractUrls("end https://x.io.")[0], "https://x.io")
  assert.equal(M.linkifiedHtml("<b> https://a.io/?q=1&r=2\nnext"),
    "&lt;b&gt; <a href=\"https://a.io/?q=1&amp;r=2\">https://a.io/?q=1&amp;r=2</a><br>next")
})

test("parses khal organizer strings and hides placeholders", () => {
  same(M.parseOrganizer("Family (family@group.calendar.google.com)"), { name: "Family", email: "family@group.calendar.google.com" })
  same(M.parseOrganizer("kate@example.com (kate@example.com)"), { name: "", email: "kate@example.com" })
  assert.equal(M.isPlaceholderOrganizer(M.parseOrganizer("Unknown Organizer (unknownorganizer@calendar.google.com)")), true)
  assert.equal(M.isPlaceholderOrganizer(M.parseOrganizer("Family (f@group.calendar.google.com)")), true)
  assert.equal(M.isPlaceholderOrganizer({ name: "", email: "kate@example.com" }), false)
})

test("rejects formats it cannot read back, instead of guessing", () => {
  assert.equal(formats("2013-12-21", "21:45").error, "")
  assert.match(formats("21. Dezember 2013", "21:45").error, /Unsupported khal date format/)
  assert.match(formats("2013-12-21", "9:45 p.m.").error, /Unsupported khal time format/)
  assert.equal(formats("20131221", "21:45:00").error, "")
  const compact = formats("20131221", "21:45:00")
  same(M.parseDate("20270305", compact.date), { year: 2027, month: 3, day: 5 })
  same(M.parseTime("07:05:30", compact.time), { hour: 7, minute: 5 })
  const noYear = formats("Sat 21 Dec", "21:45")
  assert.equal(noYear.error, "")
  same(M.parseDate("Sat 2 Jan", noYear.date, new Date(2026, 11, 28).getTime()), { year: 2027, month: 1, day: 2 })
})

test("notifies within the grace window, including lead time 0", () => {
  const events = M.parseEvents(JSON.stringify([row({ uid: "x", "start-time": "14:45" })]), ISO)
  const at = (h, m, s) => new Date(2026, 8, 24, h, m, s).getTime()
  assert.equal(M.dueNotifications(events, at(14, 45, 2), 0, {}).length, 1)
  assert.equal(M.dueNotifications(events, at(14, 47, 30), 10, {}).length, 0)
})

test("escapes notification titles that look like options", () => {
  assert.equal(M.notificationTitle({ title: "-r test" }).charAt(0), "\u2060")
})

test("writes dates back in khal's own longdateformat", () => {
  const day = new Date(2026, 2, 5).getTime()
  const cases = [
    ["2013-12-21", "2026-03-05"],
    ["21.12.2013", "05.03.2026"],
    ["12/21/2013", "03/05/2026"],
    ["21/12/13", "05/03/26"],
    ["Saturday, December 21, 2013", "Thursday, March 05, 2026"],
    ["Sat 21 Dec 2013", "Thu 05 Mar 2026"]
  ]
  for (const [sample, expected] of cases) {
    assert.equal(M.formatKhalDate(day, sample), expected, sample)
    const f = formats(sample, "21:45")
    assert.equal(f.error, "", sample)
    same(M.parseDate(expected, f.date), { year: 2026, month: 3, day: 5 }, sample)
  }
})

test("builds the khal range command for a month's grid", () => {
  const range = M.monthRange(2026, 8)
  assert.equal(new Date(range.start).getDate(), 26)
  assert.equal(new Date(range.start).getMonth(), 7)
  same(M.khalRangeArgs(range.start, range.days, formats("21.12.2013", "21:45")).slice(-4),
    ["--day-format", "", "26.08.2026", "48d"])
  assert.equal(M.monthKey(2026, 8), "2026-09")
})

test("marks each day an event touches, with up to three colors", () => {
  const events = M.parseEvents([
    JSON.stringify([
      row({ uid: "trip", "calendar-color": "#ff0000", "all-day": "True", "start-time": "", "end-time": "", "end-date-long": "2026-09-26" }),
      row({ uid: "late", "calendar-color": "#00ff00", "start-time": "22:00", "end-date-long": "2026-09-25", "end-time": "00:00" }),
      row({ uid: "a", "calendar-color": "#0000ff" }),
      row({ uid: "b", "calendar-color": "#ffff00" }),
      row({ uid: "c", "calendar-color": "#0000ff" })
    ])
  ].join("\n"), ISO)
  const days = M.eventsByDay(events)
  same(Object.keys(days).sort(), ["2026-09-24", "2026-09-25", "2026-09-26"])
  // Sorted by start, so the 22:00 event is the fourth color and is dropped.
  same(days["2026-09-24"], ["#ff0000", "#0000ff", "#ffff00"])
  same(days["2026-09-25"], ["#ff0000"])
})

test("lists a chosen day's events, including ones that span it", () => {
  const events = M.parseEvents(JSON.stringify([
    row({ uid: "conf", "start-date-long": "2026-09-23", "start-time": "09:00", "end-date-long": "2026-09-25", "end-time": "17:00" }),
    row({ uid: "evening" }),
    row({ uid: "midnight", "start-date-long": "2026-09-23", "start-time": "23:00", "end-date-long": "2026-09-24", "end-time": "00:00" }),
    row({ uid: "next", "start-date-long": "2026-09-25", "end-date-long": "2026-09-25" })
  ]), ISO)
  const now = new Date(2026, 8, 20, 12, 0).getTime()
  const rows = M.dayAgendaRows(events, new Date(2026, 8, 24, 15, 0).getTime(), now)
  same(rows.map(r => r.kind === "day" ? r.label : r.event.uid), ["Thursday, Sep 24", "conf", "evening"])
})

test("offers only web and meeting-app links from invites", () => {
  assert.equal(M.isOpenableUrl("https://example.com/a"), true)
  assert.equal(M.isOpenableUrl("zoommtg://zoom.us/join?confno=1"), true)
  for (const bad of ["file:///etc/passwd", "smb://host/share", "vscode://x/y", "javascript:alert(1)", "-https://x", ""])
    assert.equal(M.isOpenableUrl(bad), false, bad)
  const ev = { description: "", url: "file:///etc/passwd", location: "", organizer: null }
  const d = M.eventDetails(ev, { conference: "vscode://evil/x", url: "https://example.com/doc" }, "Google Maps")
  same(d.links.map(l => l.url), ["https://example.com/doc"])
  assert.equal(d.meeting, null)
  assert.equal(M.linkLabel("msteams://teams.microsoft.com/l/x"), "msteams://teams.microsoft.com")
  assert.equal(M.linkLabel("https://www.example.com/x"), "example.com")
})

test("escapes invite markup in notification bodies", () => {
  const body = M.notificationBody({ start: 0, location: "<b>URGENT</b> & co" }, 0, true)
  assert.match(body, /&lt;b&gt;URGENT&lt;\/b&gt; &amp; co/)
})

test("skips cancelled events when notifying", () => {
  const now = Date.now()
  const events = [
    { key: "a", allDay: false, start: now + 60000, status: "CANCELLED" },
    { key: "b", allDay: false, start: now + 60000, status: "" }
  ]
  same(M.dueNotifications(events, now, 10, {}).map(e => e.key), ["b"])
})

test("keeps distinct events that have no UID", () => {
  const r = (title, uid, calendar) => row({ title, uid, calendar })
  const out = M.parseEvents(JSON.stringify([r("One", ""), r("Two", ""), r("Same", "u1", "work"), r("Same", "u1", "home")]), ISO)
  assert.equal(out.length, 4)
  assert.equal(M.parseEvents(JSON.stringify([r("One", ""), r("One", "")]), ISO).length, 1)
})
