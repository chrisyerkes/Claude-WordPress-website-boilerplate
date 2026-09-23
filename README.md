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

The script needs bash 4+, and Node 20+ and git for the install and first-commit steps. On Windows, run it either inside WSL or natively under Git Bash. Both are tested:

| | WSL (Ubuntu) | Native Windows (Git Bash) |
|---|---|---|
| Terminal | WSL / Ubuntu | **Git Bash**, installed with [Git for Windows](https://git-scm.com/download/win) |
| Node and git | Installed *inside* WSL (e.g. `nvm install 20`) | Windows installers ([nodejs.org](https://nodejs.org), Git for Windows) |
| Path to `wp-content/` | `/mnt/c/Users/you/Local Sites/acme/app/public/wp-content` | `/c/Users/you/Local Sites/acme/app/public/wp-content` |

Open that terminal, `cd` to the `wp-content/` directory (quote the path, since Local puts a space in `Local Sites`), and run:

```bash
cd "/c/Users/you/Local Sites/acme/app/public/wp-content"    # Git Bash
cd "/mnt/c/Users/you/Local Sites/acme/app/public/wp-content" # WSL
./setup.sh
```

macOS and Linux work the same way as WSL. macOS ships bash 3.2, so `brew install bash` first.

**Native Windows notes**

- **Typing `bash` in PowerShell or cmd starts WSL, not Git Bash.** `C:\Windows\System32\bash.exe` is the WSL launcher. Use a Git Bash window, or from PowerShell run `& "C:\Program Files\Git\bin\bash.exe" ./setup.sh`.
- **Pick one environment per project.** `node_modules/` holds platform-specific binaries (sass-embedded, esbuild): an install under WSL gets Linux builds, one under Git Bash gets Windows builds. If you switch, delete `node_modules/` and run `npm install` again.
- **Keep the site path short.** Windows has a 260-character path limit, and `node_modules/` adds about 70 characters. Past the limit the SCSS build fails with `spawn … dart.exe ENOENT` and git fails with `Filename too long`. Setup warns when the path is over 185 characters. `C:\Users\you\Local Sites\…` is well inside the limit unless the client name is very long. Moving the site somewhere shallower fixes both errors. The git error alone can also be fixed with `git config --global core.longpaths true`, as long as the site folder itself is well under 260 characters. Turning on long paths in Windows (as admin) may help other tools, but it has not been tested against the Sass error, so don't count on it for that.
- **Use an NTFS drive.** On exFAT/FAT drives, network shares and RAM disks, git refuses the new repository ("detected dubious ownership"). Setup detects this and prints the `safe.directory` command that fixes it.
- Git for Windows' default `core.autocrlf=true` is fine: `.gitattributes` forces LF for everything the build and scripts read.

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
./setup.sh --answers acme.answers  # Non-interactive: read every answer from a file (below)
./setup.sh --dry-run               # Report what would change without writing anything
./setup.sh --help                  # Usage plus a troubleshooting guide
```

`--dry-run` combines with `--answers`, which makes it a quick way to check a file.

If something goes wrong, the script reports what it was doing, the failing command, and a specific fix, then tells you whether anything had already been written. Run `./setup.sh --help` for the full list of common failures (CRLF line endings from Dropbox, npm EACCES, missing git identity, port conflicts, Node too old, and the Windows-specific ones above).

It offers to delete itself when done, since it's a one-time setup.

#### Non-interactive setup: `--answers`

For scripted or repeated setups, put the answers in a file and pass it with `--answers`. There are no prompts, no terminal is required, and there is no review screen:

```bash
./setup.sh --answers ../acme.answers
```

The file has one `KEY=value` per line. Every key is optional: a missing or empty key gets the same default the prompt would offer, derived the same way (the slug comes from `PROJECT_NAME`, the text domain from the slug, and so on). A complete example, with every key:

```ini
# acme.answers
# Keep this file outside wp-content/, or INIT_GIT will commit it.

# ── Identity ──
PROJECT_NAME=Acme Clinic
# Display name, used verbatim in style.css. Default: PROJECT_NAME
THEME_NAME=Acme Clinic
# Default: PROJECT_NAME as a slug
THEME_SLUG=acme-clinic
# Default: THEME_SLUG
TEXT_DOMAIN=acme-clinic
# Default: PROJECT_NAME with underscores, plus a trailing _
FUNC_PREFIX=acme_clinic_
THEME_DESCRIPTION=A custom WordPress block theme.

# ── Author ──
AUTHOR_NAME=Mops Digital
AUTHOR_URI=https://mopsdigital.com

# ── Local development ──
# Default: http://<THEME_SLUG>.local
LOCAL_URL=http://acme-clinic.local
BROWSERSYNC_PORT=3000

# ── Features ──
USE_ACF=yes
CREATE_PLUGIN=yes
# PLUGIN_SLUG and SCAFFOLD_* are ignored when CREATE_PLUGIN is no.
# Default: <THEME_SLUG>-plugin
PLUGIN_SLUG=acme-clinic-plugin
# bindings | acf | per-component
DATA_STRATEGY=bindings
SCAFFOLD_BINDINGS=yes
SCAFFOLD_ABILITY=no

# ── Brand colors ── blank keeps the boilerplate color
PRIMARY_COLOR=#1a3a5c
SECONDARY_COLOR=#c0392b
TERTIARY_COLOR=#e67e22
# Regenerate primary-dark, primary-light and secondary-dark from the above
DERIVE_SHADES=yes

# ── Layout ──
CONTENT_WIDTH=1170
WIDE_WIDTH=1440

# ── Finishing ── INSTALL_DEPS is skipped automatically when npm is missing
INSTALL_DEPS=yes
INIT_GIT=yes
REMOVE_SCRIPT=no
```

Format rules:

- **Only whole lines starting with `#` are comments.** A `#` later in a line is part of the value, which is what lets `PRIMARY_COLOR=#1a3a5c` work, so put notes on their own lines.
- Whitespace around keys and values is trimmed. A value may be wrapped in matching `"` or `'` quotes.
- Yes/no keys take `y`, `yes`, `true`, `1`, `n`, `no`, `false` or `0`, in any case.
- `DATA_STRATEGY` takes the short tokens `bindings`, `acf` or `per-component`. The prompt's option numbers (`1`–`3`) and full labels are accepted too.
- CRLF line endings (a file saved in Notepad) are fine.
- Unknown keys, repeated keys and lines without `=` are errors, so a typo cannot silently fall back to a default.

Every value goes through the same validators as the prompts, plus the same cross-checks: the theme slug must not already exist or collide with a WordPress name, the plugin directory must not already exist, and the wide width must not be narrower than the content width. All problems are reported together, and **nothing is written** unless the whole file is valid:

```
  ✗  acme.answers: 2 invalid answer(s). Nothing was written.
    THEME_SLUG: Lowercase letters, numbers and hyphens only, e.g. acme-clinic. (value 'Acme Clinic')
    WIDE_WIDTH: Wide width (1200px) is narrower than content width (1440px), which is backwards. (value '1200')
```

An error about a value you didn't set says `derived default '…'`. That means the fix is in the key it was derived from, usually `PROJECT_NAME`.

Once the answers validate, the script prints the resolved values, then one plain line per step as each finishes. There are no colors or progress bars in this mode, even in a terminal, so a calling process can show or parse the lines:

```
[1/13] Renaming themes/starter → themes/acme-clinic ... done (31ms)
[2/13] Rewriting slugs, prefixes and text domains ... done (20 of 63 files changed, 1.9s)
…
[11/13] Installing npm dependencies ... done (272 top-level packages, 8.6s)
[12/13] Running the first build ... done (CSS and JS compiled, 3.0s)
[13/13] Initializing the git repository ... done (branch main, 1 commit, 169ms)
```

Each line matches `^\[(\d+)/(\d+)\] (.+) \.\.\. (done|skipped|warning)(?: \((.*)\))?$`. Exit status: `0` success (possibly with `warning` steps), `1` preflight or runtime failure, `2` bad option or invalid answers file (nothing written).

### 4. Open in your editor

Open the `wp-content/` directory in Windsurf or VS Code, activate Claude Code, and start building. If you set up under WSL, open the folder through the editor's WSL remote so Claude Code runs where `node_modules/` was installed. If you used Git Bash, open it directly. Claude Code on native Windows runs its shell commands and this project's hooks through Git Bash.

**Accept the workspace trust prompt the first time.** Until you do, Claude Code reads `.claude/settings.json` but does not apply its permission rules — which looks exactly like the allowlist being ignored. See [Claude Code setup](#claude-code-setup) below.

### 5. Activate the theme

In WordPress admin, go to Appearance > Themes and activate your new theme.

## What's Included

```
wp-content/
├── setup.sh                     # Project setup, interactive or --answers (delete after use)
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

### What `.claude/settings.json` sets

| Key | Value | Effect |
|---|---|---|
| `model` | `sonnet` | Session model. Subagents pick their own (see [Model routing](#model-routing)). |
| `fallbackModel` | `[ "opus" ]` | Used only when the session model is unavailable (overload, rate limit). |
| `effortLevel` | `medium` | Default reasoning effort. |
| `permissions.defaultMode` | `acceptEdits` | File edits are applied without a prompt. |
| `permissions.allow` | `Bash`, `Read`, `Edit`, `Write`, `Glob`, `Grep`; `WebFetch` for `developer.wordpress.org`, `make.wordpress.org`, `wordpress.org`, `schemas.wp.org`, `www.advancedcustomfields.com`; the Playwright, Figma and Chrome DevTools MCP servers | Broad by design (see below). |
| `permissions.ask` | `rm -r`/`rm -rf`, `wp db`, `wp site`, `wp user delete`, `curl`, `wget`, `git push`, `npm publish`, `npm audit fix --force` | Always prompts, despite the broad allow. |
| `permissions.deny` | `sudo`, `rm -rf /` and `~`, force-push, `git reset --hard`, `git checkout --`, `git clean -f`, `wp db drop`/`reset`, `wp site empty`, and reading `.env*` by any tool or via `cat`/`head`/`tail`/`less`/`more`/`grep`/`sed`/`awk` | Never allowed. |
| `hooks` | `PreToolUse` → `block-generated-files.sh`, `PostToolUse` → `lint-changed-file.sh` | See [Hooks](#hooks). |
| `enableAllProjectMcpServers` | `true` | Starts the servers in `.mcp.json` (Playwright) without asking. |
| `env` | `NODE_ENV=development` | |
| `includeGitInstructions`, `respectGitignore` | `true` | |

Personal overrides go in `.claude/settings.local.json`, which is gitignored.

### Why the permission prompts kept happening

A long `permissions.allow` list producing constant approval prompts has three causes, and the allowlist itself is only one of them.

**1. Compound commands are decomposed.** Claude Code splits any Bash command on `&&`, `||`, `;`, `|`, `|&`, `&` and newlines, then requires *every* segment to match an allow rule independently. `Bash(git status *)` does not permit `git status && npm run build` if any segment falls outside the rules. Approving one interactively saves a separate narrow rule per subcommand — up to five — which is how an allowlist grows to a hundred entries and still misses things.

The fix is counterintuitive: a **broader** allow list, not a longer one. `.claude/settings.json` allows the `Bash` tool outright and uses short, explicit lists for what actually warrants a pause. The `ask` list covers recursive `rm`, `wp db`, `git push`, `curl`/`wget` and similar. The `deny` list covers force-push, hard reset, `git clean -f`, `sudo` and reading `.env`. Precedence is deny, then ask, then allow, so the guards win regardless of the broad allow.

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

Both stay quiet when a linter is not installed, so a fresh clone before `npm install` does not produce a wall of errors.

`settings.json` runs them as `bash "$CLAUDE_PROJECT_DIR/.claude/hooks/<name>.sh"`. The quotes matter because Local's `Local Sites` folder has a space in it. Calling through `bash` means the executable bit doesn't matter, since Dropbox and NTFS don't preserve it. Both hooks convert Windows paths (`C:\…\assets\css\main.css`) to forward slashes before matching, so they behave the same under WSL, macOS and native Windows. This was tested live in Claude Code on native Windows.

### Skills

`/verify-build`, `/new-block`, `/new-pattern` and `/escalate`. `new-block` deliberately opens by trying to talk you out of building a block — with Block Bindings in WordPress 7.0, a large share of what used to need an ACF block no longer does.

Claude is encouraged to expand on this foundation as the project requires.
