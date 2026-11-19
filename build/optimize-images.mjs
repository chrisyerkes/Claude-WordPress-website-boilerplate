#!/usr/bin/env node
/**
 * Optimize images for the theme: every raster gets a fully optimized
 * JPG/PNG fallback plus a WebP sibling, and every SVG goes through SVGO.
 *
 *   node build/optimize-images.mjs <input...> --out <dir> [--width <px>] [--name <basename>]
 *
 *   --out    Destination directory (created if missing).
 *   --width  Resize to this pixel width before encoding. Use 2x the CSS
 *            display width, so images stay sharp on retina screens.
 *   --name   Output basename, for a single input. Defaults to the input's.
 *
 * Output for photo.jpg  -> photo.jpg (mozjpeg, progressive) + photo.webp
 * Output for logo.png   -> logo.png  (palette-quantized, max zlib) + logo.webp
 * Output for icon.svg   -> icon.svg  (SVGO, viewBox kept)
 *
 * Use this for anything downloaded from Figma or supplied as a raw asset
 * before it goes into themes/<slug>/assets/. Media Library uploads are
 * handled at upload time by the companion plugin instead.
 *
 * Cross-platform: Node + sharp (prebuilt Windows binaries) + svgo. No
 * external binaries.
 */

import { readFile, writeFile, mkdir, stat, unlink } from 'node:fs/promises';
import { basename, extname, join, resolve } from 'node:path';
import sharp from 'sharp';
import { optimize } from 'svgo';

const args = process.argv.slice( 2 );
const inputs = [];
const opts = { out: null, width: null, name: null };

for ( let i = 0; i < args.length; i++ ) {
	const arg = args[ i ];
	if ( arg === '--out' ) {
		opts.out = args[ ++i ];
	} else if ( arg === '--width' ) {
		opts.width = parseInt( args[ ++i ], 10 );
	} else if ( arg === '--name' ) {
		opts.name = args[ ++i ];
	} else if ( arg === '--help' || arg === '-h' ) {
		console.log( 'Usage: node build/optimize-images.mjs <input...> --out <dir> [--width <px>] [--name <basename>]' );
		process.exit( 0 );
	} else {
		inputs.push( arg );
	}
}

if ( ! inputs.length || ! opts.out ) {
	console.error( 'Usage: node build/optimize-images.mjs <input...> --out <dir> [--width <px>] [--name <basename>]' );
	process.exit( 1 );
}

if ( opts.name && inputs.length > 1 ) {
	console.error( '--name only works with a single input.' );
	process.exit( 1 );
}

const JPEG = { quality: 80, mozjpeg: true, progressive: true };
const PNG = { compressionLevel: 9, palette: true, quality: 90, effort: 10 };
const WEBP_PHOTO = { quality: 80, effort: 6, smartSubsample: true };
const WEBP_GRAPHIC = { quality: 90, alphaQuality: 100, effort: 6 };

const kb = ( bytes ) => `${ ( bytes / 1024 ).toFixed( 1 ) } KB`;

async function optimizeSvg( input, outBase ) {
	const source = await readFile( input, 'utf8' );
	const result = optimize( source, {
		multipass: true,
		// SVGO 4's preset-default keeps viewBox, so icons still scale with CSS.
		plugins: [
			'preset-default',
			// Strip anything executable, in case the source was not ours.
			'removeScripts',
		],
	} );
	const out = `${ outBase }.svg`;
	await writeFile( out, result.data );
	return [ out ];
}

async function optimizeRaster( input, outBase ) {
	const image = sharp( input, { failOn: 'error' } ).rotate(); // apply EXIF orientation, then strip metadata
	const meta = await image.metadata();
	const resized = opts.width && meta.width > opts.width
		? image.resize( { width: opts.width, withoutEnlargement: true } )
		: image;

	// Photos (no alpha, or a JPEG source) become JPEG; graphics stay PNG.
	const isPhoto = meta.format === 'jpeg' || ! meta.hasAlpha;
	const written = [];

	if ( isPhoto ) {
		const out = `${ outBase }.jpg`;
		await resized.clone().jpeg( JPEG ).toFile( out );
		written.push( out );
		const webp = `${ outBase }.webp`;
		await resized.clone().webp( WEBP_PHOTO ).toFile( webp );
		written.push( webp );
	} else {
		const out = `${ outBase }.png`;
		await resized.clone().png( PNG ).toFile( out );
		written.push( out );
		const webp = `${ outBase }.webp`;
		await resized.clone().webp( WEBP_GRAPHIC ).toFile( webp );
		written.push( webp );
	}

	// A WebP that is not smaller than its fallback is pointless to serve (flat
	// graphics often quantize better as PNG). Drop it; the theme's <picture>
	// helper only emits a WebP source when the file exists.
	const [ fallback, webpFile ] = written;
	if ( ( await stat( webpFile ) ).size >= ( await stat( fallback ) ).size ) {
		await unlink( webpFile );
		console.log( `${ basename( webpFile ) } dropped: not smaller than ${ basename( fallback ) }` );
		return [ fallback ];
	}

	return written;
}

await mkdir( resolve( opts.out ), { recursive: true } );

for ( const input of inputs ) {
	const ext = extname( input ).toLowerCase();
	const outBase = join( resolve( opts.out ), opts.name || basename( input, extname( input ) ) );
	const before = ( await stat( input ) ).size;

	let written;
	if ( ext === '.svg' ) {
		written = await optimizeSvg( input, outBase );
	} else if ( [ '.png', '.jpg', '.jpeg', '.webp', '.tif', '.tiff' ].includes( ext ) ) {
		written = await optimizeRaster( input, outBase );
	} else {
		console.warn( `skip ${ input } (unsupported type)` );
		continue;
	}

	for ( const file of written ) {
		const after = ( await stat( file ) ).size;
		console.log( `${ basename( input ) } (${ kb( before ) }) -> ${ basename( file ) } (${ kb( after ) })` );
	}
}
