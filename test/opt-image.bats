#!/usr/bin/env bats
#
# opt-image automated tests (bats-core).
# Maps to docs/TEST-CASES.md / docs/USAGE.md; each case ID is kept in the title.
#
# Run:
#   bats test/                 # all cases
#   bats test/opt-image.bats   # this file
#
# Implementation contract these tests assume (match it when implementing opt-image):
#   - Test target is the executable `opt-image` (bash) at the repo root.
#     Override its path with the OPT_IMAGE env var.
#   - External tool paths can be overridden via env (T-01..03 depend on this):
#       MAGICK   (default: magick)
#       CJPEG    (default: /opt/homebrew/opt/mozjpeg/bin/cjpeg, else cjpeg on PATH)
#       CWEBP    (default: cwebp)
#       OXIPNG   (default: oxipng)
#       PNGQUANT (default: pngquant, optional)
#     When any is missing, exit non-zero and point to the install command.
#   - UC2 (webp/png) output is lossless (cwebp -lossless, png via oxipng).
#   - On validation failure, exit non-zero before changing the input
#     (no .bak, no intermediate files).
#   - Default format is jpg; default resize long edge is 1800.

OPT_IMAGE="${OPT_IMAGE:-$BATS_TEST_DIRNAME/../opt-image}"
FIX="$BATS_TEST_DIRNAME/../fixtures"

setup() {
  # Before the script exists, skip every case (TDD: auto-enabled once implemented).
  if [ ! -x "$OPT_IMAGE" ]; then
    skip "opt-image not implemented yet (TDD): $OPT_IMAGE"
  fi
  # Each test runs in its own tmp dir (the tool overwrites the input, so keep
  # the shared fixtures clean).
  cd "$BATS_TEST_TMPDIR"
}

# ---- Helpers ----------------------------------------------------------------

cpfix() { # cpfix <fixture> [as-name]
  local dst="${2:-$1}"
  cp "$FIX/$1" "$BATS_TEST_TMPDIR/$dst"
}

assert_success() { [ "$status" -eq 0 ] || { echo "expected success, got $status"; echo "$output"; return 1; }; }
assert_failure() { [ "$status" -ne 0 ] || { echo "expected failure, got 0"; echo "$output"; return 1; }; }
assert_file()    { [ -f "$1" ]        || { echo "missing file: $1"; return 1; }; }
refute_file()    { [ ! -e "$1" ]      || { echo "unexpected file: $1"; return 1; }; }
assert_output_contains() { case "$output" in *"$1"*) : ;; *) echo "output lacks '$1': $output"; return 1;; esac; }

long_edge()   { magick identify -format '%[fx:max(w,h)]' "$1" | cut -d. -f1; }
color_count() { magick identify -format '%k' "$1"; }
img_format()  { magick identify -format '%m' "$1"; }

assert_long_edge_le() { # <file> <max>
  local le; le="$(long_edge "$1")"
  [ "$le" -le "$2" ] || { echo "long edge $le > $2 ($1)"; return 1; }
}
assert_colors_le() { # <file> <max>
  local c; c="$(color_count "$1")"
  [ "$c" -le "$2" ] || { echo "colors $c > $2 ($1)"; return 1; }
}

# ============================================================================
# 1. Normal: UC1 lossy JPEG
# ============================================================================

@test "N-01: -f jpg optimizes JPEG, fits within 1800px, creates .bak" {
  cpfix photo.jpg
  run "$OPT_IMAGE" -f jpg photo.jpg
  assert_success
  assert_file photo.jpg
  assert_file photo.jpg.bak
  assert_long_edge_le photo.jpg 1800
}

@test "N-02: format defaults to jpg when -f omitted" {
  cpfix photo.jpg
  run "$OPT_IMAGE" photo.jpg
  assert_success
  assert_file photo.jpg
  assert_long_edge_le photo.jpg 1800
}

@test "N-03: -p 1200 sets resize long edge" {
  cpfix photo.jpg
  run "$OPT_IMAGE" -f jpg -p 1200 photo.jpg
  assert_success
  assert_long_edge_le photo.jpg 1200
}

@test "N-04: -n keeps original size (stays 2400px)" {
  cpfix photo.jpg
  run "$OPT_IMAGE" -f jpg -n photo.jpg
  assert_success
  [ "$(long_edge photo.jpg)" -eq 2400 ]
}

@test "N-05: -s white succeeds (white signature)" {
  cpfix photo.jpg
  run "$OPT_IMAGE" -f jpg -s white photo.jpg
  assert_success
  assert_file photo.jpg
}

@test "N-06: -s dark succeeds (dark signature)" {
  cpfix photo.jpg
  run "$OPT_IMAGE" -f jpg -s dark photo.jpg
  assert_success
  assert_file photo.jpg
}

# ============================================================================
# 2. Normal: UC2 lossless WebP / PNG
# ============================================================================

@test "N-07: -f webp without -c creates .webp, removes png, keeps .bak" {
  cpfix illust.png
  run "$OPT_IMAGE" -f webp illust.png
  assert_success
  assert_file illust.webp
  refute_file illust.png
  assert_file illust.png.bak
  [ "$(img_format illust.webp)" = "WEBP" ]
}

@test "N-08: -f webp -c 256 yields at most 256 colors" {
  cpfix illust.png
  run "$OPT_IMAGE" -f webp -c 256 illust.png
  assert_success
  assert_colors_le illust.webp 256
}

@test "N-09: -f png -c 4096 reduces a many-color image to <=4096 (magick -colors path)" {
  cpfix photo.jpg
  run "$OPT_IMAGE" -f png -c 4096 photo.jpg
  assert_success
  assert_file photo.png
  assert_colors_le photo.png 4096
}

@test "N-10: -f png -c 2 reduces line art to <=2 colors" {
  cpfix lineart.png
  run "$OPT_IMAGE" -f png -c 2 lineart.png
  assert_success
  assert_colors_le lineart.png 2
}

@test "N-11: all allowed -c boundary values succeed (2/16/125/256/4096)" {
  for c in 2 16 125 256 4096; do
    cpfix illust.png "in_$c.png"
    run "$OPT_IMAGE" -f png -c "$c" "in_$c.png"
    assert_success
    assert_file "in_$c.png"
  done
}

@test "N-13: shrink-only (does not upscale images smaller than 1800)" {
  cpfix illust.png   # 1200x800
  run "$OPT_IMAGE" -f png illust.png   # default 1800, no -n
  assert_success
  [ "$(long_edge illust.png)" -eq 1200 ] || { echo "upscaled: $(magick identify -format '%wx%h' illust.png)"; return 1; }
}

@test "N-12: resize + color reduction + signature combined" {
  cpfix illust.png
  run "$OPT_IMAGE" -f webp -c 256 -p 1000 -s dark illust.png
  assert_success
  assert_file illust.webp
  assert_long_edge_le illust.webp 1000
  assert_colors_le illust.webp 256
}

# ============================================================================
# 3. Errors: validation (must not damage the input)
# ============================================================================

@test "E-01: -c outside the allowed list (100) errors, input untouched" {
  cpfix illust.png
  run "$OPT_IMAGE" -f png -c 100 illust.png
  assert_failure
  assert_file illust.png
  refute_file illust.png.bak
}

@test "E-02: non-numeric -c errors" {
  cpfix illust.png
  run "$OPT_IMAGE" -f png -c abc illust.png
  assert_failure
}

@test "E-03: -c with jpg errors" {
  cpfix photo.jpg
  run "$OPT_IMAGE" -f jpg -c 256 photo.jpg
  assert_failure
}

@test "E-04: invalid format -f gif errors" {
  cpfix illust.png
  run "$OPT_IMAGE" -f gif illust.png
  assert_failure
}

@test "E-05: input file does not exist" {
  run "$OPT_IMAGE" -f jpg nonexistent.png
  assert_failure
}

@test "E-06: no arguments (input not given)" {
  run "$OPT_IMAGE" -f jpg
  assert_failure
}

@test "E-07: multiple inputs (only one accepted)" {
  cpfix illust.png a.png
  cpfix illust.png b.png
  run "$OPT_IMAGE" -f png -c 16 a.png b.png
  assert_failure
}

@test "E-08: unknown option" {
  cpfix photo.jpg
  run "$OPT_IMAGE" -x photo.jpg
  assert_failure
}

@test "E-09: invalid -s color (other than white/dark)" {
  cpfix photo.jpg
  run "$OPT_IMAGE" -f jpg -s blue photo.jpg
  assert_failure
}

@test "E-10: non-numeric -p" {
  cpfix photo.jpg
  run "$OPT_IMAGE" -f jpg -p abc photo.jpg
  assert_failure
}

# ============================================================================
# 4. Option interaction
# ============================================================================

@test "I-01: -n with -p prefers -n (no resize)" {
  cpfix photo.jpg
  run "$OPT_IMAGE" -f jpg -n -p 1000 photo.jpg
  assert_success
  [ "$(long_edge photo.jpg)" -eq 2400 ]
}

@test "I-02: -h shows help and does not process" {
  cpfix photo.jpg
  run "$OPT_IMAGE" -h -f jpg photo.jpg
  assert_success
  assert_output_contains "Usage"
  refute_file photo.jpg.bak
}

# ============================================================================
# 5. I/O and side effects
# ============================================================================

@test "O-01: backup keeps the pre-processing content" {
  cpfix photo.jpg
  run "$OPT_IMAGE" -f jpg photo.jpg
  assert_success
  assert_file photo.jpg.bak
  cmp -s "$FIX/photo.jpg" photo.jpg.bak || { echo ".bak does not match the original"; return 1; }
}

@test "O-02: on extension change, removes old png, creates new jpg, keeps png.bak" {
  cpfix illust.png
  run "$OPT_IMAGE" -f jpg illust.png
  assert_success
  assert_file illust.jpg
  refute_file illust.png
  assert_file illust.png.bak
}

@test "O-03: same-format overwrite replaces with the optimized version" {
  cpfix photo.jpg
  local before; before="$(wc -c < photo.jpg)"
  run "$OPT_IMAGE" -f jpg photo.jpg
  assert_success
  assert_file photo.jpg
  assert_file photo.jpg.bak
}

@test "O-04: broken input fails without destroying the original or leaving temp files" {
  cpfix broken.png
  run "$OPT_IMAGE" -f jpg broken.png
  assert_failure
  # Must be recoverable from broken.png or its .bak
  [ -f broken.png ] || [ -f broken.png.bak ] || { echo "input was lost"; return 1; }
  # Must not leave an intermediate file behind (loose check for fixed-path impls)
  refute_file image_processing.tmp
}

# ============================================================================
# 6. Regression (bugs in the old script)
# ============================================================================

@test "R-01: filenames with spaces are handled (old eval bug)" {
  cpfix "with space.png"
  run "$OPT_IMAGE" -f webp "with space.png"
  assert_success
  assert_file "with space.webp"
}

@test "R-02: signature © / special characters render without breaking" {
  cpfix illust.png
  run "$OPT_IMAGE" -f png -c 256 -s white illust.png
  assert_success
  assert_file illust.png
}

@test "R-03: -s dark alone works correctly (old -sd getopts bug)" {
  cpfix photo.jpg
  run "$OPT_IMAGE" -s dark photo.jpg
  assert_success
  assert_file photo.jpg
}

# ============================================================================
# 7. Missing-tool guidance (simulate absence by overriding tool paths via env)
# ============================================================================

@test "T-01: missing cjpeg (mozjpeg) errors with guidance" {
  cpfix photo.jpg
  CJPEG="/nonexistent/cjpeg" run "$OPT_IMAGE" -f jpg photo.jpg
  assert_failure
  assert_output_contains "mozjpeg"
}

@test "T-02: missing oxipng errors with guidance" {
  cpfix illust.png
  OXIPNG="/nonexistent/oxipng" run "$OPT_IMAGE" -f png -c 16 illust.png
  assert_failure
  assert_output_contains "oxipng"
}

@test "T-03: missing cwebp errors with guidance" {
  cpfix illust.png
  CWEBP="/nonexistent/cwebp" run "$OPT_IMAGE" -f webp illust.png
  assert_failure
  assert_output_contains "cwebp"
}
