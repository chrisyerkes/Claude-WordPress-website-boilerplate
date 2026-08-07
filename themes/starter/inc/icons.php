<?php
/**
 * SVG Icon System
 *
 * Store SVG files in /assets/icons/{name}.svg
 * Retrieve them with starter_get_icon() or output with starter_icon().
 *
 * @package Starter
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Get an SVG icon as a string.
 *
 * @param string $name Icon filename without extension.
 * @param int    $size Icon width and height in pixels. Default 24.
 * @return string SVG markup or empty string if not found.
 */
function starter_get_icon( $name, $size = 24 ) {
	$file = get_template_directory() . '/assets/icons/' . $name . '.svg';

	if ( ! file_exists( $file ) ) {
		return '';
	}

	$svg = file_get_contents( $file );

	// Add accessibility attributes and sizing.
	$svg = str_replace(
		'<svg',
		sprintf(
			'<svg aria-hidden="true" focusable="false" width="%d" height="%d"',
			absint( $size ),
			absint( $size )
		),
		$svg
	);

	return $svg;
}

/**
 * Echo an SVG icon.
 *
 * @param string $name Icon filename without extension.
 * @param int    $size Icon width and height in pixels. Default 24.
 */
function starter_icon( $name, $size = 24 ) {
	echo starter_get_icon( $name, $size ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- SVG markup.
}
