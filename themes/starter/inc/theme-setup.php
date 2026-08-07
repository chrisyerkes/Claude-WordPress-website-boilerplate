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
	// Post thumbnails.
	add_theme_support( 'post-thumbnails' );

	// Responsive embeds — wraps embeds so they scale with their container.
	add_theme_support( 'responsive-embeds' );

	/*
	 * Editor styles.
	 *
	 * Block themes enable 'editor-styles' by default, and add_editor_style()
	 * turns it on implicitly, so the explicit add_theme_support() call is
	 * redundant. These files are what reach the iframed editor canvas —
	 * WordPress 7.0 iframes the editor whenever every block in the post is
	 * Block API v3+, and 7.1 iframes it unconditionally. Anything the editor
	 * needs to see must come through here, wp_enqueue_block_style(), or the
	 * enqueue_block_assets hook. Do not style the editor from admin_head.
	 */
	add_editor_style( 'assets/css/main.css' );
	add_editor_style( 'assets/css/editor.css' );

	/*
	 * HTML5 markup.
	 *
	 * The 'script' and 'style' sub-features were deprecated in WordPress 7.0
	 * and now do nothing — core emits modern markup regardless. They are left
	 * out here. The remaining sub-features are still meaningful.
	 */
	add_theme_support(
		'html5',
		array(
			'search-form',
			'comment-form',
			'comment-list',
			'gallery',
			'caption',
		)
	);

	/*
	 * Core's opinionated block styles.
	 *
	 * Deliberately NOT enabled. add_theme_support( 'wp-block-styles' ) layers
	 * core's default visual treatment on top of your design, which usually
	 * means fighting it back off again in SCSS. Uncomment only if you want
	 * that baseline.
	 */
	// add_theme_support( 'wp-block-styles' );

	// Navigation menus. Block themes use the Navigation block, but classic
	// menus are still useful for a fallback or a non-block context.
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
