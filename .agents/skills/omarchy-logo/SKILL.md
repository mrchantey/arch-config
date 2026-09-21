---
name: omarchy-logo
description: >
  Generate print-ready 3840x2160 PNG sheets of eight colorized Omarchy logos.
  Use when the user wants to make Omarchy logo art for printing (stickers,
  posters), define new logo colorways, or run/edit the logo generator.
  Triggers: "generate omarchy logos", "omarchy logo png", "logo print sheet",
  "new logo colorway/variant", "rainbow omarchy logos". Each colorway paints
  the logo as solid, equal-height horizontal bars, one per color, top to bottom.
---

# Omarchy Logo Generator

Produces a `3840x2160` transparent PNG containing **eight** colorized copies of the
Omarchy wordmark (2 columns x 4 rows), ready to print. Uses ImageMagick only, no
image-generation models.

## Layout

```
.agents/skills/omarchy-logo/
  generate.sh      # the generator
  <name>.json      # a colorway set (e.g. rainbows.json)
  SKILL.md
```

## Base logo

The white-glyphs-on-transparent template lives at:

```
~/Pictures/shared/omarchy-logo/template.png
```

It is also mirrored on S3 and auto-downloaded by `generate.sh` if the local file
is missing:

```
https://mrchantey-os.s3.us-west-2.amazonaws.com/pictures/omarchy-logo/template.png
```

The whole `~/Pictures/shared` tree syncs with the bucket's `pictures/` prefix via
`just push-pictures` / `just pull-pictures`, so publishing a changed template is just:

```
just push-pictures
```

## Defining a colorway set

Create `<name>.json` next to `generate.sh`. It is a JSON array of up to eight
variants; each variant is an array of hex colors painted as solid, equal-height
horizontal bars down the logo (first color = top band, last = bottom). One color
= a solid fill.

```json
[
  ["#ff2d2d", "#ff8c00", "#ffd500", "#33cc33", "#1e6fff", "#8a2be2"],
  ["#00f5d4", "#1e6fff", "#3a0ca3"],
  ["#4caf00"]
]
```

Fewer than eight variants leaves the remaining grid cells empty. See
`rainbows.json` for a worked example.

## Generating

```
.agents/skills/omarchy-logo/generate.sh <name>
```

e.g. `generate.sh rainbows` reads `rainbows.json` and writes:

```
~/Pictures/shared/omarchy-logo/<name>.png
```

## How it works (for edits)

1. Trim the base logo and keep its alpha channel as the glyph mask.
2. For each variant, stack the colors as a 1xN column and nearest-neighbour
   scale it to the logo size (solid, equal-height bars, no blending), then punch
   the glyph mask into it via `CopyOpacity`.
3. Compose all eight onto one transparent canvas in a **single** `magick`
   invocation.

Gotchas already handled in the script, keep them if you refactor:

- A plain `xc:none` canvas is typed **grayscale**; compositing through
  intermediate PNG writes desaturates the first layer. Everything is composed in
  one pipeline and forced to `-type TrueColorAlpha` to preserve color.
- The base PNG is grayscale+alpha; `identify -format "%w %h"` has no trailing
  newline, so `read` needs `\n` in the format string to not trip `set -e`.
- `-quiet` suppresses a harmless iCCP profile warning that otherwise returns
  non-zero under `set -e`.
