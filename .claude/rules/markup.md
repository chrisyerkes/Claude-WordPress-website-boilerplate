---
description: Block markup rules for templates, template parts and patterns. Read before editing any .html template or pattern PHP file.
paths:
  - "**/templates/**"
  - "**/parts/**"
  - "**/patterns/**"
---

# Block markup

## Whitespace is significant

Core blocks in `.html` templates and pattern files are whitespace-sensitive. The HTML between a block's opening and closing comments must match what the block's `save()` function produces, or the editor offers "Attempt block recovery" and the user loses the block.

**Never indent the inner HTML of a core block.** Block comment delimiters may be indented; the HTML between them starts at column 0.

```html
<!-- wp:buttons -->
<div class="wp-block-buttons">
<!-- wp:button -->
<div class="wp-block-button"><a class="wp-block-button__link" href="#">Text</a></div>
<!-- /wp:button -->
</div>
<!-- /wp:buttons -->
```

Attribute *order* inside a tag does not matter — validation compares attributes as a set. Missing or extra attributes do matter, as does any difference in tag structure or text content.

The safest way to author a non-trivial pattern is to build it in the editor and copy the markup out, rather than writing the serialization by hand.

## Structure rules

- **Never use `wp:html` blocks.** Clients should not meet raw HTML editing in the Site Editor. If custom markup is needed, make it a block with a `render.php`.
- Lock structural blocks: `{"lock":{"move":true,"remove":true}}`.
- **Full-width sections use the block's own layout, not an inner wrapper.** Give the outer group `"align":"full"` and `"layout":{"type":"constrained"}`. That is what shows the editor's "Inner blocks use content width" toggle, so an editor can switch a section to edge-to-edge content and back. An inner constrained wrapper hides the toggle — do not use one.
- **Templates put Post Content full width:** `<!-- wp:post-content {"align":"full","layout":{"type":"constrained"}} /-->`. If Post Content sits at content width, nothing inside it can be full width.
- **Design sections have no top or bottom margin**, only padding (`layout/_spacing.scss` does this for full-width blocks at the top level of the content). Set section spacing with padding presets. To strip block gaps elsewhere, add `u-flush` (the block) or `u-flush-children` (its children) as an Additional CSS class.
- **Shortcodes go in the text, not in a block.** Write `[starter_year]` directly in a paragraph. A `wp:shortcode` block nested inside a paragraph prints its brackets literally.
- Prefer `theme.json` presets in patterns (`var:preset|color|primary`, `var:preset|spacing|l`) over literal values, so patterns follow the palette when it changes.

## SEO and accessibility baseline

- **One H1 per page.** Pages get theirs from the hero pattern; single posts from `core/post-title` level 1; the 404 template has its own. The header site title is `"level":0` (a `<p>`), never a heading.
- **Landmarks:** the header, `<main>` and footer template parts supply the `header`, `main` and `footer` landmarks. Do not add a second `<main>`.
- **Text wrapping:** headings use `text-wrap: balance` and paragraphs `text-wrap: pretty` (`base/_typography.scss`). Do not override it per block.
- **Meta, Open Graph and schema:** when Yoast SEO (or another SEO plugin) is active, the theme never outputs its own `<meta>`, Open Graph or JSON-LD. Do not add `wp_head` output for them.

## contentOnly editing (WordPress 7.0)

Unsynced patterns and template parts now default to `contentOnly` mode when inserted. Editors see text and media fields; structural and style controls are hidden.

When authoring a pattern, check it is still usable under that restriction — the fields a client needs to change must be reachable. Blocks whose content attributes lack `"role": "content"` disappear from List View entirely.

To opt a site out, set `disableContentOnlyForUnsyncedPatterns` via the `block_editor_settings_all` filter. Prefer fixing the pattern over disabling the mode.

## Pattern file header

```php
<?php
/**
 * Title: Human Readable Name
 * Slug: {theme-slug}/pattern-name
 * Categories: {theme-slug}-components
 * Description: One sentence on what it is for.
 * Keywords: comma, separated
 */
?>
```

Patterns auto-register from the `patterns/` directory. No PHP registration call is needed.
