# FigJam plugin API — things that cost a round trip

Each of these fails in a way that is not obvious from the error.

## Inspection

- `get_figjam` is the inspection tool. `get_metadata` is design-file only and
  fails immediately on a board.
- `console.log` output is **not** returned. Only the `return` value comes back,
  so return the ids you will need next.
- `get_figjam` on a whole page can exceed the response limit and fail to parse.
  Query a node, or use `use_figma` returning a filtered summary of
  `figma.currentPage.children`.
- `get_screenshot` needs a real `nodeId`. Section ids are the useful ones.

## Pages

- **`figma.createPage()` does not exist in FigJam.** Boards have pages, but you
  cannot create them from a plugin — organise with sections instead.
- A board *can* have several pages. `figma.root.children` lists them; switch with
  `await figma.setCurrentPageAsync(page)`. Setting `figma.currentPage` directly
  is unsupported.

## Text

- Load every font style you use before mutating text, `await`ed:
  `await figma.loadFontAsync({ family: 'Inter', style: 'Bold' })`.
  Styles are `'Bold'`, `'Semi Bold'`, `'Medium'` — **`'Semi Bold'` has a space**.
- `TEXT` has `textAlignHorizontal` but **no `textAlignVertical`** — setting it
  throws. Position vertically by computing `y`.
- For a fixed-width block: `textAutoResize = 'HEIGHT'` then `resize(w, 10)`; the
  height corrects itself. For a chunk that should hug its content, leave
  `'WIDTH_AND_HEIGHT'` and do not resize.
- `lineHeight = { value: 158, unit: 'PERCENT' }` is a good default for body text;
  FigJam's own default is too tight to read at distance.

## Shapes

- `figma.createShapeWithText()` always carries a `text` sublayer. To use it as a
  plain container, set `text.characters = ''` — it cannot be removed.
- `shapeType`: `'SQUARE'`, `'ROUNDED_RECTANGLE'`, `'DIAMOND'`, `'ELLIPSE'`,
  `'TRIANGLE_UP'`, and others.
- Dashed border is `dashPattern = [10, 6]` on the shape.
- Set fill, stroke and text colour together — styling one leaves the others at
  FigJam defaults, which is how a box ends up unexpectedly cyan.

## Sections and coordinates

- A section child's `x`/`y` are **section-local**. Create the section, append the
  node, *then* set position — setting it before appending moves it when it
  reparents.
- `resize(w, h)` is preferred over `resizeWithoutConstraints` on sections; they
  behave identically there.
- To send a node behind its siblings: `section.insertChild(0, node)`.
- Resize a section to fit after filling it: walk children for
  `max(x + width)` / `max(y + height)`, add ≥32px padding.

## Groups

- `figma.group(nodes, parent)` binds a shape to its text nodes. Connectors
  attached to a shape keep working once it is inside a group.
- To rebuild a grouped box: reparent the shape to the section first, remove the
  old text children, build new ones, then group again. A group whose children are
  all removed disappears on its own.
- Groups expose `x`/`y`; setting them moves every child.

## Connectors

- `connectorStart` / `connectorEnd` take `{ endpointNodeId, magnet }` where
  magnet is `'TOP' | 'BOTTOM' | 'LEFT' | 'RIGHT' | 'AUTO'`. Naming the magnet
  beats `'AUTO'` for anything you want to stay put.
- `connectorLineType = 'ELBOWED'` for structure, `'STRAIGHT'` for short hops.
- `connectorEndStrokeCap`: `'ARROW_LINES'`, `'ARROW_EQUILATERAL'`,
  `'TRIANGLE_FILLED'`, `'DIAMOND_FILLED'`, `'CIRCLE_FILLED'`, `'NONE'` — the way
  to distinguish branches without relying on colour.
- Connector labels need their font loaded like any other text, and sit at the
  line's midpoint with no offset control.
- Label text defaults to charcoal with no background pill — invisible on a dark
  board. Set `c.text.fills` (white) at creation, together with the font.
- Connectors can attach to **sections**, which is how to show flow between whole
  concepts.

## Tables

- `figma.createTable(rows, cols)`; cells via `cellAt(r, c)`; load
  `cellAt(0,0).text.fontName` before writing.
- `width`/`height` are read-only — use `resizeColumn(i, w)` and `resizeRow(i, h)`.
- Tables have no strokes. Style the header row's fill and text together.
- FigJam only — `createTable` does not exist in design files.

## Images

- `upload_assets` is the only supported way to place an image on a board.
  `figma.createImage()` / `createImageAsync()` are not available.

## Restyling existing text

- Rewriting `characters` on a node that contains **mixed fonts** requires every
  font present in the node to be loaded, not just the one you are setting —
  discover them with `getStyledTextSegments(['fontName'])` or preload every
  family the board uses.
- Keyword colouring is range styling: set the node-level font/size/fill first,
  then `setRangeFontName` / `setRangeFontSize` / `setRangeFills` per keyword.
  Ranges are start-inclusive, end-exclusive.
- Swapping `fontName` on existing nodes can leave stale fixed widths behind —
  text starts wrapping mid-word. After a font pass, re-hug the nodes that
  should size to content: `textAutoResize = 'WIDTH_AND_HEIGHT'` (skip the
  fixed-width bodies, which stay `'HEIGHT'`).
- Diamond labels have no vertical centring — after any font or size change,
  recompute `x`/`y` from the shape's centre minus half the text's size.

## After any restyle: refit, then renormalise

- Boxes do not grow with their text. After font or copy changes, refit each
  group's shape to its text extents (grow-only: `max(text.x+width)+pad`).
- Refits and moves silently drift wrapper sections — a wrapper can end up
  thousands of pixels too large with the content huddled in one corner. Fix by
  shifting all children so the min corner sits at the padding, then
  shrink-wrapping the section. Check the wrapper's reported size at the end of
  every editing session, not just after the first layout.
- Group ids go stale once you regroup or reparent — re-list `section.children`
  and match by name instead of trusting ids stored from earlier calls.
