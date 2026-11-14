# Ember Grove

A dark, warm palette: gold prose and amber/copper syntax, with sage variables,
mint key phrases and teal navigation. Cool accents provide semantic separation,
not a second rainbow of colours.

Use [palette.json](palette.json) for exact swatches and role mappings, and read
the [shared agent instructions](../README.md) before generating a theme.

## Background comes from the host

**Inherit the existing terminal/app background by default.** A transparent
editor or TUI should show the terminal beneath it, not paint a new tinted
layer. `#0a1109` is the original terminal background and an opaque fallback,
not a requirement to override every application's canvas.

Panels may use `#080d07`, selections `#232922`, and borders `#795e47`.
Use these sparingly. Selection text should stay light gold, not dark text
on another dark background. Text on a filled bright accent should be dark
and opaque, even when the main canvas is transparent.

## Semantic roles

| Meaning | Colour | Extra styling |
| --- | --- | --- |
| Body text / fields | Gold `#ffd872` | Normal |
| Secondary text / clock | Muted gold `#bfa256` | Normal |
| Variables / branch / muted metadata | Sage `#8ca391` | Normal |
| Parameters | Sage `#8ca391` | Italic |
| Constants / numbers | Golden yellow `#ffd766` | Constants bold |
| Types | Pale yellow `#ffe88e` | Normal |
| Functions | Copper `#d67e5b` | Normal |
| Keywords / prompt rails / inline code | Orange `#eb9866` | As needed |
| Strings | Amber `#edbd70` | Normal |
| Bold key phrases / success | Mint `#a3d9b1` | Key phrases bold |
| Italic emphasis | Bright orange `#ffa764` | Italic |
| Headings / links / primary mode / info | Teal `#7fcbbf` | Headings bold, links underlined |
| Comments / low-priority decoration | Grey-green `#656a64` | Comments may be italic |
| Errors / removals | Rust `#e19e63` | Also use icons, labels or underlines |

- Do not make important prose gold-on-gold with only bolding to distinguish it.
- Mode/agent labels should use the teal, orange and mint `mode_cycle`; do not
  reuse the body colour for every mode.
- For essential small text or comments, use sage instead of the darker muted
  swatch if the actual background makes the latter hard to read.
- Colour is not the only signal: retain labels, Git markers, diagnostic icons,
  underline/weight and selection backgrounds.
- For an adaptive statusline, interpolate section backgrounds from the active
  theme's surface and accent, rather than forcing Ember Grove onto other themes.

## Provenance and compatibility

The base swatches came from the Aether-generated Omarchy palette used by the
Sebenta SDL examples website. Sage is OpenCode Matrix's muted text colour.
Mint and teal were added to make semantic emphasis and modes noticeable
against the gold body text. The additional dark diff/panel surfaces come from
the existing OpenCode Ember Grove theme.

The legacy names `red`, `green`, `blue`, `cyan` and `magenta` preserve the ANSI
mapping. **They are not literal hue names:** `green` is amber, `blue` is copper,
and `cyan` is gold. Use `roles` for meaning. `ansi` lists slot references in
order from 0 through 15.

This is a lightweight repository-owned JSON format:

- `colors`: named sRGB `#rrggbb` swatches.
- `roles`: nested semantic mappings to swatch names; `inherit` is the canvas
  sentinel, not a colour.
- `typography`: role paths with complementary font styles.
- `mode_cycle`: swatch names for visibly distinct mode/agent labels.
- `background_policy`: preserve the host, with a named opaque fallback.
- `ansi`: 16 swatch names for terminal integration.

Existing implementations, useful as format-specific examples:

- [Neovim](../../dotfiles/nvim/themes/ember-grove/)
- [Ghostty](../../dotfiles/ghostty/themes/Ember%20Grove)
- [OpenCode](../../dotfiles/opencode/themes/ember-grove.json)
- [Starship](../../dotfiles/starship.toml)

These remain self-contained app configs; editing this reference does not
automatically regenerate them.
