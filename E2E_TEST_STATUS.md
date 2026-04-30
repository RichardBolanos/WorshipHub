# E2E Test Suite Status — WorshipHub Flutter UI

**Last Updated:** 2026-04-29
**Framework:** Patrol 3.20.0 + patrol_cli 3.11.0
**Backend:** Spring Boot with H2 in-memory (localhost:9090)
**Device:** Android emulator API 34 (Patrol_API34)

## Summary

| Metric | Value |
|--------|-------|
| Total tests written | ~85 |
| Total executed | 59 |
| Passing | 40 |
| Failing | 19 |
| Pass rate (executed) | 68% |
| Files fully green | 6 / 15 |

## Results by File

| # | Test File | Tests | Pass | Fail | Rate | Status |
|---|-----------|-------|------|------|------|--------|
| 1 | auth/login_test.dart | 6 | 6 | 0 | 100% | ✅ |
| 2 | auth/church_registration_test.dart | 5 | 5 | 0 | 100% | ✅ |
| 3 | songs/song_crud_test.dart | 8 | 7 | 1 | 87% | 🟡 |
| 4 | songs/song_search_filter_test.dart | 2 | 2 | 0 | 100% | ✅ |
| 5 | navigation/app_navigation_test.dart | 3 | 3 | 0 | 100% | ✅ |
| 6 | notifications/notifications_test.dart | 5 | 4 | 1 | 80% | 🟡 |
| 7 | categories/category_tag_test.dart | 6 | 5 | 1 | 83% | 🟡 |
| 8 | profile/profile_password_test.dart | 4 | 4 | 0 | 100% | ✅ |
| 9 | teams/team_management_test.dart | 4 | 1 | 3 | 25% | 🔴 |
| 10 | setlists/setlist_crud_test.dart | 5 | 1 | 4 | 20% | 🔴 |
| 11 | auth/invitation_acceptance_test.dart | 7 | 0 | 7 | 0% | 🔴 |
| 12 | error_handling/error_states_test.dart | 4 | 0 | 4 | 0% | 🔴 |
| 13 | calendar/calendar_availability_test.dart | 7 | — | — | — | ⏳ Hung |
| 14 | chat/team_chat_test.dart | 4 | — | — | — | ⏳ Hung |
| 15 | cross_feature/cross_feature_flows_test.dart | 4 | — | — | — | ⏳ Hung |

## Root Causes of Failures

### 1. Android Test Orchestrator instability (affects all files)
The orchestrator intermittently hangs, loses tests, or leaves Gradle lock files. Some runs find 6 tests, others find 4 for the same file. Files with many tests (calendar 7, chat 4, cross_feature 4) consistently hang.

### 2. Invitation tests — `_authToken != null` assertion
`sendInvitation()` requires prior `login()` but some invitation tests skip the API login step. The `ApiSeedHelper` asserts `_authToken != null` before making authenticated requests.

### 3. Error handling tests — assertion at line 175
The `ErrorSimulationInterceptor` tests fail because they try to access `GetIt.instance<Dio>()` after the app is pumped, but the Dio instance may not be accessible from the test scope.

### 4. Teams/Setlists — first test fails, rest cascade
The first test in each file fails (likely navigation or data loading timing), and subsequent tests fail because the orchestrator doesn't fully reset app state between tests.

### 5. Song edit FAB — async role loading
The edit FAB only appears after `_loadUserRole()` completes asynchronously. The polling timeout may be too short.

## What Works Well

- **Auth flows (login + registration):** 11/11 — 100%
- **Song CRUD:** 7/8 — 87%
- **Navigation:** 3/3 — 100%
- **Profile/Password:** 4/4 — 100%
- **Categories:** 5/6 — 83%
- **Notifications:** 4/5 — 80%
- **Song search:** 2/2 — 100%

**Total for stable files: 36/39 = 92%**

## Infrastructure Issues (not test logic)

1. **Gradle lock files** — `utp.0.log.lck` blocks consecutive runs. Workaround: `gradlew --stop` + delete `build/app/outputs/androidTest-results/`
2. **Orchestrator hangs** — Some test files hang indefinitely during execution. No reliable workaround found.
3. **`Stop-Process -Name java`** — Kills the backend along with Gradle. Must use `gradlew --stop` instead.
4. **Patrol MCP** — Cannot run on Windows due to `SIGTERM` not supported in Dart on Windows.

## Backend Fixes Applied

1. **NoOpEmailService.kt** — No-op email for H2 profile
2. **ChurchRegistrationService.kt** — Auto-verify users in H2 profile
3. **application-h2.yml** — Fixed mail username

## App Fixes Applied

1. **ConnectionStatusIndicator** — `Stream.periodic` → `Stream.value`
2. **LoginPage/HomePage** — Removed `controller.repeat()` shimmer animations
3. **WebSocketService** — `forTesting()` constructor + `_NoOpWebSocketService`
4. **ConnectivityService** — `_TestConnectivityService` without timers
5. **WorshipManagerApp** — Optional `locale` parameter for test override

## How to Run

```powershell
# From worship_hub_ui/ directory
$env:PATH = "$env:LOCALAPPDATA\Pub\Cache\bin;$env:PATH"
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
$env:PATH = "$env:ANDROID_HOME\platform-tools;$env:PATH"

# IMPORTANT: Clean before each run
.\android\gradlew.bat --stop
Remove-Item -Recurse -Force "build\app\outputs\androidTest-results" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "build\app\reports\androidTests" -ErrorAction SilentlyContinue

# Run one file at a time
patrol test -t integration_test/tests/auth/login_test.dart -d emulator-5554
```

## Next Steps

1. Fix invitation tests (`_authToken` assertion — add `login()` call before `sendInvitation()`)
2. Fix error handling tests (Dio access from test scope)
3. Investigate orchestrator hangs for calendar/chat/cross_feature
4. Increase `_waitForEditFab` timeout for song edit test
5. Consider splitting large test files to avoid orchestrator issues
