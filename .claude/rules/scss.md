---
description: SCSS architecture and styling conventions for this theme.
paths:
  - "**/*.scss"
---

# SCSS

Compiled by `build/compile-scss.mjs` (Dart Sass + Autoprefixer). Never edit `assets/css/` — it is generated and a PreToolUse hook will refuse the edit.

## What goes here and what does not

Most static appearance belongs in `theme.json`, not here, so it stays editable in the Site Editor. Reach for SCSS when the thing genuinely cannot be expressed as a design token or block style:

- Interactive states on blocks other than `core/button` (`:hover`, `:focus-visible`, `.is-open`)
- Transitions and animation
- Layout that block supports cannot produce
- Third-party plugin overrides (Gravity Forms, GiveWP, WooCommerce)

If you are writing a color, font size or spacing value in SCSS, stop and check whether it should be a theme.json token instead.

## Rules

- Reference `var(--wp--preset--color--*)`, `var(--wp--preset--font-size--*)`, `var(--wp--preset--spacing--*)` in compiled output. Raw hex is a lint warning outside `_variables.scss`.
- SCSS variables in `abstracts/_variables.scss` exist for use inside mixins and functions only — they mirror theme.json, they do not replace it.
- BEM for custom classes: `.{prefix}-block-name__element--modifier`.
- `@use`, never `@import`.
- No CSS frameworks, no icon fonts, no jQuery-dependent styling.
- `!important` only for third-party plugin overrides, or where a user accessibility preference must beat inline styles. Both cases need a comment saying which.

## Structure

```
src/scss/
├── main.scss              # imports everything, compiles to assets/css/main.css
├── editor.scss            # editor-only overrides, separate entry point
├── abstracts/             # variables, mixins, functions — no output
├── base/                  # reset, typography, accessibility
├── components/            # buttons, cards, forms, pagination
├── blocks/                # one partial per block needing state/behaviour CSS
├── layout/                # header, footer, template-specific
└── utilities/             # helpers, loaded last
```

Adding a partial means adding a matching `@use` in `main.scss`. Adding a new *entry point* means adding it to the `entries` array in `build/compile-scss.mjs` and enqueueing the result.

## Motion

Anything that changes state — colour, open/closed, shown/hidden — transitions. Use the tokens `--wp--custom--transition--fast|base|slow` from theme.json. Height changes (expand/collapse) go through `src/js/motion.js` (Web Animations API, `core/accordion` panels and `<details>`); add new collapsible components there rather than hand-rolling. `base/_motion.scss` collapses every duration under `prefers-reduced-motion: reduce`; its `!important` is the one justified exception, because a visitor's accessibility preference must beat every transition in the theme, core and plugins.

## Links

Text links are underlined at rest with the refined underline in `base/_typography.scss` (tokens `--wp--custom--underline--*`: thickness, thicknessHover, offset, offsetHover). Navigation, site title, post title, site logo and buttons opt out in theme.json (`elements.link.typography.textDecoration: "none"` on those blocks). Add a block there if its links should not be underlined.

## Buttons

Two buttons: the default is **Primary** (`styles.elements.button` in theme.json); **Secondary** is a block style registered in `inc/blocks.php` whose colours and states live in `styles.blocks."core/button".variations.secondary`. Core's "Fill" and "Outline" styles are removed by `src/js/editor.js` (PHP cannot unregister styles that core declares in `block.json`). The arrow is `assets/icons/arrow-right-long.svg` applied as a CSS mask on `::after` in `components/_buttons.scss`, coloured by `--starter-button-icon-color`. Add `has-no-icon` as an Additional CSS class to drop it. Do not add an "outline" variation back without a design for it.

## Quote

`blocks/_quote.scss` generates hanging open and close quotation marks (negative inline margin on the first paragraph's `::before`). `starter_quote_strip_typed_marks()` in `inc/blocks.php` removes marks an editor types at the start or end, so they never double. Remove both together if the project has no hanging quotes.

## Block spacing

Project default: template regions (header, main, footer) and top-level full-width sections have **no** margin (`layout/_spacing.scss`); sections use padding. The utilities `u-flush` (the block) and `u-flush-children` (its children) strip margins elsewhere without `!important`, so a margin set in the editor still wins. Background on how core spaces blocks:

WordPress injects `:root :where(.is-layout-flow) > * { margin-block-start: 24px }` onto direct children of any flow-layout group. Structural chrome — header, footer, overlays — must reset it with `> * { margin-block-start: 0; }` on the outermost container. `:where()` has zero specificity, so a plain child selector wins.

## Per-block stylesheets

For CSS that only matters when one block is on the page, compile it to `assets/css/blocks/{block}.css` and register it with `wp_enqueue_block_style()` in `inc/enqueue.php` rather than adding it to `main.scss`. WordPress then loads it only on pages using that block, and puts it in the iframed editor automatically.

## Deprecated CSS to avoid

- `clip: rect(...)` for visually-hidden text — use `clip-path: inset(50%)`.
- `word-break: break-word` — use `overflow-wrap: break-word`.
- Separate `margin-block-start` / `margin-block-end` where `margin-block` shorthand works.
