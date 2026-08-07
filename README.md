# WordPress Block Theme Boilerplate

A copy-paste-and-go WordPress project template optimized for Claude Code. Drop it into a Local by Flywheel site, run the setup script, and start building.

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

Open the `wp-content/` directory in Windsurf (or VS Code) via WSL, activate Claude Code, and start building. The `.claude/settings.json` has pre-approved permissions for all the common build, git, and file operations so Claude can work autonomously.

### 5. Activate the theme

In WordPress admin, go to Appearance > Themes and activate your new theme.

## What's Included

```
wp-content/
├── setup.sh                     # Interactive project setup (delete after use)
├── CLAUDE.md                    # Claude Code instructions and coding standards
├── package.json                 # npm build scripts
├── .claude/settings.json        # Pre-approved permissions for Claude Code
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
    ├── functions.php            # Bootstrap, ACF block registration, block styles
    ├── theme.json               # Design tokens, typography, colors, spacing
    ├── inc/
    │   ├── theme-setup.php      # Theme supports, nav menus, image sizes
    │   ├── enqueue.php          # Asset enqueueing with conditional loading
    │   ├── helpers.php          # Utility functions
    │   └── icons.php            # SVG icon system
    ├── templates/               # 7 block templates (index, page, single, etc.)
    ├── parts/                   # Header and footer template parts
    ├── patterns/                # Empty, ready for block patterns
    ├── blocks/                  # Empty, ready for ACF blocks
    └── src/
        ├── scss/                # Full SCSS architecture (14 partials)
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

## For Claude Code

The `CLAUDE.md` file contains everything Claude needs: architecture decisions, coding standards, build system docs, common task checklists, and the theme-plugin separation principle. The `.claude/settings.json` pre-approves npm, git, file, and PHP lint commands so Claude can work without excessive permission prompts.

Claude is encouraged to expand on this foundation as the project requires.
