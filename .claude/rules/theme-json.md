---
description: theme.json and section-style conventions. Read before changing design tokens or block styling.
paths:
  - "**/theme.json"
  - "**/styles/*.json"
---

# theme.json

Schema is **version 3**, pinned to `https://schemas.wp.org/wp/7.0/theme.json`. There is no version 4; v3 has been current since WordPress 6.6 and 7.0 added capability without bumping it. Pin to the release, not to `trunk` — `trunk` tracks in-development Gutenberg and will validate keys that are not in shipped WordPress.

theme.json is the single source of truth for design tokens. If a value can live here, it lives here, because that keeps it editable in the Site Editor and available as a CSS custom property.

## The palette contract

Brand slugs are `primary`, `primary-dark`, `primary-light`, `secondary`, `secondary-dark`, `tertiary`, plus neutrals from `white` to `black`.

`styles.elements` and several SCSS partials reference these by name. Add new slugs freely; **renaming an existing one means updating every reference**, so do not rename casually.

## What belongs here vs. in SCSS

| In theme.json | In SCSS |
|---|---|
| Colors, type scale, spacing, borders, shadows | Interactive states on most blocks (`:hover`, `.is-open`) |
| Per-block static appearance under `styles.blocks` | Transitions and animation |
| Element styling under `styles.elements` | Layout that block supports cannot express |
| Section variations in `/styles/*.json` | Third-party plugin overrides |

**Exception:** `core/button` supports `:hover`, `:focus`, `:focus-visible` and `:active` directly in theme.json as of WordPress 7.0, at both block and variation level. Only those four pseudo-classes are recognised; anything else is ignored. Prefer theme.json there.

## Capabilities available in 7.0

- `styles.elements.select` and `styles.elements.textInput` style form controls without CSS (6.9+). `textInput` covers `<textarea>` and `<input>` of type email, number, password, search, text, tel and url. `:focus` on these is not yet supported — that still needs CSS.
- `settings.dimensions.dimensionSizes` defines width/height presets, exposed as `--wp--preset--dimension-size--{slug}`.
- `settings.typography.textIndent`, `textColumns` and `writingMode` exist.
- `styles.css` accepts raw CSS scoped to its level, and `&` nesting works inside it.
- Per-block custom CSS in the editor is on by default for all blocks; disable per block with `"customCSS": false` in that block's `block.json` supports.

## Two traps

- **`appearanceTools: true` does not enable shadow presets.** Set `settings.shadow.defaultPresets` and `settings.shadow.presets` explicitly. It does enable: background image/size, all four border controls, link/heading/button/caption colors, aspect ratio and dimensions, sticky position, blockGap/margin/padding, and lineHeight.
- **Defining your own `fontSizes` or `spacingSizes` does not replace core's.** Set `defaultFontSizes: false` and `defaultSpacingSizes: false` or the editor shows both sets.

## Section styles

Block style variations that apply to whole sections live as separate files in `themes/{slug}/styles/`. Each needs `slug`, `title`, `blockTypes` and `styles`. The presence of `blockTypes` is what marks the file as a block style variation rather than a whole-theme style variation.

Register a variation with `register_block_style()` in PHP only when you need a name that theme.json alone cannot introduce; a `/styles/*.json` partial is auto-discovered without any PHP.
