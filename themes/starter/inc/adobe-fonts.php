<?php
/**
 * Adobe Fonts (Typekit) web project connection.
 *
 * Adobe Fonts licenses are per account, so each site owner connects their own
 * web project under Appearance › Adobe Fonts. The fonts cannot be self-hosted:
 * the Adobe Fonts licence only covers serving them from Adobe's CDN.
 *
 * Implementation follows Adobe's current recommendation:
 * - the CSS embed (<link rel="stylesheet" href="https://use.typekit.net/{id}.css">),
 *   not the legacy JavaScript kit. The JS embed is only needed for dynamic
 *   subsetting of East Asian fonts. A pasted JS embed is accepted and converted,
 *   because the same project ID serves both.
 * - preconnect hints to Adobe's hosts so the font request starts early.
 * - the kit is loaded in the editor iframe too, so the editor matches the front end.
 *
 * Only the project ID is stored, never the pasted markup, so nothing the user
 * pastes is ever echoed into a page.
 *
 * Which ID is used, first match wins:
 * 1. ADOBE_FONTS_PROJECT_ID in wp-config.php. For development: it overrides
 *    the saved setting on that install only, so a developer's kit never
 *    travels to production with a database migration.
 * 2. The setting saved under Appearance › Adobe Fonts.
 * 3. The default below, which setup.sh fills in when a project ID was given.
 *
 * Delete this file, and its require in functions.php, if the project uses no
 * Adobe Fonts.
 *
 * @package Starter
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Option name holding the Adobe Fonts project ID.
 *
 * @return string
 */
function starter_adobe_fonts_option() {
	return 'starter_adobe_fonts_project_id';
}

/**
 * Settings page slug.
 *
 * @return string
 */
function starter_adobe_fonts_page() {
	return 'starter-adobe-fonts';
}

/**
 * Project ID to use until one is saved on the settings page.
 *
 * setup.sh sets this from the Adobe Web Project ID it was given. Leave it
 * empty and nothing is requested from Adobe until the site owner connects a
 * project.
 *
 * @return string
 */
function starter_adobe_fonts_default_id() {
	return ''; // ADOBE_KIT_ID
}

/**
 * Font families the design expects the web project to contain.
 *
 * Keys are the CSS family names Adobe serves; values are the weights the
 * design uses. The settings page warns when any are missing from the kit.
 * setup.sh lists the Adobe fonts chosen for the heading and body roles with
 * weights 400 and 700. Keep this in step with theme.json fontFamilies and the
 * weights the design uses.
 *
 * @return array<string, int[]>
 */
function starter_adobe_fonts_expected() {
	return array(
		// ADOBE_EXPECTED
	);
}

/**
 * Extract an Adobe Fonts project ID from whatever the user pasted.
 *
 * Accepts a bare ID, a use.typekit.net URL, the <link> embed, the @import
 * embed, or the legacy JavaScript embed.
 *
 * @param string $input Raw input.
 * @return string Project ID, or '' if none was found.
 */
function starter_adobe_fonts_parse_id( $input ) {
	$input = trim( (string) $input );

	if ( '' === $input ) {
		return '';
	}

	if ( preg_match( '~use\.typekit\.net/([a-z0-9]+)\.(?:css|js)~i', $input, $matches ) ) {
		return strtolower( $matches[1] );
	}

	if ( preg_match( '~^[a-z0-9]{5,16}$~i', $input ) ) {
		return strtolower( $input );
	}

	return '';
}

/**
 * The active project ID: the wp-config constant, else the saved setting, else the default.
 *
 * @return string
 */
function starter_adobe_fonts_project_id() {
	if ( defined( 'ADOBE_FONTS_PROJECT_ID' ) && ADOBE_FONTS_PROJECT_ID ) {
		return starter_adobe_fonts_parse_id( ADOBE_FONTS_PROJECT_ID );
	}

	return starter_adobe_fonts_parse_id( get_option( starter_adobe_fonts_option(), starter_adobe_fonts_default_id() ) );
}

/**
 * Stylesheet URL for a project.
 *
 * @param string $project_id Project ID.
 * @return string
 */
function starter_adobe_fonts_url( $project_id ) {
	return 'https://use.typekit.net/' . rawurlencode( $project_id ) . '.css';
}

/**
 * Enqueue the kit stylesheet.
 *
 * enqueue_block_assets fires on the front end and inside the iframed block and
 * site editors, so one hook covers both.
 */
function starter_adobe_fonts_enqueue() {
	$project_id = starter_adobe_fonts_project_id();

	if ( '' === $project_id ) {
		return;
	}

	// No version: Adobe controls cache-busting of the kit itself.
	wp_enqueue_style( 'starter-adobe-fonts', starter_adobe_fonts_url( $project_id ), array(), null ); // phpcs:ignore WordPress.WP.EnqueuedResourceParameters.MissingVersion
}
add_action( 'enqueue_block_assets', 'starter_adobe_fonts_enqueue' );

/**
 * Preconnect to Adobe's font hosts.
 *
 * use.typekit.net serves the CSS and the font files (fonts are fetched in CORS
 * mode, hence crossorigin). p.typekit.net receives the page-view ping Adobe uses
 * for licence accounting.
 *
 * @param array  $urls          Resource hint URLs.
 * @param string $relation_type Hint type.
 * @return array
 */
function starter_adobe_fonts_resource_hints( $urls, $relation_type ) {
	if ( 'preconnect' !== $relation_type || '' === starter_adobe_fonts_project_id() ) {
		return $urls;
	}

	$urls[] = array(
		'href'        => 'https://use.typekit.net',
		'crossorigin' => 'anonymous',
	);
	$urls[] = array(
		'href' => 'https://p.typekit.net',
	);

	return $urls;
}
add_filter( 'wp_resource_hints', 'starter_adobe_fonts_resource_hints', 10, 2 );

/**
 * Register the setting.
 */
function starter_adobe_fonts_register_setting() {
	register_setting(
		starter_adobe_fonts_page(),
		starter_adobe_fonts_option(),
		array(
			'type'              => 'string',
			'show_in_rest'      => false,
			'sanitize_callback' => 'starter_adobe_fonts_sanitize',
		)
	);
}
add_action( 'admin_init', 'starter_adobe_fonts_register_setting' );

/**
 * Sanitize the pasted embed code down to a project ID.
 *
 * @param mixed $value Submitted value.
 * @return string
 */
function starter_adobe_fonts_sanitize( $value ) {
	$raw = is_string( $value ) ? wp_unslash( $value ) : '';
	$id  = starter_adobe_fonts_parse_id( $raw );

	if ( '' !== trim( $raw ) && '' === $id ) {
		add_settings_error(
			starter_adobe_fonts_option(),
			'starter-adobe-fonts-invalid',
			__( 'That doesn’t look like Adobe Fonts embed code or a project ID. Copy the embed code from your web project on fonts.adobe.com and paste it again.', 'starter' )
		);

		return (string) get_option( starter_adobe_fonts_option(), '' );
	}

	delete_transient( 'starter_adobe_fonts_kit_' . $id );

	return $id;
}

/**
 * Let anyone who can edit theme options save this page, not only admins.
 *
 * @return string
 */
function starter_adobe_fonts_capability() {
	return 'edit_theme_options';
}
add_filter( 'option_page_capability_' . starter_adobe_fonts_page(), 'starter_adobe_fonts_capability' );

/**
 * Add Appearance › Adobe Fonts.
 */
function starter_adobe_fonts_add_page() {
	add_theme_page(
		__( 'Adobe Fonts', 'starter' ),
		__( 'Adobe Fonts', 'starter' ),
		'edit_theme_options',
		starter_adobe_fonts_page(),
		'starter_adobe_fonts_render_page'
	);
}
add_action( 'admin_menu', 'starter_adobe_fonts_add_page' );

/**
 * Read the families and weights a kit serves.
 *
 * Fetched server-side and cached for 12 hours. A server request carries no
 * page referrer, so this confirms the project exists and what it contains;
 * the live preview on the settings page confirms the browser can load it.
 *
 * @param string $project_id Project ID.
 * @return array{ok: bool, families?: array<string, int[]>, error?: string}
 */
function starter_adobe_fonts_inspect( $project_id ) {
	$key    = 'starter_adobe_fonts_kit_' . $project_id;
	$cached = get_transient( $key );

	if ( is_array( $cached ) ) {
		return $cached;
	}

	$response = wp_remote_get( starter_adobe_fonts_url( $project_id ), array( 'timeout' => 8 ) );

	if ( is_wp_error( $response ) ) {
		// Not cached: a network blip should not stick for 12 hours.
		return array(
			'ok'    => false,
			'error' => $response->get_error_message(),
		);
	}

	$code = (int) wp_remote_retrieve_response_code( $response );

	if ( 200 !== $code ) {
		$result = array(
			'ok'    => false,
			/* translators: %d: HTTP status code. */
			'error' => sprintf( __( 'Adobe returned HTTP %d. Check the project ID, and that the web project has not been deleted.', 'starter' ), $code ),
		);
		set_transient( $key, $result, HOUR_IN_SECONDS );
		return $result;
	}

	$families = array();

	if ( preg_match_all( '~@font-face\s*\{([^}]*)\}~i', wp_remote_retrieve_body( $response ), $faces ) ) {
		foreach ( $faces[1] as $face ) {
			if ( ! preg_match( '~font-family:\s*["\']?([^"\';]+)~i', $face, $family ) ) {
				continue;
			}

			$name   = strtolower( trim( $family[1] ) );
			$weight = preg_match( '~font-weight:\s*(\d+)~i', $face, $w ) ? (int) $w[1] : 400;
			$italic = (bool) preg_match( '~font-style:\s*italic~i', $face );

			$families[ $name ][] = $italic ? $weight . 'i' : $weight;
		}
	}

	foreach ( $families as $name => $weights ) {
		$weights = array_unique( $weights );
		natsort( $weights );
		$families[ $name ] = array_values( $weights );
	}

	$result = array(
		'ok'       => true,
		'families' => $families,
	);
	set_transient( $key, $result, 12 * HOUR_IN_SECONDS );

	return $result;
}

/**
 * Render the settings page.
 */
function starter_adobe_fonts_render_page() {
	if ( ! current_user_can( 'edit_theme_options' ) ) {
		return;
	}

	$from_constant = defined( 'ADOBE_FONTS_PROJECT_ID' ) && ADOBE_FONTS_PROJECT_ID;
	$saved_id      = (string) get_option( starter_adobe_fonts_option(), starter_adobe_fonts_default_id() );
	$project_id    = starter_adobe_fonts_project_id();
	$expected      = starter_adobe_fonts_expected();
	?>
	<div class="wrap">
		<h1><?php echo esc_html( get_admin_page_title() ); ?></h1>

		<p>
			<?php esc_html_e( 'This site’s typefaces are served through Adobe Fonts. The fonts are served by Adobe under the site owner’s own Adobe account, so each site needs its own web project.', 'starter' ); ?>
		</p>

		<h2><?php esc_html_e( 'Connect your web project', 'starter' ); ?></h2>
		<ol>
			<li>
				<?php
				printf(
					/* translators: %s: link to fonts.adobe.com. */
					esc_html__( 'Sign in at %s with an Adobe Creative Cloud account that includes Adobe Fonts.', 'starter' ),
					'<a href="https://fonts.adobe.com/my_fonts#web_projects-section" target="_blank" rel="noopener noreferrer">fonts.adobe.com<span class="screen-reader-text"> ' . esc_html__( '(opens in a new tab)', 'starter' ) . '</span></a>'
				);
				?>
			</li>
			<li>
				<?php
				if ( empty( $expected ) ) {
					esc_html_e( 'Add the fonts this site uses to a web project.', 'starter' );
				}

				foreach ( $expected as $family => $weights ) {
					printf(
						/* translators: 1: font family, 2: list of weights. */
						esc_html__( 'Add %1$s to a web project, including weights %2$s.', 'starter' ),
						'<strong>' . esc_html( ucwords( str_replace( '-', ' ', $family ) ) ) . '</strong>',
						esc_html( implode( ', ', $weights ) )
					);
				}
				?>
			</li>
			<li><?php esc_html_e( 'In the web project’s settings, set Font display to “swap” so text stays visible while the fonts load.', 'starter' ); ?></li>
			<li><?php esc_html_e( 'Copy the embed code (or just the project ID) and paste it below.', 'starter' ); ?></li>
		</ol>

		<?php settings_errors( starter_adobe_fonts_option() ); ?>

		<form method="post" action="options.php">
			<?php settings_fields( starter_adobe_fonts_page() ); ?>
			<table class="form-table" role="presentation">
				<tr>
					<th scope="row">
						<label for="starter-adobe-fonts-id"><?php esc_html_e( 'Embed code or project ID', 'starter' ); ?></label>
					</th>
					<td>
						<textarea
							id="starter-adobe-fonts-id"
							name="<?php echo esc_attr( starter_adobe_fonts_option() ); ?>"
							class="large-text code"
							rows="3"
							spellcheck="false"
							aria-describedby="starter-adobe-fonts-help"
							placeholder="&lt;link rel=&quot;stylesheet&quot; href=&quot;https://use.typekit.net/abc1234.css&quot;&gt;"
						><?php echo esc_textarea( $saved_id ); ?></textarea>
						<p class="description" id="starter-adobe-fonts-help">
							<?php esc_html_e( 'Paste the whole <link> embed code, the @import code, or the project ID. Only the project ID is saved. Clear the field to disconnect.', 'starter' ); ?>
						</p>
					</td>
				</tr>
			</table>
			<?php submit_button(); ?>
		</form>

		<h2><?php esc_html_e( 'Status', 'starter' ); ?></h2>

		<?php if ( $from_constant ) : ?>
			<div class="notice notice-info inline"><p>
				<?php
				printf(
					/* translators: 1: constant name, 2: project ID. */
					esc_html__( '%1$s is defined in wp-config.php, so this install uses project %2$s and ignores the field above. Remove the constant to use the saved setting.', 'starter' ),
					'<code>ADOBE_FONTS_PROJECT_ID</code>',
					'<code>' . esc_html( $project_id ) . '</code>'
				);
				?>
			</p></div>
		<?php endif; ?>

		<?php if ( '' === $project_id ) : ?>
			<div class="notice notice-warning inline"><p>
				<?php esc_html_e( 'Not connected. The site is using fallback system fonts.', 'starter' ); ?>
			</p></div>
		<?php else : ?>
			<?php $kit = starter_adobe_fonts_inspect( $project_id ); ?>

			<?php if ( ! $kit['ok'] ) : ?>
				<div class="notice notice-error inline"><p>
					<?php
					printf(
						/* translators: 1: project ID, 2: error message. */
						esc_html__( 'Could not read project %1$s: %2$s', 'starter' ),
						'<code>' . esc_html( $project_id ) . '</code>',
						esc_html( $kit['error'] )
					);
					?>
				</p></div>
			<?php else : ?>
				<?php
				$missing = array();
				foreach ( $expected as $family => $weights ) {
					$have = $kit['families'][ $family ] ?? array();
					foreach ( $weights as $weight ) {
						if ( ! in_array( $weight, $have, true ) ) {
							$missing[] = $family . ' ' . $weight;
						}
					}
				}
				?>
				<div class="notice <?php echo esc_attr( $missing ? 'notice-warning' : 'notice-success' ); ?> inline"><p>
					<?php
					if ( $missing ) {
						printf(
							/* translators: 1: project ID, 2: list of missing fonts. */
							esc_html__( 'Project %1$s is connected, but it is missing: %2$s. Add them to the web project on fonts.adobe.com; changes can take a few minutes to appear.', 'starter' ),
							'<code>' . esc_html( $project_id ) . '</code>',
							'<strong>' . esc_html( implode( ', ', $missing ) ) . '</strong>'
						);
					} else {
						printf(
							/* translators: %s: project ID. */
							esc_html__( 'Project %s is connected and contains every font the design uses.', 'starter' ),
							'<code>' . esc_html( $project_id ) . '</code>'
						);
					}
					?>
				</p></div>

				<table class="widefat striped" style="max-width:48rem">
					<thead>
						<tr>
							<th scope="col"><?php esc_html_e( 'CSS family', 'starter' ); ?></th>
							<th scope="col"><?php esc_html_e( 'Weights in project', 'starter' ); ?></th>
						</tr>
					</thead>
					<tbody>
						<?php if ( empty( $kit['families'] ) ) : ?>
							<tr><td colspan="2"><?php esc_html_e( 'The project contains no fonts yet.', 'starter' ); ?></td></tr>
						<?php endif; ?>
						<?php foreach ( $kit['families'] as $family => $weights ) : ?>
							<tr>
								<td><code><?php echo esc_html( $family ); ?></code></td>
								<td><?php echo esc_html( implode( ', ', $weights ) ); ?></td>
							</tr>
						<?php endforeach; ?>
					</tbody>
				</table>

				<h3><?php esc_html_e( 'Live preview', 'starter' ); ?></h3>
				<p class="description"><?php esc_html_e( 'Rendered by this browser from Adobe’s servers. If these lines look like a plain system font, the browser could not load the kit.', 'starter' ); ?></p>
				<?php foreach ( $expected as $family => $weights ) : ?>
					<?php foreach ( $weights as $weight ) : ?>
						<p style="font-family:<?php echo esc_attr( $family ); ?>, monospace;font-weight:<?php echo esc_attr( (string) $weight ); ?>;font-size:1.75rem;line-height:1.2;margin:.5rem 0">
							<?php echo esc_html( $weight . ' · ' . __( 'The quick brown fox jumps over the lazy dog.', 'starter' ) ); ?>
						</p>
					<?php endforeach; ?>
				<?php endforeach; ?>
			<?php endif; ?>
		<?php endif; ?>
	</div>
	<?php
}

/**
 * Load the kit on the settings page itself, for the live preview.
 *
 * @param string $hook_suffix Current admin page.
 */
function starter_adobe_fonts_admin_preview( $hook_suffix ) {
	if ( 'appearance_page_' . starter_adobe_fonts_page() !== $hook_suffix ) {
		return;
	}

	starter_adobe_fonts_enqueue();
}
add_action( 'admin_enqueue_scripts', 'starter_adobe_fonts_admin_preview' );

/**
 * Remind theme editors on the Dashboard and Themes screens when no project is connected.
 */
function starter_adobe_fonts_admin_notice() {
	if ( '' !== starter_adobe_fonts_project_id() || ! current_user_can( 'edit_theme_options' ) ) {
		return;
	}

	$screen = get_current_screen();

	if ( ! $screen || ! in_array( $screen->id, array( 'dashboard', 'themes' ), true ) ) {
		return;
	}

	printf(
		'<div class="notice notice-warning"><p>%s <a href="%s">%s</a></p></div>',
		esc_html__( 'The site’s Adobe Fonts are not connected, so fallback system fonts are showing.', 'starter' ),
		esc_url( admin_url( 'themes.php?page=' . starter_adobe_fonts_page() ) ),
		esc_html__( 'Connect Adobe Fonts', 'starter' )
	);
}
add_action( 'admin_notices', 'starter_adobe_fonts_admin_notice' );

/**
 * Suggested privacy policy text, under Settings › Privacy › Policy Guide.
 */
function starter_adobe_fonts_privacy_content() {
	if ( ! function_exists( 'wp_add_privacy_policy_content' ) ) {
		return;
	}

	wp_add_privacy_policy_content(
		wp_get_theme()->get( 'Name' ),
		'<p>' . esc_html__( 'This site uses Adobe Fonts to display its typefaces. When you visit, your browser requests the fonts from Adobe’s servers, which receive your IP address and the page you visited. Adobe uses this to serve the fonts and to count page views for licensing. Adobe Fonts does not set cookies. See Adobe’s Adobe Fonts privacy information for details.', 'starter' ) . '</p>'
	);
}
add_action( 'admin_init', 'starter_adobe_fonts_privacy_content' );
