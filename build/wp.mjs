#!/usr/bin/env node
/**
 * WP-CLI wrapper for Local (Local by Flywheel) sites on Windows.
 *
 *   node build/wp.mjs <wp args>        e.g. node build/wp.mjs option get home
 *
 * Local keeps PHP and MySQL inside its own install, so a bare `wp` is not on
 * PATH and cannot reach the database. On every run this script finds the
 * Local site whose folder contains this repo, from %APPDATA%/Local/sites.json,
 * then runs WP-CLI against it one of two ways:
 *
 *   1. Local CLI (preferred). Local 10.2+ ships `localwp cli <site> -- <args>`
 *      (https://localwp.com/help-docs/advanced/local-cli/). Local supplies PHP,
 *      the MySQL port and WP-CLI itself, so nothing is downloaded. Enable it in
 *      Local > Preferences > Advanced > "Install Local CLI". See
 *      build/local-cli.mjs for why this does not call localwp.bat.
 *
 *   2. Bundled phar (fallback). Runs Local's own php.exe with the site's
 *      php.ini, pointed at the current MySQL port, against .tools/wp-cli.phar.
 *      The port changes when Local restarts, so it is read on every run.
 *      Install the phar once with `npm run tools:setup`.
 *
 * `wp db query` does not work either way: it shells out to a mysql client
 * that cannot reach Local's MySQL. Use `wp eval '...$wpdb...'` instead.
 *
 * Overrides, for non-standard layouts:
 *   WP_PATH         WordPress root (the folder that holds wp-config.php).
 *                   Forces the phar route, since the Local CLI always uses
 *                   the site's own web root.
 *   LOCAL_SITE_ID   site id in sites.json, skips the path match
 *   WP_MJS_PHAR=1   use the phar even when the Local CLI is installed
 */

import { spawnSync } from 'node:child_process';
import { existsSync, readdirSync, readFileSync, realpathSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { findLocalCli, runLocalCli } from './local-cli.mjs';

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const phar = join(repoRoot, '.tools', 'wp-cli.phar');
const wpArgs = process.argv.slice(2);

function fail(message) {
	console.error(`wp.mjs: ${message}`);
	process.exit(1);
}

/** Normalise a path for comparison: absolute, forward slashes, lower case. */
function norm(p) {
	let real = resolve(p);
	try {
		real = realpathSync(real);
	} catch {
		// A site folder that no longer exists still compares fine as written.
	}
	return real.split(sep).join('/').replace(/\/+$/, '').toLowerCase();
}

function expandHome(p) {
	return p.startsWith('~') ? join(homedir(), p.slice(1)) : p;
}

const appData = process.env.APPDATA;
if (!appData) fail('APPDATA is not set. This wrapper is for Local on Windows.');

const sitesFile = join(appData, 'Local', 'sites.json');
if (!existsSync(sitesFile)) fail(`${sitesFile} not found. Is Local installed?`);

let sites;
try {
	sites = JSON.parse(readFileSync(sitesFile, 'utf8'));
} catch (err) {
	fail(`could not parse ${sitesFile}: ${err.message}`);
}

// Find the site: by id override, otherwise the one whose folder contains the repo.
const here = norm(repoRoot);
let id = process.env.LOCAL_SITE_ID || null;
if (!id) {
	let best = null;
	for (const [key, site] of Object.entries(sites)) {
		if (!site.path) continue;
		const sitePath = norm(expandHome(site.path));
		if (here === sitePath || here.startsWith(`${sitePath}/`)) {
			if (!best || sitePath.length > best.len) best = { key, len: sitePath.length };
		}
	}
	id = best?.key ?? null;
}
const site = id ? sites[id] : null;
if (!site) fail(`no Local site in sites.json contains ${repoRoot}. Set LOCAL_SITE_ID to override.`);

// Route 1: Local CLI.
const localCli = process.env.WP_PATH || process.env.WP_MJS_PHAR === '1' ? null : findLocalCli();
if (localCli) {
	process.exit(runLocalCli(['cli', id, '--no-progress', '--', ...wpArgs], localCli));
}

// Route 2: Local's php.exe + .tools/wp-cli.phar.
if (!existsSync(phar)) {
	fail('no WP-CLI available. Either enable the Local CLI (Local 10.2+: Preferences > Advanced > "Install Local CLI"), or run: npm run tools:setup');
}

const phpVersion = site.services?.php?.version;
const mysqlPort = site.services?.mysql?.ports?.MYSQL?.[0];
if (!phpVersion) fail(`site ${id} has no services.php.version in sites.json.`);
if (!mysqlPort) fail(`site ${id} has no services.mysql.ports.MYSQL[0]. Start the site in Local.`);

// Local installs PHP as lightning-services/php-<version>+<build>/bin/win64/php.exe.
const servicesDir = join(appData, 'Local', 'lightning-services');
const phpDir = existsSync(servicesDir)
	? readdirSync(servicesDir)
		.filter((d) => d.startsWith(`php-${phpVersion}+`))
		.sort()
		.pop()
	: null;
if (!phpDir) fail(`php-${phpVersion}+* not found in ${servicesDir}.`);

const php = join(servicesDir, phpDir, 'bin', 'win64', 'php.exe');
const ini = join(appData, 'Local', 'run', id, 'conf', 'php', 'php.ini');
if (!existsSync(php)) fail(`${php} not found.`);
if (!existsSync(ini)) fail(`${ini} not found. Start the site in Local so it writes its config.`);

// WordPress root: the folder that holds wp-config.php. The repo is wp-content/.
const wpPath = process.env.WP_PATH
	? resolve(process.env.WP_PATH)
	: existsSync(join(repoRoot, '..', 'wp-config.php'))
		? resolve(repoRoot, '..')
		: join(expandHome(site.path), 'app', 'public');
if (!existsSync(join(wpPath, 'wp-config.php'))) {
	fail(`no wp-config.php in ${wpPath}. Set WP_PATH to the WordPress root.`);
}

const args = [
	'-c', ini,
	'-d', 'mysqli.default_host=127.0.0.1',
	'-d', `mysqli.default_port=${mysqlPort}`,
	phar,
	`--path=${wpPath}`,
	...wpArgs,
];

const result = spawnSync(php, args, { stdio: 'inherit' });
if (result.error) fail(result.error.message);
process.exit(result.status ?? 1);
