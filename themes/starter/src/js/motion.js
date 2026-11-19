/**
 * Motion helpers
 *
 * CSS cannot transition to or from `height: auto`, so anything that expands
 * or collapses is animated here with the Web Animations API:
 *
 * - core/accordion panels. Core shows and hides them by toggling the
 *   `hidden` attribute (Interactivity API). A MutationObserver watches that
 *   attribute and animates the height change after the fact, so core's state
 *   handling, ARIA and keyboard support are untouched.
 * - core/details (<details>/<summary>). The summary click is intercepted so
 *   closing can animate before `open` is removed. Keyboard activation fires
 *   the same click event, so Enter and Space animate too.
 *
 * Visitors who prefer reduced motion get the instant default behaviour.
 * Durations match the --wp--custom--transition--base token (300ms).
 */

const DURATION = 300;
const EASING = 'cubic-bezier(0.2, 0.7, 0.2, 1)';

// Running animation per element, so a new one can cancel the last.
const running = new WeakMap();

const reduceMotion = window.matchMedia( '(prefers-reduced-motion: reduce)' );

/**
 * Animate an element's height between two pixel values.
 *
 * @param {HTMLElement} el       Element to animate.
 * @param {number}      from     Start height in px.
 * @param {number}      to       End height in px.
 * @param {Function}    [onDone] Called when the animation finishes (not when cancelled).
 * @return {Animation} The running animation.
 */
function animateHeight( el, from, to, onDone ) {
	running.get( el )?.cancel();

	const animation = el.animate(
		[
			{ height: `${ from }px`, overflow: 'clip' },
			{ height: `${ to }px`, overflow: 'clip' },
		],
		{ duration: DURATION, easing: EASING }
	);

	running.set( el, animation );
	animation.onfinish = () => {
		running.delete( el );
		onDone?.();
	};
	animation.oncancel = () => {
		running.delete( el );
	};

	return animation;
}

/**
 * Accordion panels: animate after core toggles `hidden`.
 *
 * @param {MutationRecord[]} records Attribute mutations.
 */
function onPanelMutation( records ) {
	if ( reduceMotion.matches ) {
		return;
	}

	for ( const { target: panel, oldValue } of records ) {
		const wasHidden = oldValue !== null;
		const isHidden = panel.hasAttribute( 'hidden' );

		if ( wasHidden === isHidden ) {
			continue;
		}

		if ( ! isHidden ) {
			// Opening: the panel is already laid out at full height.
			animateHeight( panel, 0, panel.offsetHeight );
			panel.animate( [ { opacity: 0 }, { opacity: 1 } ], { duration: DURATION, easing: EASING } );
			continue;
		}

		// Closing: core has hidden it already. Keep it displayed for the length
		// of the animation, then hand back to the hidden attribute.
		panel.style.display = 'flow-root';
		const from = panel.offsetHeight;
		panel.animate( [ { opacity: 1 }, { opacity: 0 } ], { duration: DURATION, easing: EASING } );
		const animation = animateHeight( panel, from, 0, () => panel.style.removeProperty( 'display' ) );
		animation.addEventListener( 'cancel', () => panel.style.removeProperty( 'display' ) );
	}
}

function initAccordions() {
	const panels = document.querySelectorAll( '.wp-block-accordion-panel' );

	if ( ! panels.length ) {
		return;
	}

	const observer = new MutationObserver( onPanelMutation );

	panels.forEach( ( panel ) => {
		observer.observe( panel, { attributes: true, attributeFilter: [ 'hidden' ], attributeOldValue: true } );
	} );
}

/**
 * <details>: animate open and closed.
 *
 * @param {HTMLDetailsElement} details The details element.
 */
function initDetails( details ) {
	const summary = details.querySelector( ':scope > summary' );

	if ( ! summary ) {
		return;
	}

	summary.addEventListener( 'click', ( event ) => {
		if ( reduceMotion.matches ) {
			return;
		}

		event.preventDefault();

		// The theme sets box-sizing: border-box, so the animated height is the
		// border box: closed height is the summary plus padding and borders.
		const style = getComputedStyle( details );
		const start = details.offsetHeight;
		const closed = summary.offsetHeight +
			parseFloat( style.paddingBlockStart ) +
			parseFloat( style.paddingBlockEnd ) +
			parseFloat( style.borderBlockStartWidth ) +
			parseFloat( style.borderBlockEndWidth );

		if ( details.open && ! details.classList.contains( 'is-closing' ) ) {
			details.classList.add( 'is-closing' );
			animateHeight( details, start, closed, () => {
				details.open = false;
				details.classList.remove( 'is-closing' );
			} );
			return;
		}

		details.classList.remove( 'is-closing' );
		details.open = true;
		animateHeight( details, start, details.offsetHeight );
	} );
}

function init() {
	initAccordions();
	document.querySelectorAll( 'details' ).forEach( initDetails );
}

if ( document.readyState === 'loading' ) {
	document.addEventListener( 'DOMContentLoaded', init );
} else {
	init();
}
