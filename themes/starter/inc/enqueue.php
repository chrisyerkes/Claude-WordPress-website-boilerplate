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

	// Conditional JS loading example:
	// Only load scripts when their blocks are present on the page.
	//
	// if ( has_block( 'starter/example-block' ) ) {
	// 	wp_enqueue_script(
	// 		'starter-example',
	// 		get_template_directory_uri() . '/assets/js/example.js',
	// 		array(),
	// 		$theme_version,
	// 		true
	// 	);
	// }
}
add_action( 'wp_enqueue_scripts', 'starter_enqueue_assets' );
