// Run with: node --test tests/
// ClockModel.js is Omarchy's clock model; these check the pieces the panel
// depends on still behave after copying it in.
const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const source = fs.readFileSync(path.join(__dirname, "..", "ClockModel.js"), "utf8")
  .replace(/^\.pragma library\s*$/m, "")
const C = {}
vm.createContext(C)
vm.runInContext(source, C)

test("month grid is six weeks with matching day keys", () => {
  const weeks = C.monthGrid(2026, 8, 1, "2026-09-24")
  assert.equal(weeks.length, 6)
  assert.equal(weeks[0].days[0].key, "2026-08-31")
  assert.equal(weeks[0].week, 36)
  const today = weeks.flatMap(w => w.days).filter(d => d.today)
  assert.equal(today.length, 1)
  assert.equal(today[0].key, "2026-09-24")
})

test("ISO weeks and week start", () => {
  assert.equal(C.isoWeek(2026, 0, 1), 1)
  assert.equal(C.isoWeek(2027, 0, 1), 53)
  assert.equal(C.normalizedWeekStart("sunday", 1), 0)
  assert.equal(C.toggledWeekStart(1), 0)
})
