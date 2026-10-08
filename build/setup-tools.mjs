#!/usr/bin/env node
/**
 * Downloads wp-cli.phar into .tools/ (gitignored). Run once per checkout:
 *
 *   npm run tools:setup
 *
 * This is the one place the project downloads a tool. Tooling lives in the
 * repo, not in a session scratchpad, because scratchpads are wiped between
 * sessions. Use --force to re-download.
 */

import { existsSync, mkdirSync, renameSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const toolsDir = join(repoRoot, '.tools');
const target = join(toolsDir, 'wp-cli.phar');
const url = 'https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar';

if (existsSync(target) && !process.argv.includes('--force')) {
	console.log(`wp-cli.phar already present (${statSync(target).size} bytes). Use --force to re-download.`);
	process.exit(0);
}

mkdirSync(toolsDir, { recursive: true });

const res = await fetch(url, { redirect: 'follow' });
if (!res.ok) {
	console.error(`Download failed: ${res.status} ${res.statusText} (${url})`);
	process.exit(1);
}

const buf = Buffer.from(await res.arrayBuffer());
// A phar starts with a PHP stub; an HTML error page would not.
if (buf.length < 1_000_000 || !buf.subarray(0, 5).toString().startsWith('#!/us')) {
	console.error('Downloaded file does not look like wp-cli.phar. Nothing was written.');
	process.exit(1);
}

const tmp = `${target}.part`;
writeFileSync(tmp, buf);
renameSync(tmp, target);
console.log(`Installed ${target} (${buf.length} bytes)`);
