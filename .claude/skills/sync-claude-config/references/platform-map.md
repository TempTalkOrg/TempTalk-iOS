# Platform Adaptation Map

## Substitution Table

| Category | Android/Kotlin | iOS/Swift |
|----------|---------------|-----------|
| Language | `.kt`, `kotlin`, `Kotlin` | `.swift`, `swift`, `Swift` |
| Functions | `fun functionName` | `func functionName` |
| Build | `build.gradle.kts`, `gradle` | `Podfile`, `xcodebuild`, `fastlane` |
| Architecture | MVI, Compose | MVVM, UIKit |
| Async | Coroutines, Flow | async/await, Combine |
| DI | Hilt/Dagger | Manual DI / Protocol-based |
| Theme | `DifftTheme` | `Theme` |
| Module paths | `:app`, `:core`, `:feature` | `TempTalk/src/`, `TTServiceKit/`, `TTMessaging/` |
| CI triggers | `/wea_insider`, `/cc_insider` | `/tt_tf`, `/tt_tf online` |
| Repo | `difftim/difft-android` | `difftim/TempTalk-iOS` |
| Logs | ADB logcat, tombstones | Console.app, crash logs |
| Package ID | `org.difft.wea` | Bundle ID (org.difft.chative) |

## Skip List (Never Port)

| Android-only | iOS-only |
|-------------|----------|
| `log-analyze/` (ADB) | — |
| `verify-apk/` | — |
| `log-collect.sh` (ADB) | — |
| `query-anrs.md` (ANR) | — |
| Tombstone/ANR analysis | Watchdog termination analysis |
