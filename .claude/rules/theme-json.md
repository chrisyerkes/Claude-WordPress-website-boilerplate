---
description: theme.json and section-style conventions. Read before changing design tokens or block styling.
paths:
  - "**/theme.json"
  - "**/styles/*.json"
---

# theme.json

## Schema pin

`theme.json` is **version 3**. There is no version 4; v3 has been current since WordPress 6.6 and later releases added capability without bumping it.

The `$schema` is pinned to the **WordPress release the theme targets**: `https://schemas.wp.org/wp/<major.minor>/theme.json`. Do not copy a release number from memory or from another file. `setup.sh` reads the installed release from `../wp-includes/version.php` (`$wp_version`), writes the pin into `theme.json` and every `styles/*.json`, and reports the version it used. If core is not found it asks, or takes `WP_VERSION` from an answers file. Pin to a release, never to `trunk`: `trunk` tracks in-development Gutenberg and validates keys that shipped WordPress does not have.

`schemas.wp.org` redirects every version to a generic GitHub branch URL, so a successful redirect does not prove that a version exists. The authority for which keys are valid is the installed core, in `wp-includes/class-wp-theme-json.php`:

- `VALID_SETTINGS` and `VALID_STYLES`: top-level keys
- `ELEMENTS`: element keys under `styles.elements`
- `VALID_ELEMENT_PSEUDO_SELECTORS` and `VALID_BLOCK_PSEUDO_SELECTORS`: allowed `:hover`-style keys
- `VALID_BLOCK_CUSTOM_STATES`: allowed `-current`-style states

Before using a key you have not used before, grep for it in that file.

## Single source of truth

theme.json holds the design tokens. If a value can live here, it lives here, because that keeps it editable in the Site Editor and available as a CSS custom property.

## The palette contract

The template palette is exactly: `primary`, `secondary`, `tertiary`, `white`, `black`. Labels are descriptive, so the role and the color show in the editor: `Primary · Slate Teal`, or just `Primary` when no name was given.

`setup.sh` can add, and only add:

- `off-white`, an optional neutral
- named accents, such as `sky`, with any slug that is not already used (see `v_accent_slug` in `setup.sh` for the reserved list)
- `primary-dark`, `primary-light` and `secondary-dark`, when the derive-shades option is on. Nothing in the template uses them.

`white` and `black` are always present. Adding slugs is free. **Renaming or removing a slug means updating every reference** in `theme.json`, `styles/*.json`, `parts/`, `templates/`, `patterns/`, `inc/` and `src/scss/`. The references are `preset--color--<slug>` (CSS and SCSS), `preset|color|<slug>` (JSON `var:` references) and `has-<slug>-background-color` or `has-<slug>-color` (block classes). `setup.sh` warns when any of them names a slug the palette does not define.

Form borders and other non-text UI use `primary`, which clears the 3:1 floor for non-text UI on white. Text needs 4.5:1. `setup.sh` prints the WCAG ratio of each color against white and black when you enter it.

## Type and spacing scale

Two labelled sets, fluid first, then fixed. The values come from `build/fluid-clamp.mjs`, which is the only place the sizes are defined.

- **Font sizes.** Fluid slugs `small` through `colossal`, each with `fluid: { min, max }` in rem. WordPress computes the clamp from `settings.typography.fluid`. Names show the range in px, e.g. `Fluid · Medium (16 → 18px)`. Fixed slugs `fixed-14` to `fixed-60` with `fluid: false`, e.g. `Fixed · 16px`.
- **Spacing.** Fluid slugs keep the original names `xs`, `s`, `m`, `l`, `xl`, `2-xl`, `3-xl`, so templates and patterns do not break. Their values are `clamp()` expressions across the viewport range. WordPress does not compute spacing clamps, so they are written out. Fixed slugs `fixed-4` to `fixed-96`.
- `defaultFontSizes` and `defaultSpacingSizes` stay `false`, and `spacingScale.steps` stays `0`.

To change a size, edit the table in `build/fluid-clamp.mjs` and regenerate:

```bash
node build/fluid-clamp.mjs                                  # print the scale
node build/fluid-clamp.mjs --write themes/<slug>/theme.json --vmin 375 --vmax 1440
```

`setup.sh` runs the second command with the viewport range it asks for.

## Fonts

Fonts have role slugs, `heading` and `body`. Templates and styles reference `var(--wp--preset--font-family--heading)`, never a font name, so swapping a font does not touch any reference.

The system stacks in the template are the fallback. A locally hosted font is installed by `build/install-fonts.mjs` (or by `setup.sh`), which:

- fetches the font with `npm pack @fontsource-variable/<name>` into a temp directory and extracts it with `tar`
- copies the Latin `wght` and `opsz` woff2 files, and the package LICENSE as `OFL.txt`, into `themes/<slug>/assets/fonts/<name>/`
- reads the `@font-face` rules from the package's own CSS, so the weight range (usually `100 900`) comes from the package
- registers the `wght` face per style with `fontDisplay: "swap"` and `src: ["file:./assets/fonts/..."]`

The `opsz` file is copied but not registered, so the browser's automatic optical sizing applies. Only one face per style is registered; register another by hand if a design needs it.

Keep the `fontFamily` value as `'<Family Name>', <system fallback stack>`, so text still renders before the font loads or if it fails.

## What belongs here vs. in SCSS

| In theme.json | In SCSS |
|---|---|
| Colors, type scale, spacing, borders, shadows | Interactive states on most blocks (`.is-open`, transitions) |
| Per-block static appearance under `styles.blocks` | Transitions and animation |
| Element styling under `styles.elements` | Layout that block supports cannot express |
| Section variations in `/styles/*.json` | Third-party plugin overrides |

**Exception:** `core/button` supports `:hover`, `:focus`, `:focus-visible` and `:active` directly in theme.json, at both block and variation level. Only those four pseudo-classes are recognised; anything else is ignored. Prefer theme.json there.

`styles.elements.link` and `styles.elements.button` also carry `:focus-visible` outlines in the template. Confirm those against `VALID_ELEMENT_PSEUDO_SELECTORS` if you change them. Link hover underlines are in SCSS (`base/_typography.scss`), because theme.json has no text-decoration state for links.

## Element and block styles in the template

- `styles.elements.caption` and `cite` set small text and the caption colour.
- `core/quote` and `core/pullquote` use the heading font, and give their `cite` its own style under `elements.cite`.
- `core/post-date` uses the small size.
- The outline button variation has a `:hover` state.

## Capabilities in 7.0

- `styles.elements.select` and `styles.elements.textInput` style form controls without CSS (6.9+). `textInput` covers `<textarea>` and `<input>` of type email, number, password, search, text, tel and url. `:focus` on these is not yet supported; that still needs CSS.
- `settings.dimensions.dimensionSizes` defines width and height presets, exposed as `--wp--preset--dimension-size--{slug}`.
- `settings.typography.textIndent`, `textColumns` and `writingMode` exist.
- `styles.css` accepts raw CSS scoped to its level, and `&` nesting works inside it.
- Per-block custom CSS in the editor is on by default; disable it per block with `"customCSS": false` in that block's `block.json` supports.

## Capabilities added in 7.1

These are **not used by the template**. The template is pinned to the release the project targets, and these keys fail validation on earlier releases. Use them only after the pin is 7.1, and check each one against `class-wp-theme-json.php` in that core first.

- `settings.viewport.mobile` and `settings.viewport.tablet`, in px, em or rem only. They drive the `@mobile` and `@tablet` style states.
- `typography.textShadow`
- `background.gradient`
- `dimensions.minWidth`
- `core/navigation-link` pseudo-selectors, and its `-current` custom state.

## Two traps

- **`appearanceTools: true` does not enable shadow presets.** Set `settings.shadow.defaultPresets` and `settings.shadow.presets` explicitly. It does enable background image and size, all four border controls, link, heading, button and caption colours, aspect ratio and dimensions, sticky position, blockGap, margin, padding and lineHeight.
- **Defining your own `fontSizes` or `spacingSizes` does not replace core's.** Set `defaultFontSizes: false` and `defaultSpacingSizes: false`, or the editor shows both sets.

## Section styles

Block style variations that apply to whole sections live as separate files in `themes/{slug}/styles/`. Each needs `slug`, `title`, `blockTypes` and `styles`. The presence of `blockTypes` is what marks the file as a block style variation rather than a whole-theme style variation.

Register a variation with `register_block_style()` in PHP only when you need a name that theme.json alone cannot introduce. A `/styles/*.json` partial is auto-discovered without any PHP.
