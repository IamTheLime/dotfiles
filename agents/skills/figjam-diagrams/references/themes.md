# Themes

Two palettes. **Dark is the default** — use light only when asked.

Colours go in as `hex/255`. Rounded decimals make FigJam treat a colour as
custom, which breaks the palette swatch in its UI:

```js
const h = (r, g, b) => ({ r: r / 255, g: g / 255, b: b / 255 })
```

## Dark (default)

Tokyo Night. Reads well projected in a lit room, which the FigJam default
palette does not.

| Role | Hex | Use |
| --- | --- | --- |
| `bg` | `#1A1B26` | section background |
| `bgDeep` | `#16161E` | nested container, dashed panel, decision fill |
| `panel` | `#292E42` | box fill |
| `fg` | `#C0CAF5` | body text |
| `muted` | `#565F89` | captions, column headers, de-emphasised rows |
| `blue` | `#7AA2F7` | |
| `cyan` | `#7DCFFF` | |
| `green` | `#9ECE6A` | |
| `magenta` | `#BB9AF7` | |
| `orange` | `#FF9E64` | |
| `red` | `#F7768E` | |
| `yellow` | `#E0AF68` | |
| `teal` | `#73DACA` | |

```js
const TN = {
  bg: h(0x1a,0x1b,0x26), bgDeep: h(0x16,0x16,0x1e), panel: h(0x29,0x2e,0x42),
  fg: h(0xc0,0xca,0xf5), muted: h(0x56,0x5f,0x89),
  blue: h(0x7a,0xa2,0xf7), cyan: h(0x7d,0xcf,0xff), green: h(0x9e,0xce,0x6a),
  magenta: h(0xbb,0x9a,0xf7), orange: h(0xff,0x9e,0x64), red: h(0xf7,0x76,0x8e),
  yellow: h(0xe0,0xaf,0x68), teal: h(0x73,0xda,0xca),
}
```

## Light

Use FigJam's own palette so boards stay recolourable from its UI. White box
fills with coloured strokes and `#1E1E1E` text — do **not** put body text on a
saturated fill, it stops being readable at projector contrast.

| Role | Hex |
| --- | --- |
| `bg` (section) | `#F9F9F9` |
| `panel` (box fill) | `#FFFFFF` |
| `fg` | `#1E1E1E` |
| `muted` | `#757575` |
| strokes | blue `#3DADFF` · cyan `#5AD8CC` · green `#66D575` · violet `#874FFF` · orange `#FF9E42` · red `#FF7556` · yellow `#FFC943` · grey `#B3B3B3` |

## Applying either

Fill, stroke and text are one decision — set all three together or a box ends up
with dark text on a dark fill:

```js
box.fills  = [{ type: 'SOLID', color: T.panel }]
box.strokes= [{ type: 'SOLID', color: T.blue }]
box.strokeWeight = 3
title.fills= [{ type: 'SOLID', color: T.blue }]   // title takes the box's accent
body.fills = [{ type: 'SOLID', color: T.fg }]
```

Titles in the box's own accent; structured rows in `fg`; `muted` only to
de-emphasise a row inside a panel. Connector labels, floating captions, and
the prose in commentary panels are plain white — `fg` reads dim against `bg`
and `muted` disappears. Dashed commentary panels take `bgDeep` so they sit
visually behind the content they describe.

## Accent roles

Assign meaning once per board and hold it. A workable default:

- **magenta / violet** — the thing the diagram is about
- **blue** and **orange** — the two sides of a contrast being drawn
- **yellow** — decisions and guards
- **green** — success, resolution, the happy path
- **red** — refusal, failure, the thing being deleted
- **cyan / teal** — interfaces and contracts
- **muted** — deprecated, system-internal, out of scope
