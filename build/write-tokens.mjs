#!/usr/bin/env node
/**
 * Writes the palette and the schema pin into theme.json and styles/*.json.
 *
 * Usage:
 *   node build/write-tokens.mjs --theme-dir themes/<slug> --schema 7.0 --palette <file>
 *
 * --palette is a file of `slug|#hex|Label` lines, in the order they should
 * appear in the editor. setup.sh builds it from the answers. The palette in
 * theme.json is replaced wholesale, so the file must contain every color the
 * theme should have. `white` and `black` are appended when missing.
 *
 * --schema is the WordPress major.minor the theme targets, for example 7.0.
 * It becomes https://schemas.wp.org/wp/<major.minor>/theme.json.
 *
 * --derive adds primary-dark, primary-light and secondary-dark, computed in
 * HSL from primary and secondary. Dark multiplies lightness by 0.62; light
 * moves it 28% of the way toward white. Hue and saturation are kept, which a
 * straight mix toward black or white does not do. Off unless asked for.
 */

import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

const SLUG_RE = /^[a-z0-9]([a-z0-9-]*[a-z0-9])?$/;
const HEX_RE = /^#[0-9a-f]{6}$/i;

export function parsePaletteLines(text) {
	const entries = [];
	const problems = [];
	text.split(/\r?\n/).forEach((raw, i) => {
		const line = raw.trim();
		if (!line) return;
		const [ slug, hex, ...rest ] = line.split('|');
		const label = rest.join('|').trim();
		if (!SLUG_RE.test(slug ?? '')) problems.push(`line ${i + 1}: bad slug '${slug}'`);
		if (!HEX_RE.test(hex ?? '')) problems.push(`line ${i + 1}: bad hex '${hex}'`);
		if (entries.some((e) => e.slug === slug)) problems.push(`line ${i + 1}: duplicate slug '${slug}'`);
		entries.push({ slug, color: (hex ?? '').toLowerCase(), name: label || slug });
	});
	for (const [ slug, color, name ] of [ [ 'white', '#ffffff', 'White' ], [ 'black', '#000000', 'Black' ] ]) {
		if (!entries.some((e) => e.slug === slug)) entries.push({ slug, color, name });
	}
	return { entries, problems };
}

function setSchema(file, schema) {
	const json = JSON.parse(readFileSync(file, 'utf8'));
	json.$schema = `https://schemas.wp.org/wp/${schema}/theme.json`;
	writeFileSync(file, JSON.stringify(json, null, '\t') + '\n');
}

const toRgb = (h) => [ 1, 3, 5 ].map((i) => parseInt(h.slice(i, i + 2), 16));
const toHex = (rgb) => '#' + rgb.map((v) => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0')).join('');

function rgbToHsl([ r, g, b ]) {
	r /= 255; g /= 255; b /= 255;
	const max = Math.max(r, g, b), min = Math.min(r, g, b);
	const l = (max + min) / 2;
	if (max === min) return [ 0, 0, l ];
	const d = max - min;
	const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
	let h;
	if (max === r) h = (g - b) / d + (g < b ? 6 : 0);
	else if (max === g) h = (b - r) / d + 2;
	else h = (r - g) / d + 4;
	return [ h / 6, s, l ];
}

function hslToRgb([ h, s, l ]) {
	if (s === 0) return [ l * 255, l * 255, l * 255 ];
	const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
	const p = 2 * l - q;
	const f = (t) => {
		if (t < 0) t += 1;
		if (t > 1) t -= 1;
		if (t < 1 / 6) return p + (q - p) * 6 * t;
		if (t < 1 / 2) return q;
		if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
		return p;
	};
	return [ f(h + 1 / 3) * 255, f(h) * 255, f(h - 1 / 3) * 255 ];
}

export function shade(hex, fn) {
	const [ h, s, l ] = rgbToHsl(toRgb(hex));
	return toHex(hslToRgb([ h, s, Math.max(0, Math.min(1, fn(l))) ]));
}

// Derived entries follow the base entry's label, so "Primary · Slate Teal"
// yields "Primary Dark · Slate Teal".
export function withDerived(entries) {
	const out = [ ...entries ];
	const derive = (base, slug, labelWord, fn) => {
		if (!entries.some((e) => e.slug === slug) && base) {
			out.push({ slug, color: shade(base.color, fn), name: base.name.replace(/^\w+/, labelWord) });
		}
	};
	const primary = entries.find((e) => e.slug === 'primary');
	const secondary = entries.find((e) => e.slug === 'secondary');
	derive(primary, 'primary-dark', 'Primary Dark', (l) => l * 0.62);
	derive(primary, 'primary-light', 'Primary Light', (l) => l + (1 - l) * 0.28);
	derive(secondary, 'secondary-dark', 'Secondary Dark', (l) => l * 0.62);
	return out;
}

export function writeTokens(themeDir, schema, inputEntries, { derive = false } = {}) {
	const themeJson = join(themeDir, 'theme.json');
	const json = JSON.parse(readFileSync(themeJson, 'utf8'));
	const entries = derive ? withDerived(inputEntries) : inputEntries;
	json.settings ??= {};
	json.settings.color ??= {};
	json.settings.color.palette = entries.map(({ slug, color, name }) => ({ slug, color, name }));
	writeFileSync(themeJson, JSON.stringify(json, null, '\t') + '\n');
	setSchema(themeJson, schema);

	const stylesDir = join(themeDir, 'styles');
	for (const f of readdirSync(stylesDir).filter((n) => n.endsWith('.json'))) {
		setSchema(join(stylesDir, f), schema);
	}
}

function parseArgs(argv) {
	const out = { themeDir: null, schema: null, palette: null, derive: false };
	for (let i = 0; i < argv.length; i++) {
		const a = argv[i];
		if (a === '--theme-dir') out.themeDir = argv[++i];
		else if (a === '--schema') out.schema = argv[++i];
		else if (a === '--palette') out.palette = argv[++i];
		else if (a === '--derive') out.derive = true;
		else throw new Error(`unknown argument: ${a}`);
	}
	if (!out.themeDir || !out.schema || !out.palette) {
		throw new Error('usage: write-tokens.mjs --theme-dir <dir> --schema <major.minor> --palette <file>');
	}
	if (!/^\d+\.\d+$/.test(out.schema)) throw new Error(`--schema must be major.minor, got '${out.schema}'`);
	return out;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
	try {
		const opts = parseArgs(process.argv.slice(2));
		const { entries, problems } = parsePaletteLines(readFileSync(opts.palette, 'utf8'));
		if (problems.length) {
			for (const p of problems) console.error(p);
			process.exit(2);
		}
		writeTokens(opts.themeDir, opts.schema, entries, { derive: opts.derive });
		const written = opts.derive ? withDerived(entries) : entries;
		console.log(`Palette: ${written.map((e) => e.slug).join(', ')}`);
		console.log(`Schema:  https://schemas.wp.org/wp/${opts.schema}/theme.json`);
	} catch (err) {
		console.error(err.message);
		process.exit(2);
	}
}
