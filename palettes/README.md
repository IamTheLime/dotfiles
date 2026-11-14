# Palette library

Portable colour references for generating themes for other applications.
These are design inputs, **not application configuration files**.

| Palette | Style | Files |
| --- | --- | --- |
| [Ember Grove](ember-grove/README.md) | Dark; gold, copper and amber with restrained sage, mint and teal | [palette.json](ember-grove/palette.json) |

## Instructions for theme-generating agents

1. Read this file, the chosen palette's README, and its `palette.json`.
2. Use `roles` to choose colours by meaning, rather than spreading every swatch
   across the interface. Role values reference keys in `colors`; `inherit`
   means use the host application's existing background.
3. Preserve the host/terminal background by default. Use a transparent canvas
   where supported, otherwise leave its existing background setting alone.
   Use `background_policy.opaque_fallback` only when an explicit opaque
   background is necessary. Do not introduce an extra green tint or overlay.
4. Keep body text, strong emphasis, code identifiers and mode labels visibly
   distinct. Bold or italic alone is not enough for important semantic
   distinctions. Follow `typography` as a complement to colour.
5. The ANSI slot names are historical terminal labels, **not literal hue
   descriptions**. For example, Ember Grove's ANSI `green` is amber.
   Use semantic roles for UI/syntax and `ansi` only for terminal slots.
6. Keep the palette restrained. Prefer the supplied colours and existing
   derived surfaces. If an app needs more shades, interpolate subtly from
   the relevant foreground/accent and background; do not invent unrelated
   neon colours. Maintain readable contrast against the actual background.
7. Check the target application's current configuration format. Preserve
   unrelated settings, back up existing configuration, and validate the
   result. Do not modify packaged/system-owned themes.
8. Keep portable theme files in this dotfiles repository where practical.
   Do not silently change the palette to accommodate one application's API.

## Example request

> Generate a theme for **APP** using `palettes/ember-grove/`.
> Read `palettes/README.md`, the palette README, and `palette.json` first.
> Preserve my existing terminal/app background, keep semantic differences
> noticeable without a rainbow of colours, and add the portable configuration
> to my dotfiles. Back up and validate any live configuration you change.

## Adding another palette

Create `palettes/<slug>/README.md` and `palette.json`, following Ember Grove's
format. Give it a stable `id`, hex colour swatches, semantic role mappings,
background policy, and provenance. Add it to the table above.

Existing app themes are self-contained; this library does not automatically
reload or regenerate them.
