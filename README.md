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

## Second patch: a nil-record panic (value check, not a fix to the upload path)

`015-nil-fileinfo-guard.patch` guards two handlers in `backend/internal/controllers/file.go`.
Both call `GetRedisFileInfo(r.FileId)`, check only the error, then dereference the result:

    fileInfo, err := filemodel.GetRedisFileInfo(r.FileId)
    if err != nil { ... }
    // then reads fileInfo.CreatedAt  (UploadFileSlice)
    //      or   fileInfo.FileType   (FinishUploadTask)

When no record exists for the id - an expired upload task, or an id never created -
`GetRedisFileInfo` returns `(nil, nil)`, so the handler panics. The client sees a bare 502 and the
UI says "upload failed, please try again"; the log shows

    http: panic serving ...: runtime error: invalid memory address or nil pointer dereference
    backend/internal/controllers.UploadFileSlice(...) file.go:130
    backend/internal/controllers.FinishUploadTask(...) file.go:185

The fix is a nil check in both handlers returning the expired-task error. Verified locally: the same
request now answers `400 {"message":"UploadTaskExpired"}`.

## Building both

    PATCH=$PWD/015-upload-speed-fix.patch bash apply-and-build.sh 0.14.0

`apply-and-build.sh` takes a single patch; concatenate the two files to carry both, or apply them in
sequence to a checkout. It dry-runs first and refuses to build if the patch no longer applies.
