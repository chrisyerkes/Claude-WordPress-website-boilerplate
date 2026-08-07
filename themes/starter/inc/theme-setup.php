<?php
/**
 * Theme Setup
 *
 * @package Starter
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Sets up theme defaults and registers support for various WordPress features.
 */
function starter_theme_setup() {
	// Add support for block styles.
	add_theme_support( 'wp-block-styles' );

	// Add support for post thumbnails.
	add_theme_support( 'post-thumbnails' );

	// Add support for responsive embeds.
	add_theme_support( 'responsive-embeds' );

	// Add support for editor styles.
	add_theme_support( 'editor-styles' );

	// Enqueue editor styles (paths relative to theme root).
	add_editor_style( 'assets/css/main.css' );
	add_editor_style( 'assets/css/editor.css' );

	// Add support for HTML5 markup.
	add_theme_support(
		'html5',
		array(
			'search-form',
			'comment-form',
			'comment-list',
			'gallery',
			'caption',
			'style',
			'script',
		)
	);

	// Register navigation menus.
	register_nav_menus(
		array(
			'primary' => __( 'Primary Navigation', 'starter' ),
			'footer'  => __( 'Footer Navigation', 'starter' ),
		)
	);

	// Add custom image sizes as the project requires.
	// add_image_size( 'starter-card', 370, 220, true );
	// add_image_size( 'starter-hero', 1440, 800, true );
}
add_action( 'after_setup_theme', 'starter_theme_setup' );
