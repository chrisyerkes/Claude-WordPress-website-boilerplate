<?php
/**
 * SVG uploads.
 *
 * Allows SVG files in the Media Library, safely. An SVG is an XML document
 * that can carry scripts, event handlers and external references, so every
 * upload is sanitized before WordPress stores it:
 *
 * - DOCTYPE and entity declarations are refused outright (XXE, "billion laughs").
 * - Only drawing elements are kept; script, foreignObject, iframe and anything
 *   unknown are removed with their contents.
 * - Event handler attributes (on*) are removed.
 * - href / xlink:href may only point inside the file (#id) or at an embedded
 *   raster image (data:image/png|jpeg|gif|webp).
 * - style attributes and <style> blocks lose anything that can load or run
 *   code (url() to anything but #id, @import, expression(), javascript:).
 *
 * A file that cannot be parsed as SVG is rejected, not stored.
 *
 * This lives in the plugin, not the theme: losing it on a theme switch would
 * break every SVG already in the library.
 *
 * @package {{TITLE}}
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Allow the SVG MIME type for users who can upload files.
 *
 * @param array $mimes Allowed MIME types keyed by extension pattern.
 * @return array
 */
function {{PFX}}_svg_mimes( $mimes ) {
	$mimes['svg'] = 'image/svg+xml';
	return $mimes;
}
add_filter( 'upload_mimes', '{{PFX}}_svg_mimes' );

/**
 * Confirm SVGs pass WordPress's real-type check.
 *
 * PHP's fileinfo reports SVG as image/svg+xml or text/xml depending on the
 * build, and WordPress rejects the upload when that disagrees with the
 * extension. Accept it only when the file really starts like an SVG document.
 *
 * @param array  $data     Values for ext, type and proper_filename.
 * @param string $file     Full path to the file.
 * @param string $filename Original file name.
 * @return array
 */
function {{PFX}}_svg_filetype( $data, $file, $filename ) {
	if ( 'svg' !== strtolower( pathinfo( $filename, PATHINFO_EXTENSION ) ) ) {
		return $data;
	}

	$head = (string) file_get_contents( $file, false, null, 0, 4096 ); // phpcs:ignore WordPress.WP.AlternativeFunctions.file_get_contents_file_get_contents -- Local temp file.

	if ( preg_match( '~<svg[\s>]~i', $head ) ) {
		$data['ext']  = 'svg';
		$data['type'] = 'image/svg+xml';
	}

	return $data;
}
add_filter( 'wp_check_filetype_and_ext', '{{PFX}}_svg_filetype', 10, 3 );

/**
 * Sanitize an SVG on upload or sideload, in place.
 *
 * @param array $file Upload array (name, type, tmp_name, error, size).
 * @return array
 */
function {{PFX}}_svg_prefilter( $file ) {
	if ( 'svg' !== strtolower( pathinfo( (string) $file['name'], PATHINFO_EXTENSION ) ) ) {
		return $file;
	}

	$source = file_get_contents( $file['tmp_name'] ); // phpcs:ignore WordPress.WP.AlternativeFunctions.file_get_contents_file_get_contents -- Local temp file.
	$clean  = false === $source ? false : {{PFX}}_svg_sanitize( $source );

	if ( false === $clean ) {
		$file['error'] = __( 'This SVG could not be uploaded: it is not valid SVG, or it contains code that is not allowed. Re-export it from your design tool as a plain SVG and try again.', '{{PLUGIN_SLUG}}' );
		return $file;
	}

	file_put_contents( $file['tmp_name'], $clean ); // phpcs:ignore WordPress.WP.AlternativeFunctions.file_system_operations_file_put_contents -- Rewriting the upload's own temp file.
	$file['size'] = strlen( $clean );

	return $file;
}
add_filter( 'wp_handle_upload_prefilter', '{{PFX}}_svg_prefilter' );
add_filter( 'wp_handle_sideload_prefilter', '{{PFX}}_svg_prefilter' );

/**
 * Sanitize SVG markup.
 *
 * @param string $svg Raw SVG source.
 * @return string|false Clean SVG, or false if it cannot be made safe.
 */
function {{PFX}}_svg_sanitize( $svg ) {
	// Strip a UTF-8 BOM, then refuse DTDs and entities before parsing anything.
	$svg = preg_replace( '/^\xEF\xBB\xBF/', '', (string) $svg );

	if ( '' === trim( $svg ) || preg_match( '~<!(?:DOCTYPE|ENTITY)~i', $svg ) ) {
		return false;
	}

	$allowed_elements = array(
		'svg', 'g', 'defs', 'symbol', 'use', 'title', 'desc', 'metadata',
		'path', 'rect', 'circle', 'ellipse', 'line', 'polyline', 'polygon',
		'text', 'tspan', 'textpath',
		'clippath', 'mask', 'pattern', 'marker',
		'lineargradient', 'radialgradient', 'stop',
		'image', 'style', 'switch', 'view',
		'filter', 'feblend', 'fecolormatrix', 'fecomponenttransfer', 'fecomposite',
		'feconvolvematrix', 'fediffuselighting', 'fedisplacementmap', 'fedistantlight',
		'fedropshadow', 'feflood', 'fefunca', 'fefuncb', 'fefuncg', 'fefuncr',
		'fegaussianblur', 'feimage', 'femerge', 'femergenode', 'femorphology',
		'feoffset', 'fepointlight', 'fespecularlighting', 'fespotlight', 'fetile',
		'feturbulence',
	);

	$previous = libxml_use_internal_errors( true );
	$dom      = new DOMDocument();
	// LIBXML_NONET blocks network access; entity substitution stays off (no LIBXML_NOENT).
	$loaded = $dom->loadXML( $svg, LIBXML_NONET | LIBXML_COMPACT );
	libxml_clear_errors();
	libxml_use_internal_errors( $previous );

	if ( ! $loaded || ! $dom->documentElement || 'svg' !== strtolower( $dom->documentElement->localName ) ) {
		return false;
	}

	$xpath = new DOMXPath( $dom );

	// Remove processing instructions and comments (they can hide payloads).
	foreach ( iterator_to_array( $xpath->query( '//processing-instruction() | //comment()' ) ) as $node ) {
		$node->parentNode->removeChild( $node );
	}

	// Walk every element; collect removals first so iteration is stable.
	$remove = array();
	foreach ( $xpath->query( '//*' ) as $element ) {
		if ( ! in_array( strtolower( $element->localName ), $allowed_elements, true ) ) {
			$remove[] = $element;
			continue;
		}

		if ( 'style' === strtolower( $element->localName ) ) {
			$element->textContent = {{PFX}}_svg_clean_css( $element->textContent );
		}

		foreach ( iterator_to_array( $element->attributes ) as $attribute ) {
			$name  = strtolower( $attribute->nodeName );
			$local = strtolower( $attribute->localName );
			$value = trim( $attribute->value );

			// Event handlers.
			if ( str_starts_with( $local, 'on' ) ) {
				$element->removeAttributeNode( $attribute );
				continue;
			}

			// Links: in-document fragments or embedded rasters only.
			if ( 'href' === $local ) {
				$safe = str_starts_with( $value, '#' ) || preg_match( '~^data:image/(?:png|jpe?g|gif|webp);base64,[a-z0-9+/=\s]+$~i', $value );
				if ( ! $safe ) {
					$element->removeAttributeNode( $attribute );
				}
				continue;
			}

			if ( 'style' === $name ) {
				$attribute->value = {{PFX}}_svg_clean_css( $value );
				continue;
			}

			// Anything else carrying a script or external reference.
			if ( preg_match( '~(?:java|vb)script:|data:(?!image/)|url\(\s*[\'"]?\s*(?!#)~i', $value ) ) {
				$element->removeAttributeNode( $attribute );
			}
		}
	}

	foreach ( $remove as $element ) {
		if ( $element->parentNode ) {
			$element->parentNode->removeChild( $element );
		}
	}

	$clean = $dom->saveXML( $dom->documentElement );

	return false === $clean ? false : "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" . $clean . "\n";
}

/**
 * Remove anything from CSS that can load or run code.
 *
 * @param string $css CSS text.
 * @return string
 */
function {{PFX}}_svg_clean_css( $css ) {
	$css = preg_replace( '~@import[^;]*;?~i', '', $css );
	$css = preg_replace( '~expression\s*\(~i', '', $css );
	$css = preg_replace( '~(?:java|vb)script:~i', '', $css );
	// url() is kept only for in-document references such as url(#gradient).
	return preg_replace( '~url\(\s*[\'"]?\s*(?!#)[^)]*\)~i', 'none', $css );
}

/**
 * Give SVG attachments width and height metadata.
 *
 * WordPress cannot read dimensions from a vector, so without this the Image
 * block outputs SVGs with no width/height attributes, which causes layout
 * shift. Read them from the width/height attributes, or the viewBox.
 *
 * @param array $metadata      Attachment metadata.
 * @param int   $attachment_id Attachment ID.
 * @return array
 */
function {{PFX}}_svg_metadata( $metadata, $attachment_id ) {
	if ( 'image/svg+xml' !== get_post_mime_type( $attachment_id ) ) {
		return $metadata;
	}

	$path = get_attached_file( $attachment_id );
	$svg  = $path && is_readable( $path ) ? file_get_contents( $path ) : ''; // phpcs:ignore WordPress.WP.AlternativeFunctions.file_get_contents_file_get_contents -- Local upload.

	if ( ! preg_match( '~<svg\b[^>]*>~is', (string) $svg, $tag ) ) {
		return $metadata;
	}

	$width  = preg_match( '~\swidth\s*=\s*["\']([\d.]+)(?:px)?["\']~i', $tag[0], $w ) ? (float) $w[1] : 0;
	$height = preg_match( '~\sheight\s*=\s*["\']([\d.]+)(?:px)?["\']~i', $tag[0], $h ) ? (float) $h[1] : 0;

	if ( ( ! $width || ! $height ) && preg_match( '~viewBox\s*=\s*["\']\s*[-\d.]+[\s,]+[-\d.]+[\s,]+([\d.]+)[\s,]+([\d.]+)~i', $tag[0], $box ) ) {
		$width  = (float) $box[1];
		$height = (float) $box[2];
	}

	$metadata           = is_array( $metadata ) ? $metadata : array();
	$metadata['width']  = (int) round( $width );
	$metadata['height'] = (int) round( $height );
	$metadata['file']   = _wp_relative_upload_path( $path );

	return $metadata;
}
add_filter( 'wp_generate_attachment_metadata', '{{PFX}}_svg_metadata', 10, 2 );

/**
 * Show SVG previews in the Media Library grid and modal.
 *
 * @param array   $response   Attachment data for JS.
 * @param WP_Post $attachment Attachment post.
 * @return array
 */
function {{PFX}}_svg_media_js( $response, $attachment ) {
	if ( 'image/svg+xml' !== $response['mime'] ) {
		return $response;
	}

	$url    = wp_get_attachment_url( $attachment->ID );
	$width  = (int) ( $response['width'] ?? 0 );
	$height = (int) ( $response['height'] ?? 0 );
	$full   = array(
		'url'         => $url,
		'width'       => $width,
		'height'      => $height,
		'orientation' => $height > $width ? 'portrait' : 'landscape',
	);

	$response['image'] = array(
		'src'    => $url,
		'width'  => $width,
		'height' => $height,
	);
	$response['icon']  = $url;
	$response['sizes'] = array(
		'full'      => $full,
		'medium'    => $full,
		'thumbnail' => $full,
	);

	return $response;
}
add_filter( 'wp_prepare_attachment_for_js', '{{PFX}}_svg_media_js', 10, 2 );
