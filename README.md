# opt-image

A small command-line image optimizer for macOS. It resizes, optionally reduces
colors, optionally stamps a signature, and re-encodes images with free,
arm64-native CLI tools — no GUI app required.

`opt-image` replaces an older script that offloaded optimization to
[Optimage.app](https://optimage.app/), which is no longer maintained and runs
only under Rosetta 2. See [`docs/HANDOFF.md`](docs/HANDOFF.md) for the full
background.

## How it works

The right tool depends on whether the image tolerates **lossy** compression:

| Use case | Format | Best for | Pipeline |
|---|---|---|---|
| **Lossy** | JPEG | photos, gradients | `magick` → `cjpeg` (mozjpeg) |
| **Lossless** | WebP | illustrations, logos, screenshots | `magick` → `cwebp -lossless` |
| **Lossless** | PNG | same, max compatibility | `magick` → `oxipng` |

For the lossless path you can also **reduce the color count** (`-c`) to shrink
the file further. Output is always 8-bit. See
[`docs/USAGE.md`](docs/USAGE.md) for the rationale and detailed use cases.

## Requirements

All dependencies are free and arm64-native (no Rosetta):

```sh
brew install imagemagick mozjpeg webp oxipng
```

| Tool | Used for |
|---|---|
| `magick` (ImageMagick 7) | resize, signature, color reduction |
| `cjpeg` (mozjpeg, keg-only) | JPEG encoding |
| `cwebp` (webp) | WebP encoding |
| `oxipng` | PNG optimization |

`mozjpeg` is keg-only; `opt-image` finds it automatically at
`/opt/homebrew/opt/mozjpeg/bin/cjpeg`.

## Install

Put the `opt-image` script somewhere on your `PATH`:

```sh
install -m 0755 opt-image ~/bin/opt-image   # or any dir on $PATH
```

## Usage

```
opt-image [options] <input-image>
```

| Option | Meaning | Default |
|---|---|---|
| `-f <jpg\|webp\|png>` | output format (jpg = lossy, webp/png = lossless) | `jpg` |
| `-c <2\|16\|125\|256\|4096>` | reduce colors (webp/png only) | none |
| `-p <pixels>` | resize long edge to `<pixels>` (shrink only, never upscales) | `1800` |
| `-n` | do not resize | — |
| `-s <white\|dark>` | add signature text (white / dark) | — |
| `-h` | show help | — |

### Examples

```sh
# Photo → optimized JPEG, fit within 1800px (default)
opt-image photo.jpg

# Photo with a dark signature, capped at 1600px
opt-image -f jpg -p 1600 -s dark photo.jpg

# Illustration → lossless WebP, reduced to 256 colors
opt-image -f webp -c 256 illustration.png

# Screenshot → optimized PNG, keep full resolution
opt-image -f png -n screenshot.png

# Black-and-white line art → 2-color PNG
opt-image -f png -c 2 lineart.png
```

### Behavior notes

- The original file is **overwritten in place**; a backup is kept as
  `<input>.bak`. If the format changes, the extension changes too
  (`photo.png` → `photo.jpg`, with `photo.png.bak` left behind).
- Resize is **shrink-only**: images smaller than the target are left as-is.
- Validation failures (bad `-c`, unknown format, etc.) exit non-zero **before**
  touching the input.

### Environment overrides

| Variable | Purpose | Default |
|---|---|---|
| `OPT_IMAGE_SIG1` / `OPT_IMAGE_SIG2` | signature text (two lines) | `© 2026 Toshiyuki Yoshida` / `CC BY-NC-SA 4.0` |
| `OPT_IMAGE_FONT` | signature font path | `/System/Library/Fonts/Supplemental/Arial.ttf` |
| `OPT_IMAGE_JPEG_QUALITY` | JPEG quality for `cjpeg` | `85` |
| `OPT_IMAGE_PIXELS` | default resize long edge | `1800` |
| `MAGICK` / `CJPEG` / `CWEBP` / `OXIPNG` | override tool paths | auto-detected |

> **Changing the signature:** the default name/license is set in the
> **user-settings block at the top of the `opt-image` script** — edit it there,
> or override per-run with `OPT_IMAGE_SIG1` / `OPT_IMAGE_SIG2` without touching
> the source.
>
> ImageMagick on this platform is built without fontconfig, so a font path must
> be given explicitly for the signature. `opt-image` defaults to Arial; override
> with `OPT_IMAGE_FONT` if needed.

## Tests

Automated tests use [bats-core](https://github.com/bats-core/bats-core):

```sh
brew install bats-core
bats test/
```

See [`docs/TEST-CASES.md`](docs/TEST-CASES.md) for the case catalog and
[`test/README.md`](test/README.md) for the implementation contract.

## License

See [`LICENSE`](LICENSE).
