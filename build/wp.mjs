#!/usr/bin/env node
/**
 * WP-CLI wrapper for Local (Local by Flywheel) sites on Windows.
 *
 *   node build/wp.mjs <wp args>        e.g. node build/wp.mjs option get home
 *
 * Local keeps PHP and MySQL inside its own install, so a bare `wp` is not on
 * PATH and cannot reach the database. On every run this script:
 *
 *   1. finds the Local site whose folder contains this repo, from
 *      %APPDATA%/Local/sites.json
 *   2. reads the site id, PHP version and current MySQL port (the port can
 *      change when Local restarts, so it is never cached)
 *   3. runs Local's own php.exe with that site's php.ini, pointed at the
 *      right MySQL port, against .tools/wp-cli.phar
 *
 * Install the phar once with `npm run tools:setup`.
 *
 * `wp db query` does not work: it shells out to a mysql client that Local
 * does not put on PATH. Use `wp eval '...$wpdb...'` instead.
 *
 * Overrides, for non-standard layouts:
 *   WP_PATH         WordPress root (the folder that holds wp-config.php)
 *   LOCAL_SITE_ID   site id in sites.json, skips the path match
 */

import { spawnSync } from 'node:child_process';
import { existsSync, readdirSync, readFileSync, realpathSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const phar = join(repoRoot, '.tools', 'wp-cli.phar');

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

if (!existsSync(phar)) fail('.tools/wp-cli.phar is missing. Run: npm run tools:setup');

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
	...process.argv.slice(2),
];

const result = spawnSync(php, args, { stdio: 'inherit' });
if (result.error) fail(result.error.message);
process.exit(result.status ?? 1);
