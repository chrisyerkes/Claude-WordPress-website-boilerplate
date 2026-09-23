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
- Full-width blocks must still constrain inner content to the content width — use an inner container with a constrained layout.
- Prefer `theme.json` presets in patterns (`var:preset|color|primary`, `var:preset|spacing|l`) over literal values, so patterns follow the palette when it changes.

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
