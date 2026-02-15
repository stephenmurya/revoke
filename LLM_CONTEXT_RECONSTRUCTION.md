# Revoke Mobile App - Context Reconstruction
Generated from repository scan at: c:\\Users\\USER\\Documents\\dev\\revoke
This file is designed to be pasted into a fresh LLM session.
Notes:
- Repo contains generated and vendor directories (build/, .dart_tool/, functions/node_modules/, .git/). These are not enumerated line-by-line here.
- Core application logic: Flutter (Dart) + Android native Kotlin + Firebase backend (Firestore + Cloud Functions + FCM).

## File/Dir Inventory (High-Level)
Top-level entries:
- `.dart_tool`
- `.firebaserc`
- `.flutter-plugins-dependencies`
- `.git`
- `.gitignore`
- `.idea`
- `.metadata`
- `analysis_options.yaml`
- `android`
- `assets`
- `build`
- `firebase.json`
- `firestore.indexes.json`
- `firestore.rules`
- `flutter_01.png`
- `flutter_02.png`
- `flutter_03.png`
- `flutter_launcher_icons.yaml`
- `functions`
- `generate_context_pack.ps1`
- `ios`
- `lib`
- `linux`
- `LLM_CONTEXT_RECONSTRUCTION.md`
- `macos`
- `policy.json`
- `prd`
- `pubspec.lock`
- `pubspec.yaml`
- `README.md`
- `revoke.iml`
- `test`
- `web`
- `windows`

Total file count (including generated/vendor):
- 23731 files
Per-directory file counts:
- `.git`: 3291 files
- `.dart_tool`: 89 files
- `build`: 14291 files
- `functions\\node_modules`: 5789 files
- `android`: 61 files
- `ios`: 51 files
- `lib`: 56 files
- `test`: 1 files
- `web`: 7 files
- `windows`: 18 files
- `macos`: 30 files
- `linux`: 10 files
- `assets`: 6 files
- `prd`: 2 files
- `functions`: 5794 files

Tracked/core file list (ripgrep respects ignore rules):
```text
analysis_options.yaml
android\app\build.gradle.kts
android\app\src\debug\AndroidManifest.xml
android\app\src\main\AndroidManifest.xml
android\app\src\main\kotlin\com\example\revoke\AppMonitorService.kt
android\app\src\main\kotlin\com\example\revoke\BootReceiver.kt
android\app\src\main\kotlin\com\example\revoke\MainActivity.kt
android\app\src\main\kotlin\com\example\revoke\ServiceRestartReceiver.kt
android\app\src\main\res\drawable\ic_lock_premium.xml
android\app\src\main\res\drawable\launch_background.xml
android\app\src\main\res\drawable-hdpi\ic_launcher_foreground.png
android\app\src\main\res\drawable-hdpi\notification_icon.png
android\app\src\main\res\drawable-mdpi\ic_launcher_foreground.png
android\app\src\main\res\drawable-mdpi\notification_icon.png
android\app\src\main\res\drawable-v21\launch_background.xml
android\app\src\main\res\drawable-xhdpi\ic_launcher_foreground.png
android\app\src\main\res\drawable-xhdpi\notification_icon.png
android\app\src\main\res\drawable-xxhdpi\ic_launcher_foreground.png
android\app\src\main\res\drawable-xxhdpi\notification_icon.png
android\app\src\main\res\drawable-xxxhdpi\ic_launcher_foreground.png
android\app\src\main\res\drawable-xxxhdpi\notification_icon.png
android\app\src\main\res\mipmap-anydpi-v26\ic_launcher.xml
android\app\src\main\res\mipmap-hdpi\ic_launcher.png
android\app\src\main\res\mipmap-mdpi\ic_launcher.png
android\app\src\main\res\mipmap-xhdpi\ic_launcher.png
android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png
android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png
android\app\src\main\res\raw\lookatthisdude.mp3
android\app\src\main\res\values\colors.xml
android\app\src\main\res\values\styles.xml
android\app\src\main\res\values-night\styles.xml
android\app\src\profile\AndroidManifest.xml
android\build.gradle.kts
android\gradle.properties
android\gradle\wrapper\gradle-wrapper.properties
android\settings.gradle.kts
assets\branding\icon_source.png
assets\branding\icon_source_primary_transparent.png
assets\branding\notification_icon.png
assets\fonts\NeueMontreal-Bold.otf
assets\fonts\NeueMontreal-Medium.otf
assets\fonts\NeueMontreal-Regular.otf
firebase.json
firestore.indexes.json
firestore.rules
flutter_01.png
flutter_02.png
flutter_03.png
flutter_launcher_icons.yaml
functions\index.js
functions\package.json
functions\package-lock.json
generate_context_pack.ps1
ios\Flutter\AppFrameworkInfo.plist
ios\Flutter\Debug.xcconfig
ios\Flutter\Release.xcconfig
ios\Runner.xcodeproj\project.pbxproj
ios\Runner.xcodeproj\project.xcworkspace\contents.xcworkspacedata
ios\Runner.xcodeproj\project.xcworkspace\xcshareddata\IDEWorkspaceChecks.plist
ios\Runner.xcodeproj\project.xcworkspace\xcshareddata\WorkspaceSettings.xcsettings
ios\Runner.xcodeproj\xcshareddata\xcschemes\Runner.xcscheme
ios\Runner.xcworkspace\contents.xcworkspacedata
ios\Runner.xcworkspace\xcshareddata\IDEWorkspaceChecks.plist
ios\Runner.xcworkspace\xcshareddata\WorkspaceSettings.xcsettings
ios\Runner\AppDelegate.swift
ios\Runner\Assets.xcassets\AppIcon.appiconset\Contents.json
ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-1024x1024@1x.png
ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@1x.png
ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@2x.png
ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@3x.png
ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@1x.png
ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@2x.png
ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@3x.png
ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@1x.png
ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@2x.png
ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@3x.png
ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-50x50@1x.png
ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-50x50@2x.png
ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-57x57@1x.png
ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-57x57@2x.png
ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@2x.png
ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@3x.png
ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-72x72@1x.png
ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-72x72@2x.png
ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-76x76@1x.png
ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-76x76@2x.png
ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-83.5x83.5@2x.png
ios\Runner\Assets.xcassets\LaunchImage.imageset\Contents.json
ios\Runner\Assets.xcassets\LaunchImage.imageset\LaunchImage.png
ios\Runner\Assets.xcassets\LaunchImage.imageset\LaunchImage@2x.png
ios\Runner\Assets.xcassets\LaunchImage.imageset\LaunchImage@3x.png
ios\Runner\Assets.xcassets\LaunchImage.imageset\README.md
ios\Runner\Base.lproj\LaunchScreen.storyboard
ios\Runner\Base.lproj\Main.storyboard
ios\Runner\Info.plist
ios\Runner\Runner-Bridging-Header.h
ios\RunnerTests\RunnerTests.swift
lib\core\app_router.dart
lib\core\models\plea_message_model.dart
lib\core\models\plea_model.dart
lib\core\models\schedule_model.dart
lib\core\models\squad_model.dart
lib\core\models\user_model.dart
lib\core\native_bridge.dart
lib\core\services\app_discovery_service.dart
lib\core\services\auth_service.dart
lib\core\services\notification_service.dart
lib\core\services\persistence_service.dart
lib\core\services\regime_service.dart
lib\core\services\schedule_service.dart
lib\core\services\scoring_service.dart
lib\core\services\squad_service.dart
lib\core\theme\app_theme.dart
lib\core\utils\app_categorizer.dart
lib\core\widgets\revoke_logo.dart
lib\core\widgets\revoke_progress_bar.dart
lib\features\admin\god_mode_dashboard.dart
lib\features\admin\sub_screens\adjust_score_screen.dart
lib\features\admin\sub_screens\admin_ledger_screen.dart
lib\features\admin\sub_screens\grant_amnesty_screen.dart
lib\features\admin\widgets\admin_user_directory.dart
lib\features\auth\onboarding_screen.dart
lib\features\home\focus_score_detail_screen.dart
lib\features\monitor\app_list_screen.dart
lib\features\monitor\create_schedule_screen.dart
lib\features\monitor\home_screen.dart
lib\features\monitor\widgets\focus_score_card.dart
lib\features\monitor\widgets\single_app_icon.dart
lib\features\navigation\main_shell.dart
lib\features\navigation\placeholder_screen.dart
lib\features\overlay\lock_screen.dart
lib\features\permissions\permission_screen.dart
lib\features\plea\plea_compose_screen.dart
lib\features\profile\profile_screen.dart
lib\features\regimes\regimes_screen.dart
lib\features\settings\controls_hub_screen.dart
lib\features\settings\pages\account_settings_page.dart
lib\features\settings\pages\advanced_settings_page.dart
lib\features\settings\pages\app_management_settings_page.dart
lib\features\settings\pages\appearance_settings_page.dart
lib\features\settings\pages\behavioural_settings_page.dart
lib\features\settings\pages\notification_settings_page.dart
lib\features\settings\pages\privacy_settings_page.dart
lib\features\settings\pages\squad_social_settings_page.dart
lib\features\splash\splash_screen.dart
lib\features\squad\squad_screen.dart
lib\features\squad\tribunal_screen.dart
lib\features\squad\widgets\chat_bubble.dart
lib\features\squad\widgets\plea_judgment_card.dart
lib\features\squad\widgets\squad_member_card.dart
lib\main.dart
linux\CMakeLists.txt
linux\flutter\CMakeLists.txt
linux\flutter\generated_plugin_registrant.cc
linux\flutter\generated_plugin_registrant.h
linux\flutter\generated_plugins.cmake
linux\runner\CMakeLists.txt
linux\runner\main.cc
linux\runner\my_application.cc
linux\runner\my_application.h
LLM_CONTEXT_RECONSTRUCTION.md
macos\Flutter\Flutter-Debug.xcconfig
macos\Flutter\Flutter-Release.xcconfig
macos\Flutter\GeneratedPluginRegistrant.swift
macos\Runner.xcodeproj\project.pbxproj
macos\Runner.xcodeproj\project.xcworkspace\xcshareddata\IDEWorkspaceChecks.plist
macos\Runner.xcodeproj\xcshareddata\xcschemes\Runner.xcscheme
macos\Runner.xcworkspace\contents.xcworkspacedata
macos\Runner.xcworkspace\xcshareddata\IDEWorkspaceChecks.plist
macos\Runner\AppDelegate.swift
macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_1024.png
macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_128.png
macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_16.png
macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_256.png
macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_32.png
macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_512.png
macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_64.png
macos\Runner\Assets.xcassets\AppIcon.appiconset\Contents.json
macos\Runner\Base.lproj\MainMenu.xib
macos\Runner\Configs\AppInfo.xcconfig
macos\Runner\Configs\Debug.xcconfig
macos\Runner\Configs\Release.xcconfig
macos\Runner\Configs\Warnings.xcconfig
macos\Runner\DebugProfile.entitlements
macos\Runner\Info.plist
macos\Runner\MainFlutterWindow.swift
macos\Runner\Release.entitlements
macos\RunnerTests\RunnerTests.swift
policy.json
prd\prd.md
prd\status.md
pubspec.lock
pubspec.yaml
README.md
test\widget_test.dart
web\favicon.png
web\icons\Icon-192.png
web\icons\Icon-512.png
web\icons\Icon-maskable-192.png
web\icons\Icon-maskable-512.png
web\index.html
web\manifest.json
windows\CMakeLists.txt
windows\flutter\CMakeLists.txt
windows\flutter\generated_plugin_registrant.cc
windows\flutter\generated_plugin_registrant.h
windows\flutter\generated_plugins.cmake
windows\runner\CMakeLists.txt
windows\runner\flutter_window.cpp
windows\runner\flutter_window.h
windows\runner\main.cpp
windows\runner\resource.h
windows\runner\resources\app_icon.ico
windows\runner\runner.exe.manifest
windows\runner\Runner.rc
windows\runner\utils.cpp
windows\runner\utils.h
windows\runner\win32_window.cpp
windows\runner\win32_window.h
```

## Canonical Documents
## `prd/prd.md`
```
# Project Revoke: Technical PRD (Re-baselined)

Version: 1.1 (Feb 2026)

Status: Active (Aligned to repository implementation)

Primary Platform: Android (iOS scaffolding exists; enforcement is Android-only)

Core Philosophy: Social accountability through friction and peer-governed access.

## 1. Executive Summary

Revoke is a discipline app with:

1. A hard enforcement layer on Android (Usage Stats + Overlay + Foreground Service).
2. A social governance layer (Squads + Tribunals) for temporary clearance.

When a blocked app is opened during an active regime, a native overlay blocks access. Users can request temporary clearance via a Tribunal where squad members attend, chat, and vote. Verdict resolution is server-authoritative.

## 2. Current Technical Stack

- Flutter app (routing via `go_router`).
- Firebase: Auth, Firestore, Cloud Functions (Node.js 22), FCM.
- Native Android: Kotlin foreground service (`AppMonitorService`) + overlay + MethodChannel bridge.
- State management: service-layer patterns (no Riverpod dependency in current implementation).

## 3. System Requirements (Current Baseline)

### 3.1 Android Enforcement

- Foreground service monitors foreground apps using `UsageStatsManager` and blocks restricted apps using an overlay.
- Adaptive polling:
  - 2s in high-risk situations (restricted app detected / immediately after a block).
  - 5s during an active schedule window.
  - 9s otherwise.
  - 10s and skip enforcement when screen is off.
- Boot persistence:
  - Service restarts on device boot (`BOOT_COMPLETED` receiver).
  - Best-effort restart strategy on service/task removal.
- Battery optimization:
  - App requires exemption from battery optimizations for reliability.

### 3.2 Regimes (Schedules)

- Users define regimes (time blocks and usage limits) and the apps affected.
- Regimes are cloud-synced and survive reinstall/new devices:
  - `/users/{uid}/regimes/{regimeId}`
- Native enforcement consumes regimes via MethodChannel schedule sync.

### 3.3 Squads

- Users create/join a squad via a code.
- Squad HUD shows member list and active Tribunal entry points.

### 3.4 Tribunals (Plea Sessions)

Terminology:
- A "plea" document is a Tribunal session.
- Attendance = `participants` list (users who enter or act in the room).
- Eligible voters = `participants` excluding `userId` (the requester).

Flow:
1. Requester composes plea (app icon, time chips, reason).
2. Server creates `/pleas/{pleaId}` and notifies squad members via FCM.
3. Members enter Tribunal, chat, and cast votes.
4. Server finalizes verdict and updates plea status.
5. If approved, requester receives a temporary unlock for the requested package and duration (enforced by native service).

Quorum:
- Attendance-based quorum is the global model.
- Completion condition: all eligible voters in `participants` have cast a vote.
- Tie-breaker: tie resolves to `rejected`.
- Timeout: stale active pleas auto-finalize on the server (tie/incomplete defaults to reject).

## 4. Backend Architecture (Current)

### 4.1 Firestore Collections

`/users/{uid}`
- `uid`, `email`, `fullName`, `nickname`
- `squadId`, `squadCode`
- `focusScore`
- `fcmToken`

`/users/{uid}/regimes/{regimeId}`
- `name`, `apps`, `daysOfWeek`, `startTime`, `endTime`, `isEnabled`
- Compatibility fields used by native sync (e.g., `targetApps`, `days`, `startHour`, etc.)

`/squads/{squadId}`
- `squadCode`, `creatorId`, `memberIds`

`/pleas/{pleaId}`
- `userId` (requester), `userName`
- `squadId`
- `appName`, `packageName`
- `durationMinutes`, `reason`
- `status`: `active | approved | rejected`
- `participants`: array of uids
- `votes`: map `{ uid: accept|reject }`
- `voteCounts`: map `{ accept: number, reject: number }`
- `createdAt`, `resolvedAt`
- lifecycle metadata: `markedForDeletion`, `deletionMarkedAt`, `outcomeSource`, etc.

`/pleas/{pleaId}/messages/{messageId}`
- `senderId`, `senderName`, `text`, `timestamp`
- optional `isSystem`

`/limits/{uid}` (anti-spam)
- rolling timestamp arrays and cooldown state for plea creation and messages

### 4.2 Cloud Functions (Server Authority)

Callables:
- `createPlea`
- `castVote`
- `joinPleaSession`
- `sendPleaMessage`
- `markPleaForDeletion`

Firestore triggers:
- `broadcastPleaCreated` (FCM fanout)
- `resolvePleaVerdict` (verdict finalizer)

Schedulers:
- `autoFinalizeStalePleas`
- `cleanupPleaData`

### 4.3 Security Model (Rules + Authority)

- Plea documents are server-only mutable (clients cannot create/update/delete `/pleas/{pleaId}`).
- Chat messages are sent via callable; direct client writes are blocked.
- User doc reads are restricted to self or same-squad.
- Regimes are read/write for self (and admin).

## 5. Admin ("God Mode") Baseline

- Admin is controlled by Firebase custom claim `admin: true`.
- Admin dashboard exists as a dedicated screen.
- Admin can view global stats and perform privileged operations via callables/privileged writes.

## 6. Planned Migration Milestones

P0:
- Optional migration to a vote subcollection model (Option A) for simpler integrity boundaries:
  - `/pleas/{pleaId}/votes/{uid}`
  - Aggregate counts and verdicts computed from vote docs.

P1:
- Stronger Android reliability on OEM-kill devices:
  - WorkManager fallback + stricter â€œservice runningâ€ UX gate.

P2:
- Reintroduce / prioritize previously drafted features if desired:
  - Vandalism (wallpaper), Simp Protocol, MAD heartbeat, leaderboards.


```

## `prd/status.md`
```
# Revoke Project Status

## Completed
- [x] Project Foundation & Permissions (Usage Stats, Overlay, Wallpaper, etc.)
- [x] Design System (Black/Orange base palette + centralized theme system)
- [x] Core Navigation Shell
- [x] App Discovery (Fetching installed user apps with icons)
- [x] Local Persistence (Saving restricted apps using SharedPreferences)
- [x] Usage Monitoring (Kotlin Foreground Service with polling logic)
- [x] Overlay Triggering (Native-to-Flutter communication via Broadcast & MethodChannel)
- [x] Fixed Android 14 FGS Crash (Added FOREGROUND_SERVICE_DATA_SYNC permission)
- [x] App Categorization (Native category fetch + Flutter categorizer)
- [x] Harder Lock Overlay (Opaque + Home screen trigger)
- [x] Website Blocker UI (Bottom sheet trigger for web-aware apps)
- [x] Regime (Schedules) Engine (Custom time blocks and usage limits)
- [x] Command Center Dashboard (HUD with Focus Score and Active Regimes)
- [x] Home Optimization (Vertical ListView + Optimistic UI + Caching)
- [x] App Selector Integration (Dedicated AppListScreen)
- [x] Native UI Upgrade (Buttons + Dynamic Shame Copy)
- [x] Focus Score Visualization (Animated Card with Rank Titles)
- [x] Focus Score Detail Page (Tap-through analytics/explainer screen)
- [x] Blocking Sync Fix (Schedules now properly enforce on Android)
- [x] Native Persistence (SharedPreferences storage for service restarts)
- [x] Loop Hardening (Timestamp-based event tracking)
- [x] Lazy Loading (On-demand icon fetching for instant Dashboard load)
- [x] Home Screen Performance (Removed full app list scan from init)
- [x] Permission Gatekeeper (Forced access on first launch)
- [x] Persistent Permission Checks (Real-time warning banner)
- [x] Premium Overlay Redesign (Gen Z HUD + High-fidelity UI)
- [x] Smart Dashboard Cards (Real-time status + Time remaining context)
- [x] High-fidelity Branding (Lock Vector + Home HUD)
- [x] Squad Data Layer (User & Squad Models)
- [x] Squad Service (Create/Join Logic)
- [x] Squad HUD (Member List & Real-time Scores)
- [x] Plea Data Engine (Firestore Logic)
- [x] Native-to-Cloud Bridge (Plea Trigger)
- [x] Judgment Day (Voting UI & Real-time Pleas)
- [x] Outcome Enforcement (Native Stand-Down)
- [x] Judgment Siren
- [x] Account Management (Profile & Deletion)
- [x] Global Nickname Editing (Profile bottom-sheet editor + Firestore update)
- [x] Squad Topbar Copy Action (Copy squad code directly from Squad HUD)
- [x] Focus Score Algorithm (Decay & Reward)
- [x] Native Bridge Synchronization
- [x] Firestore Rule Alignment
- [x] Firebase Auth (Google Sign-In)
- [x] Smart Onboarding Resume (Skip/rejoin flow based on squad + profile state)
- [x] Onboarding UI Refinements (Input consistency, slider/time styling, copy interactions)
- [x] Reality Check Cleanup (Centered duration + system-app filtering)
- [x] Category Bulk Selection (Select/Deselect all by category header)
- [x] FCM Delivery Hardening (Token refresh sync + safe Cloud Function token routing)
- [x] Plea Notification Deep Links (Tap notification to open live session)
- [x] Plea Compose Flow Upgrade (App icon + duration chips + reason input before send)
- [x] Dynamic Plea Copy (Notification + judgment text include selected duration/app)
- [x] Live Judgement Banner (Squad HUD card for active session entry)
- [x] Plea Chat Infrastructure (messages sub-collection stream + send pipeline)
- [x] Attendance-Based Voting Model (participants + voteCounts + string vote map)
- [x] Attendance Resolution Rule (resolve when attendees have all voted, tie => reject)
- [x] Verdict Lifecycle UX (3s full-screen verdict + 5s redirect + deletion mark)
- [x] Squad-only Plea/Chat Rules (Firestore guardrails by squadId)
- [x] Outcome Grant Accuracy (approved unlock uses requested minutes + package)
- [x] Overlay Monitor Stability (usage-stats fallback throttling to reduce spam/overhead)
- [x] Home Screen Flicker Mitigation (permission setState guard + cached user future)
- [x] Tribunal Rename + Routing (JudgementChatScreen renamed to TribunalScreen)
- [x] Auto Tribunal Jump (BegForTime submit now pushReplacement into Tribunal)
- [x] Tribunal Live Scoreboard (REJECT/APPROVE counters with winning-side color emphasis)
- [x] Server-Authoritative Pleas (callables for create/vote/join/message + server-only plea mutations)
- [x] Deadlock Fix (Requester excluded from eligible voter set in server verdict resolution)
- [x] Firestore Rules Hardening (plea doc client writes disabled; chat writes via callable; same-squad user reads)
- [x] Anti-spam Backend Throttles (plea + message rolling limits in callable layer)
- [x] Stale Session Auto-finalization (scheduled timeout resolves long-active pleas server-side)
- [x] Plea Lifecycle Cleanup (scheduled deletion of resolved/marked pleas + messages)
- [x] Android Boot Restart (BOOT_COMPLETED receiver restarts AppMonitorService)
- [x] Android Service Reliability (self-health tick + restart-on-task-removal strategy)
- [x] Adaptive Polling (2s/5s/9s tiers + skip when screen off; reduced heavy checks)
- [x] Battery Optimization Gate (explicit permission requirement in permissions UX and service start gating)
- [x] Admin Flow Consolidation (GodModeDashboard is primary; legacy GodModeScreen removed)

## In Progress
- [ ] Onboarding Final Polish (copy tuning + micro-interactions)
- [ ] Website Blocker Flow Consolidation (single-source bottom sheet behavior)
- [x] Social Hard-Lock (Squad Invites)
- [ ] Option A Vote Subcollection Migration (reduce long-term integrity complexity)
- [ ] Production Hardening Pass (remove debug prints, add index docs, emulator tests)

## Backlog
- [ ] Vandalism Feature (Wallpaper changing)
- [ ] Simp Protocol (Friction-based unlocking)
- [ ] The Squad (Social leaderboards)
- [ ] AI Vibe Rater

```

## Flutter/Dart Core (Selected)
## `pubspec.yaml`
```
name: revoke
description: "A new Flutter project."
# The following line prevents the package from being accidentally published to
# pub.dev using `flutter pub publish`. This is preferred for private packages.
publish_to: 'none' # Remove this line if you wish to publish to pub.dev

# The following defines the version and build number for your application.
# A version number is three numbers separated by dots, like 1.2.43
# followed by an optional build number separated by a +.
# Both the version and the builder number may be overridden in flutter
# build by specifying --build-name and --build-number, respectively.
# In Android, build-name is used as versionName while build-number used as versionCode.
# Read more about Android versioning at https://developer.android.com/studio/publish/versioning
# In iOS, build-name is used as CFBundleShortVersionString while build-number is used as CFBundleVersion.
# Read more about iOS versioning at
# https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html
# In Windows, build-name is used as the major, minor, and patch parts
# of the product and file versions while build-number is used as the build suffix.
version: 1.0.0+1

environment:
  sdk: ^3.10.8

# Dependencies specify other packages that your package needs in order to work.
# To automatically upgrade your package dependencies to the latest versions
# consider running `flutter pub upgrade --major-versions`. Alternatively,
# dependencies can be manually updated by changing the version numbers below to
# the latest version available on pub.dev. To see which dependencies have newer
# versions available, run `flutter pub outdated`.
dependencies:
  flutter:
    sdk: flutter

  # The following adds the Cupertino Icons font to your application.
  # Use with the CupertinoIcons class for iOS style icons.
  cupertino_icons: ^1.0.8
  go_router: ^17.1.0
  phosphor_flutter: ^2.1.0
  shared_preferences: ^2.5.4
  uuid: ^4.5.1
  firebase_core: ^4.4.0
  firebase_messaging: ^16.0.2
  firebase_auth: ^6.1.4
  cloud_firestore: ^6.1.2
  cloud_functions: ^6.0.2
  flutter_local_notifications: ^19.4.0
  share_plus: ^12.0.1
  google_sign_in: ^7.2.0
  google_sign_in_android: 7.2.7
  google_sign_in_platform_interface: 3.1.0
  cached_network_image: ^3.4.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_launcher_icons: ^0.14.4

  # The "flutter_lints" package below contains a set of recommended lints to
  # encourage good coding practices. The lint set provided by the package is
  # activated in the `analysis_options.yaml` file located at the root of your
  # package. See that file for information about deactivating specific lint
  # rules and activating additional ones.
  flutter_lints: ^6.0.0

# For information on the generic Dart part of this file, see the
# following page: https://dart.dev/tools/pub/pubspec

# The following section is specific to Flutter packages.
flutter:

  # The following line ensures that the Material Icons font is
  # included with your application, so that you can use the icons in
  # the material Icons class.
  uses-material-design: true

  assets:
    - assets/branding/
    - assets/fonts/

  fonts:
    - family: NeueMontreal
      fonts:
        - asset: assets/fonts/NeueMontreal-Regular.otf
          weight: 400
        - asset: assets/fonts/NeueMontreal-Medium.otf
          weight: 500
        - asset: assets/fonts/NeueMontreal-Bold.otf
          weight: 700

  # An image asset can refer to one or more resolution-specific "variants", see
  # https://flutter.dev/to/resolution-aware-images

  # For details regarding adding assets from package dependencies, see
  # https://flutter.dev/to/asset-from-package

  # To add custom fonts to your application, add a fonts section here,
  # in this "flutter" section. Each entry in this list should have a
  # "family" key with the font family name, and a "fonts" key with a
  # list giving the asset and other descriptors for the font. For
  # example:
  # fonts:
  #   - family: Schyler
  #     fonts:
  #       - asset: fonts/Schyler-Regular.ttf
  #       - asset: fonts/Schyler-Italic.ttf
  #         style: italic
  #   - family: Trajan Pro
  #     fonts:
  #       - asset: fonts/TrajanPro.ttf
  #       - asset: fonts/TrajanPro_Bold.ttf
  #         weight: 700
  #
  # For details regarding fonts from package dependencies,
  # see https://flutter.dev/to/font-from-package

```

## `lib/main.dart`
```
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/app_router.dart';
import 'core/native_bridge.dart';
import 'core/theme/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/services/auth_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/squad_service.dart';
import 'core/services/scoring_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.initialize();
  await NotificationService.subscribeToGlobalCitizensTopic();
  await AuthService.initializeMessagingTokenSync();
  NativeBridge.setupOverlayListener();
  ScoringService.initializePeriodicSync();
  runApp(const RevokeApp());
}

class RevokeApp extends StatelessWidget {
  const RevokeApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Set up the listener for the overlay
    NativeBridge.onShowOverlay = () {
      final uid = AuthService.currentUser?.uid;
      if (uid != null) {
        ScoringService.syncFocusScore(uid);
      }
      AppRouter.router.push('/lock_screen');
    };
    NativeBridge.onRequestPlea = (appName, packageName) {
      AppRouter.router.go(
        '/plea-compose',
        extra: {'appName': appName, 'packageName': packageName},
      );
    };
    NotificationService.registerPleaJudgementTapHandler((pleaId) {
      AppRouter.router.go('/tribunal/$pleaId');
    });

    // Global listener for approved pleas (Stand-down logic)
    final uid = AuthService.currentUser?.uid;
    if (uid != null) {
      final processedPleas = <String>{};
      SquadService.getUserApprovedPleasStream(uid).listen((pleas) {
        for (var plea in pleas) {
          if (!processedPleas.contains(plea.id)) {
            final packageName = plea.packageName.trim();
            final grantedMinutes = plea.durationMinutes > 0
                ? plea.durationMinutes
                : 5;

            if (packageName.isNotEmpty) {
              print(
                'PLEA_DEBUG: Applying approved unlock plea=${plea.id} package=$packageName minutes=$grantedMinutes',
              );
              NativeBridge.temporaryUnlock(packageName, grantedMinutes);
            } else {
              print(
                'PLEA_DEBUG: Skipping approved unlock plea=${plea.id} due to empty packageName',
              );
            }
            processedPleas.add(plea.id);
          }
        }
      });
    }

    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.data == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final currentLocation =
                AppRouter.router.routeInformationProvider.value.uri.path;
            if (currentLocation != '/onboarding') {
              AppRouter.router.go('/onboarding');
            }
          });
        }

        return MaterialApp.router(
          title: 'Revoke',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          routerConfig: AppRouter.router,
        );
      },
    );
  }
}

```

## `lib/core/app_router.dart`
```
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/navigation/main_shell.dart';
import '../features/navigation/placeholder_screen.dart';
import '../features/regimes/regimes_screen.dart';
import '../features/squad/squad_screen.dart';
import '../features/squad/tribunal_screen.dart';
import '../features/overlay/lock_screen.dart';
import '../features/permissions/permission_screen.dart';
import '../features/home/focus_score_detail_screen.dart';
import '../features/plea/plea_compose_screen.dart';
import '../features/settings/controls_hub_screen.dart';
import '../features/admin/god_mode_dashboard.dart';

import '../core/services/auth_service.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/profile/profile_screen.dart';
import 'native_bridge.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static const Duration _cacheTtl = Duration(seconds: 8);

  static String? _cachedUid;
  static Map<String, dynamic>? _cachedUserData;
  static DateTime? _cachedUserDataAt;
  static Future<Map<String, dynamic>?>? _pendingUserDataFetch;

  static bool? _cachedHasAllPermissions;
  static DateTime? _cachedPermissionsAt;
  static Future<bool>? _pendingPermissionsCheck;

  static bool _hasSessionBootstrap = false;

  static bool _isShellLocation(String location) {
    return location == '/home' ||
        location == '/squad' ||
        location == '/analytics' ||
        location == '/controls';
  }

  static void clearSessionCaches() {
    _cachedUid = null;
    _cachedUserData = null;
    _cachedUserDataAt = null;
    _pendingUserDataFetch = null;
    _cachedHasAllPermissions = null;
    _cachedPermissionsAt = null;
    _pendingPermissionsCheck = null;
    _hasSessionBootstrap = false;
  }

  static Future<Map<String, dynamic>?> _getCachedUserData(String uid) async {
    final now = DateTime.now();
    if (_cachedUid != uid) {
      clearSessionCaches();
      _cachedUid = uid;
    }

    if (_cachedUserData != null &&
        _cachedUserDataAt != null &&
        now.difference(_cachedUserDataAt!) < _cacheTtl) {
      return _cachedUserData;
    }

    _pendingUserDataFetch ??= AuthService.getUserData()
        .then((data) {
          _cachedUserData = data;
          _cachedUserDataAt = DateTime.now();
          return data;
        })
        .whenComplete(() => _pendingUserDataFetch = null);

    return _pendingUserDataFetch!;
  }

  static Future<bool> _getCachedPermissions() async {
    final now = DateTime.now();
    if (_cachedHasAllPermissions != null &&
        _cachedPermissionsAt != null &&
        now.difference(_cachedPermissionsAt!) < _cacheTtl) {
      return _cachedHasAllPermissions!;
    }

    _pendingPermissionsCheck ??= NativeBridge.checkPermissions()
        .then((perms) {
          final hasAll =
              (perms['usage_stats'] ?? false) &&
              (perms['overlay'] ?? false) &&
              (perms['battery_optimization_ignored'] ?? false);
          _cachedHasAllPermissions = hasAll;
          _cachedPermissionsAt = DateTime.now();
          return hasAll;
        })
        .whenComplete(() => _pendingPermissionsCheck = null);

    return _pendingPermissionsCheck!;
  }

  static final router = GoRouter(
    initialLocation: '/',
    navigatorKey: _rootNavigatorKey,
    redirect: (context, state) async {
      final user = AuthService.currentUser;
      final location = state.matchedLocation;
      final isGoingToOnboarding = location == '/onboarding';
      final isSplash = location == '/';
      final isPermissions = location == '/permissions';
      final isShellLocation = _isShellLocation(location);
      final forceAuth = state.uri.queryParameters['force_auth'] == '1';
      final isShareSquadResume =
          state.uri.queryParameters['step'] == 'share_squad';

      if (user == null) {
        clearSessionCaches();
        if (isSplash || isGoingToOnboarding) return null;
        return '/onboarding';
      }

      if (forceAuth && isGoingToOnboarding) {
        return null;
      }

      if (_cachedUid != user.uid) {
        clearSessionCaches();
        _cachedUid = user.uid;
      }

      if (_hasSessionBootstrap && isShellLocation) {
        return null;
      }

      final userData = await _getCachedUserData(user.uid);
      final squadId = (userData?['squadId'] as String?)?.trim();
      final nickname = (userData?['nickname'] as String?)?.trim();
      final hasSquad = squadId != null && squadId.isNotEmpty;
      final hasNickname = nickname != null && nickname.isNotEmpty;

      if (hasSquad && (isSplash || isGoingToOnboarding)) {
        return '/home';
      }

      if (!hasSquad &&
          hasNickname &&
          isGoingToOnboarding &&
          !isShareSquadResume) {
        return '/onboarding?step=share_squad';
      }

      if (isSplash) {
        if (hasSquad) return '/home';
        if (hasNickname) return '/onboarding?step=share_squad';
        return '/onboarding';
      }

      try {
        final hasAll = await _getCachedPermissions();

        if (isPermissions) {
          if (hasAll) {
            if (hasSquad) return '/home';
            if (hasNickname) return '/onboarding?step=share_squad';
            return '/onboarding';
          }
          return null;
        }

        if (!hasAll) {
          return '/permissions';
        }

        if (!hasSquad && hasNickname && !isGoingToOnboarding) {
          return '/onboarding?step=share_squad';
        }
        if (!hasSquad && !hasNickname && !isGoingToOnboarding) {
          return '/onboarding';
        }

        if (hasAll && hasSquad && isShellLocation) {
          _hasSessionBootstrap = true;
        }

        return null;
      } catch (e) {
        print("Router Error: $e");
        return null;
      }
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/permissions',
        builder: (context, state) => const PermissionScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return MainShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const RegimesScreen(),
          ),
          GoRoute(
            path: '/squad',
            builder: (context, state) => const SquadScreen(),
          ),
          GoRoute(
            path: '/analytics',
            builder: (context, state) =>
                const PlaceholderScreen(title: 'Analytics'),
          ),
          GoRoute(
            path: '/controls',
            builder: (context, state) => const ControlsHubScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/lock_screen',
        builder: (context, state) => const LockScreen(),
      ),
      GoRoute(
        path: '/plea-compose',
        builder: (context, state) {
          final extra = state.extra as Map?;
          final appName = (extra?['appName'] as String?)?.trim();
          final packageName = (extra?['packageName'] as String?)?.trim();
          if (appName == null ||
              appName.isEmpty ||
              packageName == null ||
              packageName.isEmpty) {
            return const RegimesScreen();
          }
          return BegForTimeScreen(appName: appName, packageName: packageName);
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/focus-score',
        builder: (context, state) => const FocusScoreDetailScreen(),
      ),
      GoRoute(
        path: '/god-mode',
        builder: (context, state) => const GodModeDashboard(),
      ),
      GoRoute(
        path: '/tribunal/:pleaId',
        builder: (context, state) {
          final pleaId = (state.pathParameters['pleaId'] ?? '').trim();
          if (pleaId.isEmpty) return const SquadScreen();
          return TribunalScreen(pleaId: pleaId);
        },
      ),
    ],
  );
}

```

## `lib/core/native_bridge.dart`
```
import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _channel = MethodChannel('com.revoke.app/overlay');
  static Function()? onShowOverlay;
  static Function(String appName, String packageName)? onRequestPlea;

  static void setupOverlayListener() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'showOverlay') {
        onShowOverlay?.call();
      } else if (call.method == 'requestPlea') {
        final appName = call.arguments?['appName'] as String? ?? "Unknown App";
        final packageName = call.arguments?['packageName'] as String? ?? "";
        onRequestPlea?.call(appName, packageName);
      }
    });
  }

  /// Checks the status of required permissions.
  static Future<Map<String, bool>> checkPermissions() async {
    final Map<dynamic, dynamic> result = await _channel.invokeMethod(
      'checkPermissions',
    );
    return Map<String, bool>.from(result);
  }

  /// Opens the system settings for usage stats access.
  static Future<void> requestUsageStats() async {
    await _channel.invokeMethod('requestUsageStats');
  }

  /// Opens the system settings for overlay permission.
  static Future<void> requestOverlay() async {
    await _channel.invokeMethod('requestOverlay');
  }

  /// Requests an exemption from battery optimizations (best effort).
  static Future<void> requestBatteryOptimizations() async {
    await _channel.invokeMethod('requestBatteryOptimizations');
  }

  /// Fetches a list of installed apps.
  static Future<List<Map<String, dynamic>>> getInstalledApps() async {
    final List<dynamic> result = await _channel.invokeMethod(
      'getInstalledApps',
    );
    return result.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Fetches details for a single app by package name.
  static Future<Map<String, dynamic>> getAppDetails(String packageName) async {
    final Map<dynamic, dynamic> result = await _channel.invokeMethod(
      'getAppDetails',
      {'packageName': packageName},
    );
    return Map<String, dynamic>.from(result);
  }

  /// Starts the app monitor foreground service.
  static Future<void> startService() async {
    await _channel.invokeMethod('startService');
  }

  /// Syncs schedules with the native Android service.
  static Future<void> syncSchedules(String jsonSchedules) async {
    await _channel.invokeMethod('syncSchedules', {'schedules': jsonSchedules});
  }

  /// Fetches usage stats for the last 7 days.
  static Future<Map<String, dynamic>> getRealityCheck() async {
    final Map<dynamic, dynamic> result = await _channel.invokeMethod(
      'getRealityCheck',
    );
    return Map<String, dynamic>.from(result);
  }

  /// Temporarily unlocks an app for a specific duration.
  static Future<void> temporaryUnlock(String packageName, int minutes) async {
    await _channel.invokeMethod('temporaryUnlock', {
      'packageName': packageName,
      'minutes': minutes,
    });
  }

  /// Returns package names currently under temporary tribunal approval.
  static Future<List<String>> getTemporaryApprovedPackages() async {
    final List<dynamic> result = await _channel.invokeMethod(
      'getTemporaryApprovals',
    );
    return result.map((e) => e.toString()).toList();
  }

  /// Pauses native monitoring/enforcement for a duration in minutes.
  static Future<void> pauseMonitoring(int minutes) async {
    await _channel.invokeMethod('pauseMonitoring', {'minutes': minutes});
  }
}

```

## `lib/core/services/auth_service.dart`
```
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../app_router.dart';
import 'squad_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static StreamSubscription<String>? _tokenRefreshSub;

  static User? get currentUser => _auth.currentUser;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static void _redirectToAuthFlow() {
    try {
      AppRouter.router.go('/onboarding?force_auth=1');
    } catch (_) {
      // Router might not be ready during app bootstrap; ignore safely.
    }
  }

  static Future<User?> signInWithGoogle() async {
    try {
      print('AUTH_DEBUG: Starting Google Sign In process...');

      await _googleSignIn.initialize(
        serverClientId:
            '70325101052-aae5kl5ie7npv94dqtgrktur0ql1ln01.apps.googleusercontent.com',
      );

      print('AUTH_DEBUG: Triggering authenticate()...');
      final GoogleSignInAccount? googleUser = await _googleSignIn
          .authenticate();

      if (googleUser == null) {
        print(
          'AUTH_DEBUG: googleUser is null (User canceled or configuration error).',
        );
        return null;
      }

      print('AUTH_DEBUG: Authenticated Google user: ${googleUser.email}');
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final String? idToken = googleAuth.idToken;
      if (idToken == null) {
        print(
          'AUTH_DEBUG ERROR: idToken is NULL. Check SHA-1 and Web Client ID in Firebase.',
        );
        throw Exception(
          "ID Token is missing. Verify Firebase configuration and SHA-1.",
        );
      }

      print('AUTH_DEBUG: idToken found. Creating Firebase credential...');
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      print('AUTH_DEBUG: Signing into Firebase with credential...');
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      if (user != null) {
        print('AUTH_DEBUG: Firebase sign-in SUCCESS: ${user.uid}');
        await _ensureUserDocument(user);
      }

      return user;
    } catch (e, stack) {
      print('AUTH_DEBUG EXCEPTION: $e');
      print('AUTH_DEBUG STACK: $stack');
      rethrow;
    }
  }

  static Future<void> _ensureUserDocument(User user) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);
      final String? token = await FirebaseMessaging.instance.getToken();

      // Use set with SetOptions(merge: true) to:
      // 1. Create the document if it doesn't exist.
      // 2. Update existing data (like photoUrl) if it does.
      // 3. Preserve fields like 'squadId' or 'focusScore' so they aren't reset to null.
      await userDoc.set({
        'uid': user.uid,
        'email': user.email,
        'fullName': user.displayName,
        'photoUrl': user.photoURL,
        'fcmToken': token,
        'lastLogin': FieldValue.serverTimestamp(),
        // Only set these defaults if the document is being created for the first time
        // by using a transaction or checking snapshot, but merge is safer here.
      }, SetOptions(merge: true));

      // ðŸ’¡ If focusScore or other defaults are missing, we ensure they exist
      final snapshot = await userDoc.get();
      if (!snapshot.exists || snapshot.data()?['focusScore'] == null) {
        await userDoc.set({
          'focusScore': 500,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('AUTH_DEBUG ERROR: Failed to ensure user document: $e');
      rethrow;
    }
  }

  static Future<void> initializeMessagingTokenSync() async {
    _tokenRefreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((
      token,
    ) async {
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null || token.isEmpty) return;
      try {
        await _firestore.collection('users').doc(refreshedUser.uid).set({
          'fcmToken': token,
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        print('AUTH_DEBUG: Failed to sync refreshed FCM token: $e');
      }
    });

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _firestore.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('AUTH_DEBUG: Failed to sync initial FCM token: $e');
    }
  }

  static Future<void> updateNickname(String nickname) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final normalized = nickname.trim();
    if (normalized.isEmpty) return;

    await _firestore.collection('users').doc(user.uid).update({
      'nickname': normalized,
    });
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data();
  }

  static Future<void> signOut() async {
    _redirectToAuthFlow();
    AppRouter.clearSessionCaches();
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;

    try {
      await _googleSignIn.disconnect();
    } catch (_) {}
    await _auth.signOut();
  }

  /// Validates if the current session is still valid (user document exists).
  static Future<bool> validateSession() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      await signOut();
      return false;
    }
    return true;
  }

  /// Deletes the current user's account and all associated data.
  static Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _redirectToAuthFlow();
    AppRouter.clearSessionCaches();

    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;

    final uid = user.uid;
    final userRef = _firestore.collection('users').doc(uid);

    try {
      final userData = await getUserData();
      final squadId = (userData?['squadId'] as String?)?.trim();

      // 1. Remove from squad if applicable
      if (squadId != null && squadId.isNotEmpty) {
        await SquadService.leaveSquad(uid, squadId);
      }

      // 2. Delete known user sub-collections
      await _deleteSubcollection(userRef, 'regimes');

      // 3. Delete user document
      await userRef.delete();

      // 4. Delete Firebase Auth user (reauth if required)
      await _deleteAuthUserWithReauth(user);
    } finally {
      try {
        await _googleSignIn.disconnect();
      } catch (_) {}
      await _auth.signOut();
    }
  }

  static Future<void> _deleteSubcollection(
    DocumentReference<Map<String, dynamic>> userRef,
    String subcollection,
  ) async {
    final snapshot = await userRef.collection(subcollection).get();
    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  static Future<void> _deleteAuthUserWithReauth(User user) async {
    try {
      await user.delete();
      return;
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') {
        rethrow;
      }
    }

    await _googleSignIn.initialize(
      serverClientId:
          '70325101052-aae5kl5ie7npv94dqtgrktur0ql1ln01.apps.googleusercontent.com',
    );

    final googleUser = await _googleSignIn.authenticate();

    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'reauth-failed',
        message: 'Missing Google ID token for re-authentication.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await user.reauthenticateWithCredential(credential);
    await user.delete();
  }
}

```

## `lib/core/services/notification_service.dart`
```
import 'dart:convert';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../native_bridge.dart';
import '../theme/app_theme.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService.handleBackgroundRemoteMessage(message);
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _squadAlertsChannel =
      AndroidNotificationChannel(
        'squad_alerts',
        'Squad Alerts',
        description: 'High-priority alerts for incoming squad pleas.',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('lookatthisdude'),
      );

  static bool _initialized = false;
  static bool _localNotificationsInitialized = false;
  static void Function(String pleaId)? _onPleaJudgementTap;
  static String? _pendingPleaId;

  static void registerPleaJudgementTapHandler(
    void Function(String pleaId) handler,
  ) {
    _onPleaJudgementTap = handler;
    final pending = _pendingPleaId;
    if (pending != null && pending.isNotEmpty) {
      _pendingPleaId = null;
      handler(pending);
    }
  }

  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    if (_initialized) return;
    _initialized = true;

    await _requestPermissions();
    await _initializeLocalNotifications();
    await _subscribeToGlobalTopic();
    _listenForegroundMessages();
    await _listenTapEvents();
  }

  static Future<void> subscribeToGlobalCitizensTopic() async {
    await _subscribeToGlobalTopic();
  }

  static Future<void> handleBackgroundRemoteMessage(
    RemoteMessage message,
  ) async {
    await _handleAmnestyMessage(message);
  }

  static Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: true,
      sound: true,
    );
    print(
      'FCM_DEBUG: Notification permission status = ${settings.authorizationStatus.name}',
    );
  }

  static Future<void> _subscribeToGlobalTopic() async {
    try {
      await _messaging.subscribeToTopic('global_citizens');
      print('FCM_DEBUG: Subscribed to topic global_citizens');
    } catch (e) {
      print('FCM_DEBUG: Failed to subscribe to global_citizens: $e');
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) return;

    const androidSettings = AndroidInitializationSettings('notification_icon');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleLocalNotificationTap(response.payload);
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(_squadAlertsChannel);
    _localNotificationsInitialized = true;

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static void _listenForegroundMessages() {
    FirebaseMessaging.onMessage.listen((message) async {
      final handledAmnesty = await _handleAmnestyMessage(message);
      if (handledAmnesty) return;

      final isPlea = _isPleaMessage(message);
      final title =
          message.data['title']?.toString() ??
          message.notification?.title ??
          (isPlea ? 'SQUAD ALERT' : 'Revoke');
      final body =
          message.data['body']?.toString() ??
          message.notification?.body ??
          (isPlea
              ? 'A squad member is begging for time.'
              : 'You have a new notification.');

      if (title.trim().isEmpty && body.trim().isEmpty) {
        print(
          'FCM_DEBUG: Foreground message ignored (empty title/body). id=${message.messageId}',
        );
        return;
      }

      print(
        'FCM_DEBUG: Foreground message displayed. id=${message.messageId} data=${message.data}',
      );

      await _showForegroundNotification(
        title: title,
        body: body,
        data: message.data,
      );
    });
  }

  static Future<void> _listenTapEvents() async {
    FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteNotificationTap);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleRemoteNotificationTap(initialMessage);
    }
  }

  static void _handleRemoteNotificationTap(RemoteMessage message) {
    final type = message.data['type']?.toString().trim().toLowerCase();
    final pleaId = message.data['pleaId']?.toString().trim();
    if (type == 'plea_judgement' && pleaId != null && pleaId.isNotEmpty) {
      _dispatchPleaTap(pleaId);
    }
  }

  static void _handleLocalNotificationTap(String? payload) {
    if (payload == null || payload.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      final type = decoded['type']?.toString().trim().toLowerCase();
      final pleaId = decoded['pleaId']?.toString().trim();
      if (type == 'plea_judgement' && pleaId != null && pleaId.isNotEmpty) {
        _dispatchPleaTap(pleaId);
      }
    } catch (_) {}
  }

  static void _dispatchPleaTap(String pleaId) {
    if (_onPleaJudgementTap != null) {
      _onPleaJudgementTap!(pleaId);
      return;
    }
    _pendingPleaId = pleaId;
  }

  static bool _isPleaMessage(RemoteMessage message) {
    final type =
        message.data['type']?.toString().toLowerCase() ??
        message.data['event']?.toString().toLowerCase() ??
        message.data['kind']?.toString().toLowerCase() ??
        '';
    if (type.contains('plea')) return true;
    if (message.data.containsKey('pleaId')) return true;

    final notificationText =
        '${message.notification?.title ?? ''} ${message.notification?.body ?? ''}'
            .toLowerCase();
    if (notificationText.contains('plea') ||
        notificationText.contains('beg') ||
        notificationText.contains('begging')) {
      return true;
    }

    return false;
  }

  static Future<void> _showForegroundNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'squad_alerts',
      'Squad Alerts',
      channelDescription: 'High-priority alerts for incoming squad pleas.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('lookatthisdude'),
      icon: 'notification_icon',
      color: AppSemanticColors.accent,
    );
    const iosDetails = DarwinNotificationDetails(presentSound: true);
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    String? payload;
    final type = data?['type']?.toString().trim().toLowerCase();
    final pleaId = data?['pleaId']?.toString().trim();
    if (type == 'plea_judgement' && pleaId != null && pleaId.isNotEmpty) {
      payload = jsonEncode({'type': 'plea_judgement', 'pleaId': pleaId});
    }

    final notificationId = Random().nextInt(1 << 31);
    await _localNotifications.show(
      notificationId,
      title,
      body,
      details,
      payload: payload,
    );
  }

  static Future<bool> _handleAmnestyMessage(RemoteMessage message) async {
    final type = message.data['type']?.toString().trim().toUpperCase();
    if (type != 'AMNESTY') return false;

    final rawDuration = message.data['duration']?.toString().trim() ?? '60';
    final durationMinutes = int.tryParse(rawDuration) ?? 60;

    try {
      await NativeBridge.pauseMonitoring(durationMinutes);
    } catch (e) {
      print('FCM_DEBUG: Failed to pause monitoring for amnesty: $e');
    }

    await _showAmnestyNotification(durationMinutes);
    return true;
  }

  static Future<void> _showAmnestyNotification(int durationMinutes) async {
    await _initializeLocalNotifications();

    const androidDetails = AndroidNotificationDetails(
      'squad_alerts',
      'Squad Alerts',
      channelDescription: 'High-priority alerts for incoming squad pleas.',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('lookatthisdude'),
      icon: 'notification_icon',
      color: AppSemanticColors.accent,
    );
    const iosDetails = DarwinNotificationDetails(presentSound: true);
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title = 'Amnesty Granted';
    final body =
        'The Architect has granted you Amnesty for $durationMinutes minutes.';

    final notificationId = Random().nextInt(1 << 31);
    await _localNotifications.show(notificationId, title, body, details);
  }
}

```

## `lib/core/services/squad_service.dart`
```
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/plea_message_model.dart';
import '../models/user_model.dart';
import '../models/plea_model.dart';
import 'scoring_service.dart';

class SquadService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  /// Helper to generate a 6-character alphanumeric squad code.
  static String _generateSquadCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final code = String.fromCharCodes(
      Iterable.generate(
        3,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
    return 'REV-$code';
  }

  /// Creates a new squad for the user.
  /// Uses transaction.set with merge to prevent "Permission Denied" if the user doc is missing.
  static Future<void> createSquad(String uid) async {
    final squadCode = _generateSquadCode();
    final squadRef = _firestore.collection('squads').doc();
    final userRef = _firestore.collection('users').doc(uid);

    return _firestore.runTransaction((transaction) async {
      // 1. Create the Squad document
      transaction.set(squadRef, {
        'squadCode': squadCode,
        'creatorId': uid,
        'memberIds': [uid],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Update the User document (using set + merge to ensure it exists)
      transaction.set(userRef, {
        'squadId': squadRef.id,
        'squadCode': squadCode,
      }, SetOptions(merge: true));
    });
  }

  /// Joins an existing squad using a 6-digit (REV-XXX) code.
  /// Updates both the /squads document and the user's /users document atomically.
  static Future<void> joinSquad(String uid, String squadCode) async {
    final normalizedCode = squadCode.toUpperCase().trim();
    // 1. Find the squad by code
    final querySnapshot = await _firestore
        .collection('squads')
        .where('squadCode', isEqualTo: normalizedCode)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('SQUAD NOT FOUND: Check the code and try again.');
    }

    final squadDoc = querySnapshot.docs.first;
    final squadRef = squadDoc.reference;
    final userRef = _firestore.collection('users').doc(uid);

    return _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final freshSquadSnapshot = await transaction.get(squadRef);
      final memberIds = List<String>.from(
        freshSquadSnapshot.get('memberIds') as List,
      );

      final oldSquadId = userSnapshot.data()?['squadId'] as String?;
      if (oldSquadId != null &&
          oldSquadId.isNotEmpty &&
          oldSquadId != squadRef.id) {
        final oldSquadRef = _firestore.collection('squads').doc(oldSquadId);
        final oldSquadSnapshot = await transaction.get(oldSquadRef);

        if (oldSquadSnapshot.exists) {
          final oldMemberIds = List<String>.from(
            oldSquadSnapshot.get('memberIds') as List,
          );
          oldMemberIds.remove(uid);
          final shouldDeleteOldSquad = oldMemberIds.isEmpty;
          if (shouldDeleteOldSquad) {
            transaction.delete(oldSquadRef);
          } else {
            transaction.update(oldSquadRef, {'memberIds': oldMemberIds});
          }
        }
      }

      if (!memberIds.contains(uid)) {
        memberIds.add(uid);
      }

      // 2. Update the Squad document
      transaction.update(squadRef, {'memberIds': memberIds});

      // 3. Update the User document
      transaction.update(userRef, {
        'squadId': squadRef.id,
        'squadCode': normalizedCode,
      });
    });
  }

  /// Returns a stream of users who are members of the same squad.
  static Stream<List<UserModel>> getSquadMembersStream(String squadId) {
    return _firestore
        .collection('users')
        .where('squadId', isEqualTo: squadId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => UserModel.fromJson(doc.data()))
              .toList();
        });
  }

  /// Creates a new emergency unlock plea.
  static Future<String> createPlea({
    required String uid,
    required String userName,
    required String squadId,
    required String appName,
    required String packageName,
    required int durationMinutes,
    required String reason,
  }) async {
    final callable = _functions.httpsCallable('createPlea');
    final response = await callable.call({
      'uid': uid,
      'appName': appName,
      'packageName': packageName,
      'durationMinutes': durationMinutes,
      'reason': reason,
    });

    final data = Map<String, dynamic>.from(response.data as Map? ?? const {});
    final pleaId = (data['pleaId'] as String?)?.trim();
    if (pleaId == null || pleaId.isEmpty) {
      throw Exception('INVALID_PLEA_ID');
    }

    await ScoringService.applyBeggarsTax(uid);
    return pleaId;
  }

  /// Submits a vote choice for a plea.
  /// Verdict resolution is handled server-side by Cloud Functions.
  static Future<void> voteOnPlea(
    String pleaId,
    String voterUid,
    bool vote,
  ) async {
    final voteChoice = vote ? 'accept' : 'reject';
    return voteOnPleaChoice(pleaId, voterUid, voteChoice);
  }

  static Future<void> voteOnPleaChoice(
    String pleaId,
    String voterUid,
    String voteChoice,
  ) async {
    final normalizedVote = voteChoice.trim().toLowerCase();
    if (normalizedVote != 'accept' && normalizedVote != 'reject') {
      throw Exception('INVALID VOTE');
    }

    final currentUid = voterUid.trim();
    if (currentUid.isEmpty) {
      throw Exception('INVALID_VOTER_UID');
    }

    final callable = _functions.httpsCallable('castVote');
    await callable.call({
      'pleaId': pleaId,
      'choice': normalizedVote,
    });
  }

  /// Returns a stream of approved pleas for a specific user.
  static Stream<List<PleaModel>> getUserApprovedPleasStream(String uid) {
    return _firestore
        .collection('pleas')
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => PleaModel.fromJson(doc.data(), doc.id))
              .toList();
        });
  }

  /// Returns a stream of active pleas for a squad.
  static Stream<List<PleaModel>> getActivePleasStream(String squadId) {
    final normalizedSquadId = squadId.trim();
    if (normalizedSquadId.isEmpty) {
      print(
        'PLEA_DEBUG: getActivePleasStream called with empty squadId. Returning empty stream.',
      );
      return Stream.value(const <PleaModel>[]);
    }

    print(
      'PLEA_DEBUG: Listening for active pleas in squadId=$normalizedSquadId',
    );

    return _firestore
        .collection('pleas')
        .where('squadId', isEqualTo: normalizedSquadId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
          for (final change in snapshot.docChanges) {
            final data = change.doc.data();
            final changedSquadId = data?['squadId'];
            final changedUserId = data?['userId'];
            final changedStatus = data?['status'];
            print(
              'PLEA_DEBUG: ${change.type.name.toUpperCase()} plea=${change.doc.id} squadId=$changedSquadId userId=$changedUserId status=$changedStatus',
            );
          }

          print(
            'PLEA_DEBUG: Active plea snapshot for squadId=$normalizedSquadId count=${snapshot.docs.length}',
          );

          return snapshot.docs
              .map((doc) => PleaModel.fromJson(doc.data(), doc.id))
              .toList();
        });
  }

  static Stream<PleaModel?> getPleaStream(String pleaId) {
    final normalizedPleaId = pleaId.trim();
    if (normalizedPleaId.isEmpty) return Stream.value(null);

    return _firestore.collection('pleas').doc(normalizedPleaId).snapshots().map(
      (snapshot) {
        if (!snapshot.exists || snapshot.data() == null) return null;
        return PleaModel.fromJson(snapshot.data()!, snapshot.id);
      },
    );
  }

  static Future<void> joinPleaSession(String pleaId, String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return;
    final callable = _functions.httpsCallable('joinPleaSession');
    await callable.call({'pleaId': pleaId});
  }

  static Future<String> sendPleaMessage({
    required String pleaId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      throw Exception('MESSAGE CANNOT BE EMPTY.');
    }

    // Server-authoritative message send (anti-spam enforced in callable).
    final callable = _functions.httpsCallable('sendPleaMessage');
    final response = await callable.call({
      'pleaId': pleaId,
      'text': normalizedText,
    });

    final data = Map<String, dynamic>.from(response.data as Map? ?? const {});
    final messageId = (data['messageId'] as String?)?.trim();
    if (messageId == null || messageId.isEmpty) {
      throw Exception('INVALID_MESSAGE_ID');
    }
    return messageId;
  }

  static Future<void> markPleaForDeletion(String pleaId) async {
    final normalizedPleaId = pleaId.trim();
    if (normalizedPleaId.isEmpty) return;
    final callable = _functions.httpsCallable('markPleaForDeletion');
    await callable.call({'pleaId': normalizedPleaId});
  }

  static Stream<List<PleaMessageModel>> getPleaMessagesStream(String pleaId) {
    return _firestore
        .collection('pleas')
        .doc(pleaId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => PleaMessageModel.fromJson(doc.data(), doc.id))
              .toList();
        });
  }

  /// Removes a user from their squad.
  static Future<void> leaveSquad(String uid, String squadId) async {
    final squadRef = _firestore.collection('squads').doc(squadId);

    return _firestore.runTransaction((transaction) async {
      final freshSquadSnapshot = await transaction.get(squadRef);
      if (!freshSquadSnapshot.exists) return;

      final memberIds = List<String>.from(
        freshSquadSnapshot.get('memberIds') as List,
      );

      memberIds.remove(uid);

      if (memberIds.isEmpty) {
        transaction.delete(squadRef);
      } else {
        transaction.update(squadRef, {'memberIds': memberIds});
      }
    });
  }
}

```

## `lib/core/services/schedule_service.dart`
```
import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/schedule_model.dart';
import '../native_bridge.dart';
import 'regime_service.dart';

class ScheduleService {
  static const String _key = 'regime_schedules';

  static Future<List<ScheduleModel>> _readLocalSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null || data.trim().isEmpty) return <ScheduleModel>[];
    try {
      final decoded = jsonDecode(data) as List<dynamic>;
      return decoded
          .map(
            (item) => ScheduleModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return <ScheduleModel>[];
    }
  }

  static Future<void> _writeLocalSchedules(
    List<ScheduleModel> schedules,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(schedules.map((s) => s.toJson()).toList());
    await prefs.setString(_key, data);
  }

  static Future<void> _pushSingleToCloudInBackground(
    ScheduleModel schedule,
  ) async {
    try {
      await RegimeService.saveRegime(schedule);
    } catch (_) {
      // Background sync is best-effort by design.
    }
  }

  static Future<void> _deleteFromCloudInBackground(String id) async {
    try {
      await RegimeService.deleteRegime(id);
    } catch (_) {
      // Background sync is best-effort by design.
    }
  }

  static Future<void> _refreshLocalFromCloudInBackground() async {
    try {
      final remote = await RegimeService.getRegimes();
      final local = await _readLocalSchedules();
      // Do not replace non-empty local with empty remote.
      if (remote.isEmpty && local.isNotEmpty) return;
      await _writeLocalSchedules(remote);
    } catch (_) {
      // Ignore; local-first behavior should remain resilient offline.
    }
  }

  static Future<List<ScheduleModel>> getSchedules() async {
    final local = await _readLocalSchedules();
    unawaited(_refreshLocalFromCloudInBackground());
    return local;
  }

  static Stream<List<ScheduleModel>> watchSchedules() async* {
    final local = await _readLocalSchedules();
    yield local;

    yield* RegimeService.watchRegimes().asyncMap((remote) async {
      final currentLocal = await _readLocalSchedules();
      if (remote.isEmpty && currentLocal.isNotEmpty) {
        return currentLocal;
      }
      await _writeLocalSchedules(remote);
      return remote;
    });
  }

  static Future<void> saveSchedule(ScheduleModel schedule) async {
    final schedules = await _readLocalSchedules();
    final index = schedules.indexWhere((s) => s.id == schedule.id);
    if (index == -1) {
      schedules.add(schedule);
    } else {
      schedules[index] = schedule;
    }
    await _writeLocalSchedules(schedules);
    await syncWithNative();
    unawaited(_pushSingleToCloudInBackground(schedule));
  }

  static Future<void> deleteSchedule(String id) async {
    final schedules = await _readLocalSchedules();
    schedules.removeWhere((s) => s.id == id);
    await _writeLocalSchedules(schedules);
    await syncWithNative();
    unawaited(_deleteFromCloudInBackground(id));
  }

  static Future<void> toggleSchedule(String id) async {
    final schedules = await _readLocalSchedules();
    final index = schedules.indexWhere((s) => s.id == id);
    if (index == -1) return;
    final updated = schedules[index].copyWith(
      isActive: !schedules[index].isActive,
    );
    schedules[index] = updated;
    await _writeLocalSchedules(schedules);
    await syncWithNative();
    unawaited(_pushSingleToCloudInBackground(updated));
  }

  static Future<void> syncWithNative() async {
    final schedules = await _readLocalSchedules();
    final activeSchedules = schedules.where((s) => s.isActive).toList();
    final jsonSchedules = jsonEncode(
      activeSchedules.map((s) => s.toJson()).toList(),
    );
    await NativeBridge.syncSchedules(jsonSchedules);
  }
}

```

## `lib/core/services/regime_service.dart`
```
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/schedule_model.dart';
import '../native_bridge.dart';
import 'auth_service.dart';

class RegimeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _legacyKey = 'regime_schedules';
  static final Set<String> _migratedUsers = <String>{};

  static Future<String> _requireUid() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) {
      throw Exception('NO AUTHENTICATED USER FOR REGIMES');
    }
    return uid.trim();
  }

  static String? _currentUidOrNull() {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return null;
    final normalized = uid.trim();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  static CollectionReference<Map<String, dynamic>> _regimesRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('regimes');
  }

  static String _timeToString(TimeOfDay? time) {
    if (time == null) return '';
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  static TimeOfDay? _parseTime(dynamic value, dynamic hour, dynamic minute) {
    if (value is String && value.contains(':')) {
      final parts = value.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) {
          return TimeOfDay(hour: h, minute: m);
        }
      }
    }
    if (hour is num) {
      return TimeOfDay(
        hour: hour.toInt(),
        minute: (minute as num?)?.toInt() ?? 0,
      );
    }
    return null;
  }

  static Map<String, dynamic> _toFirestore(ScheduleModel schedule) {
    return {
      // Required regime fields for cloud schema.
      'name': schedule.name,
      'apps': schedule.targetApps,
      'daysOfWeek': schedule.days,
      'startTime': _timeToString(schedule.startTime),
      'endTime': _timeToString(schedule.endTime),
      'isEnabled': schedule.isActive,
      // Legacy/compat fields used by native sync model.
      'type': schedule.type.index,
      'targetApps': schedule.targetApps,
      'days': schedule.days,
      'startHour': schedule.startTime?.hour,
      'startMinute': schedule.startTime?.minute,
      'endHour': schedule.endTime?.hour,
      'endMinute': schedule.endTime?.minute,
      'durationSeconds': schedule.durationLimit?.inSeconds,
      'isActive': schedule.isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static ScheduleModel _fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final targetApps = List<String>.from(
      data['targetApps'] as List? ?? data['apps'] as List? ?? const <String>[],
    );
    final days = List<int>.from(
      data['days'] as List? ?? data['daysOfWeek'] as List? ?? const <int>[],
    );

    final startTime = _parseTime(
      data['startTime'],
      data['startHour'],
      data['startMinute'],
    );
    final endTime = _parseTime(
      data['endTime'],
      data['endHour'],
      data['endMinute'],
    );
    final durationSeconds = (data['durationSeconds'] as num?)?.toInt();
    final rawType = (data['type'] as num?)?.toInt() ?? 0;
    final safeType = rawType.clamp(0, ScheduleType.values.length - 1);

    return ScheduleModel(
      id: doc.id,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : 'REGIME',
      type: ScheduleType.values[safeType],
      targetApps: targetApps,
      days: days,
      startTime: startTime,
      endTime: endTime,
      durationLimit: durationSeconds == null
          ? null
          : Duration(seconds: durationSeconds),
      isActive:
          (data['isActive'] as bool?) ?? (data['isEnabled'] as bool?) ?? true,
    );
  }

  static Future<void> migrateLegacyLocalDataIfNeeded() async {
    final uid = _currentUidOrNull();
    if (uid == null) return;
    if (_migratedUsers.contains(uid)) return;

    final prefs = await SharedPreferences.getInstance();
    final migrationFlagKey = 'regimes_migrated_$uid';
    final alreadyMigrated = prefs.getBool(migrationFlagKey) ?? false;
    if (alreadyMigrated) {
      _migratedUsers.add(uid);
      return;
    }

    final localRaw = prefs.getString(_legacyKey);
    if (localRaw != null && localRaw.trim().isNotEmpty) {
      try {
        final existing = await _regimesRef(uid).limit(1).get();
        if (existing.docs.isEmpty) {
          final decoded = jsonDecode(localRaw) as List<dynamic>;
          final schedules = decoded
              .map(
                (item) =>
                    ScheduleModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
          final batch = _firestore.batch();
          for (final schedule in schedules) {
            final docRef = _regimesRef(uid).doc(schedule.id);
            batch.set(docRef, {
              ..._toFirestore(schedule),
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
          await batch.commit();
        }
      } catch (_) {
        // Keep non-fatal; migration is best-effort.
      }
    }

    await prefs.setBool(migrationFlagKey, true);
    _migratedUsers.add(uid);
  }

  static Future<List<ScheduleModel>> getRegimes() async {
    try {
      await migrateLegacyLocalDataIfNeeded();
      final uid = _currentUidOrNull();
      if (uid == null) return const <ScheduleModel>[];
      final snapshot = await _regimesRef(
        uid,
      ).orderBy('createdAt', descending: false).get();
      return snapshot.docs.map(_fromFirestore).toList();
    } catch (_) {
      return const <ScheduleModel>[];
    }
  }

  static Stream<List<ScheduleModel>> watchRegimes() async* {
    try {
      await migrateLegacyLocalDataIfNeeded();
      final uid = _currentUidOrNull();
      if (uid == null) {
        yield const <ScheduleModel>[];
        return;
      }
      yield* _regimesRef(uid)
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.map(_fromFirestore).toList());
    } catch (_) {
      yield const <ScheduleModel>[];
    }
  }

  static Future<void> saveRegime(ScheduleModel schedule) async {
    await migrateLegacyLocalDataIfNeeded();
    final uid = await _requireUid();
    await _regimesRef(uid).doc(schedule.id).set({
      ..._toFirestore(schedule),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await syncEnabledRegimesWithNative();
  }

  static Future<void> deleteRegime(String id) async {
    await migrateLegacyLocalDataIfNeeded();
    final uid = await _requireUid();
    await _regimesRef(uid).doc(id).delete();
    await syncEnabledRegimesWithNative();
  }

  static Future<void> toggleRegime(String id) async {
    await migrateLegacyLocalDataIfNeeded();
    final uid = await _requireUid();
    final docRef = _regimesRef(uid).doc(id);
    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      if (!snap.exists) return;
      final data = snap.data() ?? <String, dynamic>{};
      final current =
          (data['isActive'] as bool?) ?? (data['isEnabled'] as bool?) ?? true;
      transaction.update(docRef, {
        'isActive': !current,
        'isEnabled': !current,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    await syncEnabledRegimesWithNative();
  }

  static Future<void> syncEnabledRegimesWithNative() async {
    final regimes = await getRegimes();
    final activeRegimes = regimes.where((r) => r.isActive).toList();
    final jsonSchedules = jsonEncode(
      activeRegimes.map((r) => r.toJson()).toList(),
    );
    await NativeBridge.syncSchedules(jsonSchedules);
  }
}

```

## `lib/core/services/scoring_service.dart`
```
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../native_bridge.dart';
import 'auth_service.dart';
import 'persistence_service.dart';
import 'schedule_service.dart';

class ScoringService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static Timer? _syncTimer;
  static bool _initialized = false;

  static const int _baselineScore = 500;
  static const int _minScore = 0;
  static const int _maxScore = 1000;
  static const String _scoringMetaKey = 'scoringMeta';
  static const String _dateKey = 'date';
  static const String _dailyDecayAppliedKey = 'dailyDecayApplied';
  static const String _dailyRewardAppliedKey = 'dailyRewardApplied';

  static void initializePeriodicSync() {
    if (_initialized) return;
    _initialized = true;

    AuthService.authStateChanges.listen((user) {
      _syncTimer?.cancel();
      if (user == null) return;

      syncFocusScore(user.uid);
      _syncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
        syncFocusScore(user.uid);
      });
    });

    final current = AuthService.currentUser;
    if (current != null) {
      syncFocusScore(current.uid);
      _syncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
        syncFocusScore(current.uid);
      });
    }
  }

  static Future<void> syncFocusScore(String uid) async {
    try {
      final userRef = _firestore.collection('users').doc(uid);
      final snapshot = await userRef.get();
      if (!snapshot.exists) return;

      final data = snapshot.data() ?? {};
      final double vowHours = _extractVowHours(data);
      final Map<String, dynamic> reality = await NativeBridge.getRealityCheck();
      final Map<String, bool> restricted =
          await PersistenceService.getRestrictedApps();
      final Set<String> restrictedPackages = restricted.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toSet();

      final double restrictedHoursToday = _estimateRestrictedHoursToday(
        topApps: reality['topApps'] as List? ?? const [],
        restrictedPackages: restrictedPackages,
      );

      final int decayTarget = _calculateDecay(
        restrictedHoursToday: restrictedHoursToday,
        vowHours: vowHours,
      );

      final int regimeSessionsCompleted =
          await _estimateCompletedRegimeSessions(
            restrictedHoursToday,
            vowHours,
          );
      final int rewardTarget = regimeSessionsCompleted * 15;

      await _firestore.runTransaction((tx) async {
        final fresh = await tx.get(userRef);
        if (!fresh.exists) return;

        final user = fresh.data() ?? <String, dynamic>{};
        final int current =
            (user['focusScore'] as num?)?.toInt() ?? _baselineScore;
        final List<int> history = List<int>.from(
          (user['scoreHistory'] as List?)?.map((e) => (e as num).toInt()) ??
              const <int>[],
        );

        final Map<String, dynamic> meta = Map<String, dynamic>.from(
          (user[_scoringMetaKey] as Map?) ?? const {},
        );

        final String today = _dateOnly(DateTime.now());
        final bool isSameDay = meta[_dateKey] == today;
        final int appliedDecay = isSameDay
            ? (meta[_dailyDecayAppliedKey] as num?)?.toInt() ?? 0
            : 0;
        final int appliedReward = isSameDay
            ? (meta[_dailyRewardAppliedKey] as num?)?.toInt() ?? 0
            : 0;

        final int decayDelta = (decayTarget - appliedDecay).clamp(0, 100000);
        final int rewardDelta = (rewardTarget - appliedReward).clamp(0, 100000);

        final int next = _clampScore(current - decayDelta + rewardDelta);
        final List<int> nextHistory = _pushHistory(history, next);

        tx.update(userRef, {
          'focusScore': next,
          'scoreHistory': nextHistory,
          _scoringMetaKey: {
            _dateKey: today,
            _dailyDecayAppliedKey: appliedDecay + decayDelta,
            _dailyRewardAppliedKey: appliedReward + rewardDelta,
            'restrictedHoursToday': restrictedHoursToday,
            'vowHours': vowHours,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        });
      });

      await _syncFocusScoreLocal(uid);
    } catch (_) {}
  }

  static Future<void> applyBeggarsTax(String uid) async {
    await _applyDelta(uid, -25);
  }

  static Future<void> applyRejectedPleaPenalty(String uid) async {
    await _applyDelta(uid, -100);
  }

  static Future<void> _applyDelta(String uid, int delta) async {
    try {
      final userRef = _firestore.collection('users').doc(uid);
      await _firestore.runTransaction((tx) async {
        final fresh = await tx.get(userRef);
        if (!fresh.exists) return;

        final data = fresh.data() ?? <String, dynamic>{};
        final int current =
            (data['focusScore'] as num?)?.toInt() ?? _baselineScore;
        final List<int> history = List<int>.from(
          (data['scoreHistory'] as List?)?.map((e) => (e as num).toInt()) ??
              const <int>[],
        );

        final int next = _clampScore(current + delta);
        final List<int> nextHistory = _pushHistory(history, next);

        tx.update(userRef, {
          'focusScore': next,
          'scoreHistory': nextHistory,
          'lastScoreEventAt': FieldValue.serverTimestamp(),
        });
      });

      await _syncFocusScoreLocal(uid);
    } catch (_) {}
  }

  static Future<void> _syncFocusScoreLocal(String uid) async {
    try {
      final snap = await _firestore.collection('users').doc(uid).get();
      if (!snap.exists) return;
      final int focusScore =
          (snap.data()?['focusScore'] as num?)?.toInt() ?? _baselineScore;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('focus_score', focusScore);
    } catch (_) {}
  }

  static int _clampScore(int value) => value.clamp(_minScore, _maxScore);

  static List<int> _pushHistory(List<int> history, int next) {
    final List<int> out = List<int>.from(history);
    if (out.isNotEmpty && out.last == next) return out;
    out.add(next);
    if (out.length > 7) {
      return out.sublist(out.length - 7);
    }
    return out;
  }

  static double _extractVowHours(Map<String, dynamic> userData) {
    final dynamic vow = userData['vowHours'] ?? userData['goalHours'];
    if (vow is num) return vow.toDouble().clamp(0.5, 24.0);
    return 1.0;
  }

  static int _calculateDecay({
    required double restrictedHoursToday,
    required double vowHours,
  }) {
    final double excess = restrictedHoursToday - vowHours;
    if (excess <= 0) return 0;
    return excess.floor() * 50;
  }

  static double _estimateRestrictedHoursToday({
    required List topApps,
    required Set<String> restrictedPackages,
  }) {
    if (restrictedPackages.isEmpty || topApps.isEmpty) return 0;
    double restrictedMsOver7Days = 0;
    for (final dynamic raw in topApps) {
      if (raw is! Map) continue;
      final String pkg = (raw['packageName'] ?? '').toString();
      if (!restrictedPackages.contains(pkg)) continue;
      final num usageMs = (raw['usageMs'] as num?) ?? 0;
      restrictedMsOver7Days += usageMs.toDouble();
    }
    final double dailyMs = restrictedMsOver7Days / 7.0;
    return dailyMs / (1000 * 60 * 60);
  }

  static Future<int> _estimateCompletedRegimeSessions(
    double restrictedHoursToday,
    double vowHours,
  ) async {
    final schedules = await ScheduleService.getSchedules();
    final bool hasActiveRegimes = schedules.any((s) => s.isActive);
    if (!hasActiveRegimes) return 0;
    if (restrictedHoursToday > vowHours) return 0;
    return 1;
  }

  static String _dateOnly(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}

```

## `lib/core/services/app_discovery_service.dart`
```
import '../native_bridge.dart';
import '../utils/app_categorizer.dart';
import 'persistence_service.dart';

class AppInfo {
  final String name;
  final String packageName;
  final List<int>? icon;
  final AppCategory category;
  bool isRestricted;

  AppInfo({
    required this.name,
    required this.packageName,
    required this.category,
    this.icon,
    this.isRestricted = false,
  });
}

class AppDiscoveryService {
  // Cache for individual app details
  static final Map<String, AppInfo> _appCache = {};

  // Cache for the full app list
  static List<AppInfo>? _cachedApps;
  static Future<List<AppInfo>>? _fetchFuture;

  /// Starts fetching apps in the background if not already cached.
  static void prefetch() {
    if (_cachedApps == null && _fetchFuture == null) {
      getApps();
    }
  }

  static Future<List<AppInfo>> getApps({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedApps != null) {
      return _cachedApps!;
    }

    if (_fetchFuture != null && !forceRefresh) {
      return _fetchFuture!;
    }

    _fetchFuture = _performFetch();

    try {
      final apps = await _fetchFuture!;
      _cachedApps = apps;
      return apps;
    } finally {
      _fetchFuture = null;
    }
  }

  static Future<List<AppInfo>> _performFetch() async {
    try {
      final nativeApps = await NativeBridge.getInstalledApps();
      final restrictedApps = await PersistenceService.getRestrictedApps();

      final list = nativeApps.map((app) {
        final packageName = app['packageName'] as String;
        final nativeCategory = app['category'] as int? ?? -1;

        final info = AppInfo(
          name: app['name'] as String,
          packageName: packageName,
          category: AppCategorizer.categorize(packageName, nativeCategory),
          icon: app['icon'] != null ? List<int>.from(app['icon']) : null,
          isRestricted: restrictedApps[packageName] ?? false,
        );
        _appCache[info.packageName] = info;
        return info;
      }).toList();

      return list;
    } catch (e) {
      print('Error getting apps: $e');
      return _cachedApps ?? [];
    }
  }

  static Future<AppInfo> getAppDetails(String packageName) async {
    // Check cache first
    if (_appCache.containsKey(packageName)) {
      return _appCache[packageName]!;
    }

    try {
      final result = await NativeBridge.getAppDetails(packageName);
      final restrictedApps =
          await PersistenceService.getRestrictedApps(); // Fetch restricted apps here

      final info = AppInfo(
        name: result['name'] as String,
        packageName: packageName,
        category: AppCategory
            .others, // Single app fetch doesn't need category from native, default to others
        icon: result['icon'] != null ? List<int>.from(result['icon']) : null,
        isRestricted:
            restrictedApps[packageName] ?? false, // Apply restriction status
      );

      // Cache the result
      _appCache[packageName] = info;
      return info;
    } catch (e) {
      print('Error getting app details for $packageName: $e');
      // Return a fallback AppInfo
      final fallback = AppInfo(
        name: packageName,
        packageName: packageName,
        category: AppCategory.others,
        icon: null,
        isRestricted: false, // Default to not restricted for fallback
      );
      _appCache[packageName] = fallback;
      return fallback;
    }
  }

  static Future<void> toggleRestriction(AppInfo app) async {
    app.isRestricted = !app.isRestricted;
    final restrictedApps = await PersistenceService.getRestrictedApps();
    restrictedApps[app.packageName] = app.isRestricted;
    await PersistenceService.saveRestrictedApps(restrictedApps);
  }
}

```

## `lib/core/models/user_model.dart`
```
import 'package:cloud_firestore/cloud_firestore.dart';

enum ScoreTrend { up, down, neutral }

class UserModel {
  final String uid;
  final String? email;
  final String? fullName;
  final String? photoUrl;
  final String? nickname;
  final int focusScore;
  final List<int> scoreHistory;
  final DateTime? createdAt;
  final String? squadId;
  final String? squadCode;

  UserModel({
    required this.uid,
    this.email,
    this.fullName,
    this.photoUrl,
    this.nickname,
    required this.focusScore,
    this.scoreHistory = const [],
    this.createdAt,
    this.squadId,
    this.squadCode,
  });

  ScoreTrend get scoreTrend {
    if (scoreHistory.length < 2) return ScoreTrend.neutral;
    final int prev = scoreHistory[scoreHistory.length - 2];
    final int current = scoreHistory.last;
    if (current > prev) return ScoreTrend.up;
    if (current < prev) return ScoreTrend.down;
    return ScoreTrend.neutral;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final int score = (json['focusScore'] as num?)?.toInt() ?? 500;
    final List<int> history = List<int>.from(
      (json['scoreHistory'] as List?)?.map((e) => (e as num).toInt()) ??
          <int>[score],
    );

    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String?,
      fullName: json['fullName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      nickname: json['nickname'] as String?,
      focusScore: score,
      scoreHistory: history,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      squadId: json['squadId'] as String?,
      squadCode: json['squadCode'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'photoUrl': photoUrl,
      'nickname': nickname,
      'focusScore': focusScore,
      'scoreHistory': scoreHistory,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'squadId': squadId,
      'squadCode': squadCode,
    };
  }
}

```

## `lib/core/models/squad_model.dart`
```
import 'package:cloud_firestore/cloud_firestore.dart';

class SquadModel {
  final String id;
  final String squadCode;
  final String creatorId;
  final List<String> memberIds;
  final DateTime? createdAt;

  SquadModel({
    required this.id,
    required this.squadCode,
    required this.creatorId,
    required this.memberIds,
    this.createdAt,
  });

  factory SquadModel.fromJson(Map<String, dynamic> json, String docId) {
    return SquadModel(
      id: docId,
      squadCode: json['squadCode'] as String,
      creatorId: json['creatorId'] as String,
      memberIds: List<String>.from(json['memberIds'] as List? ?? []),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'squadCode': squadCode,
      'creatorId': creatorId,
      'memberIds': memberIds,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}

```

## `lib/core/models/schedule_model.dart`
```
import 'package:flutter/material.dart';

enum ScheduleType {
  timeBlock('TIME BLOCK'),
  usageLimit('USAGE LIMIT'),
  launchCount('LAUNCH COUNT');

  final String label;
  const ScheduleType(this.label);
}

class ScheduleModel {
  final String id;
  final String name;
  final ScheduleType type;
  final List<String> targetApps;
  final List<int> days; // 1-7 (Mon-Sun)
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final Duration? durationLimit;
  final bool isActive;

  ScheduleModel({
    required this.id,
    required this.name,
    required this.type,
    required this.targetApps,
    required this.days,
    this.startTime,
    this.endTime,
    this.durationLimit,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'targetApps': targetApps,
      'days': days,
      'startHour': startTime?.hour,
      'startMinute': startTime?.minute,
      'endHour': endTime?.hour,
      'endMinute': endTime?.minute,
      'durationSeconds': durationLimit?.inSeconds,
      'isActive': isActive,
    };
  }

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    return ScheduleModel(
      id: json['id'],
      name: json['name'],
      type: ScheduleType.values[json['type']],
      targetApps: List<String>.from(json['targetApps']),
      days: List<int>.from(json['days']),
      startTime: json['startHour'] != null
          ? TimeOfDay(hour: json['startHour'], minute: json['startMinute'])
          : null,
      endTime: json['endHour'] != null
          ? TimeOfDay(hour: json['endHour'], minute: json['endMinute'])
          : null,
      durationLimit: json['durationSeconds'] != null
          ? Duration(seconds: json['durationSeconds'])
          : null,
      isActive: json['isActive'] ?? true,
    );
  }

  ScheduleModel copyWith({
    String? name,
    ScheduleType? type,
    List<String>? targetApps,
    List<int>? days,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    Duration? durationLimit,
    bool? isActive,
  }) {
    return ScheduleModel(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      targetApps: targetApps ?? this.targetApps,
      days: days ?? this.days,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationLimit: durationLimit ?? this.durationLimit,
      isActive: isActive ?? this.isActive,
    );
  }
}

```

## `lib/core/models/plea_model.dart`
```
import 'package:cloud_firestore/cloud_firestore.dart';

class PleaModel {
  final String id;
  final String userId;
  final String userName;
  final String squadId;
  final String appName;
  final String packageName;
  final int durationMinutes;
  final String reason;
  final List<String> participants;
  final Map<String, int> voteCounts;
  final Map<String, String> votes;
  final String status;
  final DateTime createdAt;

  PleaModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.squadId,
    required this.appName,
    required this.packageName,
    required this.durationMinutes,
    required this.reason,
    required this.participants,
    required this.voteCounts,
    required this.votes,
    required this.status,
    required this.createdAt,
  });

  factory PleaModel.fromJson(Map<String, dynamic> json, String docId) {
    // Be tolerant of partially-written documents (e.g. serverTimestamp fields that are
    // temporarily null in the local snapshot). A model parse error would propagate as
    // a Stream error and can cause UI flicker, focus loss, and "ACCESS DENIED" noise.
    final rawVotes = Map<String, dynamic>.from(json['votes'] as Map? ?? {});
    final normalizedVotes = <String, String>{};
    rawVotes.forEach((uid, vote) {
      if (vote is bool) {
        normalizedVotes[uid] = vote ? 'accept' : 'reject';
      } else if (vote is String) {
        final normalized = vote.trim().toLowerCase();
        if (normalized == 'accept' || normalized == 'reject') {
          normalizedVotes[uid] = normalized;
        }
      }
    });

    final rawVoteCounts = Map<String, dynamic>.from(
      json['voteCounts'] as Map? ?? {},
    );
    final acceptVotes =
        (rawVoteCounts['accept'] as num?)?.toInt() ??
        normalizedVotes.values.where((v) => v == 'accept').length;
    final rejectVotes =
        (rawVoteCounts['reject'] as num?)?.toInt() ??
        normalizedVotes.values.where((v) => v == 'reject').length;

    final createdAtRaw = json['createdAt'];
    final createdAt = createdAtRaw is Timestamp
        ? createdAtRaw.toDate()
        : DateTime.now();

    return PleaModel(
      id: docId,
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? 'Member',
      squadId: json['squadId'] as String? ?? '',
      appName: json['appName'] as String? ?? 'App',
      packageName: json['packageName'] as String? ?? '',
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 5,
      reason: json['reason'] as String? ?? '',
      participants: List<String>.from(
        json['participants'] as List? ?? const [],
      ),
      voteCounts: {'accept': acceptVotes, 'reject': rejectVotes},
      votes: normalizedVotes,
      status: json['status'] as String? ?? 'active',
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'squadId': squadId,
      'appName': appName,
      'packageName': packageName,
      'durationMinutes': durationMinutes,
      'reason': reason,
      'participants': participants,
      'voteCounts': voteCounts,
      'votes': votes,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

```

## `lib/core/models/plea_message_model.dart`
```
import 'package:cloud_firestore/cloud_firestore.dart';

class PleaMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final bool isSystem;
  final DateTime timestamp;

  PleaMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.isSystem,
    required this.timestamp,
  });

  factory PleaMessageModel.fromJson(Map<String, dynamic> json, String docId) {
    return PleaMessageModel(
      id: docId,
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String? ?? 'Member',
      text: json['text'] as String? ?? '',
      isSystem: json['isSystem'] as bool? ?? false,
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'isSystem': isSystem,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

```

## `lib/features/squad/squad_screen.dart`
```
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/squad_service.dart';
import '../../core/models/user_model.dart';
import '../../core/models/plea_model.dart';
import 'widgets/plea_judgment_card.dart';
import 'widgets/squad_member_card.dart';

class SquadScreen extends StatelessWidget {
  const SquadScreen({super.key});
  static const String _squadCodePrefix = 'REV-';
  static const int _squadCodeTotalLength = 7;
  static const int _squadCodeSuffixLength = 3;

  String _formatSquadCodeInput(String raw) {
    final cleaned = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    String suffix = cleaned.startsWith('REV') ? cleaned.substring(3) : cleaned;
    if (suffix.length > _squadCodeSuffixLength) {
      suffix = suffix.substring(0, _squadCodeSuffixLength);
    }
    final formatted = '$_squadCodePrefix$suffix';
    if (formatted.length > _squadCodeTotalLength) {
      return formatted.substring(0, _squadCodeTotalLength);
    }
    return formatted;
  }

  Future<void> _showSquadHudSheet(
    BuildContext context,
    String squadCode,
  ) async {
    final shouldTransfer = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppSemanticColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.48,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('SQUAD DIRECTIVES', style: AppTheme.h3),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: squadCode));
                      if (!sheetContext.mounted) return;
                      ScaffoldMessenger.of(sheetContext)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('SQUAD CODE COPIED'),
                            duration: Duration(milliseconds: 1200),
                          ),
                        );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.background,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppSemanticColors.accent.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'YOUR SQUAD CODE',
                            textAlign: TextAlign.center,
                            style: AppTheme.labelSmall.copyWith(
                              color: AppSemanticColors.mutedText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              squadCode,
                              textAlign: TextAlign.center,
                              style: AppTheme.squadCodeInput.copyWith(
                                color: AppSemanticColors.accent,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'TAP TO COPY',
                            textAlign: TextAlign.center,
                            style: AppTheme.labelSmall.copyWith(
                              color: AppSemanticColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop(true);
                      },
                      style: AppTheme.secondaryButtonStyle,
                      child: const Text('TRANSFER TO NEW SQUAD'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (shouldTransfer == true && context.mounted) {
      await _showTransferSheet(context, squadCode);
    }
  }

  Future<void> _showTransferSheet(
    BuildContext context,
    String currentSquadCode,
  ) async {
    String transferCode = _squadCodePrefix;
    final squadCodeFormatter = TextInputFormatter.withFunction((
      oldValue,
      newValue,
    ) {
      final formatted = _formatSquadCodeInput(newValue.text);
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    });
    bool isTransferring = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppSemanticColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final normalizedCurrent = currentSquadCode.trim().toUpperCase();
            final normalizedTarget = transferCode.trim().toUpperCase();
            final canSubmit =
                normalizedTarget.length == _squadCodeTotalLength &&
                normalizedTarget != normalizedCurrent &&
                !isTransferring;

            final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('INITIATE TRANSFER', style: AppTheme.h3),
                    const SizedBox(height: 12),
                    Text(
                      'Transferring will remove you from your current squad. If you are the last member, this squad will be deleted.',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppSemanticColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      initialValue: _squadCodePrefix,
                      autofocus: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9-]'),
                        ),
                        LengthLimitingTextInputFormatter(_squadCodeTotalLength),
                        squadCodeFormatter,
                      ],
                      textCapitalization: TextCapitalization.characters,
                      textAlign: TextAlign.center,
                      style: AppTheme.squadCodeInput,
                      onChanged: (value) {
                        setModalState(() {
                          transferCode = value;
                        });
                      },
                      decoration: AppTheme.defaultInputDecoration(
                        hintText: 'REV-XXX',
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: canSubmit
                            ? () async {
                                final uid = AuthService.currentUser?.uid;
                                if (uid == null) return;

                                setModalState(() => isTransferring = true);
                                try {
                                  await SquadService.joinSquad(
                                    uid,
                                    transferCode,
                                  );
                                  if (!sheetContext.mounted) return;
                                  Navigator.of(sheetContext).pop();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'TRANSFER COMPLETE: ALLEGIANCE UPDATED',
                                        ),
                                      ),
                                    );
                                  context.go('/squad');
                                } catch (e) {
                                  if (!sheetContext.mounted) return;
                                  ScaffoldMessenger.of(sheetContext)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      SnackBar(content: Text(e.toString())),
                                    );
                                } finally {
                                  if (sheetContext.mounted) {
                                    setModalState(() => isTransferring = false);
                                  }
                                }
                              }
                            : null,
                        style: AppTheme.primaryButtonStyle,
                        child: Text(
                          isTransferring
                              ? 'PROCESSING TRANSFER...'
                              : 'INITIATE TRANSFER',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = AuthService.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppSemanticColors.background,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>?>(
          future: AuthService.getUserData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppSemanticColors.accent,
                ),
              );
            }

            final userData = snapshot.data;
            final squadId = userData?['squadId'] as String?;
            final squadCode = userData?['squadCode'] as String?;
            final normalizedSquadId = squadId?.trim();

            print(
              'PLEA_DEBUG: SquadScreen user=$currentUid squadId=$normalizedSquadId squadCode=$squadCode',
            );

            if (normalizedSquadId == null || normalizedSquadId.isEmpty) {
              return _buildEmptyState(context, "NO SQUAD JOINED");
            }

            return Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            final normalizedCode = squadCode?.trim();
                            if (normalizedCode == null ||
                                normalizedCode.isEmpty) {
                              return;
                            }
                            _showSquadHudSheet(context, normalizedCode);
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "SQUAD HUD",
                                      style: AppTheme.xxlMedium,
                                    ),
                                    Text(
                                      "SQUAD CODE: ${squadCode ?? '--- ---'}",
                                      style: AppTheme.smMedium.copyWith(
                                        color: AppSemanticColors.accentText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppSemanticColors.accent,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    StreamBuilder<List<PleaModel>>(
                      stream: SquadService.getActivePleasStream(
                        normalizedSquadId,
                      ),
                      builder: (context, liveSnapshot) {
                        if (!liveSnapshot.hasData ||
                            liveSnapshot.data!.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final livePlea = liveSnapshot.data!.firstWhere(
                          (p) => p.status == 'active',
                          orElse: () => liveSnapshot.data!.first,
                        );

                        if (livePlea.status != 'active') {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                          child: GestureDetector(
                            onTap: () =>
                                context.push('/tribunal/${livePlea.id}'),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: AppTheme.warningBannerDecoration,
                              child: Text(
                                'LIVE TRIBUNAL IN PROGRESS',
                                textAlign: TextAlign.center,
                                style: AppTheme.warningBannerTextStyle,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Expanded(
                      child: StreamBuilder<List<UserModel>>(
                        stream: SquadService.getSquadMembersStream(
                          normalizedSquadId,
                        ),
                        builder: (context, streamSnapshot) {
                          if (streamSnapshot.hasError) {
                            return Center(
                              child: Text(
                                "ERROR: ${streamSnapshot.error}",
                                style: AppTheme.baseMedium.copyWith(
                                  color: AppSemanticColors.errorText,
                                ),
                              ),
                            );
                          }

                          if (streamSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: AppSemanticColors.accent,
                              ),
                            );
                          }

                          final members = streamSnapshot.data ?? [];

                          if (members.length <= 1) {
                            return _buildEmptyState(
                              context,
                              "YOU ARE ALONE. APPOINT A WARDEN.",
                              code: squadCode,
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: members.length,
                            itemBuilder: (context, index) {
                              return SquadMemberCard(member: members[index]);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
                // --- JUDGMENT DAY OVERLAY ---
                StreamBuilder<List<PleaModel>>(
                  stream: SquadService.getActivePleasStream(normalizedSquadId),
                  builder: (context, pleaSnapshot) {
                    if (pleaSnapshot.hasError) {
                      print(
                        'PLEA_DEBUG: Plea stream error for squadId=$normalizedSquadId -> ${pleaSnapshot.error}',
                      );
                    }

                    if (pleaSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      print(
                        'PLEA_DEBUG: Plea stream waiting for squadId=$normalizedSquadId',
                      );
                    }

                    if (!pleaSnapshot.hasData || pleaSnapshot.data!.isEmpty) {
                      print(
                        'PLEA_DEBUG: No active pleas visible for squadId=$normalizedSquadId',
                      );
                      return const SizedBox.shrink();
                    }

                    // Filter for pleas that aren't from the current user
                    // and that the current user hasn't voted on yet.
                    final activePleas = pleaSnapshot.data!.where((p) {
                      final hasNotVoted = !p.votes.containsKey(currentUid);
                      final isNotRequester = p.userId != currentUid;
                      return hasNotVoted && isNotRequester;
                    }).toList();

                    print(
                      'PLEA_DEBUG: Pleas fetched=${pleaSnapshot.data!.length} filteredForHud=${activePleas.length} currentUid=$currentUid squadId=$normalizedSquadId',
                    );

                    if (activePleas.isEmpty) return const SizedBox.shrink();

                    // Show the first available plea for judgment
                    return Container(
                      color: AppSemanticColors.background.withValues(
                        alpha: 0.8,
                      ),
                      child: Center(
                        child: PleaJudgmentCard(plea: activePleas.first),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    String message, {
    String? code,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.group_off_rounded,
              color: AppSemanticColors.surface,
              size: 80,
            ),
            const SizedBox(height: 24),
            Text(message, textAlign: TextAlign.center, style: AppTheme.h2),
            const SizedBox(height: 32),
            if (code != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Share.share(
                      "Join my Revoke Squad and watch my screen time: $code",
                    );
                  },
                  icon: const Icon(Icons.share_rounded),
                  label: const Text("SHARE SQUAD CODE"),
                  style: AppTheme.primaryButtonStyle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

```

## `lib/features/squad/tribunal_screen.dart`
```
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/plea_message_model.dart';
import '../../core/models/plea_model.dart';
import '../../core/native_bridge.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/squad_service.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/chat_bubble.dart';

class TribunalScreen extends StatefulWidget {
  final String pleaId;

  const TribunalScreen({super.key, required this.pleaId});

  @override
  State<TribunalScreen> createState() => _TribunalScreenState();
}

class _TribunalScreenState extends State<TribunalScreen> {
  static const String _architectEmail = 'stephenmurya@gmail.com';
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _messageScrollController = ScrollController();
  bool _sending = false;
  bool _voting = false;
  String _senderName = 'Member';
  String? _resolvedStatusHandled;
  bool _showVerdictOverlay = false;
  String _verdictText = '';
  bool _autoScrollQueued = false;
  String? _lastLifecycleStatus;
  PleaMessageModel? _replyingTo;
  bool _isAdminObserver = false;
  bool _adminClaimChecked = false;
  bool _sessionReady = false;
  bool _ghostMode = false;
  bool _applyingOverride = false;
  bool _typingIntent = false;
  Timer? _hideOverlayTimer;
  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();
    _messageFocusNode.addListener(() {
      // Some async rebuilds (streams, overlays, route transitions) can momentarily
      // unmount/remount the TextField, dropping focus. If the user explicitly tapped
      // into the composer, keep focus unless they dismiss it.
      if (!_typingIntent) return;
      if (_messageFocusNode.hasFocus) return;
      scheduleMicrotask(() {
        if (!mounted) return;
        if (_typingIntent && !_messageFocusNode.hasFocus) {
          _messageFocusNode.requestFocus();
        }
      });
    });
    _bootstrapSession();
  }

  @override
  void dispose() {
    _hideOverlayTimer?.cancel();
    _exitTimer?.cancel();
    _messageController.dispose();
    _messageFocusNode.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapSession() async {
    final user = AuthService.currentUser;
    final uid = user?.uid;
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _adminClaimChecked = true;
        _sessionReady = true;
      });
      return;
    }

    final email = user?.email?.trim().toLowerCase();
    bool isAdmin = email == _architectEmail;
    String resolvedSenderName = 'Member';

    try {
      // Force refresh to avoid stale claim state when entering tribunal.
      final tokenResult = await user?.getIdTokenResult(true);
      isAdmin = isAdmin || tokenResult?.claims?['admin'] == true;
    } catch (_) {
      try {
        // Fallback to cached claims when force refresh fails.
        final tokenResult = await user?.getIdTokenResult();
        isAdmin = isAdmin || tokenResult?.claims?['admin'] == true;
      } catch (_) {}
    }

    if (!isAdmin) {
      try {
        await SquadService.joinPleaSession(widget.pleaId, uid);
      } catch (_) {}
    }

    try {
      final userData = await AuthService.getUserData();
      final nickname = (userData?['nickname'] as String?)?.trim();
      final fullName = (userData?['fullName'] as String?)?.trim();
      final resolved = (nickname?.isNotEmpty == true)
          ? nickname!
          : ((fullName?.isNotEmpty == true) ? fullName! : 'Member');
      resolvedSenderName = resolved;
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isAdminObserver = isAdmin;
      _adminClaimChecked = true;
      _sessionReady = true;
      _senderName = resolvedSenderName;
      // Default admin chat to Ghost Mode to avoid callable-layer rejection for admin users
      // and make mock tribunal simulations immediately usable.
      _ghostMode = isAdmin;
    });
  }

  Future<void> _sendMessage() async {
    final uid = AuthService.currentUser?.uid;
    final text = _messageController.text.trim();
    if (uid == null || text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      if (_isAdminObserver && _ghostMode) {
        await FirebaseFirestore.instance
            .collection('pleas')
            .doc(widget.pleaId)
            .collection('messages')
            .add({
              'senderId': 'THE_ARCHITECT',
              'senderName': 'The Architect',
              'text': text,
              'isSystem': true,
              'timestamp': FieldValue.serverTimestamp(),
            });
      } else {
        await SquadService.sendPleaMessage(
          pleaId: widget.pleaId,
          senderId: uid,
          senderName: _senderName,
          text: text,
        );
      }
      _messageController.clear();
      _replyingTo = null;
      _scrollMessagesToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('MESSAGE FAILED: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollMessagesToBottom() {
    if (_autoScrollQueued) return;
    _autoScrollQueued = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _autoScrollQueued = false;
      if (!mounted || !_messageScrollController.hasClients) return;
      final target = _messageScrollController.position.maxScrollExtent;
      _messageScrollController.jumpTo(target);
    });
  }

  void _setReplyTarget(PleaMessageModel message) {
    setState(() {
      _replyingTo = message;
    });
  }

  void _clearReplyTarget() {
    if (_replyingTo == null) return;
    setState(() {
      _replyingTo = null;
    });
  }

  Future<void> _setVote(String voteChoice) async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null || _voting) return;

    setState(() => _voting = true);
    try {
      await SquadService.voteOnPleaChoice(widget.pleaId, uid, voteChoice);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('VOTE FAILED: $e')));
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  Future<void> _confirmAndOverride({
    required String verdict,
    required PleaModel plea,
  }) async {
    if (_applyingOverride) return;

    final reasonController = TextEditingController();
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppSemanticColors.surface,
          title: Text('Force Resolve this plea?', style: AppTheme.h3),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${plea.userName} on ${plea.appName} (${plea.durationMinutes}m)',
                style: AppTheme.bodySmall.copyWith(
                  color: AppSemanticColors.secondaryText,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: AppTheme.defaultInputDecoration(
                  hintText: 'Reason (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(verdict == 'approved' ? 'Approve' : 'Reject'),
            ),
          ],
        );
      },
    );

    if (shouldProceed != true) return;

    setState(() => _applyingOverride = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'adminOverridePlea',
      );
      await callable.call({
        'pleaId': widget.pleaId,
        'verdict': verdict,
        'reason': reasonController.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Override applied: ${verdict.toUpperCase()}')),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final message = e.message ?? e.code;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Override failed: $message')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Override failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _applyingOverride = false);
      }
    }
  }

  Widget _buildAdminTribunalControls(PleaModel plea) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppSemanticColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppSemanticColors.primaryText.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admin Tribunal Controls', style: AppTheme.bodyMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _applyingOverride
                      ? null
                      : () => _confirmAndOverride(
                          verdict: 'approved',
                          plea: plea,
                        ),
                  style: AppTheme.primaryButtonStyle.copyWith(
                    backgroundColor: const WidgetStatePropertyAll(
                      AppSemanticColors.approve,
                    ),
                    foregroundColor: const WidgetStatePropertyAll(
                      AppSemanticColors.inverseText,
                    ),
                  ),
                  child: const Text('Approve'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _applyingOverride
                      ? null
                      : () => _confirmAndOverride(
                          verdict: 'rejected',
                          plea: plea,
                        ),
                  style: AppTheme.dangerButtonStyle,
                  child: const Text('Reject'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ghost Mode', style: AppTheme.bodyMedium),
                    Text(
                      'Send as The Architect',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppSemanticColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _ghostMode,
                onChanged: (value) => setState(() => _ghostMode = value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleResolutionLifecycle(PleaModel plea) {
    final status = plea.status.trim().toLowerCase();
    if (status != 'approved' && status != 'rejected') return;
    if (_resolvedStatusHandled != null) return;

    _resolvedStatusHandled = status;

    final uid = AuthService.currentUser?.uid;
    if (status == 'approved' &&
        uid != null &&
        uid == plea.userId &&
        plea.packageName.trim().isNotEmpty) {
      final grantedMinutes = plea.durationMinutes > 0
          ? plea.durationMinutes
          : 5;
      NativeBridge.temporaryUnlock(plea.packageName.trim(), grantedMinutes);
    }

    // Admin observers should not auto-exit or trigger overlay transitions.
    // They can keep watching the room state without lifecycle side-effects.
    if (_isAdminObserver) {
      return;
    }

    final verdictText = status == 'approved'
        ? 'VERDICT: GRANTED'
        : 'VERDICT: REJECTED';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _verdictText = verdictText;
        _showVerdictOverlay = true;
      });
    });

    _hideOverlayTimer?.cancel();
    _hideOverlayTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showVerdictOverlay = false);
    });

    _exitTimer?.cancel();
    _exitTimer = Timer(const Duration(seconds: 5), () async {
      if (!mounted) return;
      await SquadService.markPleaForDeletion(widget.pleaId);
      if (!mounted) return;
      context.go('/squad');
    });
  }

  Widget _buildTribunalHud(PleaModel plea) {
    final rejectCount = plea.voteCounts['reject'] ?? 0;
    final approveCount = plea.voteCounts['accept'] ?? 0;
    final rejectLeading = rejectCount > approveCount;
    final approveLeading = approveCount > rejectCount;

    final rejectBg = rejectLeading
        ? AppSemanticColors.reject
        : AppSemanticColors.reject.withValues(alpha: 0.14);
    final approveBg = approveLeading
        ? AppSemanticColors.approve
        : AppSemanticColors.approve.withValues(alpha: 0.14);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: AppTheme.tribunalScoreboardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${plea.userName} asks ${plea.durationMinutes}m on ${plea.appName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.smBold.copyWith(
              color: AppSemanticColors.primaryText,
            ),
          ),
          if (plea.reason.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '"${plea.reason.trim()}"',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.smRegular.copyWith(
                color: AppSemanticColors.secondaryText,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: rejectBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppSemanticColors.reject),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: AppSemanticColors.reject,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'REJECT [$rejectCount]',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.xsBold.copyWith(
                            color: AppSemanticColors.rejectText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: approveBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppSemanticColors.approve),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AppSemanticColors.approve,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'APPROVE [$approveCount]',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.xsBold.copyWith(
                            color: AppSemanticColors.approveText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = AuthService.currentUser?.uid;

    if (!_adminClaimChecked || !_sessionReady) {
      return Scaffold(
        backgroundColor: AppSemanticColors.background,
        appBar: AppBar(
          backgroundColor: AppSemanticColors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text('The Tribunal', style: AppTheme.h2),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppSemanticColors.accent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppSemanticColors.background,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: AppSemanticColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text('The Tribunal', style: AppTheme.h2),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Some entry paths (dialogs/sheets) can yield an unbounded height.
          // Clamp Tribunal to the viewport height to avoid layout/semantics crashes.
          final boundedHeight = constraints.hasBoundedHeight
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height;

          return SizedBox(
            height: boundedHeight,
            width: double.infinity,
            child: StreamBuilder<PleaModel?>(
              stream: SquadService.getPleaStream(widget.pleaId),
              builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'ACCESS DENIED',
                style: AppTheme.h3.copyWith(color: AppSemanticColors.errorText),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppSemanticColors.accent),
            );
          }

          final plea = snapshot.data;
          if (plea == null) {
            return Center(
              child: Text(
                'SESSION NOT FOUND',
                style: AppTheme.h3.copyWith(
                  color: AppSemanticColors.accentText,
                ),
              ),
            );
          }

          final lifecycleStatus = plea.status.trim().toLowerCase();
          if (_lastLifecycleStatus != lifecycleStatus) {
            _lastLifecycleStatus = lifecycleStatus;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _handleResolutionLifecycle(plea);
            });
          }

          final isParticipant =
              currentUid != null && plea.participants.contains(currentUid);
          final canAccessSession = isParticipant || _isAdminObserver;
          if (!canAccessSession) {
            return Center(
              child: Text(
                'ACCESS DENIED',
                style: AppTheme.h3.copyWith(color: AppSemanticColors.errorText),
              ),
            );
          }

          final userVote = currentUid == null ? null : plea.votes[currentUid];
          final isRequester = currentUid != null && currentUid == plea.userId;
          final canVote =
              currentUid != null &&
              plea.status == 'active' &&
              !isRequester &&
              !_isAdminObserver;
          final isAdmin = _isAdminObserver;
          final showObserverBanner = isAdmin && !isParticipant;
          final voteLocked = !canVote || _voting;

          return Stack(
            children: [
              Column(
                children: [
                  _buildTribunalHud(plea),
                  if (showObserverBanner)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: AppTheme.warningBannerDecoration,
                      child: Text(
                        'SYSTEM OBSERVER ACTIVE',
                        textAlign: TextAlign.center,
                        style: AppTheme.warningBannerTextStyle,
                      ),
                    ),
                  Expanded(
                    child: StreamBuilder<List<PleaMessageModel>>(
                      stream: SquadService.getPleaMessagesStream(widget.pleaId),
                      builder: (context, msgSnapshot) {
                        if (msgSnapshot.hasError) {
                          return Center(
                            child: Text(
                              'ACCESS DENIED OR CHAT ERROR.',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppSemanticColors.errorText,
                              ),
                            ),
                          );
                        }

                        final messages = msgSnapshot.data ?? const [];
                        if (messages.isEmpty) {
                          return Center(
                            child: Text(
                              'NO MESSAGES YET',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppSemanticColors.mutedText,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: _messageScrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isMine = message.senderId == currentUid;
                            return ChatBubble(
                              message: message,
                              isMine: isMine,
                              onSwipeReply: _isAdminObserver
                                  ? null
                                  : () => _setReplyTarget(message),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isAdmin) ...[
                            _buildAdminTribunalControls(plea),
                            const SizedBox(height: 10),
                          ],
                          if (!isRequester && !isAdmin) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: voteLocked
                                        ? null
                                        : () => _setVote('accept'),
                                    style: AppTheme.tribunalVoteButtonStyle(
                                      isSelected: userVote == 'accept',
                                    ),
                                    child: const Text('Approve'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: voteLocked
                                        ? null
                                        : () => _setVote('reject'),
                                    style: AppTheme.tribunalVoteButtonStyle(
                                      isSelected: userVote == 'reject',
                                      isDanger: true,
                                    ),
                                    child: const Text('Reject'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (_replyingTo != null && !isAdmin) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppSemanticColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppSemanticColors.approve,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.reply_rounded,
                                    size: 16,
                                    color: AppSemanticColors.approve,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Replying to ${_replyingTo!.senderName}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTheme.labelSmall.copyWith(
                                            color: AppSemanticColors.approve,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _replyingTo!.text,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTheme.bodySmall.copyWith(
                                            color:
                                                AppSemanticColors.secondaryText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _clearReplyTarget,
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: AppSemanticColors.mutedText,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 56,
                                  child: TextField(
                                    key: const ValueKey(
                                      'tribunal_message_input',
                                    ),
                                    controller: _messageController,
                                    focusNode: _messageFocusNode,
                                    onTap: () => _typingIntent = true,
                                    onTapOutside: (_) {
                                      _typingIntent = false;
                                      _messageFocusNode.unfocus();
                                    },
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    decoration: AppTheme.defaultInputDecoration(
                                      hintText: isAdmin
                                          ? (_ghostMode
                                                ? 'Ghost message as The Architect...'
                                                : 'Send admin note...')
                                          : 'Type your argument...',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _sending ? null : _sendMessage,
                                  style: AppTheme.primaryButtonStyle.copyWith(
                                    padding: const WidgetStatePropertyAll(
                                      EdgeInsets.symmetric(horizontal: 18),
                                    ),
                                    minimumSize: const WidgetStatePropertyAll(
                                      Size(56, 56),
                                    ),
                                  ),
                                  child: const Icon(Icons.send_rounded),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_showVerdictOverlay)
                Positioned.fill(
                  child: Container(
                    color: AppSemanticColors.background.withValues(alpha: 0.92),
                    alignment: Alignment.center,
                    child: Text(
                      _verdictText,
                      style: AppTheme.h1.copyWith(
                        color: _verdictText.contains('REJECTED')
                            ? AppSemanticColors.errorText
                            : AppSemanticColors.accentText,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
            ],
          );
              },
            ),
          );
        },
      ),
    );
  }
}

```

## `lib/features/plea/plea_compose_screen.dart`
```
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/native_bridge.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/squad_service.dart';
import '../../core/theme/app_theme.dart';
import '../squad/tribunal_screen.dart';

class BegForTimeScreen extends StatefulWidget {
  final String appName;
  final String packageName;

  const BegForTimeScreen({
    super.key,
    required this.appName,
    required this.packageName,
  });

  @override
  State<BegForTimeScreen> createState() => _BegForTimeScreenState();
}

class _BegForTimeScreenState extends State<BegForTimeScreen> {
  static const List<int> _durationOptions = [5, 10, 20, 30];

  final TextEditingController _reasonController = TextEditingController();
  int _selectedMinutes = 5;
  bool _submitting = false;

  Future<Map<String, dynamic>> _loadAppDetails() async {
    try {
      return await NativeBridge.getAppDetails(widget.packageName);
    } catch (_) {
      return {'name': widget.appName};
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitPlea() async {
    if (_submitting) return;

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ADD A REASON FOR THE SQUAD.')),
      );
      return;
    }

    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;

    setState(() => _submitting = true);
    try {
      final userData = await AuthService.getUserData();
      final squadId = (userData?['squadId'] as String?)?.trim();
      final nickname = (userData?['nickname'] as String?)?.trim();

      if (squadId == null || squadId.isEmpty) {
        throw Exception('NO SQUAD FOUND');
      }

      final newPleaId = await SquadService.createPlea(
        uid: uid,
        userName: nickname?.isNotEmpty == true ? nickname! : 'A Member',
        squadId: squadId,
        appName: widget.appName,
        packageName: widget.packageName,
        durationMinutes: _selectedMinutes,
        reason: reason,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => TribunalScreen(pleaId: newPleaId)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PLEA FAILED: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Beg for time', style: AppTheme.h3),
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _loadAppDetails(),
          builder: (context, snapshot) {
            final appData = snapshot.data;
            final iconBytes = appData?['icon'] as Uint8List?;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        color: AppSemanticColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppSemanticColors.primaryText.withValues(
                            alpha: 0.08,
                          ),
                          width: 1.5,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: iconBytes != null
                          ? Image.memory(iconBytes, fit: BoxFit.cover)
                          : const Icon(
                              Icons.apps_rounded,
                              size: 56,
                              color: AppSemanticColors.accent,
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.appName,
                    textAlign: TextAlign.center,
                    style: AppTheme.xlMedium,
                  ),
                  const SizedBox(height: 24),
                  Text('Time request', style: AppTheme.labelSmall),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _durationOptions.map((minutes) {
                      final selected = _selectedMinutes == minutes;
                      return ChoiceChip(
                        label: Text('$minutes mins'),
                        selected: selected,
                        labelStyle: AppTheme.smBold.copyWith(
                          color: selected
                              ? AppSemanticColors.onAccentText
                              : AppSemanticColors.primaryText,
                        ),
                        selectedColor: AppSemanticColors.accent,
                        backgroundColor: AppSemanticColors.surface,
                        side: BorderSide(
                          color: selected
                              ? AppSemanticColors.accent
                              : AppSemanticColors.primaryText,
                        ),
                        onSelected: (_) {
                          setState(() => _selectedMinutes = minutes);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _reasonController,
                    maxLines: 4,
                    maxLength: 180,
                    decoration: AppTheme.defaultInputDecoration(
                      labelText: 'Why do you need more time?',
                      hintText: 'Tell your squad exactly why...',
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submitPlea,
                    style: AppTheme.primaryButtonStyle,
                    child: Text(_submitting ? 'Sending...' : 'Beg for time'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _submitting ? null : () => context.go('/home'),
                    style: AppTheme.secondaryButtonStyle,
                    child: const Text('Cancel plea'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

```

## `lib/features/permissions/permission_screen.dart`
```
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/native_bridge.dart';
import '../../core/theme/app_theme.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  bool _hasUsageStats = false;
  bool _hasOverlay = false;
  bool _hasBatteryOptOut = false;
  StreamSubscription? _permissionSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();

    // Check every 2 seconds while on this screen
    _permissionSubscription = Stream.periodic(const Duration(seconds: 2))
        .listen((_) {
          _checkPermissions();
        });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _permissionSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final perms = await NativeBridge.checkPermissions();
    if (mounted) {
      setState(() {
        _hasUsageStats = perms['usage_stats'] ?? false;
        _hasOverlay = perms['overlay'] ?? false;
        _hasBatteryOptOut = perms['battery_optimization_ignored'] ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text(
                'Revoke is blind.',
                style: AppTheme.h1.copyWith(
                  color: AppSemanticColors.danger,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You revoked our access. We cannot see your activity.',
                style: AppTheme.baseRegular.copyWith(
                  color: AppSemanticColors.primaryText,
                ),
              ),
              const SizedBox(height: 48),
              _buildPermissionCard(
                title: 'Usage access',
                description:
                    'Required to detect when restricted apps are opened.',
                isGranted: _hasUsageStats,
                onGrant: () => NativeBridge.requestUsageStats(),
                color: AppSemanticColors.accent,
              ),
              const SizedBox(height: 20),
              _buildPermissionCard(
                title: 'Draw over apps',
                description: 'Required to show the block screen overlay.',
                isGranted: _hasOverlay,
                onGrant: () => NativeBridge.requestOverlay(),
                color: AppSemanticColors.accent,
              ),
              const SizedBox(height: 20),
              _buildPermissionCard(
                title: 'Battery optimization',
                description:
                    'Required so Revoke can survive background restrictions and reboots.',
                isGranted: _hasBatteryOptOut,
                onGrant: () => NativeBridge.requestBatteryOptimizations(),
                color: AppSemanticColors.accent,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_hasUsageStats && _hasOverlay && _hasBatteryOptOut)
                      ? () => context.go('/home')
                      : null,
                  style: AppTheme.primaryButtonStyle,
                  child: const Text('Restore vision'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onGrant,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppSemanticColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted
              ? Colors.greenAccent
              : AppSemanticColors.primaryText.withValues(alpha: 0.1),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.lgMedium),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTheme.baseRegular.copyWith(
                    color: AppSemanticColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (isGranted)
            const Icon(Icons.check_circle, color: AppSemanticColors.success)
          else
            ElevatedButton(
              onPressed: onGrant,
              style: AppTheme.secondaryButtonStyle.copyWith(
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                backgroundColor: const WidgetStatePropertyAll(AppSemanticColors.background),
              ),
              child: Text('Grant', style: AppTheme.baseBold),
            ),
        ],
      ),
    );
  }
}

```

## Android Native (Kotlin)
## `android/app/src/main/AndroidManifest.xml`
```
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <uses-permission android:name="android.permission.PACKAGE_USAGE_STATS" tools:ignore="ProtectedPermissions" />
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
    <uses-permission android:name="android.permission.SET_WALLPAPER" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" tools:ignore="QueryAllPackagesPermission" />

    <application
        android:label="Revoke"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <!-- Specifies an Android theme to apply to this Activity as soon as
                 the Android process has started. This theme is visible to the user
                 while the Flutter UI initializes. After that, this theme continues
                 to determine the Window background behind the Flutter UI. -->
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <service
            android:name=".AppMonitorService"
            android:foregroundServiceType="dataSync"
            android:exported="false" />

        <receiver
            android:name=".BootReceiver"
            android:enabled="true"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
            </intent-filter>
        </receiver>

        <receiver
            android:name=".ServiceRestartReceiver"
            android:enabled="true"
            android:exported="false">
            <intent-filter>
                <action android:name="com.revoke.app.RESTART_SERVICE" />
            </intent-filter>
        </receiver>

        <!-- Don't delete the meta-data below.
             This is used by the Flutter tool to generate GeneratedPluginRegistrant.java -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />

        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="squad_alerts" />
    </application>
    <!-- Required to query activities that can process text, see:
         https://developer.android.com/training/package-visibility and
         https://developer.android.com/reference/android/content/Intent#ACTION_PROCESS_TEXT.

         In particular, this is used by the Flutter engine in io.flutter.plugin.text.ProcessTextPlugin. -->
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>

```

## `android/app/build.gradle.kts`
```
plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

import com.android.build.gradle.internal.api.BaseVariantOutputImpl

android {
    namespace = "com.example.revoke"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.revoke"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    applicationVariants.all {
        outputs.all {
            val output = this as BaseVariantOutputImpl
            output.outputFileName = "Revoke_v${versionName}.apk"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:34.9.0"))

    // Add the dependencies for Firebase products you want to use
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
}

```

## `android/app/src/main/kotlin/com/example/revoke/MainActivity.kt`
```
package com.example.revoke

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.usage.UsageStatsManager
import java.util.Calendar
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.revoke.app/overlay"
    private var methodChannel: MethodChannel? = null
    private var overlayReceiverRegistered = false
    private var pendingPleaPayload: Map<String, String?>? = null

    private val overlayReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                "com.revoke.app.SHOW_OVERLAY" -> {
                    methodChannel?.invokeMethod("showOverlay", null)
                }
                "com.revoke.app.REQUEST_PLEA" -> {
                    val appName = intent.getStringExtra("appName")
                    val packageName = intent.getStringExtra("packageName")
                    dispatchPleaRequest(appName, packageName)
                }
            }
        }
    }

    private fun dispatchPleaRequest(appName: String?, packageName: String?) {
        val payload = mapOf(
            "appName" to appName,
            "packageName" to packageName
        )
        if (methodChannel == null) {
            pendingPleaPayload = payload
            return
        }
        methodChannel?.invokeMethod("requestPlea", payload)
    }

    private fun handleIncomingIntent(intent: Intent?) {
        if (intent?.action == "com.revoke.app.REQUEST_PLEA") {
            val appName = intent.getStringExtra("appName")
            val packageName = intent.getStringExtra("packageName")
            dispatchPleaRequest(appName, packageName)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        pendingPleaPayload?.let {
            methodChannel?.invokeMethod("requestPlea", it)
            pendingPleaPayload = null
        }
        handleIncomingIntent(intent)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermissions" -> {
                    result.success(checkPermissions())
                }
                "requestUsageStats" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(true)
                }
                "requestOverlay" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                    }
                    result.success(true)
                }
                "requestBatteryOptimizations" -> {
                    requestIgnoreBatteryOptimizations()
                    result.success(true)
                }
                "getInstalledApps" -> {
                    // Running on a background thread to prevent UI stutter
                    Thread {
                        val apps = getInstalledApps()
                        runOnUiThread {
                            result.success(apps)
                        }
                    }.start()
                }
                "syncSchedules" -> {
                    val schedulesJson = call.argument<String>("schedules")
                    val intent = Intent(this, AppMonitorService::class.java)
                    intent.action = "com.revoke.app.SYNC_SCHEDULES"
                    intent.putExtra("schedules", schedulesJson)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "startService" -> {
                    val perms = checkPermissions()
                    val hasUsageStats = perms["usage_stats"] == true
                    val hasOverlay = perms["overlay"] == true
                    val hasBatteryOptOut =
                        perms["battery_optimization_ignored"] == true

                    if (!hasUsageStats || !hasOverlay || !hasBatteryOptOut) {
                        result.error(
                            "PERMISSION_DENIED",
                            "Usage Stats, Overlay, and Battery Optimization exemption are required before starting service.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    val intent = Intent(this, AppMonitorService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "getAppDetails" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName == null) {
                        result.error("INVALID_ARGUMENT", "packageName is required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val pm = packageManager
                        val appInfo = pm.getApplicationInfo(packageName, 0)
                        val appName = pm.getApplicationLabel(appInfo).toString()
                        val icon = getAppIcon(packageName)

                        val appMap = mutableMapOf<String, Any>(
                            "name" to appName,
                            "packageName" to packageName
                        )

                        icon?.let {
                            appMap["icon"] = it
                        }

                        result.success(appMap)
                    } catch (e: Exception) {
                        result.error("APP_NOT_FOUND", "Could not find app: $packageName", null)
                    }
                }
                "getRealityCheck" -> {
                    Thread {
                        val realityData = getRealityCheck()
                        runOnUiThread {
                            result.success(realityData)
                        }
                    }.start()
                }
                "temporaryUnlock" -> {
                    val packageName = call.argument<String>("packageName")
                    val minutes = call.argument<Int>("minutes") ?: 5
                    if (packageName != null) {
                        val intent = Intent(this, AppMonitorService::class.java)
                        intent.action = "com.revoke.app.TEMP_UNLOCK"
                        intent.putExtra("packageName", packageName)
                        intent.putExtra("minutes", minutes)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "packageName is required", null)
                    }
                }
                "getTemporaryApprovals" -> {
                    result.success(getTemporaryApprovals())
                }
                "pauseMonitoring" -> {
                    val minutes = call.argument<Int>("minutes") ?: 60
                    setAmnestyExpiry(minutes)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        registerOverlayReceiverIfNeeded()
        handleIncomingIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingIntent(intent)
    }

    private fun registerOverlayReceiverIfNeeded() {
        if (overlayReceiverRegistered) return
        val filter = android.content.IntentFilter().apply {
            addAction("com.revoke.app.SHOW_OVERLAY")
            addAction("com.revoke.app.REQUEST_PLEA")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            registerReceiver(overlayReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(overlayReceiver, filter)
        }
        overlayReceiverRegistered = true
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            if (overlayReceiverRegistered) {
                unregisterReceiver(overlayReceiver)
                overlayReceiverRegistered = false
            }
        } catch (e: Exception) {
            // Ignore
        }
    }

    private fun getRealityCheck(): Map<String, Any> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val calendar = Calendar.getInstance()
        val endTime = calendar.timeInMillis
        calendar.add(Calendar.DAY_OF_YEAR, -7)
        val startTime = calendar.timeInMillis

        val stats = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            usageStatsManager.queryAndAggregateUsageStats(startTime, endTime)
        } else {
            emptyMap()
        }
        
        var totalTimeMs = 0L
        val appUsageList = mutableListOf<Map<String, Any>>()

        for ((pkg, usage) in stats) {
            val timeInForeground = usage.totalTimeInForeground
            // Exclude common system apps and Revoke itself
            if (timeInForeground > 30000 && pkg != packageName && !pkg.contains("launcher") && !pkg.contains("systemui")) {
                totalTimeMs += timeInForeground
                appUsageList.add(mapOf(
                    "packageName" to pkg,
                    "usageMs" to timeInForeground
                ))
            }
        }

        // Sort to get top 3
        appUsageList.sortByDescending { it["usageMs"] as Long }
        val topApps = appUsageList.take(3)

        return mapOf(
            "totalAvgDailyHours" to (totalTimeMs / (1000 * 60 * 60 * 7.0)),
            "topApps" to topApps
        )
    }

    private fun getInstalledApps(): List<Map<String, Any>> {
        val pm = packageManager
        // Intent that searches for all apps that can be launched (have an icon)
        val mainIntent = Intent(Intent.ACTION_MAIN, null)
        mainIntent.addCategory(Intent.CATEGORY_LAUNCHER)

        val resolveInfos: List<ResolveInfo> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(mainIntent, PackageManager.ResolveInfoFlags.of(0L))
        } else {
            pm.queryIntentActivities(mainIntent, 0)
        }

        val installedApps = mutableListOf<Map<String, Any>>()
        val seenPackages = mutableSetOf<String>()

        for (resolveInfo in resolveInfos) {
            val activityInfo = resolveInfo.activityInfo
            val packageName = activityInfo.packageName
            
            // Prevent duplicates (some apps have multiple launcher icons)
            if (!seenPackages.contains(packageName)) {
                val appName = resolveInfo.loadLabel(pm).toString()
                
                val appMap = mutableMapOf<String, Any>(
                    "name" to appName,
                    "packageName" to packageName
                )

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    appMap["category"] = activityInfo.applicationInfo.category
                } else {
                    appMap["category"] = -1
                }

                getAppIcon(packageName)?.let {
                    appMap["icon"] = it
                }

                android.util.Log.d("RevokeAppDiscovery", "Found app: $appName ($packageName)")

                installedApps.add(appMap)
                seenPackages.add(packageName)
            }
        }
        return installedApps
    }

    private fun getAppIcon(packageName: String): ByteArray? {
        return try {
            val icon = packageManager.getApplicationIcon(packageName)
            val bitmap = if (icon is android.graphics.drawable.BitmapDrawable) {
                icon.bitmap
            } else {
                val width = icon.intrinsicWidth.takeIf { it > 0 } ?: 1
                val height = icon.intrinsicHeight.takeIf { it > 0 } ?: 1
                val bitmap = android.graphics.Bitmap.createBitmap(width, height, android.graphics.Bitmap.Config.ARGB_8888)
                val canvas = android.graphics.Canvas(bitmap)
                icon.setBounds(0, 0, canvas.width, canvas.height)
                icon.draw(canvas)
                bitmap
            }
            val stream = java.io.ByteArrayOutputStream()
            bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, stream)
            stream.toByteArray()
        } catch (e: Exception) {
            null
        }
    }

    private fun checkPermissions(): Map<String, Boolean> {
        val usageStats = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
            mode == AppOpsManager.MODE_ALLOWED
        } else {
            true
        }

        val overlay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }

        val batteryOptimizationIgnored = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            pm.isIgnoringBatteryOptimizations(packageName)
        } else {
            true
        }

        return mapOf(
            "usage_stats" to usageStats,
            "overlay" to overlay,
            "battery_optimization_ignored" to batteryOptimizationIgnored
        )
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            val intent = Intent(
                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
        } catch (_: Exception) {
            try {
                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            } catch (_: Exception) {
                // Ignore
            }
        }
    }

    private fun getTemporaryApprovals(): List<String> {
        val prefs = getSharedPreferences("RevokeConfig", Context.MODE_PRIVATE)
        val raw = prefs.getString("temp_unlocks", null) ?: return emptyList()
        val now = System.currentTimeMillis()
        return try {
            val json = JSONObject(raw)
            val active = mutableListOf<String>()
            val expired = mutableListOf<String>()
            val keys = json.keys()
            while (keys.hasNext()) {
                val pkg = keys.next()
                val expiry = json.optLong(pkg, 0L)
                if (expiry > now) {
                    active.add(pkg)
                } else {
                    expired.add(pkg)
                }
            }
            if (expired.isNotEmpty()) {
                for (pkg in expired) {
                    json.remove(pkg)
                }
                prefs.edit().putString("temp_unlocks", json.toString()).apply()
            }
            active
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun setAmnestyExpiry(minutes: Int) {
        val safeMinutes = minutes.coerceAtLeast(0)
        val now = System.currentTimeMillis()
        val expiry = now + (safeMinutes.toLong() * 60L * 1000L)
        val prefs = getSharedPreferences("RevokeConfig", Context.MODE_PRIVATE)
        prefs.edit().putLong("amnesty_expiry", expiry).apply()
        android.util.Log.d("RevokeAmnesty", "Monitoring paused for $safeMinutes minute(s).")
    }
}

```

## `android/app/src/main/kotlin/com/example/revoke/AppMonitorService.kt`
```
package com.example.revoke

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.AlarmManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.view.Gravity
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import org.json.JSONObject

class AppMonitorService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private var windowManager: WindowManager? = null
    private var overlayView: android.view.View? = null
    private var lastKnownForegroundPackage: String = ""
    private var lastLoggedApp: String = ""
    private var lastUsageStatsFallbackAt: Long = 0L
    private var lastEventsQueryAt: Long = 0L
    private var activeSchedules: java.util.concurrent.CopyOnWriteArrayList<org.json.JSONObject> = java.util.concurrent.CopyOnWriteArrayList()
    private var blockedAppsIndex: HashSet<String> = HashSet()
    private val tempUnlockedPackages = mutableMapOf<String, Long>()
    private val usageStatsFallbackIntervalMs = 12_000L
    private var lastAmnestyLogAt: Long = 0L
    private var lastRestrictedDetectedAt: Long = 0L
    private var lastHealthWriteAt: Long = 0L
    private var cachedRiskWindow: Boolean = false
    private var lastRiskEvalAt: Long = 0L
    private var monitorLoopStarted: Boolean = false
    private lateinit var prefs: android.content.SharedPreferences

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        prefs = getSharedPreferences("RevokeConfig", Context.MODE_PRIVATE)
        
        // Load persisted schedules
        val savedSchedules = prefs.getString("schedules", null)
        if (savedSchedules != null) {
            updateSchedules(savedSchedules)
            android.util.Log.d("RevokeMonitor", "Loaded ${activeSchedules.size} persisted schedules")
        }
        loadTempUnlocks()
        
        startForegroundService()
        
        // CRITICAL: Start the monitoring loop
        startMonitorLoopIfNeeded()
        android.util.Log.d("RevokeMonitor", "Monitoring loop started")
    }

    private fun startMonitorLoopIfNeeded() {
        if (monitorLoopStarted) return
        monitorLoopStarted = true
        handler.post(runnable)
    }

    private fun startForegroundService() {
        val channelId = "AppMonitorChannel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "App Monitor Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }

        val notification: Notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Revoke is active")
            .setContentText("Guarding your focus.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(1, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(1, notification)
        }
    }

    private val runnable = object : Runnable {
        override fun run() {
            val now = System.currentTimeMillis()
            var nextDelayMs = 5_000L
            try {
                writeSelfHealth(now)

                if (!isScreenInteractive()) {
                    hideBlockerOverlay()
                    nextDelayMs = 10_000L
                } else {
                    val restrictedDetected = checkForegroundApp(now)
                    nextDelayMs = computeNextPollDelayMs(now, restrictedDetected)
                }
            } catch (e: Exception) {
                android.util.Log.e("RevokeMonitor", "Error in monitor loop: ${e.message}", e)
                nextDelayMs = 5_000L
            }

            handler.postDelayed(this, nextDelayMs)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "com.revoke.app.SYNC_SCHEDULES" -> {
                val schedulesJson = intent.getStringExtra("schedules")
                if (schedulesJson != null) {
                    updateSchedules(schedulesJson)
                }
            }
            "com.revoke.app.TEMP_UNLOCK" -> {
                val pkg = intent.getStringExtra("packageName")
                val mins = intent.getIntExtra("minutes", 5)
                if (pkg != null) {
                    val expiry = System.currentTimeMillis() + (mins * 60 * 1000)
                    tempUnlockedPackages[pkg] = expiry
                    persistTempUnlocks()
                    android.util.Log.d("RevokeMonitor", "Temporarily unlocking $pkg for $mins minutes.")
                }
            }
        }
        // Loop already started in onCreate()
        startMonitorLoopIfNeeded()
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        scheduleRestart(3_000)
        super.onTaskRemoved(rootIntent)
    }

    private fun writeSelfHealth(now: Long) {
        if (now - lastHealthWriteAt < 5_000L) return
        lastHealthWriteAt = now
        prefs.edit().putLong("monitor_last_tick_ms", now).apply()
    }

    private fun isScreenInteractive(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isInteractive
    }

    private fun computeNextPollDelayMs(now: Long, restrictedDetected: Boolean): Long {
        if (restrictedDetected) return 2_000L

        // Stay in fast mode briefly after a block to reduce "open app then slip past" windows.
        if (now - lastRestrictedDetectedAt < 20_000L) return 2_000L

        return if (isRiskWindowNow(now)) 5_000L else 9_000L
    }

    private fun isRiskWindowNow(now: Long): Boolean {
        if (now - lastRiskEvalAt < 15_000L) return cachedRiskWindow
        cachedRiskWindow = computeRiskWindowNow()
        lastRiskEvalAt = now
        return cachedRiskWindow
    }

    private fun computeRiskWindowNow(): Boolean {
        if (blockedAppsIndex.isEmpty()) return false

        val calendar = java.util.Calendar.getInstance()
        val dayOfWeek = calendar.get(java.util.Calendar.DAY_OF_WEEK)
        val modelDay = if (dayOfWeek == 1) 7 else dayOfWeek - 1

        val currentHour = calendar.get(java.util.Calendar.HOUR_OF_DAY)
        val currentMinute = calendar.get(java.util.Calendar.MINUTE)
        val currentTotalMin = currentHour * 60 + currentMinute

        for (schedule in activeSchedules) {
            if (!schedule.optBoolean("isActive", true)) continue

            val days = schedule.optJSONArray("days") ?: continue
            var dayMatch = false
            for (i in 0 until days.length()) {
                if (days.optInt(i, -1) == modelDay) {
                    dayMatch = true
                    break
                }
            }
            if (!dayMatch) continue

            val type = schedule.optInt("type")
            if (type == 1) {
                // Usage limit regimes are effectively "always on" during the matched day.
                return true
            }

            if (type == 0) {
                if (!schedule.has("startHour") || schedule.isNull("startHour") ||
                    !schedule.has("endHour") || schedule.isNull("endHour")) {
                    continue
                }

                val startHour = schedule.optInt("startHour", -1)
                val startMin = schedule.optInt("startMinute", 0)
                val endHour = schedule.optInt("endHour", -1)
                val endMin = schedule.optInt("endMinute", 0)
                if (startHour == -1 || endHour == -1) continue

                val startTotalMin = startHour * 60 + startMin
                val endTotalMin = endHour * 60 + endMin

                val isWithinRange = if (startTotalMin <= endTotalMin) {
                    currentTotalMin in startTotalMin..endTotalMin
                } else {
                    currentTotalMin >= startTotalMin || currentTotalMin <= endTotalMin
                }

                if (isWithinRange) return true
            }
        }

        return false
    }

    private fun scheduleRestart(delayMs: Long) {
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent("com.revoke.app.RESTART_SERVICE").apply {
                setClass(this@AppMonitorService, ServiceRestartReceiver::class.java)
            }
            val pending = PendingIntent.getBroadcast(
                this,
                1001,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.set(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + delayMs.coerceAtLeast(0L),
                pending
            )
        } catch (_: Exception) {
            // Best effort.
        }
    }

    private fun checkTempUnlock(packageName: String): Boolean {
        val expiry = tempUnlockedPackages[packageName] ?: return false
        if (System.currentTimeMillis() > expiry) {
            tempUnlockedPackages.remove(packageName)
            persistTempUnlocks()
            android.util.Log.d("RevokeMonitor", "Temp unlock expired for $packageName")
            return false
        }
        return true
    }

    private fun loadTempUnlocks() {
        val raw = prefs.getString("temp_unlocks", null) ?: return
        val now = System.currentTimeMillis()
        try {
            val json = JSONObject(raw)
            val keys = json.keys()
            while (keys.hasNext()) {
                val pkg = keys.next()
                val expiry = json.optLong(pkg, 0L)
                if (expiry > now) {
                    tempUnlockedPackages[pkg] = expiry
                }
            }
            persistTempUnlocks()
        } catch (_: Exception) {
            tempUnlockedPackages.clear()
        }
    }

    private fun persistTempUnlocks() {
        val now = System.currentTimeMillis()
        val json = JSONObject()
        val iterator = tempUnlockedPackages.entries.iterator()
        while (iterator.hasNext()) {
            val entry = iterator.next()
            if (entry.value > now) {
                json.put(entry.key, entry.value)
            } else {
                iterator.remove()
            }
        }
        prefs.edit().putString("temp_unlocks", json.toString()).apply()
    }

    private fun updateSchedules(json: String) {
        try {
            // Persist to SharedPreferences
            prefs.edit().putString("schedules", json).apply()
            
            // Update memory
            val array = org.json.JSONArray(json)
            activeSchedules.clear()
            blockedAppsIndex.clear()
            for (i in 0 until array.length()) {
                val schedule = array.getJSONObject(i)
                activeSchedules.add(schedule)
                // Build an index of targeted packages for fast hot-loop checks.
                if (schedule.optBoolean("isActive", true)) {
                    val apps = schedule.optJSONArray("targetApps")
                    if (apps != null) {
                        for (j in 0 until apps.length()) {
                            val pkg = apps.optString(j, "").trim()
                            if (pkg.isNotEmpty()) blockedAppsIndex.add(pkg)
                        }
                    }
                }
            }
            
            android.util.Log.d("RevokeMonitor", "Synced ${activeSchedules.size} active schedules")
            
            // Visual feedback
            Handler(Looper.getMainLooper()).post {
                android.widget.Toast.makeText(
                    this,
                    "Synced ${activeSchedules.size} Rules",
                    android.widget.Toast.LENGTH_SHORT
                ).show()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        handler.removeCallbacks(runnable)
        scheduleRestart(5_000)
        super.onDestroy()
    }

    private fun checkForegroundApp(now: Long): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return false
        if (isAmnestyActive()) {
            hideBlockerOverlay()
            return false
        }

        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        
        // queryEvents is cheaper than queryUsageStats, but it can still be heavy if the window is too large.
        // Scan only recent events and keep fallback logic for reliability.
        val start = if (lastEventsQueryAt <= 0L) {
            now - 15_000
        } else {
            (lastEventsQueryAt - 2_000).coerceAtLeast(now - 30_000)
        }
        lastEventsQueryAt = now
        val usageEvents = usageStatsManager.queryEvents(start, now)
        val event = UsageEvents.Event()
        var lastEventTime = 0L
        var foundViaEvents = false

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                if (event.timeStamp > lastEventTime) {
                    lastEventTime = event.timeStamp
                    lastKnownForegroundPackage = event.packageName
                    foundViaEvents = true
                }
            }
        }

        // Fallback: queryUsageStats is heavier, so run it at a lower cadence.
        val shouldRunUsageStatsFallback =
            (!foundViaEvents || lastKnownForegroundPackage.isEmpty()) &&
            (now - lastUsageStatsFallbackAt >= usageStatsFallbackIntervalMs)

        if (shouldRunUsageStatsFallback) {
            lastUsageStatsFallbackAt = now
            val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, now - 1000 * 60 * 15, now)
            if (stats != null && stats.isNotEmpty()) {
                var latestStats: android.app.usage.UsageStats? = null
                for (usageStats in stats) {
                    if (latestStats == null || usageStats.lastTimeUsed > latestStats!!.lastTimeUsed) {
                        latestStats = usageStats
                    }
                }
                if (latestStats != null && (now - latestStats!!.lastTimeUsed) < 1000 * 60 * 5) {
                    val resolvedPackage = latestStats!!.packageName
                    if (resolvedPackage != lastKnownForegroundPackage) {
                        lastKnownForegroundPackage = resolvedPackage
                        android.util.Log.d("RevokeMonitor", "Found via stats: $lastKnownForegroundPackage")
                    }
                }
            }
        }
        
        if (lastKnownForegroundPackage.isNotEmpty()) {
            if (lastKnownForegroundPackage != packageName) { 
                // Only log if the app has changed to avoid spamming the logcat
                val shouldLogLogic = lastKnownForegroundPackage != lastLoggedApp
                if (shouldLogLogic) {
                     android.util.Log.d("RevokeMonitor", "Current App: $lastKnownForegroundPackage")
                     lastLoggedApp = lastKnownForegroundPackage
                }
                
                val restrictedAppName = getRestrictedAppName(lastKnownForegroundPackage, shouldLogLogic)
                if (restrictedAppName != null) {
                    lastRestrictedDetectedAt = now
                    if (shouldLogLogic) android.util.Log.d("RevokeMonitor", "Blocking $restrictedAppName")
                    showBlockerOverlay(restrictedAppName, lastKnownForegroundPackage)
                    return true
                } else {
                    hideBlockerOverlay()
                    return false
                }
            } else {
                // We are in Revoke, hide overlay
                hideBlockerOverlay()
                return false
            }
        }
        return false
    }

    private fun getRestrictedAppName(packageName: String, shouldLog: Boolean): String? {
        if (checkTempUnlock(packageName)) {
            if (shouldLog) android.util.Log.d("RevokeLogic", "App $packageName is temporarily unlocked.")
            return null
        }

        // Fast path: if this package is not referenced by any active schedule, it cannot be blocked.
        if (!blockedAppsIndex.contains(packageName)) {
            return null
        }
        val calendar = java.util.Calendar.getInstance()
        val dayOfWeek = calendar.get(java.util.Calendar.DAY_OF_WEEK)
        val modelDay = if (dayOfWeek == 1) 7 else dayOfWeek - 1

        val currentHour = calendar.get(java.util.Calendar.HOUR_OF_DAY)
        val currentMinute = calendar.get(java.util.Calendar.MINUTE)
        val currentTotalMin = currentHour * 60 + currentMinute
        
        // Suppress all logs for the launcher (it's the home screen, very noisy)
        val isLauncher = packageName.contains("launcher") || packageName.contains("trebuchet")
        
        if (shouldLog && !isLauncher) {
            android.util.Log.d("RevokeLogic", "Checking $packageName. Day: $modelDay, Time: $currentTotalMin")
        }

        for ((index, schedule) in activeSchedules.withIndex()) {
            if (!schedule.optBoolean("isActive", true)) {
                if (shouldLog && !isLauncher) android.util.Log.d("RevokeLogic", "Schedule $index: INACTIVE, skipping")
                continue
            }
            
            // Day check
            val days = schedule.optJSONArray("days")
            val daysList = mutableListOf<Int>()
            if (days != null) {
                for (i in 0 until days.length()) {
                    daysList.add(days.getInt(i))
                }
            }
            
            var dayMatch = false
            if (days != null) {
                for (i in 0 until days.length()) {
                    if (days.getInt(i) == modelDay) {
                        dayMatch = true
                        break
                    }
                }
            }
            
            if (!dayMatch) {
                if (shouldLog && !isLauncher) android.util.Log.d("RevokeLogic", "Schedule $index: Day mismatch. Need: $modelDay, Current: $daysList")
                continue
            }

            // App check
            val apps = schedule.optJSONArray("targetApps")
            val appsList = mutableListOf<String>()
            if (apps != null) {
                for (i in 0 until apps.length()) {
                    appsList.add(apps.getString(i))
                }
            }
            
            var appMatch = false
            if (apps != null) {
                for (i in 0 until apps.length()) {
                    if (apps.getString(i) == packageName) {
                        appMatch = true
                        break
                    }
                }
            }
            
            if (!appMatch) {
                if (shouldLog && !isLauncher) android.util.Log.d("RevokeLogic", "Schedule $index: App mismatch.")
                continue
            }

            // Constraint check
            val type = schedule.optInt("type") 
            var isBlocked = false
            if (type == 0) { // TimeBlock
                // Check if time fields exist (not null)
                if (!schedule.has("startHour") || schedule.isNull("startHour") || 
                    !schedule.has("endHour") || schedule.isNull("endHour")) {
                    if (shouldLog && !isLauncher) {
                        android.util.Log.d("RevokeLogic", "Schedule $index: Missing time data, skipping")
                    }
                    continue
                }
                
                val startHour = schedule.optInt("startHour", -1)
                val startMin = schedule.optInt("startMinute", 0)
                val endHour = schedule.optInt("endHour", -1)
                val endMin = schedule.optInt("endMinute", 0)
                
                if (startHour == -1 || endHour == -1) {
                    if (shouldLog && !isLauncher) {
                        android.util.Log.d("RevokeLogic", "Schedule $index: Invalid time values")
                    }
                    continue
                }
                
                val startTotalMin = startHour * 60 + startMin
                val endTotalMin = endHour * 60 + endMin
                
                if (shouldLog && !isLauncher) {
                    android.util.Log.d("RevokeLogic", "Schedule $index: TimeBlock ${startHour}:${startMin} - ${endHour}:${endMin} (${startTotalMin}-${endTotalMin})")
                }
                
                val isWithinRange = if (startTotalMin <= endTotalMin) {
                    currentTotalMin in startTotalMin..endTotalMin
                } else {
                    // Overnight range (e.g., 9 PM to 2 AM) OR until midnight (e.g. 9 AM to 0 AM)
                    currentTotalMin >= startTotalMin || currentTotalMin <= endTotalMin
                }

                if (isWithinRange) {
                    isBlocked = true
                    if (shouldLog && !isLauncher) android.util.Log.d("RevokeLogic", "Schedule $index: âœ“ MATCH - Time within range")
                } else {
                    if (shouldLog && !isLauncher) android.util.Log.d("RevokeLogic", "Schedule $index: âœ— Time outside range")
                }
            } else if (type == 1) { // UsageLimit
                val limitMinutes = when {
                    schedule.has("limitMinutes") && !schedule.isNull("limitMinutes") ->
                        schedule.optInt("limitMinutes", -1)
                    schedule.has("durationMinutes") && !schedule.isNull("durationMinutes") ->
                        schedule.optInt("durationMinutes", -1)
                    schedule.has("durationSeconds") && !schedule.isNull("durationSeconds") -> {
                        val seconds = schedule.optLong("durationSeconds", -1L)
                        if (seconds <= 0L) -1 else (seconds / 60L).toInt()
                    }
                    else -> -1
                }

                if (limitMinutes <= 0) {
                    if (shouldLog && !isLauncher) {
                        android.util.Log.d("RevokeLogic", "Schedule $index: UsageLimit missing/invalid duration")
                    }
                    continue
                }

                val usageStatsManager =
                    getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                val startOfDay = java.util.Calendar.getInstance().apply {
                    set(java.util.Calendar.HOUR_OF_DAY, 0)
                    set(java.util.Calendar.MINUTE, 0)
                    set(java.util.Calendar.SECOND, 0)
                    set(java.util.Calendar.MILLISECOND, 0)
                }.timeInMillis
                val nowMs = System.currentTimeMillis()

                val usageStats = usageStatsManager.queryUsageStats(
                    UsageStatsManager.INTERVAL_DAILY,
                    startOfDay,
                    nowMs
                )

                var usedMs = 0L
                if (usageStats != null) {
                    for (stats in usageStats) {
                        if (stats.packageName == packageName) {
                            usedMs = stats.totalTimeInForeground
                            break
                        }
                    }
                }

                val usedMinutes = usedMs / (1000L * 60L)
                if (usedMinutes >= limitMinutes.toLong()) {
                    isBlocked = true
                    if (shouldLog && !isLauncher) {
                        android.util.Log.d(
                            "RevokeLogic",
                            "Schedule $index: âœ“ MATCH - UsageLimit reached ($usedMinutes/$limitMinutes min)"
                        )
                    }
                } else if (shouldLog && !isLauncher) {
                    android.util.Log.d(
                        "RevokeLogic",
                        "Schedule $index: âœ— UsageLimit not reached ($usedMinutes/$limitMinutes min)"
                    )
                }
            }

            if (isBlocked) {
                return try {
                    val pm = packageManager
                    val ai = pm.getApplicationInfo(packageName, 0)
                    pm.getApplicationLabel(ai).toString()
                } catch (e: Exception) {
                    packageName
                }
            }
        }
        return null
    }

    private var currentBlockedApp: String? = null

    private fun showBlockerOverlay(blockedAppName: String, packageNameStr: String) {
        // Prevent flicker: If already showing for the same app, do nothing
        if (overlayView != null && currentBlockedApp == blockedAppName) return
        
        handler.post {
            try {
                // If showing for a DIFFERENT app, clean up first
                if (overlayView != null) {
                    try {
                        windowManager?.removeView(overlayView)
                    } catch (e: Exception) { /* ignore */ }
                    overlayView = null
                }
                
                currentBlockedApp = blockedAppName
                val context = this

                // ROOT LAYOUT (Vertical LinearLayout to ensure spacing)
                val root = android.widget.LinearLayout(context).apply {
                    orientation = android.widget.LinearLayout.VERTICAL
                    setBackgroundColor(android.graphics.Color.BLACK)
                    setPadding(60, 40, 60, 40)
                    weightSum = 10f
                }

                // TOP SECTION: HUD (Weight 1)
                val topHud = android.widget.LinearLayout(context).apply {
                    orientation = android.widget.LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                }
                val hudShield = TextView(context).apply {
                    text = "ðŸ›¡ï¸"
                    textSize = 20f
                }
                val hudText = TextView(context).apply {
                    text = " REVOKE"
                    setTextColor(android.graphics.Color.WHITE)
                    textSize = 14f
                    typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
                    letterSpacing = 0.2f
                }
                topHud.addView(hudShield)
                topHud.addView(hudText)
                
                val topParams = android.widget.LinearLayout.LayoutParams(
                    android.widget.LinearLayout.LayoutParams.MATCH_PARENT, 0, 1.5f
                ).apply {
                    gravity = Gravity.TOP
                }
                root.addView(topHud, topParams)

                // CENTER SECTION: Brand & Text (Weight 5)
                val centerLayout = android.widget.LinearLayout(context).apply {
                    orientation = android.widget.LinearLayout.VERTICAL
                    gravity = Gravity.CENTER
                }
                val lockIcon = android.widget.ImageView(context).apply {
                    // Use the custom vector drawable we created
                    setImageResource(resources.getIdentifier("ic_lock_premium", "drawable", packageName))
                    setColorFilter(android.graphics.Color.parseColor("#FF4500")) // ORANGE
                    layoutParams = android.widget.LinearLayout.LayoutParams(350, 350)
                }
                val headline = TextView(context).apply {
                    text = "COOKED."
                    setTextColor(android.graphics.Color.parseColor("#FF4500"))
                    textSize = 48f
                    gravity = Gravity.CENTER
                    typeface = android.graphics.Typeface.DEFAULT_BOLD
                    setPadding(0, 40, 0, 10)
                }
                val subtext = TextView(context).apply {
                    text = "You are trying to open $blockedAppName.\nThe Squad is judging you."
                    setTextColor(android.graphics.Color.WHITE)
                    textSize = 18f
                    gravity = Gravity.CENTER
                    setPadding(40, 0, 40, 40)
                    typeface = android.graphics.Typeface.create("sans-serif-light", android.graphics.Typeface.NORMAL)
                }
                val stats = TextView(context).apply {
                    text = "ATTEMPTS TODAY: 1"
                    setTextColor(android.graphics.Color.GRAY)
                    textSize = 11f
                    gravity = Gravity.CENTER
                    typeface = android.graphics.Typeface.MONOSPACE
                }
                centerLayout.addView(lockIcon)
                centerLayout.addView(headline)
                centerLayout.addView(subtext)
                centerLayout.addView(stats)
                
                val centerParams = android.widget.LinearLayout.LayoutParams(
                    android.widget.LinearLayout.LayoutParams.MATCH_PARENT, 0, 5.5f
                )
                root.addView(centerLayout, centerParams)

                // BOTTOM SECTION: Actions (Weight 3)
                val bottomActions = android.widget.LinearLayout(context).apply {
                    orientation = android.widget.LinearLayout.VERTICAL
                    gravity = Gravity.BOTTOM
                }

                // ACCEPT FATE is now the PRIMARY action (ORANGE)
                val fateButton = android.widget.Button(context).apply {
                    text = "ACCEPT FATE"
                    setTextColor(android.graphics.Color.WHITE)
                    setBackgroundColor(android.graphics.Color.parseColor("#FF4500")) // Orange
                    typeface = android.graphics.Typeface.DEFAULT_BOLD
                    transformationMethod = null 
                }
                fateButton.setOnClickListener {
                    val startMain = Intent(Intent.ACTION_MAIN).apply {
                        addCategory(Intent.CATEGORY_HOME)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(startMain)
                    hideBlockerOverlay()
                }

                // BEG FOR TIME is now the SECONDARY action (DARK GREY)
                val begButton = android.widget.Button(context).apply {
                    text = "BEG FOR TIME"
                    setTextColor(android.graphics.Color.WHITE)
                    setBackgroundColor(android.graphics.Color.parseColor("#121212")) // Dark Grey
                    typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
                    transformationMethod = null
                }
                begButton.setOnClickListener {
                    val intent = Intent(this@AppMonitorService, MainActivity::class.java).apply {
                        action = "com.revoke.app.REQUEST_PLEA"
                        putExtra("appName", blockedAppName)
                        putExtra("packageName", packageNameStr)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    }
                    startActivity(intent)
                    
                    // UI Feedback
                    begButton.text = "OPENING PLEA..."
                    begButton.isEnabled = false
                    begButton.alpha = 0.5f
                    
                    android.widget.Toast.makeText(context, "Open Revoke to send your plea.", android.widget.Toast.LENGTH_SHORT).show()
                }

                val btnParams = android.widget.LinearLayout.LayoutParams(
                    android.widget.LinearLayout.LayoutParams.MATCH_PARENT, 160
                ).apply {
                    setMargins(0, 20, 0, 20)
                }
                
                bottomActions.addView(fateButton, btnParams)
                bottomActions.addView(begButton, btnParams)

                val bottomParams = android.widget.LinearLayout.LayoutParams(
                    android.widget.LinearLayout.LayoutParams.MATCH_PARENT, 0, 3f
                )
                root.addView(bottomActions, bottomParams)

                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.MATCH_PARENT,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                    else
                        WindowManager.LayoutParams.TYPE_PHONE,
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or 
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_FULLSCREEN,
                    PixelFormat.TRANSLUCENT
                )

                windowManager?.addView(root, params)
                overlayView = root
                android.util.Log.d("Revoke", "Overlay Redesign Applied")

            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun hideBlockerOverlay() {
        if (overlayView == null) return
        handler.post {
            try {
                if (overlayView?.parent != null) {
                    windowManager?.removeView(overlayView)
                }
                overlayView = null
                currentBlockedApp = null
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun isAmnestyActive(): Boolean {
        val expiry = prefs.getLong("amnesty_expiry", 0L)
        if (expiry <= 0L) return false

        val now = System.currentTimeMillis()
        if (now >= expiry) {
            prefs.edit().putLong("amnesty_expiry", 0L).apply()
            return false
        }

        if (now - lastAmnestyLogAt > 15_000L) {
            lastAmnestyLogAt = now
            val remainingSec = (expiry - now) / 1000L
            android.util.Log.d(
                "RevokeAmnesty",
                "Amnesty active. Monitoring paused (${remainingSec}s remaining)."
            )
        }
        return true
    }
}

```

## `android/app/src/main/kotlin/com/example/revoke/BootReceiver.kt`
```
package com.example.revoke

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.ContextCompat

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        val isBootAction =
            action == Intent.ACTION_BOOT_COMPLETED || action == ACTION_QUICKBOOT_POWERON
        if (!isBootAction) return

        Log.d("RevokeBoot", "Boot action received: $action. Starting AppMonitorService.")
        val serviceIntent = Intent(context, AppMonitorService::class.java)
        ContextCompat.startForegroundService(context, serviceIntent)
    }

    companion object {
        private const val ACTION_QUICKBOOT_POWERON =
            "android.intent.action.QUICKBOOT_POWERON"
    }
}

```

## `android/app/src/main/kotlin/com/example/revoke/ServiceRestartReceiver.kt`
```
package com.example.revoke

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat

class ServiceRestartReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "com.revoke.app.RESTART_SERVICE") return

        val serviceIntent = Intent(context, AppMonitorService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.startForegroundService(context, serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}


```

## Firebase Backend
## `firebase.json`
```
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "functions": {
    "source": "functions",
    "runtime": "nodejs22"
  },
  "flutter": {
    "platforms": {
      "android": {
        "default": {
          "projectId": "revoke-ebb5e",
          "appId": "1:70325101052:android:35fc98fb8a93ae7e179279",
          "fileOutput": "android/app/google-services.json"
        }
      },
      "dart": {
        "lib/firebase_options.dart": {
          "projectId": "revoke-ebb5e",
          "configurations": {
            "android": "1:70325101052:android:35fc98fb8a93ae7e179279"
          }
        }
      }
    }
  }
}
```

## `functions/package.json`
```
{
  "name": "functions",
  "version": "1.0.0",
  "description": "",
  "main": "index.js",
  "engines": {
    "node": "22"
  },
  "scripts": {
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "keywords": [],
  "author": "",
  "license": "ISC",
  "dependencies": {
    "firebase-admin": "^13.6.1",
    "firebase-functions": "^7.0.5"
  }
}

```

## `functions/index.js`
```
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

// -----------------------------
// Abuse controls & lifecycle
// -----------------------------
// Quorum model: attendance-based. Eligible voters are all attendees except the requester.
// Resolution happens when all eligible voters have cast a vote, OR the session times out.
const PLEA_CREATE_WINDOW_MS = 10 * 60 * 1000;
const PLEA_CREATE_MAX_PER_WINDOW = 3;

const MESSAGE_WINDOW_MS = 60 * 1000;
const MESSAGE_MAX_PER_WINDOW = 20;
const MESSAGE_COOLDOWN_MS = 2 * 1000;
const MESSAGE_MAX_LEN = 400;

const ACTIVE_PLEA_TIMEOUT_MS = 5 * 60 * 1000;

const RESOLVED_PLEA_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const MARKED_FOR_DELETION_TTL_MS = 10 * 60 * 1000;
const CLEANUP_BATCH_LIMIT = 100;

const MOCK_SQUAD_ID = "mock_squad_core";
const MOCK_SQUAD_CODE = "MOCK-CORE";
const MOCK_USERS = [
  {
    uid: "mock_actor_azra",
    fullName: "Azra Kline",
    nickname: "Azra",
    email: "azra.actor@revoke.local",
    defaultFocusScore: 430,
  },
  {
    uid: "mock_actor_brynn",
    fullName: "Brynn Cole",
    nickname: "Brynn",
    email: "brynn.actor@revoke.local",
    defaultFocusScore: 410,
  },
  {
    uid: "mock_actor_cass",
    fullName: "Cass Vega",
    nickname: "Cass",
    email: "cass.actor@revoke.local",
    defaultFocusScore: 390,
  },
  {
    uid: "mock_actor_dima",
    fullName: "Dima Shore",
    nickname: "Dima",
    email: "dima.actor@revoke.local",
    defaultFocusScore: 370,
  },
  {
    uid: "mock_actor_eden",
    fullName: "Eden Mar",
    nickname: "Eden",
    email: "eden.actor@revoke.local",
    defaultFocusScore: 350,
  },
];

exports.broadcastPleaCreated = onDocumentCreated({
  document: "pleas/{pleaId}",
  region: "us-central1",
}, async (event) => {
  const pleaId = event.params?.pleaId;
  try {
    logger.info("Plea trigger received.", {
      pleaId,
      eventId: event.id,
      eventType: event.type,
    });

    const plea = event.data?.data();
    if (!plea) {
      logger.warn("Plea trigger fired with no document data.", {pleaId});
      return;
    }

    const squadId = plea.squadId;
    const requesterUid = plea.userId;
    const requesterName = (plea.userName || "A squad member").toString();
    const appName = (plea.appName || "an app").toString();
    const durationMinutes = Number(plea.durationMinutes) || 5;

    if (!squadId || !requesterUid) {
      logger.warn("Plea missing required routing fields.", {pleaId});
      return;
    }

    const usersSnap = await db
        .collection("users")
        .where("squadId", "==", squadId)
        .get();

    const tokens = [];
    for (const userDoc of usersSnap.docs) {
      const data = userDoc.data() || {};
      const memberUid = (data.uid || userDoc.id || "").toString();
      const token = (data.fcmToken || "").toString().trim();
      if (!memberUid || memberUid === requesterUid) continue;
      if (!token) continue;
      tokens.push(token);
    }

    const uniqueTokens = [...new Set(tokens)];
    if (uniqueTokens.length === 0) {
      logger.info("No target tokens for plea broadcast.", {pleaId, squadId});
      return;
    }

    const title = "JUDGMENT REQUIRED";
    const body = `${requesterName} is begging for ${durationMinutes} mins on ${appName}!`;
    let successCount = 0;
    let failureCount = 0;

    for (let i = 0; i < uniqueTokens.length; i += 500) {
      const tokenChunk = uniqueTokens.slice(i, i + 500);
      const response = await messaging.sendEachForMulticast({
        tokens: tokenChunk,
        notification: {
          title,
          body,
        },
        android: {
          notification: {
            channelId: "squad_alerts",
            sound: "lookatthisdude",
          },
        },
        data: {
          type: "plea_judgement",
          pleaId: String(pleaId),
          squadId: String(squadId),
        },
      });

      successCount += response.successCount;
      failureCount += response.failureCount;

      response.responses.forEach((result, idx) => {
        if (result.success) return;
        logger.warn("Plea push failed for token.", {
          pleaId,
          squadId,
          tokenSuffix: tokenChunk[idx]?.slice(-8),
          errorCode: result.error?.code,
          errorMessage: result.error?.message,
        });
      });
    }

    logger.info("Plea broadcast completed.", {
      pleaId,
      squadId,
      recipients: uniqueTokens.length,
      successCount,
      failureCount,
    });
  } catch (error) {
    logger.error("Plea broadcast crashed.", {
      pleaId,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw error;
  }
});

exports.resolvePleaVerdict = onDocumentUpdated({
  document: "pleas/{pleaId}",
  region: "us-central1",
}, async (event) => {
  const pleaId = event.params?.pleaId;
  try {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};

    const beforeVotes = _normalizeVotes(before.votes);
    const afterVotes = _normalizeVotes(after.votes);

    if (_votesAreEqual(beforeVotes, afterVotes)) {
      return;
    }

    const status = (after.status || "active").toString().trim().toLowerCase();
    if (status !== "active") {
      return;
    }

    const requesterId = (after.userId || "").toString().trim();
    const participantsRaw = Array.isArray(after.participants) ?
      after.participants : [];
    const participants = [...new Set(
      participantsRaw
          .map((id) => id?.toString().trim())
          .filter((id) => Boolean(id)),
    )];

    // Deadlock fix: requester attends, but requester does not vote.
    const voters = participants.filter((id) => id !== requesterId);
    const voterSet = new Set(voters);

    let acceptVotes = 0;
    let rejectVotes = 0;
    let votesCast = 0;

    for (const [uid, vote] of Object.entries(afterVotes)) {
      if (!voterSet.has(uid)) continue;
      votesCast += 1;
      if (vote === "accept") acceptVotes += 1;
      if (vote === "reject") rejectVotes += 1;
    }

    const updates = {
      voteCounts: {
        accept: acceptVotes,
        reject: rejectVotes,
      },
    };

    if (votesCast >= voters.length && voters.length > 0) {
      updates.status = acceptVotes > rejectVotes ? "approved" : "rejected";
      updates.resolvedAt = FieldValue.serverTimestamp();
    }

    await event.data.after.ref.update(updates);

    logger.info("resolvePleaVerdict processed vote update.", {
      pleaId,
      requesterId,
      participants: participants.length,
      voters: voters.length,
      votesCast,
      acceptVotes,
      rejectVotes,
      resolved: Boolean(updates.status),
      status: updates.status || "active",
    });
  } catch (error) {
    logger.error("resolvePleaVerdict crashed.", {
      pleaId,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw error;
  }
});

exports.recalculateShameLedger = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  if (request.auth.token?.admin !== true) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }

  try {
    const rejectedSnap = await db
        .collection("pleas")
        .where("status", "==", "rejected")
        .get();

    const rejectionByUser = {};
    for (const doc of rejectedSnap.docs) {
      const data = doc.data() || {};
      const userId = (data.userId || "").toString().trim();
      if (!userId) continue;
      rejectionByUser[userId] = (rejectionByUser[userId] || 0) + 1;
    }

    const shameLedger = Object.entries(rejectionByUser)
        .sort((a, b) => b[1] - a[1])
        .map(([userId, rejections], index) => ({
          rank: index + 1,
          userId,
          rejections,
        }));

    await db.doc("system/stats").set({
      shameLedger,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});

    logger.info("Shame ledger recalculated.", {
      totalRejectedPleas: rejectedSnap.size,
      uniqueUsers: shameLedger.length,
    });

    return {
      success: true,
      totalRejectedPleas: rejectedSnap.size,
      uniqueUsers: shameLedger.length,
    };
  } catch (error) {
    logger.error("recalculateShameLedger crashed.", {
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to recalculate shame ledger.");
  }
});

exports.adminOverridePlea = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  if (request.auth.token?.admin !== true) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }

  const pleaId = (request.data?.pleaId || "").toString().trim();
  const verdict = (request.data?.verdict || "").toString().trim().toLowerCase();
  const reason = (request.data?.reason || "").toString().trim();

  if (!pleaId) {
    throw new HttpsError("invalid-argument", "pleaId is required.");
  }
  if (verdict !== "approved" && verdict !== "rejected") {
    throw new HttpsError(
        "invalid-argument",
        "verdict must be 'approved' or 'rejected'.",
    );
  }

  const pleaRef = db.collection("pleas").doc(pleaId);

  try {
    const pleaSnap = await pleaRef.get();
    if (!pleaSnap.exists) {
      throw new HttpsError("not-found", "Plea not found.");
    }

    await pleaRef.set({
      status: verdict,
      resolvedAt: FieldValue.serverTimestamp(),
      outcomeSource: "admin_override",
    }, {merge: true});

    const architectMessage = `The Architect has intervened. Verdict: ${verdict.toUpperCase()}. Reason: ${reason || "No reason provided."}`;
    await pleaRef.collection("messages").add({
      text: architectMessage,
      senderId: "THE_ARCHITECT",
      senderName: "The Architect",
      isSystem: true,
      timestamp: FieldValue.serverTimestamp(),
    });

    logger.info("adminOverridePlea applied.", {
      pleaId,
      verdict,
      reasonProvided: Boolean(reason),
      actorUid: request.auth.uid,
    });

    return {
      success: true,
      pleaId,
      verdict,
      outcomeSource: "admin_override",
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    logger.error("adminOverridePlea crashed.", {
      pleaId,
      verdict,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to override plea.");
  }
});

exports.broadcastSystemMandate = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  if (request.auth.token?.admin !== true) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }

  const title = (request.data?.title || "").toString().trim();
  const body = (request.data?.body || "").toString().trim();
  if (!title || !body) {
    throw new HttpsError("invalid-argument", "title and body are required.");
  }

  try {
    const messageId = await messaging.send({
      topic: "global_citizens",
      notification: {title, body},
      data: {
        type: "SYSTEM_MANDATE",
        title,
        body,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "squad_alerts",
          sound: "lookatthisdude",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    logger.info("broadcastSystemMandate sent.", {
      actorUid: request.auth.uid,
      messageId,
    });
    return {success: true, messageId};
  } catch (error) {
    logger.error("broadcastSystemMandate crashed.", {
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to broadcast system mandate.");
  }
});

exports.grantAmnesty = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  if (request.auth.token?.admin !== true) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }

  const targetUserId = (request.data?.targetUserId || "")
      .toString()
      .trim();
  const durationRaw = Number(request.data?.durationMinutes);
  const durationMinutes = Number.isFinite(durationRaw) && durationRaw > 0 ?
    Math.floor(durationRaw) : 60;

  if (!targetUserId) {
    throw new HttpsError("invalid-argument", "targetUserId is required.");
  }

  try {
    const userRef = db.collection("users").doc(targetUserId);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "Target user does not exist.");
    }

    const userData = userSnap.data() || {};
    const token = (userData.fcmToken || "").toString().trim();
    if (!token) {
      throw new HttpsError(
          "failed-precondition",
          "Target user has no FCM token.",
      );
    }

    const messageId = await messaging.send({
      token,
      data: {
        type: "AMNESTY",
        duration: String(durationMinutes),
      },
      android: {
        priority: "high",
      },
      apns: {
        headers: {"apns-priority": "10"},
        payload: {
          aps: {
            contentAvailable: true,
          },
        },
      },
    });

    logger.info("grantAmnesty sent.", {
      actorUid: request.auth.uid,
      targetUserId,
      durationMinutes,
      messageId,
    });

    return {success: true, targetUserId, durationMinutes, messageId};
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    logger.error("grantAmnesty crashed.", {
      targetUserId,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to grant amnesty.");
  }
});

exports.createPlea = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const callerUid = request.auth.uid;
  const isAdmin = request.auth.token?.admin === true;
  const payload = request.data || {};
  const allowedCreateKeys = new Set([
    "uid",
    "appName",
    "packageName",
    "durationMinutes",
    "reason",
  ]);
  for (const key of Object.keys(payload)) {
    if (!allowedCreateKeys.has(key)) {
      throw new HttpsError("invalid-argument", `Unexpected field: ${key}`);
    }
  }
  const requestedUid = (payload.uid || callerUid).toString().trim();
  if (!requestedUid) {
    throw new HttpsError("invalid-argument", "uid is required.");
  }
  if (!isAdmin && requestedUid !== callerUid) {
    throw new HttpsError("permission-denied", "Cannot create plea for another user.");
  }

  const appName = (payload.appName || "").toString().trim();
  const packageName = (payload.packageName || "").toString().trim();
  const reason = (payload.reason || "").toString().trim();
  const durationRaw = Number(payload.durationMinutes);
  const durationMinutes = Number.isFinite(durationRaw) ? Math.floor(durationRaw) : 0;

  if (!appName || appName.length > 80) {
    throw new HttpsError("invalid-argument", "appName must be 1-80 characters.");
  }
  if (!packageName || packageName.length > 180) {
    throw new HttpsError("invalid-argument", "packageName must be 1-180 characters.");
  }
  if (!reason || reason.length > 300) {
    throw new HttpsError("invalid-argument", "reason must be 1-300 characters.");
  }
  if (durationMinutes < 1 || durationMinutes > 120) {
    throw new HttpsError("invalid-argument", "durationMinutes must be between 1 and 120.");
  }

  try {
    const requesterRef = db.collection("users").doc(requestedUid);
    const limitsRef = db.collection("limits").doc(requestedUid);
    const pleaRef = db.collection("pleas").doc();

    const nowMs = Date.now();

    await db.runTransaction(async (tx) => {
      const requesterSnap = await tx.get(requesterRef);
      if (!requesterSnap.exists) {
        throw new HttpsError("failed-precondition", "Requester user profile is missing.");
      }
      const requesterData = requesterSnap.data() || {};
      const squadId = (requesterData.squadId || "").toString().trim();
      if (!squadId) {
        throw new HttpsError("failed-precondition", "Requester is not in a squad.");
      }

      const limitsSnap = await tx.get(limitsRef);
      const limits = limitsSnap.exists ? (limitsSnap.data() || {}) : {};
      const cutoffMs = nowMs - PLEA_CREATE_WINDOW_MS;
      const existingEvents = _pruneTimestamps(
          limits.pleaEvents,
          cutoffMs,
          50,
      );

      if (existingEvents.length >= PLEA_CREATE_MAX_PER_WINDOW) {
        const oldestRelevant = existingEvents[0] || nowMs;
        const retryAfterMs = Math.max(0, (oldestRelevant + PLEA_CREATE_WINDOW_MS) - nowMs);
        const retryAfterSeconds = Math.ceil(retryAfterMs / 1000);
        throw new HttpsError(
            "resource-exhausted",
            `Too many pleas. Try again in ~${retryAfterSeconds}s.`,
            {retryAfterSeconds},
        );
      }

      const userName = _deriveUserDisplayName(requesterData);
      tx.set(pleaRef, {
        userId: requestedUid,
        userName,
        squadId,
        appName,
        packageName,
        durationMinutes,
        reason,
        participants: [requestedUid],
        voteCounts: {accept: 0, reject: 0},
        votes: {},
        status: "active",
        createdAt: FieldValue.serverTimestamp(),
        createdBy: callerUid,
      });

      tx.set(limitsRef, {
        pleaEvents: [...existingEvents, nowMs].slice(-50),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    });

    logger.info("createPlea callable completed.", {
      actorUid: callerUid,
      requesterUid: requestedUid,
      pleaId: pleaRef.id,
      durationMinutes,
      appName,
    });

    return {
      success: true,
      pleaId: pleaRef.id,
    };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("createPlea callable crashed.", {
      actorUid: callerUid,
      requesterUid: requestedUid,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to create plea.");
  }
});

exports.sendPleaMessage = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const isAdmin = request.auth.token?.admin === true;
  const payload = request.data || {};
  const allowedKeys = new Set(["pleaId", "text"]);
  for (const key of Object.keys(payload)) {
    if (!allowedKeys.has(key)) {
      throw new HttpsError("invalid-argument", `Unexpected field: ${key}`);
    }
  }

  const pleaId = (payload.pleaId || "").toString().trim();
  const text = (payload.text || "").toString().trim();
  if (!pleaId) {
    throw new HttpsError("invalid-argument", "pleaId is required.");
  }
  if (!text) {
    throw new HttpsError("invalid-argument", "text is required.");
  }
  if (text.length > MESSAGE_MAX_LEN) {
    throw new HttpsError("invalid-argument", `text must be <= ${MESSAGE_MAX_LEN} chars.`);
  }

  const pleaRef = db.collection("pleas").doc(pleaId);
  const userRef = db.collection("users").doc(uid);
  const limitsRef = db.collection("limits").doc(uid);
  const nowMs = Date.now();

  try {
    const messageId = await db.runTransaction(async (tx) => {
      const pleaSnap = await tx.get(pleaRef);
      if (!pleaSnap.exists) {
        throw new HttpsError("not-found", "Plea not found.");
      }
      const plea = pleaSnap.data() || {};
      const status = (plea.status || "active").toString().trim().toLowerCase();
      if (status !== "active") {
        throw new HttpsError("failed-precondition", "Tribunal is closed.");
      }

      if (!isAdmin) {
        const userSnap = await tx.get(userRef);
        if (!userSnap.exists) {
          throw new HttpsError("failed-precondition", "User profile is missing.");
        }
        const userData = userSnap.data() || {};
        const userSquadId = (userData.squadId || "").toString().trim();
        const pleaSquadId = (plea.squadId || "").toString().trim();
        if (!userSquadId || userSquadId !== pleaSquadId) {
          throw new HttpsError("permission-denied", "User cannot message this tribunal.");
        }

        const limitsSnap = await tx.get(limitsRef);
        const limits = limitsSnap.exists ? (limitsSnap.data() || {}) : {};

        const lastMessageAt = Number(limits.lastMessageAt) || 0;
        const sinceLast = nowMs - lastMessageAt;
        if (sinceLast >= 0 && sinceLast < MESSAGE_COOLDOWN_MS) {
          const retryAfterSeconds = Math.ceil((MESSAGE_COOLDOWN_MS - sinceLast) / 1000);
          throw new HttpsError(
              "resource-exhausted",
              `Slow down. Try again in ~${retryAfterSeconds}s.`,
              {retryAfterSeconds},
          );
        }

        const cutoffMs = nowMs - MESSAGE_WINDOW_MS;
        const existingEvents = _pruneTimestamps(
            limits.messageEvents,
            cutoffMs,
            120,
        );
        if (existingEvents.length >= MESSAGE_MAX_PER_WINDOW) {
          const oldestRelevant = existingEvents[0] || nowMs;
          const retryAfterMs = Math.max(0, (oldestRelevant + MESSAGE_WINDOW_MS) - nowMs);
          const retryAfterSeconds = Math.ceil(retryAfterMs / 1000);
          throw new HttpsError(
              "resource-exhausted",
              `Too many messages. Try again in ~${retryAfterSeconds}s.`,
              {retryAfterSeconds},
          );
        }

        tx.set(limitsRef, {
          messageEvents: [...existingEvents, nowMs].slice(-120),
          lastMessageAt: nowMs,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});

        // Attendance: sending a message implies being present in the room.
        tx.update(pleaRef, {
          participants: FieldValue.arrayUnion(uid),
          lastMessageAt: FieldValue.serverTimestamp(),
        });

        const senderName = _deriveUserDisplayName(userData);
        const messageRef = pleaRef.collection("messages").doc();
        tx.set(messageRef, {
          senderId: uid,
          senderName,
          text,
          isSystem: false,
          timestamp: FieldValue.serverTimestamp(),
        });
        return messageRef.id;
      }

      // Admin messages should use the admin tools (Architect/system) instead.
      throw new HttpsError(
          "failed-precondition",
          "Admin should use Architect messaging tools.",
      );
    });

    return {success: true, pleaId, messageId};
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("sendPleaMessage callable crashed.", {
      uid,
      pleaId,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to send message.");
  }
});

exports.castVote = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const isAdmin = request.auth.token?.admin === true;
  const payload = request.data || {};
  const allowedVoteKeys = new Set(["pleaId", "choice"]);
  for (const key of Object.keys(payload)) {
    if (!allowedVoteKeys.has(key)) {
      throw new HttpsError("invalid-argument", `Unexpected field: ${key}`);
    }
  }
  const pleaId = (payload.pleaId || "").toString().trim();
  const choice = (payload.choice || "").toString().trim().toLowerCase();

  if (!pleaId) {
    throw new HttpsError("invalid-argument", "pleaId is required.");
  }
  if (choice !== "accept" && choice !== "reject") {
    throw new HttpsError("invalid-argument", "choice must be 'accept' or 'reject'.");
  }

  const pleaRef = db.collection("pleas").doc(pleaId);
  try {
    await db.runTransaction(async (tx) => {
      const pleaSnap = await tx.get(pleaRef);
      if (!pleaSnap.exists) {
        throw new HttpsError("not-found", "Plea not found.");
      }
      const plea = pleaSnap.data() || {};

      const status = (plea.status || "active").toString().trim().toLowerCase();
      if (status !== "active") {
        throw new HttpsError("failed-precondition", "Plea is already resolved.");
      }

      const requesterId = (plea.userId || "").toString().trim();
      if (!isAdmin && requesterId === uid) {
        throw new HttpsError("failed-precondition", "Requester cannot vote on own plea.");
      }

      if (!isAdmin) {
        const callerRef = db.collection("users").doc(uid);
        const callerSnap = await tx.get(callerRef);
        if (!callerSnap.exists) {
          throw new HttpsError("failed-precondition", "User profile is missing.");
        }
        const callerSquadId = (callerSnap.data()?.squadId || "").toString().trim();
        const pleaSquadId = (plea.squadId || "").toString().trim();
        if (!callerSquadId || callerSquadId != pleaSquadId) {
          throw new HttpsError("permission-denied", "User is not allowed to vote on this plea.");
        }
      }

      tx.update(pleaRef, {
        [`votes.${uid}`]: choice,
        participants: FieldValue.arrayUnion(uid),
        lastVoteAt: FieldValue.serverTimestamp(),
      });
    });

    logger.info("castVote callable completed.", {
      uid,
      pleaId,
      choice,
    });
    return {success: true, pleaId, choice};
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("castVote callable crashed.", {
      uid,
      pleaId,
      choice,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to cast vote.");
  }
});

exports.joinPleaSession = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const isAdmin = request.auth.token?.admin === true;
  const pleaId = (request.data?.pleaId || "").toString().trim();
  if (!pleaId) {
    throw new HttpsError("invalid-argument", "pleaId is required.");
  }

  const pleaRef = db.collection("pleas").doc(pleaId);
  try {
    const pleaSnap = await pleaRef.get();
    if (!pleaSnap.exists) {
      throw new HttpsError("not-found", "Plea not found.");
    }
    const plea = pleaSnap.data() || {};
    const status = (plea.status || "active").toString().trim().toLowerCase();
    if (status !== "active") {
      return {success: true, pleaId, active: false};
    }

    if (!isAdmin) {
      await _assertUserCanAccessPlea(uid, plea);
    }

    await pleaRef.set({
      participants: FieldValue.arrayUnion(uid),
      lastJoinAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return {success: true, pleaId, active: true};
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("joinPleaSession callable crashed.", {
      uid,
      pleaId,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to join plea session.");
  }
});

exports.markPleaForDeletion = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const isAdmin = request.auth.token?.admin === true;
  const pleaId = (request.data?.pleaId || "").toString().trim();
  if (!pleaId) {
    throw new HttpsError("invalid-argument", "pleaId is required.");
  }

  try {
    const pleaRef = db.collection("pleas").doc(pleaId);
    const pleaSnap = await pleaRef.get();
    if (!pleaSnap.exists) {
      return {success: true, pleaId, existed: false};
    }
    const plea = pleaSnap.data() || {};
    if (!isAdmin) {
      await _assertUserCanAccessPlea(uid, plea);
    }

    await pleaRef.set({
      markedForDeletion: true,
      deletionMarkedAt: FieldValue.serverTimestamp(),
      deletionMarkedBy: uid,
    }, {merge: true});

    return {success: true, pleaId, existed: true};
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("markPleaForDeletion callable crashed.", {
      uid,
      pleaId,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to mark plea for deletion.");
  }
});

exports.createMockTribunal = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  if (request.auth.token?.admin !== true) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }

  try {
    await _ensurePermanentMockActors();
    const staleSquadIds = await _cleanupLegacyMockUsersAndSquads();
    await _destroyMockSessions({staleSquadIds});

    const pleaRef = db.collection("pleas").doc();

    const mockUserIds = MOCK_USERS.map((user) => user.uid);
    const requester = MOCK_USERS[0];

    await pleaRef.set({
      userId: requester.uid,
      userName: requester.fullName,
      squadId: MOCK_SQUAD_ID,
      appName: "Instagram",
      packageName: "com.instagram.android",
      durationMinutes: 20,
      reason: "Need to publish campaign updates before deadline.",
      participants: mockUserIds,
      voteCounts: {accept: 1, reject: 1},
      votes: {
        [MOCK_USERS[1].uid]: "accept",
        [MOCK_USERS[2].uid]: "reject",
      },
      status: "active",
      isMockSession: true,
      mockSessionOwnerUid: request.auth.uid,
      createdAt: FieldValue.serverTimestamp(),
    });

    const messagesRef = pleaRef.collection("messages");
    const seedMessages = /** @type {Array<{senderId:string,senderName:string,text:string,isSystem:boolean}>} */ ([
      {
        senderId: "THE_ARCHITECT",
        senderName: "The Architect",
        text: "Simulation initialized. Tribunal recording has begun.",
        isSystem: true,
      },
      {
        senderId: requester.uid,
        senderName: requester.fullName,
        text: "Requesting 20 minutes for Instagram.",
        isSystem: false,
      },
      {
        senderId: MOCK_USERS[1].uid,
        senderName: MOCK_USERS[1].fullName,
        text: "State your case quickly. Time is expensive.",
        isSystem: false,
      },
      {
        senderId: MOCK_USERS[2].uid,
        senderName: MOCK_USERS[2].fullName,
        text: "I am leaning toward reject.",
        isSystem: false,
      },
      {
        senderId: requester.uid,
        senderName: requester.fullName,
        text: "I need this window to answer urgent messages.",
        isSystem: false,
      },
      {
        senderId: MOCK_USERS[3].uid,
        senderName: MOCK_USERS[3].fullName,
        text: "The squad needs evidence, not promises.",
        isSystem: false,
      },
      {
        senderId: MOCK_USERS[4].uid,
        senderName: MOCK_USERS[4].fullName,
        text: "I can support a short extension if accountability is clear.",
        isSystem: false,
      },
    ]);

    const baseMillis = Date.now() - (seedMessages.length * 15000);
    for (let i = 0; i < seedMessages.length; i += 1) {
      const msg = seedMessages[i];
      await messagesRef.add({
        ...msg,
        timestamp: Timestamp.fromMillis(baseMillis + (i * 15000)),
      });
    }

    logger.info("createMockTribunal completed.", {
      actorUid: request.auth.uid,
      squadId: MOCK_SQUAD_ID,
      pleaId: pleaRef.id,
      mockActors: mockUserIds,
    });

    return {
      success: true,
      squadId: MOCK_SQUAD_ID,
      pleaId: pleaRef.id,
      userIds: mockUserIds,
    };
  } catch (error) {
    logger.error("createMockTribunal crashed.", {
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to create mock tribunal.");
  }
});

exports.destroyMockTribunal = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  if (request.auth.token?.admin !== true) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }

  const pleaId = (request.data?.pleaId || "").toString().trim();
  try {
    let deletedPleas = 0;
    if (pleaId) {
      const pleaRef = db.collection("pleas").doc(pleaId);
      const pleaSnap = await pleaRef.get();
      if (pleaSnap.exists) {
        const data = pleaSnap.data() || {};
        const isMock = data.isMockSession === true ||
          (data.squadId || "").toString().trim() === MOCK_SQUAD_ID;
        if (isMock) {
          await _deletePleaWithMessages(pleaRef);
          deletedPleas = 1;
        }
      }
    } else {
      deletedPleas = await _destroyMockSessions({staleSquadIds: []});
    }

    logger.info("destroyMockTribunal completed.", {
      actorUid: request.auth.uid,
      pleaId: pleaId || null,
      deletedPleas,
    });
    return {success: true, deletedPleas};
  } catch (error) {
    logger.error("destroyMockTribunal crashed.", {
      pleaId: pleaId || null,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to destroy mock tribunal.");
  }
});

exports.autoFinalizeStalePleas = onSchedule({
  region: "us-central1",
  schedule: "every 1 minutes",
}, async () => {
  const nowMs = Date.now();
  const cutoff = Timestamp.fromMillis(nowMs - ACTIVE_PLEA_TIMEOUT_MS);

  try {
    const snap = await db
        .collection("pleas")
        .where("status", "==", "active")
        .where("createdAt", "<=", cutoff)
        .orderBy("createdAt", "asc")
        .limit(50)
        .get();

    if (snap.empty) return;

    let finalized = 0;

    for (const doc of snap.docs) {
      const pleaRef = doc.ref;
      const plea = doc.data() || {};

      if (plea.isMockSession === true) continue;

      const requesterId = (plea.userId || "").toString().trim();
      const participantsRaw = Array.isArray(plea.participants) ? plea.participants : [];
      const participants = [...new Set(
          participantsRaw
              .map((id) => id?.toString().trim())
              .filter((id) => Boolean(id)),
      )];
      const voters = participants.filter((id) => id !== requesterId);
      const voterSet = new Set(voters);
      const votes = _normalizeVotes(plea.votes);

      let acceptVotes = 0;
      let rejectVotes = 0;
      let votesCast = 0;

      for (const [uid, vote] of Object.entries(votes)) {
        if (!voterSet.has(uid)) continue;
        votesCast += 1;
        if (vote === "accept") acceptVotes += 1;
        if (vote === "reject") rejectVotes += 1;
      }

      // Timeout verdict is always rejected on tie or incomplete quorum.
      const verdict = acceptVotes > rejectVotes ? "approved" : "rejected";

      await pleaRef.set({
        status: verdict,
        voteCounts: {accept: acceptVotes, reject: rejectVotes},
        resolvedAt: FieldValue.serverTimestamp(),
        outcomeSource: "timeout",
        timedOutAt: FieldValue.serverTimestamp(),
      }, {merge: true});

      await pleaRef.collection("messages").add({
        senderId: "SYSTEM",
        senderName: "System",
        isSystem: true,
        text: `Tribunal timed out. Verdict: ${verdict.toUpperCase()}.`,
        timestamp: FieldValue.serverTimestamp(),
      });

      finalized += 1;
      logger.info("autoFinalizeStalePleas resolved plea.", {
        pleaId: doc.id,
        requesterId,
        participants: participants.length,
        voters: voters.length,
        votesCast,
        acceptVotes,
        rejectVotes,
        verdict,
      });
    }

    logger.info("autoFinalizeStalePleas completed.", {finalized});
  } catch (error) {
    logger.error("autoFinalizeStalePleas crashed.", {
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
  }
});

exports.cleanupPleaData = onSchedule({
  region: "us-central1",
  schedule: "every 60 minutes",
}, async () => {
  const nowMs = Date.now();
  const resolvedCutoff = Timestamp.fromMillis(nowMs - RESOLVED_PLEA_TTL_MS);
  const deletionCutoff = Timestamp.fromMillis(nowMs - MARKED_FOR_DELETION_TTL_MS);

  const toDelete = new Map();

  try {
    const resolvedSnap = await db
        .collection("pleas")
        .where("status", "in", ["approved", "rejected"])
        .where("resolvedAt", "<=", resolvedCutoff)
        .orderBy("resolvedAt", "asc")
        .limit(CLEANUP_BATCH_LIMIT)
        .get();

    for (const doc of resolvedSnap.docs) {
      const data = doc.data() || {};
      if (data.isMockSession === true) continue;
      toDelete.set(doc.id, doc.ref);
    }

    const markedSnap = await db
        .collection("pleas")
        .where("markedForDeletion", "==", true)
        .where("deletionMarkedAt", "<=", deletionCutoff)
        .orderBy("deletionMarkedAt", "asc")
        .limit(CLEANUP_BATCH_LIMIT)
        .get();

    for (const doc of markedSnap.docs) {
      const data = doc.data() || {};
      if (data.isMockSession === true) continue;
      toDelete.set(doc.id, doc.ref);
    }

    if (toDelete.size === 0) return;

    const writer = db.bulkWriter();
    writer.onWriteError((err) => {
      // Retry transient failures a few times.
      return err.failedAttempts < 3;
    });

    let messageDeletes = 0;
    let pleaDeletes = 0;

    for (const pleaRef of toDelete.values()) {
      const messages = await pleaRef.collection("messages").listDocuments();
      for (const msgRef of messages) {
        writer.delete(msgRef);
        messageDeletes += 1;
      }
      writer.delete(pleaRef);
      pleaDeletes += 1;
    }

    await writer.close();

    logger.info("cleanupPleaData completed.", {
      pleasDeleted: pleaDeletes,
      messagesDeleted: messageDeletes,
    });
  } catch (error) {
    logger.error("cleanupPleaData crashed.", {
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
  }
});

async function _ensurePermanentMockActors() {
  const squadRef = db.collection("squads").doc(MOCK_SQUAD_ID);
  const userRefs = MOCK_USERS.map((user) => db.collection("users").doc(user.uid));
  const userSnaps = await db.getAll(...userRefs);

  const batch = db.batch();
  batch.set(squadRef, {
    squadCode: MOCK_SQUAD_CODE,
    creatorId: MOCK_USERS[0].uid,
    memberIds: MOCK_USERS.map((user) => user.uid),
    isMockSquad: true,
    updatedAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  for (let i = 0; i < MOCK_USERS.length; i += 1) {
    const mock = MOCK_USERS[i];
    const existing = userSnaps[i].data() || {};
    const existingScore = Number(existing.focusScore);
    const preservedFocus = Number.isFinite(existingScore) ?
      Math.floor(existingScore) : mock.defaultFocusScore;

    batch.set(userRefs[i], {
      uid: mock.uid,
      fullName: mock.fullName,
      nickname: mock.nickname,
      email: mock.email,
      squadId: MOCK_SQUAD_ID,
      squadCode: MOCK_SQUAD_CODE,
      isMockUser: true,
      focusScore: preservedFocus,
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: existing.createdAt || FieldValue.serverTimestamp(),
    }, {merge: true});
  }

  await batch.commit();
}

async function _cleanupLegacyMockUsersAndSquads() {
  const staleSquadIds = [];

  const legacyUserSnap = await db
      .collection("users")
      .where("email", ">=", "mock.user")
      .where("email", "<", "mock.user\uf8ff")
      .get();

  for (const userDoc of legacyUserSnap.docs) {
    if (MOCK_USERS.some((user) => user.uid === userDoc.id)) {
      continue;
    }
    await userDoc.ref.delete();
  }

  const mockSquadSnap = await db
      .collection("squads")
      .where("squadCode", ">=", "MOCK-")
      .where("squadCode", "<", "MOCK-\uf8ff")
      .get();

  for (const squadDoc of mockSquadSnap.docs) {
    if (squadDoc.id === MOCK_SQUAD_ID) continue;
    staleSquadIds.push(squadDoc.id);
    await squadDoc.ref.delete();
  }

  return staleSquadIds;
}

async function _destroyMockSessions({staleSquadIds}) {
  const sessionRefs = new Map();

  const markedMockSessions = await db
      .collection("pleas")
      .where("isMockSession", "==", true)
      .get();
  for (const pleaDoc of markedMockSessions.docs) {
    sessionRefs.set(pleaDoc.id, pleaDoc.ref);
  }

  const mockSquadSessions = await db
      .collection("pleas")
      .where("squadId", "==", MOCK_SQUAD_ID)
      .get();
  for (const pleaDoc of mockSquadSessions.docs) {
    sessionRefs.set(pleaDoc.id, pleaDoc.ref);
  }

  for (const staleSquadId of staleSquadIds) {
    const staleSquadSessions = await db
        .collection("pleas")
        .where("squadId", "==", staleSquadId)
        .get();
    for (const pleaDoc of staleSquadSessions.docs) {
      sessionRefs.set(pleaDoc.id, pleaDoc.ref);
    }
  }

  let deleted = 0;
  for (const pleaRef of sessionRefs.values()) {
    await _deletePleaWithMessages(pleaRef);
    deleted += 1;
  }
  return deleted;
}

async function _deletePleaWithMessages(pleaRef) {
  const messagesSnap = await pleaRef.collection("messages").get();
  const batch = db.batch();
  for (const messageDoc of messagesSnap.docs) {
    batch.delete(messageDoc.ref);
  }
  batch.delete(pleaRef);
  await batch.commit();
}

function _deriveUserDisplayName(userData) {
  const nickname = (userData?.nickname || "").toString().trim();
  if (nickname) return nickname;
  const fullName = (userData?.fullName || "").toString().trim();
  if (fullName) return fullName;
  const email = (userData?.email || "").toString().trim();
  if (email) return email;
  return "A Member";
}

async function _assertUserCanAccessPlea(uid, pleaData) {
  const pleaSquadId = (pleaData?.squadId || "").toString().trim();
  if (!pleaSquadId) {
    throw new HttpsError("failed-precondition", "Plea has no squad.");
  }
  const userSnap = await db.collection("users").doc(uid).get();
  if (!userSnap.exists) {
    throw new HttpsError("failed-precondition", "User profile is missing.");
  }
  const userSquadId = (userSnap.data()?.squadId || "").toString().trim();
  if (!userSquadId || userSquadId !== pleaSquadId) {
    throw new HttpsError("permission-denied", "User is not in the plea squad.");
  }
}

function _normalizeVotes(rawVotes) {
  if (!rawVotes || typeof rawVotes !== "object") return {};
  const normalized = {};
  for (const [uidRaw, voteRaw] of Object.entries(rawVotes)) {
    const uid = uidRaw.toString().trim();
    const vote = voteRaw?.toString().trim().toLowerCase();
    if (!uid) continue;
    if (vote !== "accept" && vote !== "reject") continue;
    normalized[uid] = vote;
  }
  return normalized;
}

function _pruneTimestamps(raw, cutoffMs, maxKeep) {
  if (!Array.isArray(raw)) return [];
  const pruned = raw
      .map((v) => Number(v))
      .filter((v) => Number.isFinite(v) && v >= cutoffMs)
      .sort((a, b) => a - b);
  if (!Number.isFinite(maxKeep) || maxKeep <= 0) return pruned;
  return pruned.slice(-maxKeep);
}

function _votesAreEqual(a, b) {
  const aKeys = Object.keys(a);
  const bKeys = Object.keys(b);
  if (aKeys.length !== bKeys.length) return false;
  for (const key of aKeys) {
    if (a[key] !== b[key]) return false;
  }
  return true;
}

```

## `firestore.rules`
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function signedIn() {
      return request.auth != null;
    }
    
    function isAdmin() {
      return signedIn() && request.auth.token.admin == true;
    }

    function isSelf(userId) {
      return signedIn() && request.auth.uid == userId;
    }

    function isCurrentSquadMember() {
      return signedIn() &&
        resource.data.memberIds is list &&
        resource.data.memberIds.hasAny([request.auth.uid]);
    }

    function isResultingSquadMember() {
      return signedIn() &&
        request.resource.data.memberIds is list &&
        request.resource.data.memberIds.hasAny([request.auth.uid]);
    }

    function currentUserSquadId() {
      return signedIn()
        ? get(/databases/$(database)/documents/users/$(request.auth.uid)).data.squadId
        : null;
    }

    function canAccessPleaData(pleaData) {
      return signedIn() &&
        pleaData.squadId is string &&
        currentUserSquadId() == pleaData.squadId;
    }

    function isMockPlea(pleaData) {
      return pleaData.isMockSession == true;
    }

    function canReadUserDoc(userId, userData) {
      return isSelf(userId) ||
        (signedIn() &&
          userData.squadId is string &&
          currentUserSquadId() == userData.squadId);
    }

    function isValidPleaMessageCreate(messageData) {
      return messageData.keys().hasOnly([
          'senderId',
          'senderName',
          'text',
          'timestamp',
          'isSystem',
        ]) &&
        messageData.senderId is string &&
        messageData.senderId == request.auth.uid &&
        messageData.senderName is string &&
        messageData.senderName.size() > 0 &&
        messageData.senderName.size() <= 64 &&
        messageData.text is string &&
        messageData.text.size() > 0 &&
        messageData.text.size() <= 400 &&
        messageData.timestamp is timestamp &&
        (!messageData.keys().hasAny(['isSystem']) ||
          messageData.isSystem == false);
    }

    // User profiles
    match /users/{userId} {
      // Self read or same-squad read.
      allow read: if isAdmin() || canReadUserDoc(userId, resource.data);

      // Own profile management (create/update/delete account doc)
      allow create, update, delete: if isAdmin() || isSelf(userId);

      // Cloud-synced regimes live under the user's document.
      match /regimes/{regimeId} {
        allow read, write: if isAdmin() || isSelf(userId);
      }
    }

    // Squad collaboration
    match /squads/{squadId} {
      allow create, read: if isAdmin() || signedIn();

      // Allows joining/leaving/updating squad membership for authenticated users
      // and supports deleting an emptied squad during account delete/leave flow.
      allow update, delete: if isAdmin() || isCurrentSquadMember() || isResultingSquadMember();
    }

    // Plea creation/voting
    match /pleas/{pleaId} {
      // Plea documents are created/updated by Cloud Functions (Admin SDK), not by clients.
      allow create: if false;
      allow read: if isAdmin() || canAccessPleaData(resource.data) || isMockPlea(resource.data);
      allow update, delete: if false;

      // Session chat messages
      match /messages/{messageId} {
        allow read: if isAdmin() || (signedIn() &&
          (canAccessPleaData(get(/databases/$(database)/documents/pleas/$(pleaId)).data) ||
            isMockPlea(get(/databases/$(database)/documents/pleas/$(pleaId)).data)));

        // Client message writes are disabled; normal users must send via callable.
        // Admin clients may still write system messages directly if needed.
        allow create: if isAdmin();
        allow update, delete: if false;
      }
    }
    
    // Default deny all other access
    match /{document=**} {
      allow read, write: if isAdmin();
    }
  }
}

```

## `firestore.indexes.json`
```
{
  "indexes": [],
  "fieldOverrides": []
}

```

## iOS (Scaffolding)
## `ios/Runner/AppDelegate.swift`
```
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

```

END OF CONTEXT PACK
