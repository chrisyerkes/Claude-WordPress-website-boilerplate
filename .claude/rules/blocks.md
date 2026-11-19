---
description: Custom block authoring — block.json contract, ACF blocks, bindings, interactivity.
paths:
  - "**/blocks/**"
  - "**/block.json"
  - "**/src/js/**"
---

# Custom blocks

## Before building one

Check, in order:

1. Can a core block do it? WordPress ships far more than it used to — Accordion, Details, Breadcrumbs, Icon, Terms Query, Query Total, Math, Table of Contents.
2. Can core blocks configured and saved as a **pattern** do it?
3. Can a **Block Binding** put the dynamic value into a core block? Since 7.0 this covers most "I need a field value in a heading" cases and needs no custom block at all.
4. Only then build a block.

A custom block is warranted for repeater data, multiple related fields, conditional rendering, or markup patterns genuinely cannot express.

## block.json contract

```json
{
  "$schema": "https://schemas.wp.org/trunk/block.json",
  "apiVersion": 3,
  "name": "{prefix}/example",
  "title": "Example",
  "category": "design",
  "textdomain": "{text-domain}",
  "supports": { "anchor": true, "interactivity": true },
  "viewScriptModule": "file:./view.js",
  "viewStyle": "file:./view.css"
}
```

- **`apiVersion` must be 3.** 6.9 warns below that; 7.1 iframes the editor unconditionally and lower versions misbehave there.
- Attributes holding user content need `"role": "content"`. Without it the attribute is uneditable and hidden from List View inside patterns — and unsynced patterns default to `contentOnly` mode as of 7.0.
- `viewScriptModule` for front-end ES-module JS, `viewScript` only for non-module vanilla JS, `viewStyle` for front-end-only CSS. **Classic scripts cannot depend on script modules**, so mixing the two fails silently.
- To make a custom block's attributes bindable (and therefore overridable in patterns), add them via the `block_bindings_supported_attributes_{$block_type}` filter.

## Full-width custom blocks

A custom or ACF block that can go full width must behave like a core Group: declare `"align": ["wide", "full"]` and `"layout": { "default": { "type": "constrained" }, "allowSwitching": false, "allowEditing": true }` in `supports`, and render its inner content through `<InnerBlocks />` (ACF: `<InnerBlocks />` in the render template). That gives it the editor's "Inner blocks use content width" toggle and lets the editor override it. Default spacing is padding, never margin.

## Editor parity

Blocks and patterns must look like the live site in the editor (`main.css` is loaded into the editor iframe). Interactive pieces — sliders, carousels, tabs — only need to look right: render the first slide or tab statically in the editor and leave the behaviour to the front-end script. Editable fields live in the block sidebar when the block is selected (ACF `mode: "preview"`, `blockVersion` 3), not in an inline form that changes the layout.

## ACF blocks

An ACF block is an ordinary block whose `block.json` carries an `acf` key. Register it with core's `register_block_type()` pointed at the directory. `acf_register_block_type()` has been deprecated since ACF 6.0 — do not use it.

```json
"acf": {
  "blockVersion": 3,
  "mode": "preview",
  "renderTemplate": "render.php",
  "autoInlineEditing": true
}
```

**Use `blockVersion: 3`.** V2's edit form relies on jQuery widgets that cannot work inside the iframed editor, which WordPress 7.1 makes unconditional. V3 also unlocks inline editing and the Expanded Editor.

Field definitions can now live inline in `block.json` under `acf.fields` (ACF 6.8.1+), which keeps a block's fields with the block instead of in a separate field group.

## Interactivity

Use the Interactivity API rather than hand-rolled listeners. Opt in with `"interactivity": true` in supports and point `viewScriptModule` at a module that calls `store()`.

`watch()` (new in 7.0) subscribes to reactive values from module-level code and returns an unwatch callback. It is additive — there is no public `effect()` in `@wordpress/interactivity` and never was, so ignore any source describing `watch()` as a rename.

Do not read `state.navigation.hasStarted` or `hasFinished` from `core/router`; both are deprecated in 7.0.

Never reference bare `document` or `window` in block JS. Use `ownerDocument` and `defaultView` so the code survives the iframed editor.
