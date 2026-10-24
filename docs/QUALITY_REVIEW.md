# Visual conversion review

Real engine outputs and comparison images are in [quality/](quality/). Regenerate them with the developer commands in the README. These are conversions of actual pixels, not sample strings or stand-ins.

The reviewed corpus covers a NASA portrait, Chelsea the cat, an outdoor rocket/sky scene, a typographic logo, thin line drawings, a darkened portrait, and an RGBA image with fully transparent colored pixels. An additional WebP rendition checks the pure Dart decoder. Each has 100-column silhouette, smooth-shading, dense-detail, block, and dithered Braille outputs. Counts and source paths are recorded in [manifest.json](quality/manifest.json).

| Source | Observed result | Practical limitation |
| --- | --- | --- |
| Portrait | Face, hair, collar, suit, and helmet remain distinguishable. Dense ASCII gives more tonal steps; blocks give stronger masses. | Eyes, teeth, and small facial contours need enough columns. No facial reconstruction is performed. |
| Pet | Both eyes and the nose remain located correctly; whiskers become partial thin strokes. | Fur can look busy with a dense ramp or dithering. A tight crop and more columns help. |
| Outdoor/sky | Sky gradient, central rocket, and bright lamps remain visible. | Narrow towers lose continuity in coarse ASCII; contrast can flatten the dark sky. |
| Logo | Large @ and G shapes stay readable. Block and Braille modes make the silhouette most apparent. | Text cells still quantize rounded edges. This is not a vector trace. |
| Line drawing | Circle and diagonal strokes survive, with Braille giving finer spatial steps. | Thin strokes can break when downsampled. Edge enhancement is capped to avoid strong halos. |
| Dark image | Dark masses and some separation survive in detailed ASCII. The silhouette preset clips most shadow differences. | Lower contrast, then raise brightness/gamma. Clipped or absent detail cannot be recovered. |
| Transparent PNG | Hidden magenta RGB does not leak into the white background or edges. Visible eyes and smile remain. | Matte choice is deliberate: black, gray, or white produces different art. |

Character-cell correction uses `rows = round(imageHeight / imageWidth × columns × cellAspect)`. With the default 0.5 aspect, 100 columns use 50 rows for a square source. Braille samples twice as many columns and four times as many rows before encoding each cell. Glyph appearance in the receiving app is outside this engine's control.

The ASCII calibration measures antialiased ink area in the bundled font and normalizes it to the densest selected glyph. This is a useful tone model, not a universal perceptual guarantee. Custom ramps use the user's light-to-dense order. Unicode shading blocks use nominal quarter-density steps. All output keeps full row widths, including trailing spaces.

The app's zoom and background controls are display transforms. They do not change text, line lengths, whitespace, or exported bytes. The supplied reference image is available as a bundled offline sample; review fixtures are not application assets.
