/**
 * SCSS Compiler
 *
 * Compiles SCSS entry points to CSS using Dart Sass with PostCSS/Autoprefixer.
 * Supports watch mode with chokidar for WSL2 compatibility.
 *
 * Source maps are always emitted (in dev and production) so DevTools can map
 * compiled CSS back to original SCSS file/line locations.
 *
 * Exports compileAll() so build/dev-server.mjs can call it in-process,
 * keeping the sass-embedded daemon warm across recompiles.
 *
 * Usage:
 *   node build/compile-scss.mjs              # One-shot compile
 *   node build/compile-scss.mjs --watch      # Watch mode
 *   node build/compile-scss.mjs --minify     # Production (compressed)
 */

import * as sass from 'sass-embedded';
import postcss from 'postcss';
import autoprefixer from 'autoprefixer';
import { writeFileSync, mkdirSync } from 'fs';
import { basename, dirname, resolve, relative } from 'path';
import { fileURLToPath } from 'url';
import { watch as chokidarWatch } from 'chokidar';

// ── Configuration ──────────────────────────────────────────────────────
// Add new SCSS entry points here as the project grows.
// Each entry: { input: 'path/to/source.scss', output: 'path/to/output.css' }

const THEME_DIR = 'themes/starter';
// const PLUGIN_DIR = 'plugins/starter-plugin'; // Uncomment when plugin exists.

const entries = [
	{
		input: `${ THEME_DIR }/src/scss/main.scss`,
		output: `${ THEME_DIR }/assets/css/main.css`,
	},
	{
		input: `${ THEME_DIR }/src/scss/editor.scss`,
		output: `${ THEME_DIR }/assets/css/editor.css`,
	},
	// Add more theme entries as needed:
	// {
	// 	input: `${ THEME_DIR }/src/scss/gravity-forms.scss`,
	// 	output: `${ THEME_DIR }/assets/css/gravity-forms.css`,
	// },
	// PLUGIN_SCSS_ENTRY

];

const isWatch = process.argv.includes( '--watch' );
let isMinify = process.argv.includes( '--minify' );

// ── Compile function ───────────────────────────────────────────────────

async function compileEntry( entry ) {
	const startTime = Date.now();

	try {
		const result = sass.compile( entry.input, {
			style: isMinify ? 'compressed' : 'expanded',
			sourceMap: true,
			loadPaths: [ dirname( entry.input ) ],
		} );

		// Run PostCSS with Autoprefixer.
		const processed = await postcss( [ autoprefixer ] ).process( result.css, {
			from: entry.input,
			to: entry.output,
			map: result.sourceMap
				? { prev: JSON.stringify( result.sourceMap ), inline: false }
				: false,
		} );

		// Ensure output directory exists.
		mkdirSync( dirname( entry.output ), { recursive: true } );

		// Write CSS with an explicit sourceMappingURL annotation. PostCSS
		// sometimes omits the annotation depending on how `prev` is passed,
		// so we strip any existing one and append a known-good reference.
		let css = processed.css.replace(
			/\n?\/\*# sourceMappingURL=.*? \*\/\s*$/,
			''
		);
		if ( processed.map ) {
			css += `\n/*# sourceMappingURL=${ basename( entry.output ) }.map */\n`;
		}
		writeFileSync( entry.output, css );

		// Write source map.
		if ( processed.map ) {
			const mapJson = JSON.parse( processed.map.toString() );
			// Rewrite source paths for better DevTools readability.
			mapJson.sources = mapJson.sources.map( ( s ) =>
				relative( dirname( entry.output ), resolve( s ) )
			);
			writeFileSync( entry.output + '.map', JSON.stringify( mapJson ) );
		}

		const elapsed = Date.now() - startTime;
		console.log( `✓ ${ entry.output } (${ elapsed }ms)` );
	} catch ( err ) {
		console.error( `✗ ${ entry.input }: ${ err.message }` );
	}
}

export async function compileAll( { minify = isMinify } = {} ) {
	isMinify = minify;
	console.log( `\nCompiling SCSS${ isMinify ? ' (minified)' : '' }…` );
	await Promise.all( entries.map( compileEntry ) );
}

// ── Execute ────────────────────────────────────────────────────────────
//
// Only auto-run when invoked directly as a script (e.g., `node build/compile-scss.mjs`),
// not when imported by dev-server.mjs. This is the ESM equivalent of
// `if (require.main === module)`.

const isMain =
	process.argv[ 1 ] &&
	resolve( process.argv[ 1 ] ) === fileURLToPath( import.meta.url );

if ( isMain ) {
	await compileAll();
}

if ( isMain && isWatch ) {
	console.log( '\nWatching SCSS for changes…' );

	// Watch directories (not globs) and filter by extension in callbacks.
	// Chokidar v3's glob resolution with polling can miss subdirectories;
	// watching parent directories is simpler and more reliable on WSL2.
	const watchPaths = [
		`${ THEME_DIR }/src/scss`,
		// `${ PLUGIN_DIR }/src/scss`, // Uncomment when plugin exists.
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
		if ( ! filePath.endsWith( '.scss' ) ) return;
		console.log( `\nChanged: ${ filePath }` );
		await compileAll();
	} );
	watcher.on( 'add', async ( filePath ) => {
		if ( ! filePath.endsWith( '.scss' ) ) return;
		console.log( `\nAdded: ${ filePath }` );
		await compileAll();
	} );
}
