---
name: figjam-diagrams
description: Building diagrams in FigJam that survive a projector and stay editable — theming (dark by default), text as its own nodes rather than shape labels, real columns instead of space-padding, spacing that does not collide, sections and groups so blocks move as units. Read when asked to draw, diagram, or map anything on a Figma board — flow charts, architecture, state machines, sequence or decision diagrams, comparison tables.
---

# FigJam diagrams

A diagram is read twice: once on a projector by people who did not write it, and
again months later by whoever has to change it. Most of the rules below exist to
serve the second reading, because the first is easy to fake.

Verify with `get_screenshot` before declaring anything finished. FigJam renders
text differently from how the code implies, and overlaps are invisible until you
look. Read `references/api-notes.md` before the first `use_figma` call — it lists
the mistakes that cost a round trip each.

## Theme

**Default to the dark theme.** Switch only when asked for light. Palettes,
including the semantic accent roles, are in `references/themes.md`.

Pick accents semantically and keep them consistent across every section of a
board: one colour per concept, reused wherever that concept appears. A reader
who learns "orange means the warehouse asserts a destination" in the first
section should not have to relearn it in the fourth.

Text colour follows the surface it sits on, and the test is contrast, not
palette membership. Anything floating on the section background — connector
labels, captions — and the prose inside commentary panels is plain white on
the dark theme. `fg` is for structured rows inside panels; `muted` only ever
de-emphasises a row inside a panel, never anything free-floating. A colour that
matches the palette but cannot be read from the back of the room is wrong.

## Text belongs in text nodes, not in shapes

Never leave content in a shape's built-in `text`. It cannot be styled per run,
it centres by default, its wrapping is not yours to control, and you cannot
align anything to anything.

Build every box as **shape + title node + body node**, then `figma.group(...)`
them so dragging the box takes the text with it. Group name matches the shape
name, which keeps the layer list navigable.

This is what buys you a title in the box's accent colour, body in the foreground
colour, and the ability to bold or recolour one line without touching the rest.

## Columns are columns

Never simulate a table with spaces inside one text node. Inter is proportional;
`ADVANCE          → StepAction` will not line up with the row beneath it, and it
looks broken on a projector.

One text node per cell, positioned on a shared x. Then colour the value column
by category, so the shape of the data is visible before anything is read — if
four rows are blue and two are orange, that grouping *is* the point being made.

Break prose into atomic chunks whenever the formatting benefits: a numbered step
is a number node, a keyword node and a description node, not one string with
manual indentation.

## Density

Numbers that work, as a starting point rather than a law:

- Box padding 20–24px. Title 15–17px Bold, body 11.5px Medium, line-height 158%.
- List row pitch 26–30px. Label column ~58px from the box edge, value beside it.
- 30px between boxes in a row; **120–160px between bands.** Under-spacing bands
  is the most common way a board becomes unreadable.
- 60px of section padding around content.
- Anything a reader must scan (a state, a pill) wants a fixed size — pick one and
  reuse it, e.g. 230×86 for a status, 380–470 wide for a panel.

Long connector labels collide with boxes, because FigJam pins a label to the
line's midpoint. Keep labels to a few words and put the detail in a box. If a
label must be long, widen the gap between the endpoints instead.

## Structure: sections, then bands

**Nothing lives loose on the canvas.** Every node belongs to a section, and the
sections themselves belong to one outer board section carrying the title. A node
on the page root is unfindable in the navigator, gets left behind when someone
drags a region, and survives cleanup by accident. This includes the connectors
that run *between* sections — put them in the outer board section with the
sections they join. Superseded or reference material gets a section of its own
(`0 · Superseded`) rather than being left floating or silently deleted.

Check before finishing: `page.children` should contain exactly one section.

**One section per concept**, named with a leading number (`1 · Vocabulary`,
`2 · Dispatcher`) so the navigator reads in presentation order. Sections are the
unit people share and reference, so a section should stand alone.

**Sections must actually contain their content.** A section's children use
section-local coordinates, so a child at a negative `x`/`y` hangs outside the
frame — which is easy to cause and invisible until you screenshot. After filling
a section, normalise it: shift every child so the top-left of the content sits at
the padding, then resize to `max(x + width) + padding`. Do it again after any
move. Uniform padding on all four sides, and no large dead area at the bottom —
that gap is what makes a board look unfinished when it is projected.

Lay sections out on a grid with real gutters (~240px). Touching or overlapping
sections read as one confusing region.

Inside a section, **group each horizontal band** — the row of boxes plus its
heading plus its notes. Bands are what someone drags when they rearrange, and a
band that leaves its heading behind is worse than no grouping at all.

Nest sections when a set of diagrams share a thesis: a wrapper section with a
title and one child section per variant beats four sibling sections, because the
shared idea gets stated once.

## Shape vocabulary

Keep it small and consistent:

- **Rounded rectangle** — a state or a thing that exists.
- **Square** — a component, a panel, a note.
- **Diamond** — a decision. Use one wherever the diagram branches on a question;
  it is the single clearest way to show that two paths are alternatives.
- **Dashed border** — an interface, a contract, a commentary panel. Anything that
  describes the diagram rather than participating in it.

Give the branches out of a decision **different arrowheads**, not just different
colours — the distinction survives greyscale printing and colour blindness.
Dashed lines for asynchronous or event-driven flow, solid for direct calls.

## Arrows: the fewest, the shortest, the most honest

**Prefer containment and adjacency to an arrow.** If B is part of A, draw B
inside A. If B is what A talks to, put B next to A. Every arrow you avoid is a
crossing that cannot happen, and nesting states "part of" more clearly than a
line ever does. Reach for a connector only when the relationship is a *flow*
between things that genuinely sit apart.

**Align to a column grid.** Boxes sharing an `x` or a `y` let elbow connectors
run dead straight; boxes offset by 20px force a dog-leg through whatever is
between them. Pick a few column positions and a row pitch, and reuse them.

**Point at the right thing.** If a branch applies to a whole set, point it at the
container, not at whichever member happens to be nearest — a reader takes an
arrow literally, and one aimed at a single box says that box is special. Equally,
if two branches leave a decision, both must be drawn: a decision with one visible
arm reads as a fact, not a choice.

**Deleting a node silently deletes its connectors.** Nothing warns you, and the
loss shows up as a diagram that quietly means something else. After removing or
replacing anything, re-list the connectors and confirm every decision still has
all its branches and every box still has the edges it had.

## Comparisons are tables

When the content is genuinely rows and columns — before/after, option matrices —
use `figma.createTable()`, not a grid of shapes. Style the header row and let the
body inherit. A shape grid pretending to be a table cannot be edited like one.

## Annotations are content, not decoration

A note explaining *why* — an exclusion, a caveat, a warning — is its own
callout panel, never a line folded into a data panel. The author scans for the
note, not for a row; a note demoted to a row reads as deleted.

When reproducing an existing diagram (an SVG, a photo, a whiteboard), inventory
its annotations first and check every one off before finishing. A missing note
is the first thing the original author notices — before layout, before colour.

## Before finishing

Screenshot the section and look for: labels sitting on boxes, bands whose
spacing collapsed, text overflowing its shape, and connectors routing through
unrelated content.

Then check the structure, which a screenshot will not show you: nothing loose on
the page root, every section's content inside its frame with even padding, no
section left oversized around a small amount of content.

Fix what you find; then say plainly what you left for the human to adjust, rather
than implying the layout is final.
