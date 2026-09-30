---
name: figjam-diagrams
description: Building diagrams in FigJam that survive a projector and stay editable — a reduced single-accent palette, readable Simple typography, product-readable prose with jargon pushed to footnotes, text as its own nodes rather than shape labels, real columns instead of space-padding, sections and groups so blocks move as units. Read when asked to draw, diagram, or map anything on a Figma board — flow charts, architecture, state machines, sequence or decision diagrams, comparison tables.
---

# FigJam diagrams

A diagram is read twice: once on a projector by people who did not write it, and
again months later by whoever has to change it. Most of the rules below exist to
serve the second reading, because the first is easy to fake.

Verify with `get_screenshot` before declaring anything finished. FigJam renders
text differently from how the code implies, and overlaps are invisible until you
look. Read `references/api-notes.md` before the first `use_figma` call — it lists
the mistakes that cost a round trip each.

## Palette

**One MAIN colour carries all emphasis; everything else stays quiet.** The
default palette, its role table, and the rules for deriving a palette from a
different MAIN colour are in `references/themes.md`. Two things belong up here:

- Important elements stand out *because* the palette is reduced. Do not add a
  second accent family to distinguish concepts — distinguish with placement,
  weight, and the standout border instead.
- If the user asks for different colours, don't improvise a full palette from
  one word. Ask for the 3–4 anchors (`MAIN`, ground, note, warning — or accept
  a single hex/name for `MAIN` and propose derived anchors for confirmation),
  then derive every tone from those per `themes.md`.

## Simple typography; no handwritten fonts

Use FigJam **Simple** (`Inter`) for all prose, headings, annotations,
connector labels and footnotes. Never use Scribbled (`Figma Hand`) or other
handwritten fonts: they are difficult to read.

Use Bold for headings and the one standout title per section, Medium for
labels, and Regular for body text. Keep emphasis selective through size,
weight and the single MAIN accent rather than a different font family.

Technical identifiers may use `Roboto Mono`; use MAIN for code embedded in
prose and white for standalone code. Keep separators in the body font.

## Write for product readers

The prose in a box must make sense to someone who does not work on the system.

- **No jargon suffixes.** "Read-only: server is `updatable 'false'` — the DB
  enforces it" is a config value wearing a sentence. Write "The foreign table
  cannot be written to — the database itself is read-only", and let a `MAIN`
  keyword or a footnote carry the technical detail.
- **Footnotes carry the technicalia.** When the implementation detail matters
  but would clog the box, mark the statement with a red `*` and put the detail
  below the box: `*` in red, the note in the note colour, Simple voice, any
  embedded code in `MAIN` mono. One `*` on the statement, one on the note —
  they find each other.
- **Bullets over inline density.** A list of three or more things gets one
  `•`-prefixed line each, never `a / b / c` crammed into a sentence.
- **Breathing room.** A blank line between statements inside a body; ~20px
  between a box title and its body; bodies never touch the box border.

## Annotations: concepts live outside the boxes

Free-floating text explaining the *idea* of a section — the trick, the payoff,
the problem breakdown — is a first-class element, not clutter. One or two per
section, Simple voice, placed in clear space near what they explain.

**Two-tone rule:** a short hook in `MAIN` ("the trick:", "the payoff:"), the
explanation in white. A fully-`MAIN` sentence fights the headings; a fully-white
one disappears into the bodies.

## One standout per section

Each section names one element as its point — the mechanism the section exists
to explain. That element gets the bright-`MAIN` border and (if titled) the
Simple voice. Everything else is a borderless panel. Two standouts per section
is zero standouts.

## Text belongs in text nodes, not in shapes

Never leave content in a shape's built-in `text`. It cannot be styled per run,
it centres by default, its wrapping is not yours to control, and you cannot
align anything to anything.

Build every box as **shape + title node + body node**, then `figma.group(...)`
them so dragging the box takes the text with it. Group name matches the shape
name, which keeps the layer list navigable.

This is what buys you a title in the Simple `MAIN` voice, a body in white, and
the ability to recolour one keyword without touching the rest.

## Columns are columns

Never simulate a table with spaces inside one text node. Proportional fonts
will not line up, and it looks broken on a projector.

One text node per cell, positioned on a shared x. Key-columns that name code
things (script names, config keys) are mono white; key-columns that name
concepts are Simple `MAIN`; the value column is Simple white with `MAIN` mono
keywords where code appears.

## Density

Numbers that work, as a starting point rather than a law:

- Box padding 20–24px. Simple titles 15–17px Bold; Simple Bold titles 20–24px;
  body 11px at line-height 158%; mono ranges 10.5px.
- ~20px between a title and its body. List row pitch 26–30px; panel rows with
  multi-line values 46–56px.
- 30px between boxes in a row; **120–160px between bands.** Under-spacing bands
  is the most common way a board becomes unreadable.
- 60px of section padding around content.
- Fixed sizes for anything scanned repeatedly — pick one flow-box size and
  reuse it. Boxes must fit their text: after any font or copy change, refit
  every box (text extents + padding) before calling the section done.

Long connector labels collide with boxes, because FigJam pins a label to the
line's midpoint. Keep labels to a few words and put the detail in a box.

## Structure: sections, then bands

**Nothing lives loose on the canvas.** Every node belongs to a section, and the
sections themselves belong to one outer board section carrying the title. A node
on the page root is unfindable in the navigator, gets left behind when someone
drags a region, and survives cleanup by accident. This includes the connectors
that run *between* sections. Superseded or reference material gets a section of
its own (`0 · Superseded`) rather than being left floating or silently deleted.

Check before finishing: `page.children` should contain exactly one section.

**One section per concept**, named with a leading number (`1 · Vocabulary`,
`2 · Dispatcher`) so the navigator reads in presentation order. Sections are the
unit people share and reference, so a section should stand alone.

**Sections must actually contain their content.** A section's children use
section-local coordinates, so a child at a negative `x`/`y` hangs outside the
frame. After filling a section, normalise it: shift content to the padding,
resize to fit, uniform padding on all four sides, no dead area at the bottom.
Do it again after any move or refit — box growth silently drifts wrappers.

Lay sections out on a grid with real gutters (~240px). Touching or overlapping
sections read as one confusing region.

Inside a section, **group each horizontal band** — the row of boxes plus its
heading plus its notes. Bands are what someone drags when they rearrange.

Nest sections when a set of diagrams share a thesis: a wrapper section with a
title and one child section per variant beats four sibling sections.

## Shape vocabulary

Keep it small and consistent. **Straight edges only — `SQUARE`, never
`ROUNDED_RECTANGLE`.** Rounded corners read as informal; square edges read as
engineered.

- **Square** — a thing that exists: a state, a component, a panel, a store.
- **Diamond** — a decision. Use one wherever the diagram branches on a
  question. Label in the Simple voice, centred.
- **Dashed border** — commentary, a contract, a superseded/before state.
  Callout panels are dashed in dim-`MAIN`; before/failure states are dashed in
  the warning colour.
- Ordinary boxes are **borderless** (stroke = fill). A visible border is
  information: bright `MAIN` = the standout; dashed = commentary or a prior
  state.

Give the branches out of a decision **different arrowheads**, not just
different colours — the distinction survives greyscale printing and colour
blindness. Dashed lines for asynchronous flow or before-states, solid for
direct calls and the current world.

## Arrows: the fewest, the shortest, the most honest

**Prefer containment and adjacency to an arrow.** If B is part of A, draw B
inside A. If B is what A talks to, put B next to A. Every arrow you avoid is a
crossing that cannot happen. Reach for a connector only when the relationship
is a *flow* between things that genuinely sit apart.

Connectors are `MAIN` for live flow, warning-colour dashed for the before
state. Labels are Simple white.

**Align to a column grid.** Boxes sharing an `x` or a `y` let elbow connectors
run dead straight. Pick a few column positions and a row pitch, and reuse them.

**Point at the right thing.** If a branch applies to a whole set, point it at
the container, not at whichever member happens to be nearest. If two branches
leave a decision, both must be drawn.

**Deleting a node silently deletes its connectors.** After removing or
replacing anything, re-list the connectors and confirm every decision still has
all its branches.

## Comparisons are tables

When the content is genuinely rows and columns — before/after, option matrices —
use `figma.createTable()`, not a grid of shapes. Style the header row (Simple
`MAIN` headers work well) and let the body inherit; cell content that is code
is mono. A shape grid pretending to be a table cannot be edited like one.

## Before finishing

Screenshot the section and look for: labels sitting on boxes, bands whose
spacing collapsed, text overflowing its shape, boxes their text has outgrown,
and connectors routing through unrelated content.

Then check the structure, which a screenshot will not show you: nothing loose
on the page root, every section's content inside its frame with even padding,
no section left oversized around a small amount of content, no wrapper drift
from refits.

Then check the voice: Simple used consistently, exactly one standout per section,
no jargon-suffixed sentences, every `*` paired with its footnote.

Fix what you find; then say plainly what you left for the human to adjust,
rather than implying the layout is final.

## Worked example (imaginary system)

A section explaining a cache-fallback read in an imaginary `orders-service`:

- Standout box (bright-`MAIN` border, Simple title): `2 · cache fallback`.
- Ordinary boxes (borderless, Simple `MAIN` titles): `Read request`,
  `1 · Try the cache`, `Serve the row`.
- Diamond: `hit?` — solid `MAIN` "yes" arrow with one arrowhead style, dashed
  warning "no" arrow with another.
- Body line with embedded code: "Look the order up in `order_summary` first" —
  `order_summary` in `MAIN` mono.
- Annotation: "**the idea:** serve stale before serving slow — the miss rate
  tells us when to resize" (hook in `MAIN`, rest white).
- Footnote: "`*` Note: a miss costs a full scan of `order_events`" — red `*`,
  note-colour Simple, `order_events` in `MAIN` mono.
