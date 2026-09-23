---
name: new-block
description: Scaffold a new custom block in this theme or its companion plugin, with a WordPress 7.0-correct block.json, render template, SCSS partial and registration. Use when asked to create, add or build a block.
argument-hint: "[block name] [optional: acf | core | interactive]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Scaffold a block

$ARGUMENTS

## First: confirm a block is actually the answer

Work down this list and say which rung you landed on before writing any files.

1. **A core block already does this.** WordPress now ships Accordion, Details, Breadcrumbs, Icon, Terms Query, Query Total, Math, Navigation, Table of Contents and more. Check before building.
2. **Core blocks saved as a pattern do this.** Most "custom" components are configuration, not code.
3. **A Block Binding does this.** If the need is "put a custom field value into a heading, paragraph, image or button", bindings cover it with no block at all. See `.claude/rules/blocks.md`.
4. **A custom block is genuinely warranted** — repeater data, several related fields, conditional rendering, or markup patterns cannot express.

If the user asked for a block but rung 1, 2 or 3 covers it, say so and propose that instead. Build the block if they still want it.

## Decide where it lives

- **Theme** (`themes/{slug}/blocks/{block-name}/`) — presentational. Loses nothing meaningful if the theme changes.
- **Plugin** (`plugins/{slug}-plugin/blocks/{block-name}/`) — queries data, or its content must survive a theme switch.

## Files to create

```
blocks/{block-name}/
├── block.json
├── render.php          # server-rendered output
└── view.js             # only if the block is interactive
```

Plus `src/scss/blocks/_{block-name}.scss` and a matching `@use` in `main.scss` — but only for interactive states and behaviour. Static appearance goes in `theme.json` under `styles.blocks."{prefix}/{block-name}"`.

## block.json requirements

- `"apiVersion": 3` — mandatory. Lower versions warn in 6.9 and break in the unconditionally-iframed 7.1 editor.
- `"textdomain"` matching the project text domain.
- Attributes carrying user content need `"role": "content"`, or they vanish from List View inside patterns, which default to `contentOnly` mode in 7.0.
- Interactive blocks: `"supports": { "interactivity": true }` and `"viewScriptModule": "file:./view.js"`. Never `viewScript` for module code — classic scripts cannot depend on script modules.
- ACF blocks: add the `acf` key with `"blockVersion": 3`. V2 relies on jQuery widgets that do not work in the iframed editor. Consider declaring fields inline under `acf.fields` (ACF 6.8.1+) so they travel with the block.

## After scaffolding

1. Confirm registration picks it up — both the theme and the plugin auto-register every directory under `blocks/` containing a `block.json`, so no manual registration call is needed.
2. Add the block's static styling to `theme.json`.
3. Run `npm run scss` if you added a partial.
4. Tell the user what to check in the editor: that the block inserts without a recovery prompt, and that it renders the same in the editor as on the front end.
