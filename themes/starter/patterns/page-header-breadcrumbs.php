<?php
/**
 * Title: Page Header with Breadcrumbs
 * Slug: starter/page-header-breadcrumbs
 * Categories: starter-components, header
 * Description: A page title with a breadcrumb trail above it, using the native Breadcrumbs block introduced in WordPress 7.0.
 * Keywords: breadcrumbs, header, title, navigation
 *
 * core/breadcrumbs is server-rendered and builds its trail from the site
 * hierarchy automatically — there is nothing to configure per page. To control
 * which taxonomy term represents a post, or to inject extra items, use the
 * block_core_breadcrumbs_post_type_settings and block_core_breadcrumbs_items
 * filters. Stubs for both are in inc/blocks.php.
 *
 * @package Starter
 */

?>
<!-- wp:group {"tagName":"header","style":{"spacing":{"padding":{"top":"var:preset|spacing|l","bottom":"var:preset|spacing|l"}}},"layout":{"type":"constrained"}} -->
<header class="wp-block-group" style="padding-top:var(--wp--preset--spacing--l);padding-bottom:var(--wp--preset--spacing--l)"><!-- wp:breadcrumbs /-->

<!-- wp:post-title {"level":1,"style":{"spacing":{"margin":{"top":"var:preset|spacing|xs"}}}} /--></header>
<!-- /wp:group -->
