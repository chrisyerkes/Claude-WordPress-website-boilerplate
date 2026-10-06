#!/usr/bin/env node
/**
 * WCAG 2.2 contrast report for palette colors against white and black.
 *
 * Usage:
 *   node build/contrast.mjs primary=#1a3a5c secondary=#c0392b ...
 *
 * Reports only. A color below 4.5:1 against both white and black cannot carry
 * body text on either background, so it is flagged for decorative or large
 * text only (3:1 is the WCAG floor for large text and non-text UI). Nothing
 * here fails the build.
 */

import { pathToFileURL } from 'node:url';

const channel = (v) => {
	const c = v / 255;
	return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
};

export function luminance(hex) {
	const h = hex.replace('#', '');
	const [ r, g, b ] = [ 0, 2, 4 ].map((i) => channel(parseInt(h.slice(i, i + 2), 16)));
	return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

export function ratio(a, b) {
	const [ hi, lo ] = [ luminance(a), luminance(b) ].sort((x, y) => y - x);
	return (hi + 0.05) / (lo + 0.05);
}

// Per background: a color under 4.5:1 cannot carry body text on it.
const side = (label, r) => {
	const mark = r >= 4.5 ? '' : ' (decorative/large only)';
	return `${label} ${r.toFixed(2).padStart(5)}:1${mark}`;
};

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
	for (const arg of process.argv.slice(2)) {
		const [ name, hex ] = arg.split('=');
		const onWhite = ratio(hex, '#ffffff');
		const onBlack = ratio(hex, '#000000');
		console.log(`  ${name.padEnd(12)} ${hex.padEnd(8)} ${side('on white', onWhite)}   ${side('on black', onBlack)}`);
	}
}
