/**
 * Navigation
 *
 * Handles mobile menu toggle, sticky header, and keyboard accessibility.
 * Expand as the project requires.
 */

document.addEventListener( 'DOMContentLoaded', () => {
	// Mobile menu toggle
	const menuToggle = document.querySelector( '.menu-toggle' );
	const primaryMenu = document.querySelector( '.primary-navigation' );

	if ( menuToggle && primaryMenu ) {
		menuToggle.addEventListener( 'click', () => {
			const isOpen = menuToggle.getAttribute( 'aria-expanded' ) === 'true';
			menuToggle.setAttribute( 'aria-expanded', ! isOpen );
			primaryMenu.classList.toggle( 'is-open' );
		} );
	}
} );
