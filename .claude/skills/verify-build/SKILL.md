---
name: verify-build
description: Compile SCSS and JS, run both linters, and report only what failed. Use after a batch of edits, before committing, or when asked whether the project still builds.
argument-hint: "[optional: scss | js | lint]"
allowed-tools: Bash, Read, Grep, Glob
model: haiku
effort: low
---

# Verify the build

Run the project's build and lint pipeline and report the result concisely.

Delegate to the `wp-build` agent when the run is likely to be noisy, so verbose npm output stays out of the main conversation. For a quick single check, run it inline.

## Steps

Run from the project root (`wp-content/`). One command per Bash call — do not chain with `&&`.

1. `npm run scss`
2. `npm run js`
3. `npm run lint`

If `$ARGUMENTS` names a specific stage (`scss`, `js`, or `lint`), run only that one.

## Reporting

- Success: one line. Do not paste build output.
- Failure: the file, the line, the error, and nothing else. Strip npm banners and progress noise.
- If several errors share one cause, say that once instead of listing them all.

## Constraints

- Never run `npm audit fix --force`. It downgrades browser-sync two major versions and breaks the dev server. The `immutable` advisories are dev-only denial-of-service issues and are an accepted risk in this project.
- Never edit anything under `assets/` to make a build pass. That directory is generated.
- If the failure is not a plain syntax or lint error, stop and hand it to the `wp-architect` agent rather than guessing.
