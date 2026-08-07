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
