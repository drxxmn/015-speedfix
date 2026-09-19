# 015-speedfix

A one-file patch for [015](https://github.com/keven1024/015) (self-hosted temporary file sharing)
that makes the upload speed readout work.

## The bug

The upload progress view reads the transfer rate from `progressEvent.rate` on the axios
upload-progress event. In a browser that field is never populated - the native `ProgressEvent`
carries only `loaded` and `total` - so each sample is stored as `0`, the display sums those
samples, and the readout stays at `0 B/s` no matter how fast the transfer actually is. The
percentage still advances, which is why it reads as a cosmetic oddity rather than a bug.

## The fix

Ignore `progressEvent.rate`. On each completed chunk, spread that chunk's byte count across the
seconds it actually took; 015's existing per-second chart then displays a real rate. Roughly
twelve lines, one file, no display code touched.

## Apply it

```
curl -sL https://codeload.github.com/keven1024/015/tar.gz/refs/tags/0.14.0 | tar xz --strip-components=1 -C 015
cd 015 && patch -p1 < 015-upload-speed-fix.patch
docker build -t 015:0.14.0-speedfix .
```

Or use `apply-and-build.sh`, which fetches, dry-runs the patch (refusing cleanly if your source
has drifted), applies and builds:

```
PATCH=$PWD/015-upload-speed-fix.patch bash apply-and-build.sh 0.14.0
```

Then point your compose file at the new image and recreate. **Hard-refresh the browser
afterwards** - the frontend JS is cached, and the old bundle will keep showing `0 B/s`.

## Versions

Written against **0.14.0** (the newest upstream git tag; 0.14.1 exists only as a published image).
The change is small and self-contained, so rebasing onto another tag is straightforward - send the
tag if `patch` refuses to apply.

## Licence

015 is **AGPL-3.0**, and this patch is a modification of it. This repository exists so that the
corresponding source is available to anyone who uses a build of it, as that licence requires. The
patch is offered under the same terms. All credit for 015 itself belongs to its author.
