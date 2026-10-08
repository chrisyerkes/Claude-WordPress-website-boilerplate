#!/usr/bin/env node
/**
 * Validates theme.json and styles/*.json against the vendored WordPress 7.1
 * schema (build/schema/theme-7.1.json).
 *
 *   npm run validate                        every themes/<slug>
 *   node build/validate-theme-json.mjs <theme-dir>
 *
 * The schema is vendored so validation works offline and does not depend on
 * schemas.wp.org. The authority for what shipped WordPress accepts is still
 * wp-includes/class-wp-theme-json.php; this catches typos and wrong types.
 * Keys that are new in 7.1 validate here even if the pinned release is older.
 */

import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import Ajv from 'ajv';

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const schema = JSON.parse(readFileSync(join(repoRoot, 'build', 'schema', 'theme-7.1.json'), 'utf8'));

const ajv = new Ajv({ allErrors: true, strict: false });
const validate = ajv.compile(schema);

const arg = process.argv[2];
const themeDirs = arg
	? [resolve(arg)]
	: readdirSync(join(repoRoot, 'themes'), { withFileTypes: true })
		.filter((d) => d.isDirectory() && existsSync(join(repoRoot, 'themes', d.name, 'theme.json')))
		.map((d) => join(repoRoot, 'themes', d.name));

if (themeDirs.length === 0) {
	console.error('No theme with a theme.json found.');
	process.exit(1);
}

const files = [];
for (const dir of themeDirs) {
	files.push(join(dir, 'theme.json'));
	const stylesDir = join(dir, 'styles');
	if (existsSync(stylesDir)) {
		for (const f of readdirSync(stylesDir).filter((n) => n.endsWith('.json'))) {
			files.push(join(stylesDir, f));
		}
	}
}

// Deliberate departures from the schema. Core accepts these.
// steps: 0 turns off the generated spacing scale (see .claude/rules/theme-json.md),
// but the published schema says minimum 1.
const KNOWN = [{ path: '/settings/spacing/spacingScale/steps', keyword: 'minimum' }];
const isKnown = (e) => KNOWN.some((k) => k.path === e.instancePath && k.keyword === e.keyword);

let failed = 0;
for (const file of files) {
	const name = relative(repoRoot, file);
	let json;
	try {
		json = JSON.parse(readFileSync(file, 'utf8'));
	} catch (err) {
		console.error(`FAIL ${name}: invalid JSON: ${err.message}`);
		failed++;
		continue;
	}
	const errors = validate(json) ? [] : validate.errors.filter((e) => !isKnown(e));
	if (errors.length === 0) {
		console.log(`ok   ${name}`);
	} else {
		failed++;
		console.error(`FAIL ${name}`);
		for (const e of errors) {
			console.error(`       ${e.instancePath || '/'} ${e.message}${e.params?.additionalProperty ? ` (${e.params.additionalProperty})` : ''}`);
		}
	}
}

process.exit(failed ? 1 : 0);
