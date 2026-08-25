# Palette

One reduced palette, parameterised by a single accent. **The default below is
the palette** — use it unless the user asks for something else.

Colours go in as `hex/255`. Rounded decimals make FigJam treat a colour as
custom, which breaks the palette swatch in its UI:

```js
const h = s => ({ r: parseInt(s.slice(1,3),16)/255, g: parseInt(s.slice(3,5),16)/255, b: parseInt(s.slice(5,7),16)/255 })
```

## Default palette

A deep plum ground with a single warm accent. Reads well projected in a lit
room; the reduction is what makes the standout elements land.

| Role | Hex | Use |
| --- | --- | --- |
| `ground` | `#130d18` | outer board section, dashed-panel fill |
| `section` | `#1a1221` | section background |
| `panel` | `#2c1f38` | box fill AND box stroke (borderless boxes) |
| `MAIN` | `#ffc943` | all emphasis: titles, connectors, keywords, hooks |
| `mainDim` | `#dfb41d` | dashed callout-panel borders, quieter accents |
| `mainBright` | `#efd54d` | the one standout border per section |
| `body` | `#ffffff` | body prose, separators between keywords |
| `note` | `#c2e5ff` | footnotes and side-notes (cursive voice) |
| `warning` | `#ff6655` | footnote `*` markers, before/failure states |

```js
const P = {
  ground: h('#130d18'), section: h('#1a1221'), panel: h('#2c1f38'),
  main: h('#ffc943'), mainDim: h('#dfb41d'), mainBright: h('#efd54d'),
  body: { r:1, g:1, b:1 }, note: h('#c2e5ff'), warning: h('#ff6655'),
}
```

## Deriving a palette from different anchors

The palette is a function of **3–4 anchor colours**. When the user wants a
different look, ask for (or confirm proposals for):

1. `MAIN` — the accent. They may give a hex or a word ("blue"); a word alone is
   enough to propose a concrete hex back for confirmation.
2. `ground` — the darkest surface. Defaults to a near-black tinted *towards*
   `MAIN`'s complement or towards `MAIN` itself — never pure `#000`.
3. `note` — the side-note colour. Defaults to a pale, desaturated colour far
   from `MAIN` in hue (a pale blue against a warm `MAIN`, a pale peach against
   a cool one).
4. `warning` — the footnote-marker / failure colour. Defaults to a clear red
   unless `MAIN` is itself red-ish, in which case pick a red-orange and check
   it still separates from `MAIN`.

Then derive the rest, checking contrast at every step:

- `section` = `ground` lightened just enough to read as a different surface
  (ΔL ≈ 3–5%). `panel` = another step lighter (ΔL ≈ 8–10% over `section`).
  All three stay in the same hue family.
- `mainDim` = `MAIN` darkened ~15% (for dashed borders that must not compete).
- `mainBright` = `MAIN` lightened ~10% (for the standout border — it must
  visibly outrank `MAIN` connectors next to it).
- `body` stays white on dark grounds. On a light ground (user explicitly asks),
  invert: near-black body, and re-check every `MAIN` usage — a `MAIN` light
  enough to glow on dark may need darkening to hold contrast on white.

**The contrast test is the law, not the formula.** Every text/fill pairing must
be readable from the back of a room: body-on-panel, `MAIN`-on-section,
note-on-ground, dark-text-on-`mainBright` if a filled standout is used. If a
derived tone fails, move the tone, not the role.

## Applying

Fill, stroke and text are one decision — set all three together or a box ends
up with dark text on a dark fill:

```js
// ordinary box: borderless
box.fills   = [{ type: 'SOLID', color: P.panel }]
box.strokes = [{ type: 'SOLID', color: P.panel }]
title.fills = [{ type: 'SOLID', color: P.main }]   // serif Bold
body.fills  = [{ type: 'SOLID', color: P.body }]

// the section's one standout
standout.strokes = [{ type: 'SOLID', color: P.mainBright }]; standout.strokeWeight = 3.5

// dashed callout panel
panel.fills = [{ type: 'SOLID', color: P.ground }]
panel.strokes = [{ type: 'SOLID', color: P.mainDim }]; panel.dashPattern = [10, 6]
```

Inline keyword ranges (mono `MAIN` names, white separators):

```js
// "invoice · invoice_line" — names pop, dots separate
t.setRangeFontName(0, 7, { family: 'Roboto Mono', style: 'Regular' })
t.setRangeFills(0, 7, [{ type: 'SOLID', color: P.main }])
// the " · " between them keeps body font and colour
```

## Font roles (summary — the full rules live in SKILL.md)

- Cursive display (`Figma Hand`) — scarce, attention only. Always `MAIN`
  (hooks, headings) or `note` (footnote text); never body colour.
- Bookish serif (`Merriweather`) — Bold `MAIN` for ordinary titles, Regular
  `body` for prose.
- Mono (`Roboto Mono`) — `MAIN` for keywords embedded in prose, `body` for
  standalone code lines and key-columns.
