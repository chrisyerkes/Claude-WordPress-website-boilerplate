<?php
/**
 * Starter Theme Functions
 *
 * @package Starter
 */

// Prevent direct access.
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Include files.
 */
require_once get_template_directory() . '/inc/theme-setup.php';
require_once get_template_directory() . '/inc/enqueue.php';
require_once get_template_directory() . '/inc/helpers.php';
require_once get_template_directory() . '/inc/icons.php';

/**
 * Register ACF blocks from the /blocks/ directory.
 *
 * Each block must have a block.json file with the "acf" key.
 * Only runs if ACF PRO is active.
 */
function starter_register_blocks() {
	if ( ! function_exists( 'acf_register_block_type' ) ) {
		return;
	}

	$blocks_dir = get_template_directory() . '/blocks';

	if ( ! is_dir( $blocks_dir ) ) {
		return;
	}

	$blocks = glob( $blocks_dir . '/*/block.json' );

	foreach ( $blocks as $block_json ) {
		register_block_type( dirname( $block_json ) );
	}
}
add_action( 'init', 'starter_register_blocks' );

/**
 * Register block pattern categories.
 */
function starter_register_pattern_categories() {
	register_block_pattern_category(
		'starter-components',
		array(
			'label' => __( 'Starter Components', 'starter' ),
		)
	);
}
add_action( 'init', 'starter_register_pattern_categories' );

/**
 * Register custom block styles.
 *
 * Add project-specific block styles here as the design requires.
 * Examples:
 *   register_block_style( 'core/button', [ 'name' => 'starter-outline', 'label' => 'Outline' ] );
 *   register_block_style( 'core/image', [ 'name' => 'starter-rounded', 'label' => 'Rounded' ] );
 */
function starter_register_block_styles() {
	// Add block styles here as needed.
}
add_action( 'init', 'starter_register_block_styles' );

/**
 * ACF PRO dependency notice.
 *
 * Shows an admin notice if ACF PRO is required but not active.
 * Remove this function if the project does not use ACF.
 */
function starter_acf_admin_notice() {
	if ( function_exists( 'acf_register_block_type' ) ) {
		return;
	}

	// Only show if there are block.json files expecting ACF.
	$blocks_dir = get_template_directory() . '/blocks';
	if ( ! is_dir( $blocks_dir ) || empty( glob( $blocks_dir . '/*/block.json' ) ) ) {
		return;
	}

	echo '<div class="notice notice-warning"><p>';
	echo esc_html__( 'This theme includes custom blocks that require ACF PRO. Please install and activate ACF PRO for full functionality.', 'starter' );
	echo '</p></div>';
}
add_action( 'admin_notices', 'starter_acf_admin_notice' );
