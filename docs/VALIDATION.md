# Completed verification

Verified on **2026-10-22** using Flutter 3.47.0, Dart 3.13.0, Windows 11, the installed Android SDK, and the `Pixel_7_API_35` Android 15 x86_64 emulator. These results describe this environment, not all devices or receiving apps.

## Automated checks

| Check | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test integration_test tool` | 29 Dart files already formatted; zero changes |
| `flutter analyze --no-pub` | No issues; exit 0 |
| `flutter test --no-pub` | **25 tests passed** |
| `flutter test integration_test/offline_workflow_test.dart -d emulator-5554 --no-pub` | **1 integration test passed**, exit 0, with emulator airplane mode enabled |
| Android release | `flutter build apk --release` succeeded; exit 0; min SDK 24, target/compile SDK 36 |
| Windows release | `flutter build windows --release` succeeded; exit 0 |

Raw test and build logs are local artifacts excluded from Git. This report, the linked screenshots, and the exported text samples retain the verification record in the source repository. During the 2026-10-24 repository cleanup, existing logs and delivery packages were moved to a sibling local archive outside the source folder.

The integration test recreates the SQLite connection and application controller after saving. This verifies durable history rather than merely reusing in-memory models. A separate release-APK force-stop/relaunch check verified the renamed, favorited artwork in Saved.

## Android release smoke, entirely offline

Airplane mode was enabled using `adb shell cmd connectivity airplane-mode enable`, with Wi-Fi and mobile data disabled. Status-bar airplane indicators are visible in the screenshots. No account login, authenticated social operation, or automatic sending was performed.

| Operation | Observed evidence |
| --- | --- |
| First use and Home | Welcome, onboarding persistence, native screens, dark system theme, then explicit light theme. [Welcome](screenshots/01-welcome.png), [light Home](screenshots/12-home-light.png) |
| Gallery import | Android Photo Picker selected the locally staged philosopher PNG. Preparation displayed corrected 1024 × 1024 dimensions. [Preparation](screenshots/03-prepare.png) |
| Style and conversion | Live 56-column preview; final 100 × 50 detailed ASCII output with 5,049 characters. [Style](screenshots/04-style.png), [result](screenshots/05-result.png) |
| Rename and favorite | Renamed to Philosopher and favorited. Both persisted after force-stop and relaunch. [History after restart](screenshots/11-history-restart.png) |
| Native Save As | Android document picker saved `Philosopher.txt` in Downloads. Pulled bytes were decoded as UTF-8 and compared against an independently rendered original: **exact match, 5,049 code points, 50 lines, 5,049 bytes**. [Export sheet](screenshots/06-export.png), [save picker](screenshots/07-save-picker.png), [saved text](screenshots/Philosopher.txt) |
| Cancelled save | Back from the native document picker produced **“Save cancelled. No file was saved.”** [Cancellation](screenshots/10-save-cancelled.png) |
| Share text | Opened Android's text share sheet with generated artwork. No destination was selected. [Text share](screenshots/08-share-text.png) |
| Share .txt | Opened Android's file share sheet with `Philosopher.txt`. No destination was selected. [File share](screenshots/09-share-file.png) |
| File import / WebP | Native Files selected `glyphica-test.webp`; local preparation decoded it as 320 × 320. [WebP import](screenshots/13-webp-import.png) |
| Braille preview and export | Rendered 100 × 50 Braille cells with the bundled dot font. Saved `glyphica-test.txt` through the native document picker. Independent byte comparison: **exact match, 5,049 code points, 50 lines, 15,049 UTF-8 bytes**. [Braille result](screenshots/14-braille-result.png), [exported text](screenshots/Portrait-Braille.txt) |
| Destination compatibility | Discord suggested a separate 56-column ASCII variant. Keep detail restored the original 100-column Braille text, warned about its 5,057 wrapped units, and split it into three complete-line parts. Labels and fences were included: the first part had **1,935 units / 2,000**. Copy-per-part and part navigation worked; the destination variant saved separately. [Budget warning](screenshots/15-destination-budget.png), [parts](screenshots/16-destination-parts.png) |
| Fit to message | Re-rendered an independent 62-column × 31-line Braille variant: **1,952 characters, 1,960 units including fences / 2,000**. The original stayed at 100 × 50. [Fit result](screenshots/17-fit-to-message.png) |

The clipboard is verified exactly in the Android integration test, and Unicode/space/line preservation is additionally covered through the platform-channel unit test. UTF-8 exports of both ASCII and Braille were compared to source-engine output after native document-picker saves, using `tool/verify_export.dart`.

```powershell
dart run tool/verify_export.dart docs/screenshots/Philosopher.txt
dart run tool/verify_export.dart docs/screenshots/Portrait-Braille.txt test/fixtures/format.webp braille
```

`aapt dump permissions` on the release APK reports only the app's generated `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`; **no INTERNET permission** is requested. Android backup is disabled. The release artifact is a universal APK for ARMv7, ARM64, and x86_64, using the local debug signing key for evaluation.

## Visual quality and limits

Forty real engine outputs were generated from eight fixtures and inspected across silhouette, shading, detailed ASCII, block, and Braille styles. The corpus includes the requested portrait, pet, outdoor scene, logo, line drawing, dark image, and transparent PNG categories, plus a WebP decoder fixture. [Quality observations](QUALITY_REVIEW.md) record both preserved features and failures of coarse text resolution.

Final polish also adds a destination shortcut in the result app bar, a bundled font fallback in Braille palette/custom-ramp controls, correct singular/plural history wording, and static busy feedback when reduced motion is enabled. The integration test was rerun after these changes.

The final packaged release APK was reinstalled and its sample import → conversion → saved result path was checked again, including the new app-bar destination shortcut. [Final release screen](screenshots/18-final-release.png).

Not established by these checks: physical-phone performance or memory endurance, actual camera capture, iOS compilation/runtime behavior, Windows native picker/share runtime behavior, HDR/ICC color fidelity, third-party social-app rendering or exact platform maxima, recipients' glyph fonts, or delivery of any shared message. Numerical destination defaults remain explicitly adjustable estimates. The Windows release was compiled and packaged with its required assets/DLLs; iOS needs a macOS/Xcode build and device acceptance.

The Flutter SDK's `--no-pub` release-plugin registration failure was reproduced and resolved by using the normal release build command. No test plugin was moved into production dependencies. See the [official Flutter issue](https://github.com/flutter/flutter/issues/169336).

## Delivery

The 2026-10-22 delivery produced an installable evaluation APK, a complete Windows release ZIP, a source-project ZIP, and SHA-256 checksums. These generated packages are kept outside the Git source tree. After building Android and Windows releases, `python tool/package_delivery.py` recreates them under the ignored `dist/` directory. The source archive excludes generated build caches, local SDK paths, signing material, and the original design-reference directory. The supplied offline sample, licensed fonts, test fixtures, source, native hosts, tests, documentation, and regeneration scripts are included.
