#!/usr/bin/env node
/**
 * Installs one locally hosted font for a theme role (heading or body).
 *
 * Usage:
 *   node build/install-fonts.mjs --theme-dir themes/<slug> --role heading \
 *     --package @fontsource-variable/fraunces --fallback "Georgia, serif"
 *
 * What it does:
 *   1. `npm pack <package>` into a temp directory. npm is used because it is
 *      already a requirement of the build, and curl/wget are blocked by the
 *      project's Claude Code permissions.
 *   2. Extracts the tarball with `tar`, which ships with Windows 10+ and Git.
 *   3. Copies the Latin woff2 files (wght and opsz axes), plus the package LICENSE as
 *      OFL.txt, into <theme>/assets/fonts/<font>/.
 *   4. Reads the @font-face rules from the package's index.css, so the weight
 *      range comes from the package rather than from memory, and writes a
 *      fontFamilies entry with the role as its slug.
 *
 * Only the wght (or static) Latin face is registered, once per style. Variable
 * fonts with an optical-size axis also ship an opsz file. It is copied but not
 * registered, so the browser's automatic optical sizing applies.
 */

import { execSync, spawnSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, join } from 'node:path';
import { pathToFileURL } from 'node:url';

const ROLES = [ 'heading', 'body' ];

// Fontsource labels each @font-face with a comment such as
// /* fraunces-latin-wght-normal */. "latin" is the subset; the middle segment
// is the variation axis (wght, opsz, wonk …) and is absent for static fonts.
const FACE_RE = /\/\*\s*[a-z0-9-]+-latin(?:-([a-z]+))?-(normal|italic)\s*\*\/\s*@font-face\s*\{([^}]*)\}/g;

export function parseLatinFaces(css) {
	const faces = [];
	for (const m of css.matchAll(FACE_RE)) {
		const [ , axis, style, body ] = m;
		const get = (prop) => {
			const hit = body.match(new RegExp(`${prop}:\\s*([^;]+);`));
			return hit ? hit[1].trim().replace(/^['"]|['"]$/g, '') : null;
		};
		const src = body.match(/url\(\s*['"]?\.\/(files\/[^'")]+)['"]?\s*\)/);
		if (!src) continue;
		faces.push({
			family: get('font-family'),
			style: get('font-style') ?? style,
			weight: get('font-weight') ?? '400',
			axis: axis ?? null,
			file: src[1],
		});
	}
	return faces;
}

function packAndExtract(pkg, workDir) {
	// The package name is validated in parseArgs, so the shell string is safe.
	// A shell is needed on Windows, where npm is npm.cmd.
	const filename = execSync(`npm pack ${pkg} --pack-destination "${workDir}" --silent`, {
		cwd: workDir,
		encoding: 'utf8',
		shell: true,
	}).trim().split(/\r?\n/).pop();
	// Relative names only: GNU tar reads a drive letter (C:) as a remote host.
	const extract = spawnSync('tar', [ '-xzf', filename ], { cwd: workDir, encoding: 'utf8' });
	if (extract.status !== 0) throw new Error(`tar failed: ${extract.stderr || extract.stdout}`);
	return join(workDir, 'package');
}

function install({ themeDir, role, pkg, fallback }) {
	if (!ROLES.includes(role)) throw new Error(`--role must be one of ${ROLES.join(', ')}`);
	const fontName = basename(pkg);
	const work = mkdtempSync(join(tmpdir(), 'font-'));
	try {
		const pkgDir = packAndExtract(pkg, work);
		// index.css holds the wght normal faces; wght-italic.css the italic ones.
		const css = ['index.css', 'wght-italic.css']
			.filter((name) => existsSync(join(pkgDir, name)))
			.map((name) => readFileSync(join(pkgDir, name), 'utf8'))
			.join('\n');
		const latin = parseLatinFaces(css);
		if (latin.length === 0) throw new Error(`no latin @font-face rules found in ${pkg}/index.css`);

		const outDir = join(themeDir, 'assets', 'fonts', fontName);
		mkdirSync(outDir, { recursive: true });

		// Latin only (not Latin Extended), and only the wght and opsz axes. The
		// others (wonk, soft, standard, full) are rarely wanted and add weight.
		const latinFiles = readdirSync(join(pkgDir, 'files'))
			.filter((f) => /-latin-(?:(?:wght|opsz)-)?(?:normal|italic)\.woff2$/.test(f));
		for (const f of latinFiles) copyFileSync(join(pkgDir, 'files', f), join(outDir, f));

		const license = join(pkgDir, 'LICENSE');
		if (existsSync(license)) copyFileSync(license, join(outDir, 'OFL.txt'));

		const seen = new Set();
		const fontFace = [];
		for (const face of latin.filter((f) => f.axis === null || f.axis === 'wght')) {
			const key = `${face.style}|${face.weight}`;
			if (seen.has(key)) continue;
			seen.add(key);
			fontFace.push({
				fontFamily: face.family,
				fontStyle: face.style,
				fontWeight: face.weight,
				fontDisplay: 'swap',
				src: [ `file:./assets/fonts/${fontName}/${basename(face.file)}` ],
			});
		}
		if (fontFace.length === 0) throw new Error(`no wght or static Latin face in ${pkg}`);

		const family = fontFace[0].fontFamily;
		const entry = {
			fontFamily: `'${family}', ${fallback}`,
			name: role === 'heading' ? 'Heading' : 'Body',
			slug: role,
			fontFace,
		};

		const themeJson = join(themeDir, 'theme.json');
		const json = JSON.parse(readFileSync(themeJson, 'utf8'));
		json.settings.typography ??= {};
		const families = json.settings.typography.fontFamilies ?? [];
		const idx = families.findIndex((f) => f.slug === role);
		if (idx >= 0) families[idx] = entry;
		else families.push(entry);
		json.settings.typography.fontFamilies = families;
		writeFileSync(themeJson, JSON.stringify(json, null, '\t') + '\n');

		const weights = [ ...new Set(fontFace.map((f) => f.fontWeight)) ].join(', ');
		return { family, files: latinFiles.length, faces: fontFace.length, weights };
	} finally {
		rmSync(work, { recursive: true, force: true });
	}
}

function parseArgs(argv) {
	const out = { themeDir: null, role: null, pkg: null, fallback: 'sans-serif' };
	for (let i = 0; i < argv.length; i++) {
		const a = argv[i];
		if (a === '--theme-dir') out.themeDir = argv[++i];
		else if (a === '--role') out.role = argv[++i];
		else if (a === '--package') out.pkg = argv[++i];
		else if (a === '--fallback') out.fallback = argv[++i];
		else throw new Error(`unknown argument: ${a}`);
	}
	if (!out.themeDir || !out.role || !out.pkg) {
		throw new Error('usage: install-fonts.mjs --theme-dir <dir> --role <heading|body> --package <npm name> [--fallback <stack>]');
	}
	if (!/^@fontsource-variable\/[a-z0-9-]+$/.test(out.pkg)) {
		throw new Error(`--package must look like @fontsource-variable/<font>, got '${out.pkg}'`);
	}
	return out;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
	try {
		const opts = parseArgs(process.argv.slice(2));
		const r = install({ themeDir: opts.themeDir, role: opts.role, pkg: opts.pkg, fallback: opts.fallback });
		console.log(`${opts.role}: ${r.family} · ${r.files} Latin files · ${r.faces} faces · weights ${r.weights}`);
	} catch (err) {
		console.error(err.message);
		process.exit(2);
	}
}
