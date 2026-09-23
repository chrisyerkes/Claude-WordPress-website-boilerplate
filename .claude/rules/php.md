---
description: WordPress PHP conventions for this theme and its companion plugin.
paths:
  - "**/*.php"
---

# PHP conventions

Target: WordPress 7.0+, PHP 8.1+ (8.3 recommended).

## Non-negotiable

- **Escape every output.** `esc_html()`, `esc_attr()`, `esc_url()`, `wp_kses_post()`. No exceptions for "it's just a variable I set above".
- **Prefix everything.** Functions, hooks, classes, custom post types, options, transients, CSS handles. The prefix is the one in CLAUDE.md.
- Guard every file with `if ( ! defined( 'ABSPATH' ) ) { exit; }`.
- Tabs for indentation, WordPress Coding Standards spacing: `function foo( $bar )`, `array( 'key' => 'value' )`.
- Text domain on every translatable string, matching the theme's text domain.

## Hooks

- Register blocks, block styles, bindings sources, post types and taxonomies on `init`.
- Register abilities on `wp_abilities_api_init`, ability categories on `wp_abilities_api_categories_init`. Registering outside those hooks triggers `_doing_it_wrong()`.
- Theme supports and `add_editor_style()` on `after_setup_theme`.
- ACF options pages on `acf/init`.

## Detecting ACF PRO

Use `function_exists( 'acf_add_options_page' )`. Options pages are PRO-only and current.

Do not use `function_exists( 'acf_register_block_type' )` — that function was deprecated in ACF 6.0 and testing for it reads as if the deprecated registration path is still in use.

## Post meta and Block Bindings

Meta exposed to the editor or to a bindings source must be registered with `show_in_rest => true` and must not start with an underscore. Protected and non-REST meta silently resolves to nothing through `core/post-meta`, which looks like a broken binding rather than a permissions problem.

## Things WordPress 7.0 changed

- `add_theme_support( 'html5', ... )` no longer does anything for the `script` and `style` sub-features. Harmless to leave for older-WP compatibility, but do not add them to new code.
- Author link functions no longer emit `title` attributes by default; `the_author_posts_link` now passes three arguments.
- Minimum PHP for WordPress itself is 7.4, but this project targets 8.1+ and may use typed properties, named arguments, match expressions and enums.
