<?php
/**
 * Title: FAQ Accordion
 * Slug: starter/faq-accordion
 * Categories: starter-components, text
 * Description: A frequently-asked-questions section built on the native Accordion block introduced in WordPress 6.9.
 * Keywords: faq, accordion, questions, collapse
 *
 * The Accordion block ships no default presentation — core leaves styling
 * entirely to the theme. The borders, spacing and typography here come from
 * styles.blocks."core/accordion-*" in theme.json; the open/hover/focus states
 * come from src/scss/blocks/_accordion.scss, because theme.json cannot express
 * interactive states on these blocks yet.
 *
 * Container attributes worth knowing (set on the wp:accordion comment):
 *   "autoclose": true    only one item open at a time (default false)
 *   "showIcon": false    hide the +/- toggle icon
 *   "iconPosition": "left"
 *   "headingLevel": 2    heading level for every item (default 3)
 *
 * This markup was authored against the WordPress 7.0 block serialization.
 * If the editor ever offers to "Attempt block recovery" on this pattern after
 * a core update, insert it, accept the recovery, and copy the corrected markup
 * back into this file.
 *
 * @package Starter
 */

?>
<!-- wp:accordion {"autoclose":true} -->
<div class="wp-block-accordion" role="group"><!-- wp:accordion-item {"openByDefault":true} -->
<div class="wp-block-accordion-item is-open"><!-- wp:accordion-heading {"level":3} -->
<h3 class="wp-block-accordion-heading"><button type="button" class="wp-block-accordion-heading__toggle"><span class="wp-block-accordion-heading__toggle-title"><?php echo esc_html__( 'What is included in the initial consultation?', 'starter' ); ?></span><span class="wp-block-accordion-heading__toggle-icon" aria-hidden="true">+</span></button></h3>
<!-- /wp:accordion-heading -->

<!-- wp:accordion-panel -->
<div class="wp-block-accordion-panel" role="region"><!-- wp:paragraph -->
<p><?php echo esc_html__( 'Replace this answer with real content. Panels accept any blocks, so an answer can include lists, images, buttons or an embedded video rather than plain text.', 'starter' ); ?></p>
<!-- /wp:paragraph --></div>
<!-- /wp:accordion-panel --></div>
<!-- /wp:accordion-item -->

<!-- wp:accordion-item -->
<div class="wp-block-accordion-item"><!-- wp:accordion-heading {"level":3} -->
<h3 class="wp-block-accordion-heading"><button type="button" class="wp-block-accordion-heading__toggle"><span class="wp-block-accordion-heading__toggle-title"><?php echo esc_html__( 'How long does a typical project take?', 'starter' ); ?></span><span class="wp-block-accordion-heading__toggle-icon" aria-hidden="true">+</span></button></h3>
<!-- /wp:accordion-heading -->

<!-- wp:accordion-panel -->
<div class="wp-block-accordion-panel" role="region"><!-- wp:paragraph -->
<p><?php echo esc_html__( 'Replace this answer with real content.', 'starter' ); ?></p>
<!-- /wp:paragraph --></div>
<!-- /wp:accordion-panel --></div>
<!-- /wp:accordion-item -->

<!-- wp:accordion-item -->
<div class="wp-block-accordion-item"><!-- wp:accordion-heading {"level":3} -->
<h3 class="wp-block-accordion-heading"><button type="button" class="wp-block-accordion-heading__toggle"><span class="wp-block-accordion-heading__toggle-title"><?php echo esc_html__( 'Do you offer ongoing support?', 'starter' ); ?></span><span class="wp-block-accordion-heading__toggle-icon" aria-hidden="true">+</span></button></h3>
<!-- /wp:accordion-heading -->

<!-- wp:accordion-panel -->
<div class="wp-block-accordion-panel" role="region"><!-- wp:paragraph -->
<p><?php echo esc_html__( 'Replace this answer with real content.', 'starter' ); ?></p>
<!-- /wp:paragraph --></div>
<!-- /wp:accordion-panel --></div>
<!-- /wp:accordion-item --></div>
<!-- /wp:accordion -->
