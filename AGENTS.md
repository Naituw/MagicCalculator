# AGENTS.md

## Cursor Cloud specific instructions

### Project Overview

MagicCalculator is a dual-platform (iOS + Android) magic trick calculator app for the 2026 Chinese New Year Gala. It has **no backend services** — purely native mobile apps.

- **iOS**: Swift/UIKit in `MagicCalculator/` + `MagicCalculator.xcodeproj/` — requires macOS + Xcode, cannot build on Linux.
- **Android**: Kotlin/Jetpack Compose in `Android/` — builds on Linux with JDK 21 + Android SDK.

### Environment Setup (Linux Cloud Agent)

Only the Android project can be built on the Linux Cloud Agent. The Android SDK is installed at `/opt/android-sdk` and environment variables (`ANDROID_HOME`, `PATH`) are configured in `~/.bashrc`.

The `gradle-wrapper.jar` is stored in Git LFS. If it shows as a text pointer file, run `git lfs pull` before building.

### Common Commands (Android)

All commands run from `/workspace/Android/`:

| Task | Command |
|------|---------|
| Build debug APK | `./gradlew assembleDebug` |
| Run unit tests | `./gradlew testDebugUnitTest` |
| Run lint | `./gradlew lintDebug` |
| Clean build | `./gradlew clean` |

### Gotchas

- **Git LFS required**: The `gradle-wrapper.jar` is tracked by Git LFS. If you see "Invalid or corrupt jarfile" when running `./gradlew`, run `git lfs pull` first.
- **AGP 9.0.1 + compileSdk 36.1**: The project uses a very recent Android Gradle Plugin version. Gradle will auto-download the correct SDK platform (36.1) on first build if only 36 is installed.
- **No iOS on Linux**: The iOS target requires macOS with Xcode. Do not attempt to build it on Linux.
- **No backend/services**: This is a fully offline mobile app. No databases, APIs, or Docker services needed.
