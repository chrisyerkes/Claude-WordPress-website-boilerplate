# WordPress Block Theme — Claude Code Instructions

> **This is a boilerplate.** Expand, rename and adapt everything here to the project. These files are a tested starting point, not a constraint.

Detailed conventions live in `.claude/rules/` and load automatically when you touch a matching file — PHP standards when editing `.php`, SCSS architecture when editing `.scss`, and so on. This file holds only what is true all the time.

## Quick Start

Run the interactive setup once, from the `wp-content/` directory:

```bash
./setup.sh
```

It names the project, sets the text domain and prefix, writes brand colors and layout widths into `theme.json`, optionally scaffolds a companion plugin, installs dependencies and initializes git. Type `b` at any prompt to go back. `./setup.sh --dry-run` shows what would change; `./setup.sh --help` includes a troubleshooting guide.

If `setup.sh` is gone, the project is already configured.

## Project Overview

<!-- CUSTOMIZE: replace with a project-specific summary once setup.sh has run. -->
A custom WordPress block theme (`starter`) with an optional companion plugin.

**Prefix:** `starter_`  ·  **Text domain:** `starter`

## Target Platform

- **WordPress 7.0+**, block theme, `theme.json` v3 pinned to the 7.0 schema
- **PHP 8.1+** (8.3 recommended)
- **ACF PRO 6.8+** when the project uses ACF — optional, not assumed
- Dart Sass, esbuild, chokidar v3 (pinned deliberately — see README)
- No jQuery, no CSS frameworks, no icon fonts

## Architecture

### Theme or plugin

**If switching themes would lose data or functionality, it belongs in the plugin.** Custom post types, taxonomies, ACF field groups, options pages, REST endpoints, data-querying blocks, third-party integrations.

**If it is purely visual, it belongs in the theme.** `theme.json`, templates, template parts, patterns, SCSS, JS, fonts, icons, presentational blocks.

Not every project needs a plugin. A brochure site built from core blocks and patterns needs none.

### Dynamic content: bindings, patterns or a custom block

Work down this list and stop at the first rung that works:

1. **A core block already does it.** WordPress now ships Accordion, Details, Breadcrumbs, Icon, Terms Query, Query Total, Math and Table of Contents. Check before building.
2. **Core blocks saved as a pattern do it.** Most "custom" components are configuration.
3. **A Block Binding does it.** Since WordPress 7.0, bindings put a custom field value directly into a core heading, paragraph, image, button or post-date. This removes most of the historic reason to build an ACF block for a single field.
4. **A custom block is warranted** — repeater data, several related fields, conditional rendering, or markup patterns genuinely cannot express.

<!-- DATA_STRATEGY -->
**Default for this project:** decide per component.

## Build System

npm scripts run from `wp-content/`:

```bash
npm run dev       # BrowserSync + watch, in-process compiles
npm run build     # production, minified
npm run scss      # SCSS only
npm run js        # JS only
npm run lint      # stylelint + eslint
```

| Source | Output |
|--------|--------|
| `themes/starter/src/scss/main.scss` | `themes/starter/assets/css/main.css` |
| `themes/starter/src/scss/editor.scss` | `themes/starter/assets/css/editor.css` |
| `themes/starter/src/js/navigation.js` | `themes/starter/assets/js/navigation.js` |

Keep that table current as entry points are added.

**Never edit anything in `assets/`.** It is generated, and a PreToolUse hook will refuse the edit. Edit `src/` and rebuild.

**Never run `npm audit fix --force`.** It downgrades browser-sync two major versions and destroys the dev server. See README for why the advisories are accepted.

## Shell Commands

1. **Quote paths, never backslash-escape spaces.** `cd "/mnt/c/Users/..."`, not `Local\ Sites`.
2. **One command per call.** Do not chain with `&&`, `||`, `;` or `|` unless the pipeline is the point. Claude Code splits compound commands and matches every segment against the permission rules independently, so chaining is the most common cause of an unexpected approval prompt.
3. The working directory is `wp-content/`. Run `npm run build` directly.

## Delegating Work

Four subagents are defined in `.claude/agents/`, on deliberately different model tiers:

| Agent | Model | Use for |
|-------|-------|---------|
| `wp-scout` | haiku | "Where is X", "which files touch Y" — read-only search |
| `wp-build` | haiku | Running builds and linters, reporting failures |
| `wp-reviewer` | sonnet | Reviewing a batch of work against project standards |
| `wp-architect` | opus | The escalation target — hard problems only |

Prefer the cheapest agent that can do the job, and use one at all when the work would otherwise dump a lot of output into this conversation.

**Escalation.** Claude Code has no built-in "retry on a stronger model" mechanism — `fallbackModel` covers availability errors only. The convention here: a cheap agent that cannot finish replies `ESCALATE: <reason>` instead of guessing. When you see that, or when the same fix has failed twice, dispatch `wp-architect` with what was already ruled out. `/escalate` packages this.

When `wp-architect` returns a rule that will apply again, add it to the matching file in `.claude/rules/` so the next session gets it without paying for the reasoning twice.

## Standards

Full detail is in `.claude/rules/`, loaded per file type. The short version:

- **Escape all output.** Prefix all custom functions, hooks and classes.
- **`theme.json` before CSS.** Static appearance belongs in design tokens so it stays editable in the Site Editor. SCSS is for interactive states, transitions and plugin overrides.
- **`apiVersion: 3`** on every custom block. WordPress 7.1 iframes the editor unconditionally and older versions misbehave there.
- **`"role": "content"`** on block attributes holding user content, or they disappear from List View inside patterns — which default to `contentOnly` mode in 7.0.
- **Core block inner HTML starts at column 0** in templates and patterns. Indenting it causes "Attempt block recovery".
- **No `wp:html` blocks** in templates or template parts.
- WCAG 2.2 AA, Lighthouse ≥ 90, keyboard reachable, no console errors.

## Design Tokens

`theme.json` is the single source of truth. Brand palette slugs are `primary`, `primary-dark`, `primary-light`, `secondary`, `secondary-dark`, `tertiary`, plus neutrals. `styles.elements` and several SCSS partials reference them by name — adding slugs is free, renaming them is not.

Section styles live in `themes/starter/styles/*.json` and are auto-discovered.

Breakpoints: 375 / 768 / 1024 / 1440 / 1920. Test at 320 too.

## Line Endings

`.gitattributes` forces LF everywhere. This project is edited on Windows through WSL and synced through Dropbox, both of which introduce CRLF — a CRLF shebang makes `setup.sh` fail with `bad interpreter: /usr/bin/env bash^M`, and CRLF in `.mjs` breaks the build in ways that are hard to trace. Fix with `sed -i 's/\r$//' <file>`.

## Files to Always Consult

- `themes/starter/theme.json` — design tokens
- `.claude/rules/` — the conventions for whatever you are editing
- Any `*-spec.md` in the theme directory
