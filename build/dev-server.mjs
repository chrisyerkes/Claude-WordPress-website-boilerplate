/**
 * Development Server
 *
 * Unified dev server combining SCSS + JS compilation with BrowserSync.
 * Proxies the local WordPress instance and injects CSS changes without
 * full page reloads.
 *
 * Compiles in-process by importing compileAll() and buildAll() directly,
 * which keeps the sass-embedded daemon and esbuild warm across rebuilds.
 * Spawning `node` per save was the single biggest source of latency
 * (~500-1000ms of cold-start overhead per change).
 *
 * Uses chokidar v3 with polling for WSL2 compatibility. Files live on the
 * Windows partition (/mnt/c/) where native inotify events don't fire
 * across the 9P bridge. Watchers target directories (not globs) and
 * filter by extension in callbacks for reliability.
 *
 * chokidar is pinned to v3 deliberately. v4 dropped glob support in the
 * `ignored` option, so the PHP watcher below uses a predicate function
 * rather than glob strings — that form behaves identically on v3, v4 and
 * v5, which makes a future upgrade a version bump with no code change.
 * Verify polling still fires on WSL2 before making that bump.
 *
 * Usage:
 *   node build/dev-server.mjs
 *
 * Configure LOCAL_URL below to match your Local by Flywheel site URL.
 */

import browserSync from 'browser-sync';
import { watch as chokidarWatch } from 'chokidar';
import { basename } from 'path';
import { compileAll } from './compile-scss.mjs';
import { buildAll } from './bundle-js.mjs';

// ── Configuration ──────────────────────────────────────────────────────

// CUSTOMIZE: Set this to your Local by Flywheel site URL.
const LOCAL_URL = 'http://starter.local';

const THEME_DIR = 'themes/starter';
// const PLUGIN_DIR = 'plugins/starter-plugin';

// ── BrowserSync ────────────────────────────────────────────────────────

const bs = browserSync.create();

bs.init( {
	proxy: LOCAL_URL,
	port: 3000,
	ui: { port: 3001 },
	open: false,
	notify: false,
	ghostMode: false,
} );

// ── Polling options ───────────────────────────────────────────────────
//
// WSL2 requires polling when files live on the Windows partition (/mnt/c/).
// Node's fs.watch() does not receive filesystem events across the 9P bridge,
// so chokidar v3's usePolling fallback is essential.
//
// interval: 100  — chokidar polls every 100ms. Slightly higher CPU but the
//                  loop is otherwise idle. Bump to 150 if idle CPU is too high.
// awaitWriteFinish — wait until the file has stopped changing for
//                    stabilityThreshold ms. Prevents firing on a half-written
//                    save (some editors do truncate-then-write).

const pollOpts = {
	ignoreInitial: true,
	usePolling: true,
	interval: 100,
	binaryInterval: 300,
	awaitWriteFinish: {
		stabilityThreshold: 40,
		pollInterval: 20,
	},
};

// In-handler debounce to coalesce bursts of rapid saves. With in-process
// compiles, we no longer wait for Node startup, so 30ms is plenty.
const DEBOUNCE = 30;

let scssDebounce = null;
let jsDebounce = null;

// Paths the PHP/HTML watcher must never fire on. Written as a predicate
// rather than the glob strings chokidar v3 accepted, because v4 removed
// glob support from `ignored` and would have silently matched nothing —
// turning every SCSS save into a full page reload storm.
const IGNORED_PATH = /(^|[/\\])(src|assets|node_modules|\.git)([/\\]|$)/;

// ── Watchers ───────────────────────────────────────────────────────────
//
// Watch directories (not globs) and filter by extension in callbacks.
// Chokidar v3's glob resolution with polling can miss subdirectories;
// watching parent directories and filtering is simpler and more reliable.

// SCSS watcher — CSS injection (no full reload).
const scssWatcher = chokidarWatch(
	[
		`${ THEME_DIR }/src/scss`,
		// `${ PLUGIN_DIR }/src/scss`, // Uncomment when plugin exists.
	],
	pollOpts
);

function handleScssChange( filepath ) {
	if ( ! filepath.endsWith( '.scss' ) ) return;
	clearTimeout( scssDebounce );
	scssDebounce = setTimeout( async () => {
		const start = Date.now();
		console.log( `\n[SCSS] Changed: ${ basename( filepath ) }` );
		try {
			await compileAll();
			console.log( `[SCSS] Done (${ Date.now() - start }ms)` );
			bs.reload( '*.css' );
		} catch ( err ) {
			console.error( '[SCSS] Error:', err.message );
		}
	}, DEBOUNCE );
}

scssWatcher.on( 'change', handleScssChange );
scssWatcher.on( 'add', handleScssChange );

// JS watcher — full reload.
const jsWatcher = chokidarWatch(
	[
		`${ THEME_DIR }/src/js`,
		// `${ PLUGIN_DIR }/src/js`, // Uncomment when plugin exists.
	],
	pollOpts
);

function handleJsChange( filepath ) {
	if ( ! filepath.endsWith( '.js' ) ) return;
	clearTimeout( jsDebounce );
	jsDebounce = setTimeout( async () => {
		const start = Date.now();
		console.log( `\n[JS] Changed: ${ basename( filepath ) }` );
		try {
			await buildAll();
			console.log( `[JS] Done (${ Date.now() - start }ms)` );
			bs.reload();
		} catch ( err ) {
			console.error( '[JS] Error:', err.message );
		}
	}, DEBOUNCE );
}

jsWatcher.on( 'change', handleJsChange );
jsWatcher.on( 'add', handleJsChange );

// PHP + HTML watcher — full reload.
// Watches the theme root but ignores src/ and assets/ (handled above).
// Polling here is less aggressive since PHP/HTML changes don't compile.
const phpWatcher = chokidarWatch(
	[
		`${ THEME_DIR }`,
		// `${ PLUGIN_DIR }`, // Uncomment when plugin exists.
	],
	{
		...pollOpts,
		interval: 500,
		awaitWriteFinish: {
			stabilityThreshold: 150,
			pollInterval: 100,
		},
		ignored: ( watchedPath ) => IGNORED_PATH.test( watchedPath ),
	}
);
phpWatcher.on( 'change', ( filepath ) => {
	if ( ! filepath.endsWith( '.php' ) && ! filepath.endsWith( '.html' ) ) return;
	console.log( '\n[PHP/HTML] Reloading…' );
	bs.reload();
} );

console.log( `\n🚀 Dev server running. Proxying ${ LOCAL_URL } → http://localhost:3000\n` );
