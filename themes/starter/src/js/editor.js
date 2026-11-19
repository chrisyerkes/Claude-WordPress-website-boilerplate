/**
 * Block editor adjustments
 *
 * Core registers the Button block's "Fill" and "Outline" styles from its
 * block.json, so PHP's unregister_block_style() cannot remove them. The design
 * has two buttons, Primary (the default) and Secondary (registered in
 * inc/blocks.php), so the core styles are removed here to keep editors on brand.
 */

const { domReady, blocks } = window.wp;

domReady( () => {
	blocks.unregisterBlockStyle( 'core/button', [ 'fill', 'outline' ] );
} );
