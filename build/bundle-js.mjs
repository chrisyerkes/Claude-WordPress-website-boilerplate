/**
 * JavaScript Bundler
 *
 * Bundles JS entry points using esbuild.
 * Supports watch mode with chokidar for WSL2 compatibility.
 *
 * Source maps are always emitted (in dev and production) so DevTools can map
 * compiled JS back to original source file/line locations.
 *
 * Exports buildAll() so build/dev-server.mjs can call it in-process,
 * keeping esbuild warm across rebuilds.
 *
 * Usage:
 *   node build/bundle-js.mjs              # One-shot build
 *   node build/bundle-js.mjs --watch      # Watch mode
 *   node build/bundle-js.mjs --minify     # Production (minified)
 */

import * as esbuild from 'esbuild';
import { resolve } from 'path';
import { fileURLToPath } from 'url';
import { watch as chokidarWatch } from 'chokidar';

// ── Configuration ──────────────────────────────────────────────────────
// Add new JS entry points here as the project grows.
// Each entry: { input: 'path/to/source.js', output: 'path/to/output.js' }

const THEME_DIR = 'themes/starter';
// const PLUGIN_DIR = 'plugins/starter-plugin'; // Uncomment when plugin exists.

const entries = [
	{
		input: `${ THEME_DIR }/src/js/navigation.js`,
		output: `${ THEME_DIR }/assets/js/navigation.js`,
	},
	// Add more entries as needed:
	// {
	// 	input: `${ THEME_DIR }/src/js/accordion.js`,
	// 	output: `${ THEME_DIR }/assets/js/accordion.js`,
	// },
	// PLUGIN_JS_ENTRY

];

const isWatch = process.argv.includes( '--watch' );
let isMinify = process.argv.includes( '--minify' );

// ── Build function ─────────────────────────────────────────────────────

export async function buildAll( { minify = isMinify } = {} ) {
	isMinify = minify;
	const startTime = Date.now();
	console.log( `\nBundling JS${ isMinify ? ' (minified)' : '' }…` );

	const promises = entries.map( async ( entry ) => {
		try {
			await esbuild.build( {
				entryPoints: [ entry.input ],
				outfile: entry.output,
				bundle: true,
				format: 'iife',
				target: [ 'es2020' ],
				minify: isMinify,
				sourcemap: true,
				logLevel: 'warning',
			} );
			console.log( `✓ ${ entry.output }` );
			return true;
		} catch ( err ) {
			console.error( `✗ ${ entry.input }: ${ err.message }` );
			return false;
		}
	} );

	const results = await Promise.all( promises );
	const elapsed = Date.now() - startTime;
	console.log( `Done (${ elapsed }ms)` );
	return results.filter( ( ok ) => ! ok ).length;
}

// ── Execute ────────────────────────────────────────────────────────────
//
// Only auto-run when invoked directly as a script (e.g., `node build/bundle-js.mjs`),
// not when imported by dev-server.mjs.

const isMain =
	process.argv[ 1 ] &&
	resolve( process.argv[ 1 ] ) === fileURLToPath( import.meta.url );

// A failed entry must fail the process, or `npm run build` and setup.sh
// report success with the output missing. Watch mode keeps running.
if ( isMain && ( await buildAll() ) > 0 && ! isWatch ) {
	process.exitCode = 1;
}

if ( isMain && isWatch ) {
	console.log( '\nWatching JS for changes…' );

	// Watch directories (not globs) and filter by extension in callbacks.
	// Chokidar v3's glob resolution with polling can miss subdirectories;
	// watching parent directories is simpler and more reliable on WSL2.
	const watchPaths = [
		`${ THEME_DIR }/src/js`,
		// `${ PLUGIN_DIR }/src/js`, // Uncomment when plugin exists.
	];

	const watcher = chokidarWatch( watchPaths, {
		ignoreInitial: true,
		usePolling: true,
		interval: 300,
		binaryInterval: 300,
		awaitWriteFinish: {
			stabilityThreshold: 150,
			pollInterval: 100,
		},
	} );

	watcher.on( 'change', async ( filePath ) => {
		if ( ! filePath.endsWith( '.js' ) ) return;
		console.log( `\nChanged: ${ filePath }` );
		await buildAll();
	} );
	watcher.on( 'add', async ( filePath ) => {
		if ( ! filePath.endsWith( '.js' ) ) return;
		console.log( `\nAdded: ${ filePath }` );
		await buildAll();
	} );
}
