# E2E Test Suite Status — WorshipHub Flutter UI

**Last Updated:** 2026-04-29
**Framework:** Patrol 3.20.0 + patrol_cli 3.11.0
**Backend:** Spring Boot with H2 in-memory (localhost:9090)
**Device:** Android emulator API 34 (Patrol_API34)

## Summary

| Metric | Value |
|--------|-------|
| Total tests executed | 51 / ~85 |
| Passing | 38 |
| Failing | 13 |
| Pass rate | 75% |
| Files fully green | 6 / 10 executed |

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
| 9 | teams/team_management_test.dart | 6 | 1 | 5 | 17% | 🔴 |
| 10 | setlists/setlist_crud_test.dart | 6 | 1 | 5 | 17% | 🔴 |
| 11 | auth/invitation_acceptance_test.dart | 7 | — | — | — | ⏳ Pending |
| 12 | calendar/calendar_availability_test.dart | 7 | — | — | — | ⏳ Pending (hung) |
| 13 | chat/team_chat_test.dart | 4 | — | — | — | ⏳ Pending |
| 14 | cross_feature/cross_feature_flows_test.dart | 4 | — | — | — | ⏳ Pending |
| 15 | error_handling/error_states_test.dart | 4 | — | — | — | ⏳ Pending |

## Known Failing Tests

### songs/song_crud_test.dart — 1 failure
- **"Tap edit FAB on Song_Detail_Page shows pre-filled form"** — The edit FAB (Icons.edit) loads asynchronously via `_loadUserRole()` from SharedPreferences. The `_waitForEditFab` polling timeout may be too short on the emulator.

### notifications/notifications_test.dart — 1 failure
- TBD — need to identify which test fails

### categories/category_tag_test.dart — 1 failure
- TBD — need to identify which test fails

### teams/team_management_test.dart — 5 failures
- **Previous root cause:** NavigationHelper `_navigateViaFeatureCard` failed with `Bad state: No element` when trying to find and tap the "Equipos" feature card on the Home page. The card was below the fold, and the `.last` finder threw when the text appeared only once.
- **Fix applied:** NavigationHelper refactored to use programmatic `appRouter.go()` instead of UI-based feature card tapping. This eliminates scroll/finder issues entirely. Needs re-run to confirm fix.
- Tests 2 (create form) passes because it uses `registerUniqueAndLogin()` which doesn't need pre-seeded data.

## Backend Fixes Applied

1. **NoOpEmailService.kt** — Created for H2 profile to prevent email sending failures
2. **ChurchRegistrationService.kt** — Auto-verify and activate users in H2 profile so E2E tests can login immediately
3. **application-h2.yml** — Fixed mail username to valid email address

## App Fixes Applied

1. **ConnectionStatusIndicator** — Replaced `Stream.periodic` with `Stream.value` to prevent persistent timers
2. **LoginPage shimmer** — Removed `controller.repeat()` to prevent persistent animation
3. **HomePage shimmer** — Removed `controller.repeat()` to prevent persistent animation
4. **WebSocketService** — Added `forTesting()` constructor; test_app uses `_NoOpWebSocketService`
5. **ConnectivityService** — test_app uses `_TestConnectivityService` without periodic timers
6. **WorshipManagerApp** — Added optional `locale` parameter for test locale override

## Test Infrastructure

- **patrol_base.dart** — `TestEnvironment` with setup/tearDown, uses `$.pumpWidget` + `$.pump(3s)` instead of `pumpWidgetAndSettle`
- **test_app.dart** — Forces `Locale('es')`, no-op WebSocket, no-op ConnectivityService, in-memory Drift DB
- **NavigationHelper** — Programmatic navigation via `appRouter.go()` (replaced UI-based feature card tapping to avoid scroll/finder issues)
- **FormHelper** — Tap before enterText, ensureVisible before tap
- **WaitHelper** — All waits use `$.pump(Duration)`, never `pumpAndSettle`
- **ApiSeedHelper** — Direct HTTP client for seeding data via real API
- **Android build.gradle.kts** — PatrolJUnitRunner + Android Test Orchestrator

## How to Run

```powershell
# Prerequisites: backend running with H2, emulator running
$env:PATH = "$env:LOCALAPPDATA\Pub\Cache\bin;$env:PATH"
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
$env:PATH = "$env:ANDROID_HOME\platform-tools;$env:PATH"

# Clean before each run (Gradle lock file workaround)
Remove-Item -Recurse -Force "build\app\outputs\androidTest-results" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "build\app\reports\androidTests" -ErrorAction SilentlyContinue

# Run a specific test file
patrol test -t integration_test/tests/auth/login_test.dart -d emulator-5554

# Run from worship_hub_ui/ directory
```
