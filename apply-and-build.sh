#!/usr/bin/env bash
# Rebuild our patched 015 image from an upstream release.
#
#   sudo bash /srv/share/patches/apply-and-build.sh 0.14.0
#
# What it does, in order: fetch upstream source at the given ref, apply the upload-speed patch,
# build the image, tag it as hestia/015:<ref>-speedfix. Nothing upstream is modified - this is
# our own local image, built from their code plus one reviewed patch.
#
# To go back to their stock image, point /srv/share/compose.yaml at fudaoyuanicu/015-app:<tag>
# and recreate. A copy of the previous compose is kept as compose.yaml.bak-*.
set -euo pipefail

REF="${1:?usage: apply-and-build.sh <upstream ref, e.g. 0.14.0>}"
PATCH="${PATCH:-/srv/share/patches/015-upload-speed-fix.patch}"
WORK="/tmp/015-build-${REF}"
TAG="hestia/015:${REF}-speedfix"

[[ -f "$PATCH" ]] || { echo "patch not found: $PATCH"; exit 1; }

echo "== fetching upstream $REF =="
rm -rf "$WORK"; mkdir -p "$WORK"
curl -sL "https://codeload.github.com/keven1024/015/tar.gz/refs/tags/${REF}" \
  | tar xz -C "$WORK" --strip-components=1
cd "$WORK"

echo "== checking the patch still applies cleanly (upstream may have drifted) =="
if ! patch -p1 --dry-run < "$PATCH"; then
  echo
  echo "The patch no longer applies as-is. Inspect the file it touches:"
  echo "  front/components/Home/File/FileUploadProgressView/index.vue"
  echo "Nothing was changed and no image was built."
  exit 1
fi

echo "== applying =="
patch -p1 < "$PATCH"

echo "== building $TAG =="
docker build -t "$TAG" .

echo
echo "Built $TAG. To use it, set that tag in /srv/share/compose.yaml and recreate:"
echo "  cd /srv/share && docker compose up -d"
