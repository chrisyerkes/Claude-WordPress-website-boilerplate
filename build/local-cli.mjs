#!/usr/bin/env node
/**
 * Locate and run Local's built-in CLI (`localwp`, Local 10.2+).
 *
 *   node build/local-cli.mjs <localwp args>   e.g. node build/local-cli.mjs list --json
 *   node build/local-cli.mjs --check          exit 0 if the Local CLI is installed
 *
 * Docs: https://localwp.com/help-docs/advanced/local-cli/
 * Enable it in Local > Preferences > Advanced > "Install Local CLI" > Apply.
 *
 * Why not call `localwp` directly? On Windows, Local installs a launcher,
 * %APPDATA%/Local/bin/localwp.bat, and that launcher breaks when Local is
 * installed under "C:\Program Files (x86)": the ")" in the path closes one of
 * the batch file's `if (...)` blocks and cmd fails with
 * "\Local\Local.exe was unexpected at this time." Git Bash also can't run a
 * bare `localwp`, because it won't resolve the .bat extension.
 *
 * This script does what the launcher does, without cmd. It reads the paths
 * Local baked into localwp.bat, then runs Local's Electron binary as plain
 * Node (ELECTRON_RUN_AS_NODE=1) against Local's bundled cli.js.
 *
 * Local must be running. If it is closed, the CLI tries to launch it.
 */

import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

/**
 * @returns {{ electron: string, cliJs: string, userData: string } | null}
 */
export function findLocalCli() {
	const appData = process.env.APPDATA;
	if (!appData) return null;

	const userData = join(appData, 'Local');
	const launcher = join(userData, 'bin', 'localwp.bat');
	if (!existsSync(launcher)) return null;

	// Local writes the absolute paths into its copy of the launcher on install.
	const text = readFileSync(launcher, 'utf8');
	const baked = (name) => text.match(new RegExp(`set "${name}=([^"\\r\\n]*)"`))?.[1];

	const programFiles = [process.env['ProgramFiles(x86)'], process.env.ProgramFiles, process.env.LOCALAPPDATA && join(process.env.LOCALAPPDATA, 'Programs')]
		.filter(Boolean)
		.map((dir) => join(dir, 'Local'));

	const electron = [baked('LOCALWP_ELECTRON_BINARY'), ...programFiles.map((d) => join(d, 'Local.exe'))]
		.find((p) => p && !p.startsWith('__') && existsSync(p));
	if (!electron) return null;

	// cli.js lives inside app.asar, which existsSync can't see into, so trust the baked path.
	const bakedCli = baked('LOCALWP_CLI_JS');
	const cliJs = bakedCli && !bakedCli.startsWith('__')
		? bakedCli
		: join(resolve(electron, '..'), 'resources', 'app.asar', 'cli', 'cli.js');

	return { electron, cliJs, userData };
}

/**
 * Run a localwp command. Returns the child's exit status.
 * @param {string[]} args
 * @param {{ electron: string, cliJs: string, userData: string }} cli
 */
export function runLocalCli(args, cli) {
	const result = spawnSync(cli.electron, ['--no-deprecation', cli.cliJs, ...args], {
		stdio: 'inherit',
		env: { ...process.env, ELECTRON_RUN_AS_NODE: '1', LOCALWP_USER_DATA_PATH: cli.userData },
	});
	if (result.error) {
		console.error(`local-cli.mjs: ${result.error.message}`);
		return 1;
	}
	return result.status ?? 1;
}

// Run directly: forward the arguments to localwp.
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
	const cli = findLocalCli();
	if (process.argv[2] === '--check') process.exit(cli ? 0 : 1);
	if (!cli) {
		console.error('local-cli.mjs: Local CLI not found. Needs Local 10.2+, with Preferences > Advanced > "Install Local CLI" switched on.');
		process.exit(1);
	}
	process.exit(runLocalCli(process.argv.slice(2), cli));
}
