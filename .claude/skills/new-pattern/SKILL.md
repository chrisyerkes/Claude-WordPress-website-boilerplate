---
name: new-pattern
description: Create a new block pattern in this theme, with a correct file header and valid block markup. Use when asked to add a pattern, a section, or a reusable layout built from core blocks.
argument-hint: "[pattern name] [what it should contain]"
allowed-tools: Read, Write, Edit, Glob, Grep
---

# Create a block pattern

$ARGUMENTS

Patterns live in `themes/{slug}/patterns/` and auto-register from that directory. No PHP registration call is needed.

## File header

```php
<?php
/**
 * Title: Human Readable Name
 * Slug: {theme-slug}/pattern-name
 * Categories: {theme-slug}-components
 * Description: One sentence on what it is for and when to use it.
 * Keywords: comma, separated, search, terms
 */
?>
```

`Categories` may list several, comma-separated. Core categories worth using alongside the project's own: `header`, `footer`, `text`, `gallery`, `call-to-action`, `banner`, `about`, `contact`, `services`, `testimonials`, `posts`.

## Markup rules

These are the ones that actually cause problems — see `.claude/rules/markup.md` for the full set.

- **Inner HTML of core blocks starts at column 0.** Indenting it causes "Attempt block recovery" and the user loses the block. Comment delimiters may be indented; the HTML between them may not.
- Use `theme.json` presets rather than literal values: `var:preset|color|primary`, `var:preset|spacing|l`. A pattern written with hex codes stops matching the site the first time the palette changes.
- No `wp:html` blocks.
- Wrap translatable strings in `esc_html__()` with the project text domain, so the pattern is translatable.
- Full-width sections still constrain their inner content — use a constrained-layout inner group.

## Getting the serialization right

Hand-authoring block markup is the main source of pattern bugs. For anything beyond a few simple blocks, the reliable route is: build it in the block editor, copy the markup from the code view, and paste it into the pattern file.

If you do author it by hand, note that attribute *order* inside a tag does not matter — validation compares attributes as a set — but missing or extra attributes, and any difference in tag structure or text, do.

## Check it under contentOnly

Unsynced patterns default to `contentOnly` editing mode in WordPress 7.0: editors get text and media fields, not structure or styling. Before finishing, confirm the fields a client will actually need to change are reachable in that mode.

## Finally

Tell the user where the pattern appears in the inserter, and what in it is meant to be edited versus left alone.
