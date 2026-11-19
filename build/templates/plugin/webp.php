<?php
/**
 * WebP delivery with a JPG/PNG fallback.
 *
 * On upload, every JPEG and PNG size WordPress generates gets a WebP sibling
 * named "{file}.webp" (photo-300x200.jpg -> photo-300x200.jpg.webp, so a JPG
 * and a PNG with the same name never collide). A WebP is kept only when it is
 * smaller than the file it replaces.
 *
 * On output, attachment images are wrapped in
 *
 *   <picture class="{{THEME_SLUG}}-webp">
 *     <source type="image/webp" srcset="...webp candidates..." sizes="...">
 *     <img ...original tag, untouched...>
 *   </picture>
 *
 * so browsers that support WebP download it and the rest use the optimized
 * JPG/PNG. The <img> keeps every attribute (width, height, loading,
 * fetchpriority, classes), and the theme sets picture.{{THEME_SLUG}}-webp to
 * display: contents so layout is unchanged. Works on any server: no rewrite
 * rules needed.
 *
 * JPEG fallbacks are re-encoded at quality 82 with metadata stripped (core's
 * Imagick editor strips profiles and EXIF by default).
 *
 * Existing uploads: run `wp {{THEME_SLUG}}-webp generate` (or `wp media regenerate`).
 *
 * @package {{TITLE}}
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Metadata key holding the WebP map: original basename => WebP basename.
 */
const {{CONST}}_WEBP_META = '{{PFX}}_webp';

/**
 * JPEG and WebP quality for generated sizes.
 *
 * @param int    $quality   Quality 1-100.
 * @param string $mime_type Output MIME type.
 * @return int
 */
function {{PFX}}_image_quality( $quality, $mime_type = '' ) {
	return in_array( $mime_type, array( 'image/jpeg', 'image/webp' ), true ) ? 82 : $quality;
}
add_filter( 'wp_editor_set_quality', '{{PFX}}_image_quality', 10, 2 );

/**
 * Whether this server can write WebP.
 *
 * @return bool
 */
function {{PFX}}_webp_supported() {
	return wp_image_editor_supports( array( 'mime_type' => 'image/webp' ) );
}

/**
 * Create WebP siblings for an attachment's original and every size.
 *
 * @param array $metadata      Attachment metadata.
 * @param int   $attachment_id Attachment ID.
 * @return array Metadata with the WebP map added.
 */
function {{PFX}}_webp_generate( $metadata, $attachment_id ) {
	$mime = get_post_mime_type( $attachment_id );

	if ( ! in_array( $mime, array( 'image/jpeg', 'image/png' ), true ) || empty( $metadata['file'] ) || ! {{PFX}}_webp_supported() ) {
		return $metadata;
	}

	$dir   = trailingslashit( dirname( get_attached_file( $attachment_id ) ) );
	$files = array( wp_basename( $metadata['file'] ) );

	foreach ( (array) ( $metadata['sizes'] ?? array() ) as $size ) {
		if ( ! empty( $size['file'] ) ) {
			$files[] = $size['file'];
		}
	}

	$map = array();

	foreach ( array_unique( $files ) as $file ) {
		$source = $dir . $file;
		$target = $source . '.webp';

		if ( ! is_readable( $source ) ) {
			continue;
		}

		if ( ! file_exists( $target ) ) {
			$editor = wp_get_image_editor( $source );

			if ( is_wp_error( $editor ) ) {
				continue;
			}

			$editor->set_quality( 82 );
			$saved = $editor->save( $target, 'image/webp' );

			if ( is_wp_error( $saved ) || ! file_exists( $target ) ) {
				continue;
			}
		}

		// Only serve a WebP that actually saves bytes.
		if ( filesize( $target ) >= filesize( $source ) ) {
			wp_delete_file( $target );
			continue;
		}

		$map[ $file ] = wp_basename( $target );
	}

	$metadata[ {{CONST}}_WEBP_META ] = $map;

	return $metadata;
}
add_filter( 'wp_generate_attachment_metadata', '{{PFX}}_webp_generate', 20, 2 );

/**
 * Delete WebP siblings with their attachment.
 *
 * @param int $attachment_id Attachment ID.
 */
function {{PFX}}_webp_delete( $attachment_id ) {
	$metadata = wp_get_attachment_metadata( $attachment_id );
	$file     = get_attached_file( $attachment_id );

	if ( empty( $metadata[ {{CONST}}_WEBP_META ] ) || ! $file ) {
		return;
	}

	$dir = trailingslashit( dirname( $file ) );

	foreach ( $metadata[ {{CONST}}_WEBP_META ] as $webp ) {
		wp_delete_file( $dir . wp_basename( $webp ) );
	}
}
add_action( 'delete_attachment', '{{PFX}}_webp_delete' );

/**
 * Wrap an attachment <img> in a <picture> with a WebP source.
 *
 * @param string $img           The <img> tag.
 * @param int    $attachment_id Attachment ID.
 * @return string
 */
function {{PFX}}_webp_picture( $img, $attachment_id ) {
	if ( ! $attachment_id || str_contains( $img, 'data-{{THEME_SLUG}}-webp' ) ) {
		return $img;
	}

	$metadata = wp_get_attachment_metadata( $attachment_id );
	$map      = $metadata[ {{CONST}}_WEBP_META ] ?? array();

	if ( ! $map ) {
		return $img;
	}

	$processor = new WP_HTML_Tag_Processor( $img );

	if ( ! $processor->next_tag( 'img' ) ) {
		return $img;
	}

	$srcset = (string) $processor->get_attribute( 'srcset' );
	$src    = (string) $processor->get_attribute( 'src' );
	$sizes  = (string) $processor->get_attribute( 'sizes' );

	// Candidates are "url descriptor" pairs; with no srcset, the src alone.
	$candidates = $srcset ? array_map( 'trim', explode( ',', $srcset ) ) : array( $src );
	$webp       = array();

	foreach ( $candidates as $candidate ) {
		$parts = preg_split( '/\s+/', $candidate, 2 );
		$url   = $parts[0] ?? '';
		$name  = wp_basename( (string) wp_parse_url( $url, PHP_URL_PATH ) );

		if ( '' === $name || empty( $map[ $name ] ) ) {
			continue;
		}

		$webp[] = trim( substr( $url, 0, -strlen( $name ) ) . $map[ $name ] . ' ' . ( $parts[1] ?? '' ) );
	}

	if ( ! $webp ) {
		return $img;
	}

	// Mark the <img> so a second pass (template + content filters) skips it.
	$processor->set_attribute( 'data-{{THEME_SLUG}}-webp', '' );

	$source = sprintf(
		'<source type="image/webp" srcset="%s"%s>',
		esc_attr( implode( ', ', $webp ) ),
		$sizes ? ' sizes="' . esc_attr( $sizes ) . '"' : ''
	);

	return '<picture class="{{THEME_SLUG}}-webp">' . $source . $processor->get_updated_html() . '</picture>';
}

/**
 * Content and template images (Image, Cover, Media & Text, Gallery blocks).
 *
 * @param string $filtered_image The <img> tag.
 * @param string $context        Filter context.
 * @param int    $attachment_id  Attachment ID, 0 if unknown.
 * @return string
 */
function {{PFX}}_webp_content_img( $filtered_image, $context, $attachment_id ) {
	return {{PFX}}_webp_picture( $filtered_image, (int) $attachment_id );
}
add_filter( 'wp_content_img_tag', '{{PFX}}_webp_content_img', 20, 3 );

/**
 * Images output through wp_get_attachment_image() (featured images, ACF image
 * fields rendered with wp_get_attachment_image, theme templates).
 *
 * @param string $html          The <img> tag.
 * @param int    $attachment_id Attachment ID.
 * @return string
 */
function {{PFX}}_webp_attachment_image( $html, $attachment_id ) {
	if ( is_admin() && ! wp_doing_ajax() ) {
		return $html;
	}

	return {{PFX}}_webp_picture( $html, (int) $attachment_id );
}
add_filter( 'wp_get_attachment_image', '{{PFX}}_webp_attachment_image', 20, 2 );

/**
 * WP-CLI: create WebP siblings for images uploaded before this was active.
 *
 * Usage: wp {{THEME_SLUG}}-webp generate [--force]
 */
if ( defined( 'WP_CLI' ) && WP_CLI ) {
	WP_CLI::add_command(
		'{{THEME_SLUG}}-webp generate',
		function ( $args, $assoc_args ) {
			$ids = get_posts(
				array(
					'post_type'      => 'attachment',
					'post_mime_type' => array( 'image/jpeg', 'image/png' ),
					'post_status'    => 'inherit',
					'posts_per_page' => -1,
					'fields'         => 'ids',
				)
			);

			$force = ! empty( $assoc_args['force'] );
			$done  = 0;

			foreach ( $ids as $id ) {
				$metadata = wp_get_attachment_metadata( $id );

				if ( ! is_array( $metadata ) || ( isset( $metadata[ {{CONST}}_WEBP_META ] ) && ! $force ) ) {
					continue;
				}

				wp_update_attachment_metadata( $id, {{PFX}}_webp_generate( $metadata, $id ) );
				++$done;
			}

			WP_CLI::success( sprintf( 'Processed %d of %d images.', $done, count( $ids ) ) );
		},
		array( 'shortdesc' => 'Create WebP copies of existing JPEG and PNG uploads.' )
	);
}
