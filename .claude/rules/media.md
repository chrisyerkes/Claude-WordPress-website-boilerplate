---
description: Images, icons and media — optimization, WebP, SVG, retina sizing.
paths:
  - "**/assets/images/**"
  - "**/assets/icons/**"
  - "**/includes/webp.php"
  - "**/includes/svg-uploads.php"
  - "build/optimize-images.mjs"
---

# Media

## Theme assets (assets/images, assets/icons)

- **Optimize before committing.** `node build/optimize-images.mjs <file...> --out <dir> [--width <px>] [--name <base>]` writes an optimized JPG (mozjpeg) or PNG (palette-quantized) plus a WebP sibling, and drops the WebP when it is not smaller. SVGs go through SVGO with the viewBox kept and scripts removed.
- **Export at 2x** the CSS display size (`--width` = 2 × display width) so images are sharp on retina screens.
- **Figma:** get asset URLs from the Figma MCP (`get_design_context`, `download_assets`) and download them with curl into the session scratchpad — curl is permitted for Figma asset URLs only (the one exception to the no-curl rule in CLAUDE.md; `Bash(curl *)` still prompts). Then optimize into the theme with `node build/optimize-images.mjs`. Never reference temporary Figma URLs, and never ship watermarked stock previews from a comp.
- **Icons are SVG files** in `assets/icons/`, `fill="currentColor"`, no fixed colours. Output inline with `starter_icon()`, or use as a CSS mask (see the button arrow in `components/_buttons.scss`). No icon fonts. The shipped `arrow-right-long.svg` is a plain placeholder arrow; replace it with the design's icon, and check that the icon licence covers the site.

## Media Library (companion plugin)

- **WebP** (`includes/webp.php`): every JPEG/PNG size gets a `{file}.webp` sibling at upload, kept only when smaller. Attachment images are wrapped in `<picture class="starter-webp">` with a WebP `<source>`; the theme sets that picture to `display: contents`, so layout and the `<img>` attributes are unchanged. Backfill older uploads with `node build/wp.mjs starter-webp generate` (the command is named after the theme slug).
- **SVG uploads** (`includes/svg-uploads.php`) are allowed and sanitized on upload (no DTDs, scripts, event handlers, external references or foreignObject). Width and height are read from the SVG so images do not shift layout.
- Give images real alt text in patterns; decorative images get `alt=""`.
