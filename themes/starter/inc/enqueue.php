<?php
/**
 * Enqueue Scripts and Styles
 *
 * @package Starter
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Adobe Fonts Web Project ID.
 *
 * setup.sh fills this in when a heading or body font comes from Adobe Fonts.
 * Leave it empty and nothing is requested from Adobe. The ID is the code in
 * the project's embed link, https://use.typekit.net/<ID>.css.
 *
 * @return string
 */
function starter_adobe_fonts_kit_id() {
	return ''; // ADOBE_KIT_ID
}

/**
 * Adobe Fonts stylesheet URL, or an empty string when no project is set.
 *
 * @return string
 */
function starter_adobe_fonts_url() {
	$kit = preg_replace( '/[^a-zA-Z0-9]/', '', starter_adobe_fonts_kit_id() );

	return '' === $kit ? '' : 'https://use.typekit.net/' . $kit . '.css';
}

/**
 * Load Adobe Fonts on the front end.
 */
function starter_enqueue_adobe_fonts() {
	$url = starter_adobe_fonts_url();

	if ( '' === $url ) {
		return;
	}

	// Null version: Adobe versions the kit itself, and a query string would
	// defeat its caching.
	wp_enqueue_style( 'starter-adobe-fonts', $url, array(), null ); // phpcs:ignore WordPress.WP.EnqueuedResourceParametersNotExplicit.MissingVersion -- Third-party kit.
}
add_action( 'wp_enqueue_scripts', 'starter_enqueue_adobe_fonts', 5 );

/**
 * Load Adobe Fonts in the editor, so the Site Editor shows the real typeface.
 */
function starter_editor_adobe_fonts() {
	$url = starter_adobe_fonts_url();

	if ( '' !== $url ) {
		add_editor_style( $url );
	}
}
add_action( 'after_setup_theme', 'starter_editor_adobe_fonts' );

/**
 * Open the connection to Adobe's font hosts early.
 *
 * @param array<int, mixed> $hints         URLs or hint arrays.
 * @param string            $relation_type The hint type.
 * @return array<int, mixed>
 */
function starter_adobe_fonts_resource_hints( $hints, $relation_type ) {
	if ( 'preconnect' === $relation_type && '' !== starter_adobe_fonts_url() ) {
		$hints[] = array(
			'href'        => 'https://use.typekit.net',
			'crossorigin' => 'anonymous',
		);
		$hints[] = array(
			'href'        => 'https://p.typekit.net',
			'crossorigin' => 'anonymous',
		);
	}

	return $hints;
}
add_filter( 'wp_resource_hints', 'starter_adobe_fonts_resource_hints', 10, 2 );

/**
 * Enqueue front-end styles and scripts.
 */
function starter_enqueue_assets() {
	$theme_version = starter_get_theme_version();

	// Main stylesheet (always loaded).
	wp_enqueue_style(
		'starter-main',
		get_template_directory_uri() . '/assets/css/main.css',
		array(),
		$theme_version
	);

	// Navigation JS (always loaded).
	wp_enqueue_script(
		'starter-navigation',
		get_template_directory_uri() . '/assets/js/navigation.js',
		array(),
		$theme_version,
		true
	);
}
add_action( 'wp_enqueue_scripts', 'starter_enqueue_assets' );

/**
 * Per-block stylesheets.
 *
 * wp_enqueue_block_style() ties a stylesheet to a specific block name so
 * WordPress only emits it on pages where that block actually renders, and
 * loads it into the iframed editor automatically. Block themes get
 * should_load_separate_core_block_assets = true by default, so this is the
 * right way to style an individual core block without inflating main.css.
 *
 * Each entry expects a compiled file at assets/css/blocks/{block}.css. Add
 * matching SCSS entry points to build/compile-scss.mjs as you create them.
 */
function starter_block_styles() {
	$block_styles = array(
		// 'core/accordion' => 'accordion',
		// 'core/quote'     => 'quote',
	);

	foreach ( $block_styles as $block_name => $file ) {
		$path = get_theme_file_path( "assets/css/blocks/{$file}.css" );

		if ( ! file_exists( $path ) ) {
			continue;
		}

		wp_enqueue_block_style(
			$block_name,
			array(
				'handle' => 'starter-block-' . sanitize_title( $file ),
				'src'    => get_theme_file_uri( "assets/css/blocks/{$file}.css" ),
				'path'   => $path,
				'ver'    => starter_get_theme_version(),
			)
		);
	}
}
add_action( 'after_setup_theme', 'starter_block_styles' );

/*
 * Script modules for interactive blocks.
 *
 * Any front-end JavaScript that uses ES module syntax — anything importing
 * @wordpress/interactivity, for instance — must go through the Script Modules
 * API. Classic scripts registered with wp_enqueue_script() cannot depend on a
 * script module, so mixing the two silently fails.
 *
 * For a custom block, prefer declaring "viewScriptModule" in its block.json
 * over registering by hand. Register manually only for theme-level modules
 * that are not owned by a single block.
 *
 * function starter_register_script_modules() {
 *     wp_register_script_module(
 *         '@starter/shared',
 *         get_template_directory_uri() . '/assets/js/shared.js',
 *         array(),
 *         starter_get_theme_version()
 *     );
 * }
 * add_action( 'init', 'starter_register_script_modules' );
 */
