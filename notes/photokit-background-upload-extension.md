---
title: PhotoKit background upload extension — evaluation for cairn
date: 2026-10-19
status: evaluated; not adopting
---

# PhotoKit background upload extension

An Immich GitHub comment noted that "iOS 27 added a PhotoKit background
upload extension." This note records what the API is and why cairn
doesn't use it. API details come from the iOS 27.1 SDK headers
(`Photos.framework`: `PHAssetResourceUploadJob.h`,
`PHAssetResourceUploadJobChangeRequest.h`, `PHPhotoLibrary.h`, and the
Swift interface), not from Apple's prose docs, which render client-side
and don't fetch.

## What it is

- **iOS 26.1** introduced the `com.apple.photos.background-upload`
  extension point. The system invokes the extension on its own schedule;
  the extension enqueues `PHAssetResourceUploadJob`s through
  `PHAssetResourceUploadJobChangeRequest`. A job is one
  `PHAssetResource` plus a destination `NSURLRequest`, and the system
  performs the upload even while the app is suspended or the device is
  locked.
- The host app turns the feature on via `PHPhotoLibrary`, and it requires
  full library access. Unacknowledged jobs are capped at
  `PHAssetResourceUploadJob.jobLimit`; the extension must acknowledge or
  retry finished jobs to free slots.
- **iOS 26.4** added `responseHeaderFields`, `error`, `cancel()`, and a
  download-only job type (`creationRequestForDownloadJob(resource:)`),
  which pulls an iCloud original onto the device without uploading it.
  The system may purge the downloaded copy later.
- **iOS 27** deprecated `PHBackgroundResourceUploadExtension`
  (`process()` / `notifyTermination()`) in favor of
  `PHBackgroundResourceUploadJobExtension` (async `processJobs()` /
  `willTerminate()`). It also replaced `setUploadJobExtensionEnabled` with
  `enableUploadJobExtension(options:)` / `disableUploadJobExtension()`,
  added `PHAssetResourceUploadJobOptions.preventsExpensiveNetworkAccess`
  (Wi-Fi-only), and added `PHAssetResource.assetResource(forUploadJob:)`.
  The iOS 27 comment refers to this revision of the 26.1 feature.
- The upload body is the raw resource bytes only. Immich's upload
  endpoint needs multipart form fields (`deviceAssetId`, `deviceId`), so
  the Immich app hasn't adopted it
  ([immich#23245](https://github.com/immich-app/immich/discussions/23245)).

## Why cairn doesn't use it

- **cairn doesn't upload.** The API is a system-managed upload queue.
  cairn's network work is tagging and trashing on the Immich server,
  which the API can't express.
- **Using it as a background wake is a bad bet.** In principle the
  extension could check for deletions (`fetchPersistentChanges`) and
  drain the trash queue when the system launches it. Against that:
  - The headers don't say when the system launches the extension.
  - cairn would need an App Group to share its SwiftData stores with the
    extension.
  - Using an upload extension for anything else invites App Review
    rejection under guideline 2.5.4 (background services only for their
    intended purpose).
  - Users would see it as "background upload", which misdescribes cairn.
- **The closest real fit is the download-only job type.** It could
  pre-fetch iCloud originals for the hash backlog that the
  `app.cairn.hash` `BGProcessingTask` currently handles. It isn't worth a
  new extension target on its own: it works only from inside the
  extension, the system may purge the download, and it carries the same
  "background upload" framing.

## Worth watching

If the Immich app or a third-party uploader (e.g. YAIIU) moves to this
API, check which `PHAssetResource` it uploads. If it isn't the original,
the server-side SHA1 won't match the checksum cairn computes on the
phone, and reconciliation will treat those assets as unmatched.

## Sources

- iOS 27.1 SDK, `Photos.framework` headers and Swift interface (Xcode 27.1).
- [immich#23245](https://github.com/immich-app/immich/discussions/23245) — the two limitations blocking Immich adoption.
- [immich#23358](https://github.com/immich-app/immich/discussions/23358) — original feature request.
- [nextcloud/ios#4279](https://github.com/nextcloud/ios/pull/4279) — a shipping iOS 27 adoption.
- [FawenYo/YAIIU#78](https://github.com/FawenYo/YAIIU/pull/78) — an Immich uploader adopting the iOS 27 extension.
