---
inclusion: auto
description: Rules and patterns for E2E integration tests with Patrol
---

# E2E Testing Rules — WorshipHub

## Mandatory Rules

### 1. Use localized strings, never hardcoded text

All UI text assertions in tests MUST use the localization system (`AppLocalizations`) instead of hardcoded Spanish strings. This ensures tests remain valid if translations change and enforces proper i18n in the app code.

**Wrong:**
```dart
await env.assertionHelper.expectTextVisible('Equipos de Alabanza');
```

**Right:**
```dart
// Use AppLocalizations from the test context
final l10n = AppLocalizations.of(context)!;
await env.assertionHelper.expectTextVisible(l10n.teamsTitle);
```

**If a translation key doesn't exist yet:** Add it to `lib/l10n/app_es.arb` (and `app_en.arb`) first, then use it in both the page widget AND the test. Never leave hardcoded strings in production code.

**Exception:** Dynamically generated text (timestamps, user-entered data like team names) can be asserted directly since they come from test fixtures, not from the UI.

### 2. Never use `pumpAndSettle()`

The app has persistent timers (ConnectivityService, WebSocket heartbeats). Always use `pump(Duration(...))` with explicit durations.

### 3. Use `find.widgetWithText(WidgetType, text)` for interactive elements

Never use `find.text(name)` to tap elements in bottom sheets or overlays — the same text may appear in widgets behind the overlay (e.g., category name in SongCard AND in FilterChip).

### 4. Incremental pump for SnackBar detection

Instead of a single large `pump(5s)`, poll in small increments:
```dart
for (int i = 0; i < 10; i++) {
  await $.tester.pump(const Duration(seconds: 1));
  if (find.byType(SnackBar).evaluate().isNotEmpty) break;
}
```

### 5. Use `kIsWeb` guards for platform-specific UI

Elements that only render on mobile (Google Sign-In button, native dialogs) must be guarded with `if (!kIsWeb)` in assertions.

### 6. Repositories must use injected dependencies

Never access static singletons (`DatabaseService.database`) from repositories. Always use the instance received via constructor injection. This enables proper testing with in-memory databases.

### 7. Database tables must have proper primary keys

Use the server-provided UUID as the primary key (`Set<Column> get primaryKey => {serverId}`). Never use a separate autoincrement `id` column when a natural key exists. Use `insertOnConflictUpdate` for upserts.

### 8. `TextInputType.emailAddress` must be conditional on web

On web, `TextInputType.emailAddress` generates `<input type="email">` which doesn't support `setSelectionRange`. Always use:
```dart
keyboardType: kIsWeb ? TextInputType.text : TextInputType.emailAddress,
```

### 9. Error SnackBars must have explicit duration

Default 4s is too short for error messages. Use `duration: const Duration(seconds: 6)` minimum.

### 10. Unique test data per test

Always use timestamps in emails/names to avoid H2 database collisions between test runs:
```dart
final uniqueEmail = 'user_${DateTime.now().millisecondsSinceEpoch}@test.com';
```

### 11. Debug failures across the full sync chain

When an E2E test fails, do NOT assume the problem is in the test or the UI. Check the entire chain in order:

1. **Backend API** — Does the endpoint return the correct response? (Backend has 120 integration tests — run them first)
2. **Frontend repository** — Does the Dio call hit the right endpoint? Is the JSON parsed correctly?
3. **Local DB sync** — Does the upsert store the data correctly? Are there duplicate rows, missing columns, or wrong primary keys?
4. **BLoC state** — Does the BLoC emit the correct state after the repository call? Does it reload data after mutations?
5. **UI render** — Does the widget tree rebuild with the new state? Is there a `buildWhen` or `listenWhen` that filters out the relevant state?

The frontend-backend sync layer (steps 2-3) is the most common failure point. Examples found in this project:
- `TeamRepositoryImpl` used `DatabaseService.database` (static singleton) instead of the injected `AppDatabase` → "Database not initialized" error
- `Teams` table had no UNIQUE constraint on `teamId` → duplicate rows → `getSingleOrNull` threw "Too many elements"
- `TeamListPage` didn't listen for `TeamDeleted` state → list didn't reload after deletion
- `TeamMembersPage` returned `SizedBox.shrink()` instead of empty state when member list was empty

### 12. Use `byWidgetPredicate` for generic-typed widgets

`find.byType(SomeWidget)` matches `SomeWidget<dynamic>`, which won't find `SomeWidget<ConcreteType>`. Use `byWidgetPredicate` with an `is` check instead:

```dart
final finder = find.byWidgetPredicate((w) => w is TableCalendar);
```

This applies to any widget with a generic type parameter (e.g., `TableCalendar<ServiceEvent>`, `AnimatedList<Item>`). Define the finder as a top-level variable in the test file for reuse.

### 13. Capture full test output to a file for analysis

When running `patrol test`, always redirect the full output to a file. This captures all Dio requests/responses, BLoC state changes, error stack traces, and assertion failures in one place for quick analysis without re-running.

```powershell
$env:PATH = "$env:LOCALAPPDATA\Pub\Cache\bin;$env:PATH"
patrol test -t integration_test/tests/teams/team_management_test.dart -d chrome 2>&1 | Out-File -FilePath "test_output.log" -Encoding utf8
# Then read test_output.log to analyze failures
```

After a failure, read `test_output.log` first — it has everything needed to diagnose the issue.

### 13. Debugging failed tests with Playwright report

When `patrol test` fails on Chrome, the error details are visible in the Playwright HTML report.

**Kiro can fetch the report directly:** Use `webFetch` on `http://127.0.0.1:5500/worship_hub_ui/playwright-report/index.html` to read the report without needing the user to paste logs. The Live Server extension must be running on the workspace for this URL to be accessible.

**Workflow:**
1. Kiro executes `patrol test` and captures the result
2. If tests fail, Kiro fetches `http://127.0.0.1:5500/worship_hub_ui/playwright-report/index.html` to read the Playwright report
3. If the report doesn't have enough detail, ask the user to open it in the browser and paste the "Stdout" tab content for the failed test
4. Kiro analyzes the logs and fixes the code

**Why this is necessary:** Patrol web mode does not capture Flutter's error output in the terminal. The `PATROL_LOG` entries and Flutter exception stack traces are only visible in the Playwright report's "Stdout" tab for each failed test. The `.md` files in `playwright-report/data/` only contain a generic "Test finished" page snapshot — they do NOT contain the actual error.

**Example:** This workflow found the `TeamChatPage.dispose()` bug — `context.read<ChatBloc>()` on a deactivated widget — which was completely invisible in terminal output but clearly shown in the Playwright report's stdout.

### 14. Never run patrol tests as background processes

Patrol tests are long-running commands that produce output incrementally. Always run them with `executePwsh` with a sufficient `timeout` (300000-600000ms). Never use `controlPwshProcess` — the output gets buffered and you can't monitor progress.

### 15. PATH setup for patrol CLI

The patrol CLI is installed in `$env:LOCALAPPDATA\Pub\Cache\bin`. Always prepend it to PATH before running patrol commands:
```powershell
$env:PATH = "$env:LOCALAPPDATA\Pub\Cache\bin;$env:PATH"
```

For Android, also add the Android SDK platform-tools:
```powershell
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
$env:PATH = "$env:ANDROID_HOME\platform-tools;$env:PATH"
```

### 16. Android physical device requires `adb reverse`

Physical Android devices cannot access `localhost` on the host machine. Before running tests on a physical device, set up port forwarding:
```powershell
adb -s <DEVICE_ID> reverse tcp:9090 tcp:9090
```

This makes `localhost:9090` on the device forward to port 9090 on the host. The `TestConfig` defaults to `localhost:9090` for Android when no `TEST_API_HOST` is provided.
