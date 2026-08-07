# WordPress Block Theme Boilerplate

A copy-paste-and-go WordPress project template optimized for Claude Code. Drop it into a Local by Flywheel site, run the setup script, and start building.

**Targets WordPress 7.0+ and PHP 8.1+.** The theme uses the current block APIs out of the gate: the native Accordion block, Breadcrumbs, Block Bindings, section styles, per-block pseudo-class states, form element styling, script modules and the Interactivity API.

## Setup

### 1. Create a Local by Flywheel site

Create a new WordPress site in Local. The site name doesn't matter yet.

### 2. Replace wp-content

Copy the contents of this boilerplate into your new site's `wp-content/` directory, replacing the default contents. The folder structure should look like this:

```
your-local-site/
└── app/
    └── public/
        └── wp-content/          ← This entire folder is the boilerplate
            ├── setup.sh
            ├── CLAUDE.md
            ├── package.json
            ├── .claude/
            ├── .mcp.json
            ├── build/
            └── themes/
                └── starter/
```

### 3. Run the setup script

Open a WSL terminal, navigate to the `wp-content/` directory, and run:

```bash
./setup.sh
```

The script will walk you through:

- **Project name and theme display name** (the display name goes into `style.css` exactly as typed, spaces and capitals included)
- **Theme slug, text domain, function prefix** (auto-derived, all editable)
- **Author info**
- **Local dev URL and BrowserSync port**
- **ACF PRO toggle** (defaults to yes)
- **Companion plugin scaffolding** (optional, creates a full plugin skeleton)
- **Primary, secondary and tertiary brand colors**, with an option to derive `primary-dark`, `primary-light` and `secondary-dark` from them
- **Content and wide layout widths**
- **npm install + initial build**
- **Git initialization** with a clean first commit

Type `b` (or `back`) at any prompt to return to the previous question — answers you already gave are preserved. Nothing is written to disk until you confirm at the review screen.

Every step reports real progress: a step counter sized to the answers you gave, a bar driven by actual file counts during find-and-replace, and a live elapsed timer during `npm install` so a slow network is distinguishable from a hang.

Other flags:

```bash
./setup.sh --dry-run    # Report what would change without writing anything
./setup.sh --help       # Usage plus a troubleshooting guide
```

If something goes wrong, the script reports what it was doing, the failing command, and a specific fix — then tells you whether anything had already been written. Run `./setup.sh --help` for the full list of common failures (CRLF line endings from Dropbox, npm EACCES, missing git identity, port conflicts, Node too old).

It offers to delete itself when done, since it's a one-time setup.

### 4. Open in your editor

Open the `wp-content/` directory in Windsurf (or VS Code) via WSL, activate Claude Code, and start building.

**Accept the workspace trust prompt the first time.** Until you do, Claude Code reads `.claude/settings.json` but does not apply its permission rules — which looks exactly like the allowlist being ignored. See [Claude Code setup](#claude-code-setup) below.

### 5. Activate the theme

In WordPress admin, go to Appearance > Themes and activate your new theme.

## What's Included

```
wp-content/
├── setup.sh                     # Interactive project setup (delete after use)
├── CLAUDE.md                    # Claude Code instructions and coding standards
├── package.json                 # npm build scripts
├── .claude/
│   ├── settings.json            # Permissions, model, hooks
│   ├── agents/                  # 4 subagents on tiered models
│   ├── rules/                   # Path-scoped conventions (load on demand)
│   ├── skills/                  # /verify-build, /new-block, /new-pattern, /escalate
│   └── hooks/                   # Block generated-file edits, lint on write
├── .mcp.json                    # MCP server config (Playwright)
├── .gitignore
├── .gitattributes               # Forces LF endings (Dropbox/OneDrive on Windows)
├── .stylelintrc.json
├── eslint.config.mjs
├── build/
│   ├── compile-scss.mjs         # Dart Sass compiler with PostCSS/Autoprefixer
│   ├── bundle-js.mjs            # esbuild JavaScript bundler
│   └── dev-server.mjs           # BrowserSync dev server with file watching
└── themes/starter/
    ├── style.css                # Theme header
    ├── functions.php            # Bootstrap, pattern categories, ACF notice
    ├── theme.json               # Design tokens, v3 schema pinned to WP 7.0
    ├── inc/
    │   ├── theme-setup.php      # Theme supports, editor styles, nav menus
    │   ├── enqueue.php          # Assets, per-block styles, script modules
    │   ├── blocks.php           # Block registration, block styles, core filters
    │   ├── helpers.php          # Utility functions
    │   └── icons.php            # SVG icon system
    ├── styles/                  # Section style variations (auto-discovered)
    ├── templates/               # 7 block templates (index, page, single, etc.)
    ├── parts/                   # Header and footer template parts
    ├── patterns/                # FAQ accordion, page header with breadcrumbs
    ├── blocks/                  # Empty, ready for custom blocks
    └── src/
        ├── scss/                # SCSS architecture, incl. blocks/_accordion
        └── js/                  # Navigation starter script
```

## Build Commands

Run from the `wp-content/` directory:

```bash
npm run dev       # BrowserSync dev server with live reload
npm run build     # Production build (minified)
npm run scss      # Compile SCSS only
npm run js        # Bundle JS only
npm run lint      # Run Stylelint + ESLint
```

## Dependency notes

- **chokidar is pinned to v3 on purpose.** v4 dropped glob support in the `ignored` option. `build/dev-server.mjs` therefore uses a predicate function instead of glob strings, which behaves identically on v3, v4 and v5 — so upgrading is a version bump with no code change. Verify polling still fires on WSL2 before making it.
- **`npm audit` reports high-severity findings in `immutable`**, pulled in transitively by `browser-sync` → `browser-sync-ui`. Do **not** run `npm audit fix --force`: it "resolves" this by installing `browser-sync@1.9.2`, a two-major-version downgrade that breaks the dev server. There is no patched `browser-sync`; 3.0.4 is the latest. These are denial-of-service issues in a dev-only, local-only server that never ships to production. Accept them, or add an `overrides` block pinning `immutable@^5` and test that BrowserSync's UI still works.
- **ESLint is held at v9** while v10 exists. Nothing in the build requires v10 and the flat-config surface changed; bump deliberately, not incidentally.

## Claude Code setup

### Why the permission prompts kept happening

A long `permissions.allow` list producing constant approval prompts has three causes, and the allowlist itself is only one of them.

**1. Compound commands are decomposed.** Claude Code splits any Bash command on `&&`, `||`, `;`, `|`, `|&`, `&` and newlines, then requires *every* segment to match an allow rule independently. `Bash(git status *)` does not permit `git status && npm run build` if any segment falls outside the rules. Approving one interactively saves a separate narrow rule per subcommand — up to five — which is how an allowlist grows to a hundred entries and still misses things.

The fix is counterintuitive: a **broader** allow list, not a longer one. `.claude/settings.json` now allows the `Bash` tool outright and uses short, explicit `ask` and `deny` lists for what actually warrants a pause — destructive `rm`, force-push, hard reset, `wp db`, `sudo`, reading `.env`. Precedence is deny then ask then allow, so the guards win regardless of the broad allow.

For the record, `Bash(npm run *)` and `Bash(npm run:*)` are equivalent — `:*` is sugar for a trailing ` *`. That syntax was never the problem. A colon *mid*-pattern is: in `Bash(git:* push)` the colon is literal and the rule matches nothing.

**2. Workspace trust.** Project `permissions.allow` rules are read but **not applied** until you accept the workspace trust dialog for that folder. Moving the project, using a git worktree, or dismissing the dialog leaves a perfectly correct allowlist completely inert. If prompts persist, check `/status` before editing settings again.

**3. Protected paths.** Writes to `.git`, `.claude`, `.vscode`, `.npmrc`, `.gitconfig` and similar are never pre-approved by `permissions.allow` in any mode — the safety check runs before allow rules are evaluated. Claude editing its own `.claude/settings.json` will always prompt. That is deliberate and cannot be configured away.

Two smaller ones: an environment-variable prefix breaks matching, so `CI=1 npm run build` will not match `Bash(npm run *)`; and `cd` combined with `git` always prompts, because running git in a new directory can execute that directory's hooks.

### Model routing

`.claude/settings.json` sets `sonnet` as the session model with `opus` as an availability fallback. Four subagents in `.claude/agents/` sit on deliberately different tiers:

| Agent | Model | Use |
|---|---|---|
| `wp-scout` | haiku | Read-only search: "where is X", "which files touch Y" |
| `wp-build` | haiku | Running builds and linters, reporting failures |
| `wp-reviewer` | sonnet | Reviewing work against project standards |
| `wp-architect` | opus | Escalation target for hard problems |

**On escalation:** Claude Code has no built-in mechanism for retrying on a stronger model when a cheaper one struggles. `fallbackModel` handles availability errors — overload, rate limits — not "the model got it wrong". So this is a convention rather than a feature: each cheap agent is instructed to reply `ESCALATE: <reason>` rather than guess when a task exceeds it, and `/escalate` packages the problem for `wp-architect` together with what was already ruled out. It works, but it is worth knowing it is a pattern and not a switch.

### Context efficiency

`CLAUDE.md` is deliberately short. The detailed conventions live in `.claude/rules/*.md`, each scoped with a `paths:` glob so it loads only when Claude touches a matching file — PHP standards when editing `.php`, theme.json rules when editing `theme.json`, block markup rules when editing a pattern. Nothing pays context rent while it is irrelevant.

### Hooks

Two hooks in `.claude/hooks/` enforce what documentation can only request:

- **`block-generated-files.sh`** (PreToolUse) refuses edits to `assets/css`, `assets/js`, `node_modules`, `package-lock.json` and `vendor`. Editing compiled CSS instead of the SCSS source is work the next build silently destroys.
- **`lint-changed-file.sh`** (PostToolUse) runs `php -l`, stylelint, eslint or a JSON parse on whatever was just written and feeds failures straight back, so they get fixed in context rather than surfacing at the next build.

Both stay quiet when a linter is not installed, so a fresh clone before `npm install` does not produce a wall of errors. `setup.sh` makes them executable; if you copy the boilerplate around by hand, run `chmod +x .claude/hooks/*.sh`.

### Skills

`/verify-build`, `/new-block`, `/new-pattern` and `/escalate`. `new-block` deliberately opens by trying to talk you out of building a block — with Block Bindings in WordPress 7.0, a large share of what used to need an ACF block no longer does.

Claude is encouraged to expand on this foundation as the project requires.
