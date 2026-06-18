# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-06-18

Initial release: a rewrite of the old Optimage-dependent script into a
self-contained CLI built on free, arm64-native tools.

### Added

- `opt-image` CLI with format-driven pipelines:
  - `-f jpg` — lossy JPEG via mozjpeg (`cjpeg`).
  - `-f webp` — lossless WebP via `cwebp -lossless -exact`.
  - `-f png` — lossless PNG via `oxipng`.
- Optional color reduction `-c` (`2`, `16`, `125`, `256`, `4096`) for the
  lossless formats, with allow-list validation.
- Resize `-p` (shrink-only, never upscales) and `-n` to skip resizing.
- Signature `-s <white|dark>` with name/license configurable in the script's
  user-settings block or via `OPT_IMAGE_SIG1` / `OPT_IMAGE_SIG2`.
- In-place overwrite with a `.bak` backup; validation failures exit before
  touching the input.
- Environment overrides: `OPT_IMAGE_JPEG_QUALITY`, `OPT_IMAGE_FONT`,
  `OPT_IMAGE_PIXELS`, and tool paths `MAGICK` / `CJPEG` / `CWEBP` / `OXIPNG`.
- bats test suite (`test/opt-image.bats`, 35 cases) and fixtures.
- Documentation: `README.md`, `docs/USAGE.md`, `docs/TEST-CASES.md`,
  `docs/HANDOFF.md`.

### Notes

- Output is normalized to 8-bit; for webp/png "lossless" means lossless at
  8-bit (webp cannot hold more), avoiding a 16→8 bit conversion mismatch.
- Replaces the dependency on Optimage.app, which is unmaintained and
  Rosetta-only.

[0.1.0]: https://github.com/yostos/opt-image/releases/tag/v0.1.0
