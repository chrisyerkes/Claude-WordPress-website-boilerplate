# WordPress Block Theme — Claude Code Instructions

> **This is a boilerplate.** You are expected to expand, rename, and adapt everything here to the specific project. These files give you a solid, tested foundation. Do not treat them as rigid constraints — they are a starting point.

## Quick Start

Run the interactive setup script from the `wp-content/` directory to configure the project:

```bash
./setup.sh
```

This walks through naming the project, setting the text domain, function prefix, local dev URL, brand colors, layout widths, and optionally scaffolding a companion plugin. It handles all the find-and-replace, installs npm dependencies, runs the first build, and initializes git. Type `b` at any prompt to go back; nothing is written until you confirm at the review screen. `./setup.sh --dry-run` reports what would change, and `./setup.sh --help` includes a troubleshooting guide.

If `setup.sh` has already been run (or removed), the project is configured and ready to build.

## Project Overview

<!-- CUSTOMIZE: Replace this section with a project-specific summary once setup.sh has been run. -->
This is a custom WordPress block theme (`starter`) with an optional companion plugin pattern. Update the theme slug, text domain, and prefix throughout once the project is named (or run `./setup.sh` to do it automatically).

**Prefix:** `starter_` (change globally when the project is named)
**Text domain:** `starter` (change globally when the project is named)

## Architecture

### Theme-Plugin Separation Principle

**Theme (`themes/starter/`)** — All presentation: `theme.json`, templates, template parts, patterns, CSS/SCSS, JS, fonts, icons, and presentational ACF blocks.

**Plugin(s) (optional)** — All data and functionality that should survive a theme switch: Custom Post Types, taxonomies, ACF field groups, ACF Options Pages, REST API endpoints, data-querying blocks, shortcodes, and integrations with external services.

**The dividing line:** If switching themes would lose important data or functionality, it belongs in a plugin. If it's purely visual or layout, it belongs in the theme.

> **You do NOT need to create a companion plugin for every project.** Only create one when the project requires CPTs, custom taxonomies, complex ACF field groups, or data-centric blocks. A simple brochure site with only core blocks and patterns needs no plugin at all.

### When to Create a Plugin

Create a companion plugin when any of these are true:
- The project needs Custom Post Types or custom taxonomies
- ACF field groups store data that should persist across theme changes
- You need data-querying blocks (e.g., a filterable directory, a map, a custom feed)
- You need ACF Options Pages for site-wide settings (social links, API keys, etc.)
- There are integrations with third-party APIs or services

### Plugin Structure (when needed)

```
plugins/{project}-plugin/
├── {project}-plugin.php           (plugin header, bootstrap)
├── includes/
│   ├── post-types.php             (register CPTs and taxonomies)
│   ├── acf-field-groups.php       (ACF field group registrations)
│   ├── acf-options-page.php       (Options page setup)
│   └── helpers.php                (shared utility functions)
├── blocks/
│   └── {block-name}/
│       ├── block.json
│       └── render.php
└── assets/
    ├── css/
    └── js/
```

## Tech Stack

- WordPress 6.7+ block theme with `theme.json` v3
- ACF PRO 6.7+ (when the project uses ACF Blocks V3, `block.json` registration, `autoInlineEditing`)
- Dart Sass for SCSS compilation
- esbuild for JavaScript bundling
- chokidar v3 for file watching (with polling enabled for WSL2 compatibility). Pinned deliberately: v4 removed glob support from the `ignored` option, so `dev-server.mjs` uses a predicate function that works identically on v3, v4 and v5.
- No jQuery, no CSS frameworks (Tailwind, Bootstrap, etc.), no icon font libraries (FontAwesome, etc.)

> **ACF PRO is not mandatory.** Many projects can be built entirely with core blocks and block patterns. Only introduce ACF when the project genuinely needs custom fields, repeater fields, or custom block types that can't be achieved with core blocks + patterns. When ACF is used, always include a graceful admin notice if the plugin is missing.

## Build System

SCSS and JS are compiled via npm scripts at the `wp-content/` level.

```bash
npm run dev       # Watch mode: auto-compiles SCSS + JS on save
npm run build     # Production build: minified CSS + JS
npm run scss      # Compile SCSS only
npm run js        # Bundle JS only
npm run lint      # Run all linters (SCSS + JS)
npm run lint:scss # Stylelint SCSS only
npm run lint:js   # ESLint JS only
```

> **Shell commands — CRITICAL RULES:**
> 1. **No backslash-escaped spaces.** Use double-quoted paths: `cd "/mnt/c/Users/..."` — NEVER `Local\ Sites`. Backslash escapes trigger permission prompts in WSL.
> 2. **No chained commands.** Do not use `&&` (e.g., `cd foo && npm run build`). Run each command as a separate Bash tool call.
> 3. Rely on the working directory being `wp-content/`. Use `npm run build` directly.

### Source → Output Mapping

| Source | Output |
|--------|--------|
| `themes/starter/src/scss/main.scss` | `themes/starter/assets/css/main.css` |
| `themes/starter/src/scss/editor.scss` | `themes/starter/assets/css/editor.css` |
| `themes/starter/src/js/navigation.js` | `themes/starter/assets/js/navigation.js` |

> **Expand this table** as you add SCSS entry points (e.g., gravity-forms.scss, givewp.scss) and JS modules. Keep it up to date so future sessions know what compiles where.

### SCSS Architecture

```
themes/starter/src/scss/
├── main.scss                  # Primary theme stylesheet (imports all partials)
├── editor.scss                # Block editor overrides (standalone entry)
├── abstracts/
│   ├── _variables.scss        # SCSS vars mirroring theme.json tokens
│   ├── _mixins.scss           # Responsive breakpoints, containers, utilities
│   └── _functions.scss        # SCSS helper functions
├── base/
│   ├── _reset.scss            # CSS reset / normalization
│   ├── _typography.scss       # Global type styles
│   └── _accessibility.scss    # Skip links, focus styles, screen reader utilities
├── components/
│   ├── _buttons.scss          # Button styles and block style overrides
│   ├── _cards.scss            # Card patterns
│   ├── _forms.scss            # Form element styles
│   └── _pagination.scss       # Pagination styles
├── blocks/                    # One partial per custom block (add as needed)
├── layout/
│   ├── _header.scss
│   ├── _footer.scss
│   └── _templates.scss        # Template-specific layout overrides
└── utilities/
    └── _helpers.scss           # Utility classes
```

> **Add new block partials** to `blocks/` as you build them, and `@use` them in `main.scss`. Add new standalone entry points (e.g., for plugin CSS overrides) to `compile-scss.mjs`.

## Coding Standards

### PHP
- Follow WordPress Coding Standards (tabs for indentation)
- Prefix all custom functions, hooks, and classes with the project prefix (e.g., `starter_`)
- Escape all output: `esc_html()`, `esc_attr()`, `esc_url()`, `wp_kses_post()`
- Enqueue all assets properly via `wp_enqueue_script()` / `wp_enqueue_style()`
- Use strict typing where appropriate

### SCSS / CSS
- Use CSS custom properties from `theme.json` (`--wp--preset--color--*`, `--wp--preset--font-size--*`, etc.)
- No CSS frameworks. No rogue hex values. All colors from the `theme.json` palette.
- BEM naming for custom classes: `.starter-block-name__element--modifier`
- SCSS variables in `_variables.scss` mirror `theme.json` tokens for use in SCSS functions/mixins only. Compiled CSS should reference `var(--wp--preset--color--*)`.

### WordPress Block Spacing & Structural Elements
- WordPress injects default block spacing via `:root :where(.is-layout-flow) > * { margin-block-start: 24px }`. This applies to all direct children of any `wp:group` using flow layout.
- Structural/chrome elements (header, footer, overlays) must reset this: `> * { margin-block-start: 0; }` on the outermost container. The `:where()` selector has zero specificity, so a simple `> *` wins.
- Always check for unwanted block spacing when building new template parts or structural components that use `wp:group` blocks.

### JavaScript
- Vanilla JS only. No jQuery dependency.
- ES modules, bundled by esbuild
- All icons are inline SVGs (no icon font libraries)

### ACF Blocks (when using ACF)
- Every ACF block uses `block.json` with the `acf` key (not legacy `acf_register_block_type()`)
- Required in every block.json:
  ```json
  {
    "apiVersion": 3,
    "acf": {
      "blockVersion": 3,
      "renderTemplate": "render.php",
      "autoInlineEditing": true
    }
  }
  ```
- Register all blocks via `register_block_type()` pointed at the block's directory
- For flexible inner content areas, enable `"jsx": true` in supports and use `<InnerBlocks />` in render template

### Block Patterns
- **Evaluate patterns before building ACF blocks.** Many components that feel custom can be achieved with well-configured core blocks saved as patterns. Only reach for ACF when you need repeater fields, custom field data, or logic that patterns can't handle.
- Register patterns in `/patterns/` using file-based auto-registration
- Use `theme.json` palette colors, font sizes, and spacing presets in patterns
- Use native WordPress block wrapper inline CSS to inject editor-supported styles via the built-in WordPress controls (margin, padding, color, background color, border radius, etc.). Do not hardcode these values in SCSS when the editor can handle them natively.
- Blocks that use the full-width alignment option must still constrain their inner content to the content width defined in `theme.json`. Use an inner container with `contentSize` or the appropriate `wp:group` layout settings to prevent content from stretching edge-to-edge.

### Template Parts & wp:html
- **Never use `wp:html` blocks** in template parts or templates. Clients should never encounter raw HTML editing in the Site Editor.
- If custom markup is needed, create an ACF block with a `render.php` template.
- Even components with no editable fields should be ACF blocks for a clean editor experience.
- Lock structural blocks in templates with `{"lock":{"move":true,"remove":true}}`.

### Template HTML Formatting (Block Recovery Prevention)
- Core blocks in `.html` template parts are whitespace-sensitive. The HTML between a block's opening and closing comments must match exactly what WordPress's `save()` function produces.
- **Never indent the inner HTML of core blocks.** WordPress serializes block content without leading whitespace. Extra tabs/spaces cause "Attempt block recovery" errors.
- Block comment delimiters (`<!-- wp:block-name -->`) can be indented, but the HTML content between them must start at column 0.
- Example of correct `core/buttons` + `core/button` format:
  ```html
  <!-- wp:buttons -->
  <div class="wp-block-buttons">
  <!-- wp:button {attrs} -->
  <div class="wp-block-button"><a class="wp-block-button__link" ...>Text</a></div>
  <!-- /wp:button -->
  </div>
  <!-- /wp:buttons -->
  ```

### Editor Styles
- Both `main.css` and `editor.css` are registered as editor stylesheets via `add_editor_style()`.
- `editor.scss` is for editor-specific overrides only (making hidden elements visible in previews, removing fixed-header padding, etc.).
- For ACF blocks with hidden/collapsed front-end states, use `$is_preview` in `render.php` to add a preview class and override visibility in editor CSS.

## Design Tokens

`theme.json` is the single source of truth. The starter ships a placeholder palette and type scale; replace them with project-specific tokens.

The palette is built around three brand slugs plus neutrals:

| Slug | Purpose |
|------|---------|
| `primary` | Main brand color. Used for headings, links and buttons in `styles`. |
| `primary-dark` / `primary-light` | Hover and tint variants of primary. |
| `secondary` | Supporting brand color. |
| `secondary-dark` | Hover variant of secondary. |
| `tertiary` | Third brand color / accent. |
| `white`, `off-white`, `light-gray`, `medium-gray`, `dark-gray`, `near-black`, `black` | Neutrals. |

`setup.sh` prompts for primary, secondary and tertiary, and can derive the `-dark` and `-light` variants from them. **Keep these slugs** when replacing the palette — `styles.elements` in `theme.json` and several SCSS partials reference `var(--wp--preset--color--primary)` and `--primary-dark` by name. Add new slugs freely; renaming the existing ones means updating every reference.

## Responsive Breakpoints

```scss
$bp-mobile:  375px;
$bp-tablet:  768px;
$bp-desktop: 1024px;
$bp-wide:    1440px;
$bp-ultra:   1920px;
```

Test at: 320px, 375px, 768px, 1024px, 1440px, 1920px.

## Performance & Accessibility

- Target: Lighthouse scores >= 90 across all categories
- WCAG 2.2 AA compliance
- No console errors
- Keyboard navigation everywhere
- Semantic HTML and proper ARIA attributes
- Lazy-load images, conditionally enqueue plugin-specific CSS/JS

## Common Tasks

### Adding a New ACF Block (theme)
1. Create directory: `themes/starter/blocks/{block-name}/`
2. Create `block.json` with proper ACF config (see standards above)
3. Create `render.php` with the block's HTML output
4. Add SCSS partial: `src/scss/blocks/_{block-name}.scss`
5. `@use` the partial in `main.scss`
6. Register the block in `functions.php` via `register_block_type()`
7. Add the JS entry to `bundle-js.mjs` if the block needs client-side JS

### Adding a New Block Pattern
1. Create PHP file in `themes/starter/patterns/{pattern-name}.php`
2. Add the required comment header (Title, Slug, Categories)
3. Use core blocks configured with `theme.json` presets
4. Pattern auto-registers from the `/patterns/` directory

### Adding a New SCSS Entry Point
1. Create the `.scss` file in `themes/starter/src/scss/`
2. Add it to the `entries` array in `build/compile-scss.mjs`
3. Enqueue the compiled CSS in `inc/enqueue.php` (conditionally if possible)
4. Update the Source → Output table in this file

### Adding a New JS Module
1. Create the `.js` file in `themes/starter/src/js/`
2. Add it to the `entries` array in `build/bundle-js.mjs`
3. Enqueue the compiled JS in `inc/enqueue.php` (conditionally if possible)
4. Update the Source → Output table in this file

### Creating a Companion Plugin
1. Create `plugins/{project}-plugin/` with the structure described above
2. Register the plugin in its main PHP file with a standard plugin header
3. Add data-centric blocks, CPTs, taxonomies, and field groups there
4. Add plugin JS entries to `bundle-js.mjs` if needed
5. Add plugin SCSS entries to `compile-scss.mjs` if needed

## Files to Never Edit Directly

- `themes/starter/assets/css/*.css` — Compiled from SCSS. Edit source in `src/scss/`.
- `themes/starter/assets/js/*.js` — Bundled from source. Edit in `src/js/`.
- `node_modules/` — Managed by npm.

## Line Endings

`.gitattributes` forces LF for every text file. This project is edited on Windows through WSL and synced through Dropbox, both of which can introduce CRLF — a CRLF shebang makes `setup.sh` fail with `bad interpreter: /usr/bin/env bash^M`, and CRLF in `.mjs` files breaks the build in ways that are hard to trace. Never commit CRLF; if a file has it, fix with `sed -i 's/\r$//' <file>`.

## Files to Always Consult

- `themes/starter/theme.json` — Single source of truth for design tokens.
- This `CLAUDE.md` — Project instructions and coding standards.
- The project spec (if one exists) — Check for a `*-spec.md` file in the theme directory.

## Expanding This Boilerplate

You are free and encouraged to:
- Rename `starter` to the actual project name (update the prefix, text domain, and all file references)
- Add more SCSS entry points for third-party plugin overrides (Gravity Forms, GiveWP, The Events Calendar, WooCommerce, etc.)
- Add more JS modules as interactivity requirements emerge
- Create a companion plugin when data requirements call for it
- Add custom image sizes, nav menus, and theme supports in `inc/theme-setup.php`
- Register additional block styles, block patterns, and template variations
- Add SVG icons to the icon system as the design requires
- Expand the build system (add PostCSS plugins, image optimization, etc.)
