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
require_once get_template_directory() . '/inc/blocks.php';

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
 * ACF PRO dependency notice.
 *
 * Only shown when the theme actually ships blocks that declare an "acf" key,
 * so a project built entirely from core blocks never sees it.
 *
 * Detection uses acf_add_options_page(), which is PRO-only and current.
 * The older idiom, function_exists( 'acf_register_block_type' ), still works
 * but tests for a function ACF deprecated in 6.0.
 *
 * Delete this function if the project does not use ACF.
 */
function starter_acf_admin_notice() {
	if ( function_exists( 'acf_add_options_page' ) ) {
		return;
	}

	if ( ! current_user_can( 'activate_plugins' ) ) {
		return;
	}

	$blocks_dir = get_template_directory() . '/blocks';

	if ( ! is_dir( $blocks_dir ) ) {
		return;
	}

	$block_files = glob( $blocks_dir . '/*/block.json' );

	if ( empty( $block_files ) ) {
		return;
	}

	// Only warn if at least one block actually needs ACF.
	$needs_acf = false;

	foreach ( $block_files as $block_json ) {
		$raw = file_get_contents( $block_json ); // phpcs:ignore WordPress.WP.AlternativeFunctions.file_get_contents_file_get_contents -- Local theme file.

		if ( false === $raw ) {
			continue;
		}

		$data = json_decode( $raw, true );

		if ( is_array( $data ) && isset( $data['acf'] ) ) {
			$needs_acf = true;
			break;
		}
	}

	if ( ! $needs_acf ) {
		return;
	}

	echo '<div class="notice notice-warning"><p>';
	echo esc_html__( 'This theme includes custom blocks that require ACF PRO. Please install and activate ACF PRO for full functionality.', 'starter' );
	echo '</p></div>';
}
add_action( 'admin_notices', 'starter_acf_admin_notice' );
