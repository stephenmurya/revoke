$ErrorActionPreference = "Stop"
$out = "LLM_CONTEXT_RECONSTRUCTION.md"
Remove-Item $out -ErrorAction SilentlyContinue

function Add([string]$s) {
  Add-Content -Path $out -Value $s -Encoding utf8
}

function AddFile([string]$path) {
  Add('## ' + $bt + $path + $bt)
  Add('```')
  Add-Content -Path $out -Value (Get-Content -Path $path -Raw) -Encoding utf8
  Add('```')
  Add('')
}

$bt = '`'

Add('# Revoke Mobile App - Context Reconstruction')
Add('Generated from repository scan at: c:\\Users\\USER\\Documents\\dev\\revoke')
Add('This file is designed to be pasted into a fresh LLM session.')
Add('Notes:')
Add('- Repo contains generated and vendor directories (build/, .dart_tool/, functions/node_modules/, .git/). These are not enumerated line-by-line here.')
Add('- Core application logic: Flutter (Dart) + Android native Kotlin + Firebase backend (Firestore + Cloud Functions + FCM).')
Add('')

Add('## File/Dir Inventory (High-Level)')
Add('Top-level entries:')
Get-ChildItem -Force | Sort-Object -Property Name | ForEach-Object {
  Add(('- ' + $bt + $_.Name + $bt))
}
Add('')

$allCount = (Get-ChildItem -Force -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
Add('Total file count (including generated/vendor):')
Add(('- ' + $allCount + ' files'))
Add('Per-directory file counts:')
foreach ($d in @('.git', '.dart_tool', 'build', 'functions\\node_modules', 'android', 'ios', 'lib', 'test', 'web', 'windows', 'macos', 'linux', 'assets', 'prd', 'functions')) {
  if (Test-Path $d) {
    $c = (Get-ChildItem -Force -Recurse -File -ErrorAction SilentlyContinue $d | Measure-Object).Count
    Add(('- ' + $bt + $d + $bt + ': ' + $c + ' files'))
  }
}
Add('')

Add('Tracked/core file list (ripgrep respects ignore rules):')
Add('```text')
$files = rg --files | Sort-Object
Add-Content -Path $out -Value ($files -join "`n") -Encoding utf8
Add('```')
Add('')

Add('## Canonical Documents')
AddFile 'prd/prd.md'
AddFile 'prd/status.md'

Add('## Flutter/Dart Core (Selected)')
AddFile 'pubspec.yaml'
AddFile 'lib/main.dart'
AddFile 'lib/core/app_router.dart'
AddFile 'lib/core/native_bridge.dart'
AddFile 'lib/core/services/auth_service.dart'
AddFile 'lib/core/services/notification_service.dart'
AddFile 'lib/core/services/squad_service.dart'
AddFile 'lib/core/services/schedule_service.dart'
AddFile 'lib/core/services/regime_service.dart'
AddFile 'lib/core/services/scoring_service.dart'
AddFile 'lib/core/services/app_discovery_service.dart'
AddFile 'lib/core/models/user_model.dart'
AddFile 'lib/core/models/squad_model.dart'
AddFile 'lib/core/models/schedule_model.dart'
AddFile 'lib/core/models/plea_model.dart'
AddFile 'lib/core/models/plea_message_model.dart'
AddFile 'lib/features/squad/squad_screen.dart'
AddFile 'lib/features/squad/tribunal_screen.dart'
AddFile 'lib/features/plea/plea_compose_screen.dart'
AddFile 'lib/features/permissions/permission_screen.dart'

Add('## Android Native (Kotlin)')
AddFile 'android/app/src/main/AndroidManifest.xml'
AddFile 'android/app/build.gradle.kts'
AddFile 'android/app/src/main/kotlin/com/example/revoke/MainActivity.kt'
AddFile 'android/app/src/main/kotlin/com/example/revoke/AppMonitorService.kt'
AddFile 'android/app/src/main/kotlin/com/example/revoke/BootReceiver.kt'
AddFile 'android/app/src/main/kotlin/com/example/revoke/ServiceRestartReceiver.kt'

Add('## Firebase Backend')
AddFile 'firebase.json'
AddFile 'functions/package.json'
AddFile 'functions/index.js'
AddFile 'firestore.rules'
AddFile 'firestore.indexes.json'

Add('## iOS (Scaffolding)')
AddFile 'ios/Runner/AppDelegate.swift'

Add('END OF CONTEXT PACK')

Get-Item $out | Select-Object FullName, Length | Format-List
