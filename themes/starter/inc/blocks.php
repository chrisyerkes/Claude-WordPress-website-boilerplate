<?php
/**
 * Block Registration, Styles and Core Block Configuration
 *
 * Presentational block concerns live here. Data-layer concerns — custom post
 * types, field groups, block bindings that read post meta — belong in the
 * companion plugin so they survive a theme switch.
 *
 * @package Starter
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Register custom block style variations.
 *
 * A block style variation registered here can be styled entirely from
 * theme.json under styles.blocks.{block}.variations.{name}, including
 * :hover, :focus, :focus-visible and :active states as of WordPress 7.0.
 * No CSS file is required.
 *
 * The matching styles for 'outline' ship in theme.json.
 */
function starter_register_block_styles() {
	register_block_style(
		'core/button',
		array(
			'name'  => 'outline',
			'label' => __( 'Outline', 'starter' ),
		)
	);

	// Add more as the design requires. Example:
	// register_block_style( 'core/group', array( 'name' => 'card', 'label' => __( 'Card', 'starter' ) ) );
}
add_action( 'init', 'starter_register_block_styles' );

/**
 * Register theme block types.
 *
 * Every block directory under /blocks/ containing a block.json is registered.
 * This works for both plain server-rendered blocks and ACF blocks — ACF blocks
 * are ordinary blocks whose block.json carries an "acf" key.
 *
 * Custom blocks must declare "apiVersion": 3. WordPress 6.9 warns on lower
 * versions and 7.1 iframes the editor unconditionally, where API v2 blocks
 * misbehave.
 */
function starter_register_blocks() {
	$blocks_dir = get_template_directory() . '/blocks';

	if ( ! is_dir( $blocks_dir ) ) {
		return;
	}

	$blocks = glob( $blocks_dir . '/*/block.json' );

	if ( empty( $blocks ) ) {
		return;
	}

	foreach ( $blocks as $block_json ) {
		register_block_type( dirname( $block_json ) );
	}
}
add_action( 'init', 'starter_register_blocks' );

/**
 * Breadcrumbs block: choose which taxonomy term represents a post.
 *
 * The core/breadcrumbs block (WordPress 7.0) builds its trail from the site
 * hierarchy. For non-hierarchical post types it needs to know which taxonomy
 * to walk. Uncomment and adjust when the project has custom post types.
 *
 * function starter_breadcrumbs_post_type_settings( $settings, $post_type ) {
 *     if ( 'post' === $post_type ) {
 *         $settings['taxonomy'] = 'category';
 *     }
 *     return $settings;
 * }
 * add_filter( 'block_core_breadcrumbs_post_type_settings', 'starter_breadcrumbs_post_type_settings', 10, 2 );
 */

/**
 * Breadcrumbs block: add or reorder trail items.
 *
 * Each item is array( 'label' => string, 'url' => string, 'allow_html' => bool ).
 *
 * function starter_breadcrumbs_items( $items ) {
 *     array_unshift( $items, array( 'label' => __( 'Home', 'starter' ), 'url' => home_url( '/' ) ) );
 *     return $items;
 * }
 * add_filter( 'block_core_breadcrumbs_items', 'starter_breadcrumbs_items' );
 */

/**
 * Opt a custom block's attributes into Block Bindings and Pattern Overrides.
 *
 * Since WordPress 6.9 the set of bindable attributes is filterable, and since
 * 7.0 anything bindable is automatically overridable in patterns too. Core's
 * default list covers paragraph, heading, image, button, post-date and the two
 * navigation link blocks; custom blocks must opt in explicitly.
 *
 * add_filter(
 *     'block_bindings_supported_attributes_starter/example-block',
 *     function ( $supported_attributes ) {
 *         $supported_attributes[] = 'title';
 *         return $supported_attributes;
 *     }
 * );
 */
