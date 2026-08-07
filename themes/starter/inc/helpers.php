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
