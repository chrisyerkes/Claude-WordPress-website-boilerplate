#!/usr/bin/env node
/**
 * Fluid and fixed type and spacing scales for theme.json.
 *
 * Every size is defined once, here, as a min and max in px. The scale is then
 * written into theme.json as two labelled sets:
 *
 *   Fluid  — slugs that scale between the viewport bounds. Font sizes use
 *            { min, max } in rem and let WordPress compute the clamp() from
 *            settings.typography.fluid. Spacing has no such computation in
 *            WordPress, so the clamp() expression is written here directly.
 *   Fixed  — one px value per slug, for places where a size must not move.
 *
 * Usage:
 *   node build/fluid-clamp.mjs                       Print the scale
 *   node build/fluid-clamp.mjs --write <theme.json>  Rewrite the fluid and
 *       [--vmin 375] [--vmax 1440]                   fixed presets in place
 *
 * Fluid spacing slugs (xs … 3-xl) are kept from the original boilerplate so
 * templates and patterns that reference them do not break. Change a size by
 * editing the table below, then run --write (setup.sh does this for you).
 */

import { readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

// Font sizes: [slug, label, minPx, maxPx]. Sizes are px at the viewport bounds.
export const FLUID_FONT_SIZES = [
	[ 'small', 'Small', 14, 15 ],
	[ 'medium', 'Medium', 16, 18 ],
	[ 'large', 'Large', 20, 22 ],
	[ 'x-large', 'X-Large', 24, 28 ],
	[ 'xx-large', 'XX-Large', 28, 34 ],
	[ 'huge', 'Huge', 34, 44 ],
	[ 'gigantic', 'Gigantic', 42, 60 ],
	[ 'colossal', 'Colossal', 52, 76 ],
];

export const FIXED_FONT_SIZES = [ 14, 16, 18, 20, 24, 28, 32, 40, 48, 60 ];

// Spacing: [slug, label, minPx, maxPx].
export const FLUID_SPACING = [
	[ 'xs', 'XS', 8, 12 ],
	[ 's', 'S', 12, 20 ],
	[ 'm', 'M', 16, 32 ],
	[ 'l', 'L', 24, 48 ],
	[ 'xl', 'XL', 40, 72 ],
	[ '2-xl', '2XL', 56, 96 ],
	[ '3-xl', '3XL', 80, 128 ],
];

export const FIXED_SPACING = [ 4, 8, 12, 16, 24, 32, 48, 64, 96 ];

export const DEFAULT_VIEWPORT = { min: 375, max: 1440 };
export const MIN_FONT_SIZE_PX = 14;
export const ROOT_PX = 16;

const round = (n) => Math.round(n * 10000) / 10000;

// Linear interpolation between minPx and maxPx across the viewport range,
// returned as clamp(). Lengths are emitted in rem so they respect user
// font-size preferences; the viewport bounds are px because media queries
// and the preferred value are both viewport-relative.
export function clamp(minPx, maxPx, vmin = DEFAULT_VIEWPORT.min, vmax = DEFAULT_VIEWPORT.max) {
	if (vmax <= vmin) throw new Error(`viewport max (${vmax}) must be greater than min (${vmin})`);
	const slope = (maxPx - minPx) / (vmax - vmin);          // px per px of viewport
	const intercept = minPx - slope * vmin;                   // px at zero viewport
	const preferred = `${round(slope * 100)}vw${intercept >= 0 ? ' + ' : ' - '}${round(Math.abs(intercept) / ROOT_PX)}rem`;
	return `clamp(${round(minPx / ROOT_PX)}rem, ${preferred}, ${round(maxPx / ROOT_PX)}rem)`;
}

const rem = (px) => `${round(px / ROOT_PX)}rem`;

export function fluidSpacingPresets(vmin, vmax) {
	return FLUID_SPACING.map(([ slug, label, min, max ]) => ({
		slug,
		size: clamp(min, max, vmin, vmax),
		name: `Fluid · ${label} (${min} → ${max}px)`,
	}));
}

export function fixedSpacingPresets() {
	return FIXED_SPACING.map((px) => ({ slug: `fixed-${px}`, size: `${px}px`, name: `Fixed · ${px}px` }));
}

export function fontSizePresets() {
	const fluid = FLUID_FONT_SIZES.map(([ slug, label, min, max ]) => ({
		slug,
		size: rem(max),
		name: `Fluid · ${label} (${min} → ${max}px)`,
		fluid: { min: rem(min), max: rem(max) },
	}));
	const fixed = FIXED_FONT_SIZES.map((px) => ({
		slug: `fixed-${px}`,
		size: `${px}px`,
		name: `Fixed · ${px}px`,
		fluid: false,
	}));
	return [ ...fluid, ...fixed ];
}

function writeScale(file, vmin, vmax) {
	const json = JSON.parse(readFileSync(file, 'utf8'));
	const settings = json.settings ?? (json.settings = {});
	settings.typography ??= {};
	settings.spacing ??= {};

	settings.typography.fluid = {
		minViewportWidth: `${vmin}px`,
		maxViewportWidth: `${vmax}px`,
		minFontSize: `${MIN_FONT_SIZE_PX}px`,
	};
	settings.typography.defaultFontSizes = false;
	settings.typography.fontSizes = fontSizePresets();

	settings.spacing.defaultSpacingSizes = false;
	settings.spacing.spacingScale = { steps: 0 };
	settings.spacing.spacingSizes = [
		...fluidSpacingPresets(vmin, vmax),
		...fixedSpacingPresets(),
	];

	writeFileSync(file, JSON.stringify(json, null, '\t') + '\n');
}

function parseArgs(argv) {
	const out = { write: null, vmin: DEFAULT_VIEWPORT.min, vmax: DEFAULT_VIEWPORT.max };
	for (let i = 0; i < argv.length; i++) {
		const a = argv[i];
		if (a === '--write') out.write = argv[++i];
		else if (a === '--vmin') out.vmin = Number(argv[++i]);
		else if (a === '--vmax') out.vmax = Number(argv[++i]);
		else throw new Error(`unknown argument: ${a}`);
	}
	if (!(out.vmin > 0 && out.vmax > out.vmin)) throw new Error('need 0 < --vmin < --vmax');
	return out;
}

function printScale(vmin, vmax) {
	console.log(`Viewport ${vmin}px → ${vmax}px`);
	console.log('\nFont sizes');
	for (const p of fontSizePresets()) console.log(`  ${p.slug.padEnd(12)} ${p.size.padEnd(10)} ${p.name}`);
	console.log('\nSpacing');
	for (const p of [ ...fluidSpacingPresets(vmin, vmax), ...fixedSpacingPresets() ]) {
		console.log(`  ${p.slug.padEnd(12)} ${p.size.padEnd(10)} ${p.name}`);
	}
}

// Run only when executed directly, not when imported by another script.
if (process.argv[1] && import.meta.url === new URL(`file://${process.argv[1].replace(/\\/g, '/')}`).href) {
	try {
		const opts = parseArgs(process.argv.slice(2));
		if (opts.write) {
			writeScale(opts.write, opts.vmin, opts.vmax);
			console.log(`Wrote fluid and fixed scale to ${opts.write} (${opts.vmin}px → ${opts.vmax}px)`);
		} else {
			printScale(opts.vmin, opts.vmax);
		}
	} catch (err) {
		console.error(err.message);
		process.exit(2);
	}
}
