<?php
/**
 * Helper Functions
 *
 * @package Starter
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Get the current theme version from style.css.
 *
 * @return string Theme version string.
 */
function starter_get_theme_version() {
	$theme = wp_get_theme();
	return $theme->get( 'Version' );
}

/**
 * [starter_year] shortcode: the current year, for the footer copyright line.
 *
 * Block templates cannot run PHP, so the year is a shortcode. Core runs
 * shortcodes in the text of any block, so write [starter_year] directly in a
 * paragraph. Do not wrap it in a Shortcode block inside the paragraph: that
 * prints the brackets literally.
 *
 * @return string
 */
function starter_year_shortcode() {
	return esc_html( wp_date( 'Y' ) );
}
add_shortcode( 'starter_year', 'starter_year_shortcode' );
