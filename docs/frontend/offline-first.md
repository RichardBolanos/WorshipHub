# Offline-First Sync — Architecture Guide & Session Handover

> **This document is the canonical handover for work on `worship_hub_ui`.**
>
> If you are an AI agent opening a new session, read this file end-to-end
> before touching any code. It contains the full mental model, the decisions
> already taken (with rationale), the tooling quirks discovered the hard way,
> the state of the test suite, and the backlog of work that is still open.
>
> If after reading this file you still don't know where to start, check the
> **Session resume cheat-sheet** at the end.

---

## Table of contents

0. [Repository layout & submodules](#0-repository-layout--submodules)
1. [The single source of truth](#1-the-single-source-of-truth)
2. [The mental model (SyncPhase / SyncViewModel)](#2-the-mental-model)
3. [Core infrastructure](#3-core-infrastructure)
4. [Feature coverage matrix](#4-feature-coverage-matrix)
5. [How to add a new sync-aware feature](#5-how-to-add-a-new-sync-aware-feature)
6. [The golden rules](#6-the-golden-rules)
7. [Testing playbook](#7-testing-playbook)
8. [Project-wide conventions you WILL trip over](#8-project-wide-conventions-you-will-trip-over)
9. [Known gaps / backlog](#9-known-gaps--backlog)
10. [Architectural history — what we already tried and why we stopped](#10-architectural-history)
11. [Session resume cheat-sheet](#11-session-resume-cheat-sheet)

---

## 0. Repository layout & submodules

The working tree is a **monorepo with two git submodules**:

```
D:\Proyectos\WorshipHub\
├── worship_hub_api/    (submodule, Kotlin/Spring Boot, backend)
├── worship_hub_ui/     (submodule, Flutter, frontend — THIS guide lives here)
└── .gitmodules
```

Each submodule has its own git history and remote. The root repo only
tracks submodule pointers via `chore(submodules): bump ...` commits.

**Rules for committing when your change touches both repos:**
1. Commit inside the submodule first (backend or frontend).
2. `cd` out and commit the submodule-pointer bump in the root repo with a
   `chore(submodules): bump ...` message that lists the child commits.
3. Never push one without the other if they are logically paired (e.g. the
   OAuth2 UserInfo change — backend returns it, frontend reads it).

**Environment**:
- OS: Windows 11, shell: PowerShell 7 (`pwsh`).
- Flutter is on PATH; `flutter test` and `flutter analyze` work from either
  submodule root. `flutter test --reporter compact` is what you want for
  machine-readable output.
- Backend builds with Gradle (`./gradlew build` / `./gradlew nativeCompile`).

---

## 1. The single source of truth

**All sync orchestration in the Flutter app goes through
`SyncManager`** (`lib/core/sync/sync_manager.dart`). This is a hard
architectural invariant — not a suggestion.

| Operation | Canonical API | Never do this |
|---|---|---|
| Sync everything | `SyncManager.requestImmediateSync()` / `syncAll()` | Loop over repos dispatching `Load*` BLoC events from the UI |
| Sync one feature | `SyncManager.syncRepository(Type)` | Expose `syncFooBars()` on a repository |
| Sync a sub-scope (e.g. chat-by-team) | `SyncManager.syncRepositoryScoped(Type, scope)` | `Timer.periodic` inside a BLoC that hits the API |
| Know if data is fresh | `SyncViewModel.freshnessWindow` (default 5 min) | `_lastFetchTime` / `_isCacheValid` TTL inside a repo |
| Refresh after a local write | `SyncManager.syncRepository(runtimeType)` (from the repo) | `Future.delayed(...).then((_) => _fetchFromApi())` |
| Pause syncing | `SyncManager.stopPeriodicSync()` (wired to logout) | Never; the manager is the only timer owner |
| Clear state between users | `SyncManager.resetState()` (wired to logout) | Keep stale `lastSuccessAt` around |

If you find yourself writing a method named `syncX`, `refreshX`,
`_syncInBackground`, or a `Timer.periodic` that talks to the backend,
**stop** — that logic belongs in the `SyncManager`. We removed seven such
methods during the unification refactor; do not reintroduce them.

### 1.1 Auth-driven lifecycle (main.dart)

The global `BlocListener<AuthBloc, AuthState>` in `lib/main.dart` is the
single authority on sync lifecycle vs. user session:

```
┌─────────────────────┐     ┌──────────────────────┐     ┌────────────────────┐
│  App bootstrap      │     │ Auth → Authenticated │     │ Auth → Unauth      │
│  (isAuthenticated   │     │ (login / refresh)    │     │ (logout / revoked) │
│   in SecureStorage) │     └──────────┬───────────┘     └─────────┬──────────┘
│                     │                │                            │
│ if (hasValidToken)  │                ▼                            ▼
│   requestImmediate  │  startPeriodicSync()               stopPeriodicSync()
│     Sync();         │  requestImmediateSync()             resetState()
│                     │  + reset all user-scoped            + reset all user-scoped
│                     │    BLoCs                              BLoCs
└─────────────────────┘
```

Tests in `test/integration/sync/sync_lifecycle_test.dart` and
`test/integration/sync/auth_sync_listener_test.dart` pin these
invariants — add regressions there, do not duplicate the logic.

### 1.2 What the user sees

After login (or reopening the app with a valid session):
1. Every pill across the app flips to **"Sincronizando"** (cyan + spinner).
2. On success, each pill settles to **"Al día"** (green) — or **"Local"**
   if there are pending unsynced writes.
3. If the device is offline, the cycle is a no-op (no wasted requests);
   pills show **"Sin conexión"**.

One mental model, N features — not the other way around.

---

## 2. The mental model

Every feature has one canonical view of its sync state, captured by
**`SyncViewModel`** (`lib/core/sync/sync_view_state.dart`):

| Phase     | Meaning                                                       | Colour (pill) | Icon |
|-----------|---------------------------------------------------------------|---------------|------|
| `syncing` | A push or pull is in flight                                   | Cyan          | spinner |
| `live`    | No pending local changes AND (fresh cache OR no sync yet this session) | Green | cloud_done_rounded |
| `cached`  | Pending local changes OR a real prior sync aged past the window | Amber | cloud_queue_rounded |
| `offline` | No connection                                                 | Grey          | cloud_off_rounded |
| `error`   | Last sync attempt failed with a retryable error               | Red           | error_outline_rounded |

The phase is **derived** from 5 inputs via `SyncViewModel.derive(...)`:
`isOnline`, `isSyncing`, `pendingCount`, `lastSyncAt`, `lastError`.

**Priority** (first match wins):
`syncing > error > offline > pending > stale-cache > live`.

**Freshness window**: 5 minutes by default, configurable per feature.

### 2.1 Subtle rule: `lastSyncAt == null` → `live` (NOT `cached`)

When the app starts and no sync has happened yet this session, `lastSyncAt`
is `null`. If there are no pending changes and we are online, the pill
shows **`live`**, not `cached`.

**Rationale**: if every row in the local DB has `isSynced=true`, showing
"Local" contradicts what the user sees. We trust the DB until we have
concrete evidence it is stale (a real successful sync that then aged out,
or pending local changes).

This rule is pinned by a **regression test** in
`test/core/sync/sync_view_state_test.dart` (group
`regression: "local" pill with all rows isSynced=true`). Do not "fix" the
test by inverting it — the contrary was the original bug.

### 2.2 The pill

The canonical UI surface is **`SyncStatusPill`**
(`lib/presentation/widgets/sync/sync_status_pill.dart`):

- Small rounded chip with colour + icon + label + optional pending-count badge.
- **Tap** → bottom sheet with: connection, last-sync age, pending count,
  error message, "Sync now" action.
- Purely presentational — hand it a `SyncViewModel` and an optional
  `onSyncNowPressed` callback.

For API-primary features (no offline writes) there is also
**`ConnectivityPill`** (`lib/presentation/widgets/sync/connectivity_pill.dart`)
that skips the SyncManager wiring and reflects only `ConnectivityService`.

---

## 3. Core infrastructure

```
lib/core/sync/
├── sync_view_state.dart         — SyncPhase enum, SyncViewModel, derive()
├── sync_manager.dart            — SyncManager (orchestrator)
│                                   + SyncableRepository (abstract contract)
│                                   + SyncEvent sealed class
│                                   + RepoSyncState + SyncManagerSnapshot
├── sync_aware_controller.dart   — SyncAwareController
│                                   (per-feature bridge BLoC ↔ SyncManager)
└── sync_state_store.dart        — SyncStateStore abstract + SharedPreferences
                                    impl that persists `lastSyncAt` per repo
                                    between app restarts. Optional constructor
                                    param on SyncManager; see §9.3.
```

```
lib/presentation/widgets/sync/
├── sync_status_pill.dart        — shared pill + detail sheet
├── connectivity_pill.dart       — simpler variant for API-primary pages
└── app_sync_status_pill.dart    — aggregated whole-app pill used on Home;
                                    binds to SyncManager.snapshots and calls
                                    requestImmediateSync from the sheet.
```

### 3.1 `SyncManager`

One singleton in `GetIt` (see `service_locator.dart` → `_setupSyncManager`).
Responsibilities:

- Periodic cycle (default 5 min) that push+pulls every registered repo.
- Listens to `ConnectivityService.statusStream` and fires a cycle on
  reconnect (offline→online transition only).
- Public API:
  - `registerRepository(SyncableRepository)` — idempotent.
  - `startPeriodicSync({Duration interval})` — idempotent; cancels the
    existing timer if any.
  - `stopPeriodicSync()`.
  - `syncAll()` — full push+pull of every registered repo. Re-entrant-safe.
  - `requestImmediateSync()` — alias for `syncAll()`, used by repos after a
    local write.
  - `syncRepository(Type)` — sync one feature (for "Sync now" buttons).
  - `syncRepositoryScoped(Type, scope)` — sync one feature with a scope
    (e.g. chat-per-team). Delegates to `pullScopedData(scope)` on the repo.
  - `resetState()` — wired to logout; zeros `RepoSyncState` for every repo
    without de-registering them.
- Streams:
  - `events: Stream<SyncEvent>` — granular lifecycle:
    `SyncCycleStarted/Completed/Skipped`, `RepoSyncStarted/Succeeded/Failed`.
  - `snapshots: Stream<SyncManagerSnapshot>` — aggregated state (all repos
    + isOnline) for reactive UIs.
  - `totalUnsyncedCount: Stream<int>` — app-wide count.
- Exponential backoff on failure: `[1, 2, 4, 8, 16]` seconds, max 5 retries.

**Critical implementation detail**: the `_isSyncing` lock is acquired
**synchronously before any `await`** inside `syncAll`. Otherwise two
callers could both pass `if (_isSyncing) return` while the other is
inside `checkStatus()`. This bug was fixed; the test
`re-entrancy guard — calls issued DURING an in-flight cycle are collapsed`
in `test/integration/sync/sync_lifecycle_test.dart` pins it.

### 3.2 `SyncableRepository` (contract)

```dart
abstract class SyncableRepository {
  Future<void> pushUnsyncedChanges();
  Future<void> pullLatestData();
  Stream<int> getUnsyncedCountStream();
  Future<void> pullScopedData(Object scope);  // see below
}
```

`pullScopedData` exists so chat-style features can refresh a sub-slice.
**Default one-liner** for every repo that doesn't care: `(scope) =>
pullLatestData();`. Only `ChatRepositoryImpl` has a real override.

Dart's `implements` keyword forces re-implementation of every method, so
every repo writes that one-liner explicitly. We tried `mixin
ScopedPullDefaults on SyncableRepository` but Dart 3's `with` requires
`extends`, not `implements` — the mixin approach failed. Don't try again.

### 3.3 `SyncAwareController`

Per-feature bridge owned by each BLoC:

```dart
final SyncAwareController? syncController;

Stream<SyncViewModel> get syncStream =>
    syncController?.stream ?? Stream.value(const SyncViewModel.initial());
```

The controller subscribes to `SyncManager.snapshots` and
`ConnectivityService.statusStream`, derives the feature's `SyncViewModel`
via `SyncViewModel.derive` and republishes it. UIs bind with a
`StreamBuilder<SyncViewModel>`.

Composition over inheritance was chosen deliberately — every BLoC in the
app has a different state class hierarchy, so a mixin would have forced
an invasive migration across the board.

---

## 4. Feature coverage matrix

| Feature       | SyncableRepository | Registered | Write queue | Scoped pulls | Pill  | Page                           |
|---------------|:------------------:|:----------:|:-----------:|:------------:|:-----:|---------------------------------|
| Songs         | ✅                 | ✅         | ✅          | —            | ✅    | `song_list_page.dart`           |
| Setlists      | ✅                 | ✅         | ✅          | —            | ✅    | `setlist_list_page.dart`        |
| Services      | ✅                 | ✅         | ✅          | —            | ✅    | `service_list_page.dart` + `service_detail_page.dart` |
| Chat          | ✅                 | ✅         | ✅          | ✅ per-team  | ✅    | `team_chat_page.dart`           |
| Availability  | ✅                 | ✅         | ✅          | —            | ✅    | `calendar_page.dart`            |
| Teams         | ✅                 | ✅         | ✅ (CRUD; `inviteMemberByEmail` stays sync) | — | ✅ | `team_list_page.dart` |
| Categories    | ✅ (read-only)     | ✅         | ❌          | —            | ✅    | `category_management_page.dart` |
| Notifications | n/a (API-primary)  | ❌         | n/a         | —            | `ConnectivityPill` | `notifications_page.dart` |
| Profile       | n/a (API-primary)  | ❌         | n/a         | —            | `ConnectivityPill` | `profile_page.dart`       |

"Write queue" = the repo buffers offline writes (`isSynced=false` rows)
and the manager pushes them on every cycle. Read-only repos are
upgradable without breaking the contract — push is a no-op today but
becomes real once an `isSynced` column lands on the Drift table.

---

## 5. How to add a new sync-aware feature

### Step 1 — Wire the repository

```dart
class MyRepositoryImpl implements MyRepository, SyncableRepository {
  @override
  Future<void> pushUnsyncedChanges() async {
    final rows = await _db.select(_db.myTable)
      .where((t) => t.isSynced.equals(false))
      .get();
    for (final row in rows) {
      try {
        final response = await dio.post('/api/v1/my-endpoint', data: ...);
        // Mark row isSynced=true, stamp serverId, etc.
      } catch (e, stack) {
        GlobalErrorHandler.logError('push failed, will retry', e, stack);
      }
    }
  }

  @override
  Future<void> pullLatestData() async {
    final response = await dio.get('/api/v1/my-endpoint');
    // Upsert locally. Never overwrite rows that are isSynced=false.
  }

  @override
  Stream<int> getUnsyncedCountStream() =>
      (_db.select(_db.myTable)..where((t) => t.isSynced.equals(false)))
        .watch()
        .map((r) => r.length);

  /// Default one-liner. Override ONLY for genuine sub-scopes.
  @override
  Future<void> pullScopedData(Object scope) => pullLatestData();
}
```

### Step 2 — Register in DI

```dart
// lib/core/dependency_injection/service_locator.dart
void _setupSyncManager() {
  // ...existing registrations...
  syncManager.registerRepository(sl<MyRepository>() as MyRepositoryImpl);
}
```

### Step 3 — Wire the BLoC

```dart
class MyBloc extends Bloc<MyEvent, MyState> {
  final SyncAwareController? syncController;

  Stream<SyncViewModel> get syncStream =>
      syncController?.stream ?? Stream.value(const SyncViewModel.initial());

  MyBloc({..., this.syncController}) : super(const MyInitial());

  @override
  Future<void> close() async {
    await syncController?.dispose();
    return super.close();
  }
}
```

And in DI:

```dart
sl.registerFactory(() => MyBloc(
  ...,
  syncController: SyncAwareController(
    repositoryType: MyRepositoryImpl,
    syncManager: sl<SyncManager>(),
    connectivity: sl<ConnectivityService>(),
  ),
));
```

### Step 4 — Mount the pill in the page header

```dart
class _MyPagePill extends StatelessWidget {
  const _MyPagePill();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<MyBloc>();
    return StreamBuilder<SyncViewModel>(
      stream: bloc.syncStream,
      initialData: bloc.syncController?.current
          ?? const SyncViewModel.initial(),
      builder: (context, snapshot) {
        final vm = snapshot.data ?? const SyncViewModel.initial();
        return SyncStatusPill(
          viewModel: vm,
          featureName: 'My Feature',
          onSyncNowPressed: bloc.syncController == null
              ? null
              : () => bloc.syncController!.requestSyncNow(),
        );
      },
    );
  }
}
```

Then plug `const _MyPagePill()` into `PremiumPageHeader.actions` (or
`AppBar.actions`).

### Step 5 — API-only features (no offline writes)

Skip the SyncManager entirely, use `ConnectivityPill`:

```dart
ConnectivityPill(
  connectivity: sl<ConnectivityService>(),
  featureName: 'My Feature',
)
```

### Step 6 — Write the tests

See section [7. Testing playbook](#7-testing-playbook).

---

## 6. The golden rules

1. **Never block the UI on a network call.** Local writes persist first
   (`isSynced=false`); the SyncManager pushes them.
2. **Never silence a sync error.** Log via
   `GlobalErrorHandler.logError` / `.logWarning`. The row stays
   `isSynced=false` so the next cycle retries.
3. **Never overwrite local pending changes in `pullLatestData`.** Upsert
   only rows already `isSynced=true`. The canonical example is
   `ServiceRepositoryImpl._upsertLocal`.
4. **Always call `await syncController?.dispose()` in `Bloc.close()`.**
5. **`StreamBuilder<SyncViewModel>` must use `initialData:
   controller.current`** to avoid a one-frame flash of neutral state.
6. **Writes must trigger `SyncManager.syncRepository(runtimeType)`** from
   inside the repo, not from the UI. The UI just writes to the DB.
7. **Never add a method called `syncX` to a repository interface.** If
   you need manual refresh, call `syncController.requestSyncNow()` from
   the UI.
8. **Never add a `Timer.periodic` that talks to the backend.** The
   `SyncManager` is the only timer owner. Scoped refresh (e.g. active
   chat) uses `syncRepositoryScoped(Type, scope)`.

---

## 7. Testing playbook

The sync suite currently totals **~746 passing tests** with 11
historically-skipped (see §10). Run the relevant subsets:

| Concern                                | Path                                                                |
|----------------------------------------|---------------------------------------------------------------------|
| SyncViewModel derivation rules         | `test/core/sync/sync_view_state_test.dart`                          |
| SyncManager orchestration / events     | `test/core/sync/sync_manager_test.dart`                             |
| SyncAwareController behaviour          | `test/core/sync/sync_aware_controller_test.dart`                    |
| SyncStateStore (SharedPreferences)     | `test/core/sync/sync_state_store_test.dart`                         |
| SyncManager × SyncStateStore wiring    | `test/core/sync/sync_manager_state_store_test.dart`                 |
| SyncStatusPill rendering + sheet       | `test/presentation/widgets/sync/sync_status_pill_test.dart`         |
| AppSyncStatusPill (aggregated)         | `test/presentation/widgets/sync/app_sync_status_pill_test.dart`     |
| Per-repo push/pull contract            | `test/unit/repositories/<repo>_sync_test.dart` (one per repo)       |
| Abstract contract                      | `test/unit/repositories/syncable_repository_contract_test.dart`     |
| BLoC syncStream contract               | `test/unit/blocs/sync_aware_bloc_contract_test.dart`                |
| BLoC integration (example: Songs)      | `test/unit/blocs/song_bloc_sync_stream_test.dart`                   |
| Login/logout/bootstrap lifecycle       | `test/integration/sync/sync_lifecycle_test.dart`                    |
|                                        | `test/integration/sync/auth_sync_listener_test.dart`                |
| lastSyncAt persistence (app restart)   | `test/integration/sync/last_sync_at_persistence_e2e_test.dart`      |
| Availability offline queue E2E         | `test/integration/sync/availability_offline_queue_e2e_test.dart`    |
| Availability local datasource (Drift)  | `test/data/datasources/local/availability_local_data_source_test.dart` |
| Pill presence per feature page         | `test/integration/sync/pages/pill_presence_test.dart` (Services)    |
|                                        | `test/integration/sync/pages/pill_presence_all_features_test.dart`  |
|                                        | `test/integration/sync/pages/home_page_pill_test.dart`              |

**One-liner to run everything sync-related:**

```sh
flutter test test/core/sync/ \
             test/presentation/widgets/sync/ \
             test/integration/sync/ \
             test/data/datasources/local/availability_local_data_source_test.dart \
             test/unit/blocs/sync_aware_bloc_contract_test.dart \
             test/unit/blocs/song_bloc_sync_stream_test.dart \
             test/unit/repositories/syncable_repository_contract_test.dart \
             test/unit/repositories/availability_repository_sync_test.dart \
             test/unit/repositories/availability_repository_impl_test.dart \
             test/unit/repositories/category_repository_sync_test.dart \
             test/unit/repositories/chat_repository_sync_test.dart \
             test/unit/repositories/service_repository_sync_test.dart \
             test/unit/repositories/setlist_repository_sync_test.dart \
             test/unit/repositories/song_repository_sync_test.dart \
             test/unit/repositories/team_repository_sync_test.dart
```

### 7.1 Test harness conventions

- **Stub `syncStream` + `syncController` on every mocked BLoC** before
  pumping a page that mounts a pill:
  ```dart
  when(() => bloc.syncStream).thenAnswer((_) => controller.stream);
  when(() => bloc.syncController).thenReturn(null);
  ```

- **Services pages need `ServiceRepository` registered in GetIt** because
  the per-row chip reads `sl<ServiceRepository>().watchIsSynced(localId)`.
  Use `_FakeServiceRepository` (see
  `test/integration/sync/pages/pill_presence_test.dart`).

- **Notifications + Profile pages need `ConnectivityService` in GetIt**
  (the `ConnectivityPill` reads it).

- **CalendarPage auto-resolves its BLoC via `sl<AvailabilityBloc>()`** —
  to test it, `sl.registerFactory<AvailabilityBloc>(() => mockBloc)`
  before pumping. You cannot `BlocProvider.value` it because
  `_CalendarView` is private.

- **Avoid `pumpAndSettle` on pages with `flutter_animate`.** They keep
  ticking forever and pumpAndSettle times out. Use
  `tester.pump(const Duration(milliseconds: 50))` instead.

- **AppLocalizations in test MaterialApp**: every page that uses
  `AppLocalizations.of(context)!` (which is every feature page) must be
  wrapped with:
  ```dart
  MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('es'),
    ...
  )
  ```

- **SongBloc emits English fallbacks in tests** because `l10n` is null
  without BuildContext. Assert on `'Song created'` / `'Error creating
  song'`, not the Spanish strings.

- **`flutter_secure_storage` needs a MethodChannel mock** in tests that
  invoke `AuthCheckRequested`. See `test/integration/auth_flow_test.dart`
  for the pattern.

- **Stream subscriptions to `SyncManager.events` must be set up BEFORE
  calling sync.** Broadcast streams drop events emitted before the
  subscription registers.

- **E2E tests that wait on async work** (por ejemplo
  `availability_offline_queue_e2e_test.dart`) usan un helper local
  `_waitFor(predicate, timeout: …)` en vez de `pumpAndSettle` o
  `Future.delayed` con un valor fijo. Le da al `SyncManager` tiempo
  real para terminar el push y falla con un mensaje útil si la
  invariante no se cumple en el timeout. Si un test se vuelve flaky,
  subir el timeout a 3-5 s es aceptable; el criterio es "¿podría esto
  tardar más en un CI lento?".

- **Fake data sources en tests de integración extienden la clase
  concreta en vez de implementarla.** El `AvailabilityRemoteDataSource`
  expone un campo `dio` obligatorio; `class _ScriptedRemote extends
  AvailabilityRemoteDataSource` (pasando un `Dio()` vacío al super) deja
  sobreescribir solo los tres métodos HTTP sin tener que crear un Dio
  real. Mismo patrón para futuros remote data sources.

- **SharedPreferences en tests** se inicializa con
  `SharedPreferences.setMockInitialValues({})` en `setUp`. Cada test
  empieza con un store vacío. Para simular "reiniciar la app" con
  estado persistido, **crea y destruye varias instancias del
  `SyncManager` sobre el MISMO `SharedPreferencesSyncStateStore`** —
  ver `last_sync_at_persistence_e2e_test.dart`.

- **Tests E2E de cola offline necesitan BD Drift real en memoria.** La
  migración `onUpgrade` y las queries con `isSynced`/`pendingDelete`
  solo se ejercitan con `AppDatabase.forTesting(NativeDatabase.memory())`,
  no con mocks. Patrón canónico en
  `availability_local_data_source_test.dart`.

### 7.2 Intentionally skipped tests

`test/bugfix/bug_condition_exploration_test.dart` has 11 tests marked
with `skip: _skipReason`. They document bugs from a past audit using the
inverted pattern `expect(hasBug, isFalse)` with hard-coded `hasBug=true`;
all those bugs have since been resolved but the assertions were never
updated. Two tests spawn `flutter analyze` via `Process.run` which is
non-reproducible in CI. Coverage for the underlying bugs lives in
`preservation_test.dart`, `category_bloc_test`, and the sync suite.

**Do not try to "fix" these tests — delete the file if/when you are
confident the coverage is duplicated elsewhere, or leave them skipped.**

---

## 8. Project-wide conventions you WILL trip over

### 8.1 Environment

- Windows 11 + PowerShell 7 (`pwsh`). PowerShell escaping for multi-line
  `git commit -m` uses the `@'…'@` here-string syntax; `--% -m "…"` and
  other `cmd`/`bash` patterns will mangle quotes.
- Line endings: the repo is CRLF-normalized. Expect
  `warning: in the working copy of 'X', LF will be replaced by CRLF`
  on every `git add` — harmless, ignore.

### 8.2 Domain / data layering

- **Domain interfaces** are in `lib/domain/repositories/`. They must NOT
  expose sync-orchestration methods (`syncX`, `refreshX`). That belongs
  to the `SyncableRepository` contract, implemented only by the data
  layer.
- **Data impls** live in `lib/data/repositories/`. Every offline-first
  impl implements both `MyRepository` (domain) and `SyncableRepository`
  (infra).
- **Drift DB**: `lib/core/database/database.dart`. Tables with `isSynced`
  + `serverId` columns: Songs, Setlists, Services, Chat, Teams,
  Availabilities. `TeamMembers` has `isSynced` + `pendingDelete` but no
  per-member `serverId` (members are children keyed by `(teamId, userId)`
  on both sides). Invitations don't have a write queue yet — if you
  need one there, bump `schemaVersion` and add a `migrator` step.

### 8.3 DI (GetIt)

- Single entry point: `lib/core/dependency_injection/service_locator.dart`.
- `_setupSyncManager()` at the bottom of `initializeDependencies()`
  registers every `SyncableRepository` — add yours there.
- `ServiceRepositoryImpl` gets `attachSyncManager(sl<SyncManager>())`
  after registration to break a would-be circular DI dependency.

### 8.4 l10n

- ARB files at `lib/l10n/app_es.arb` and `lib/l10n/app_en.arb`.
- Run `flutter gen-l10n` after editing ARB.
- Spanish is the primary locale; all user-visible strings must have both
  ES and EN entries.

### 8.5 Auth session

- The three login paths (password, Google direct, Google
  accept-invitation) all go through
  `AuthRepositoryImpl._persistAuthenticatedUser`. That is the single
  persistence chokepoint — do not duplicate it.
- The backend's `/api/v1/auth/oauth2/google/callback` and
  `/api/v1/auth/oauth2/google/accept-invitation` both return a full
  `user` block (id, email, firstName, lastName, role, churchId) in
  addition to the legacy flat `userId`. The client relies on the nested
  `user` block — do not revert to reading flat fields.

### 8.6 Backend native-image

- `api/src/main/kotlin/com/worshiphub/KotlinEmptyCollectionHints.kt`
  registers reflection metadata for Kotlin's empty-collection
  singletons. Without it, `kotlin.collections.EmptyList` fails to resolve
  inside native image and any response with an empty list crashes.
- `infrastructure/.../email/EmailNativeRuntimeHints.kt` does the same
  for the Thymeleaf email template stack.
- Both are wired via `@ImportRuntimeHints`. If you add a new email
  template or a new `emptyX()`-producing code path, think about whether
  the hints cover it.

### 8.7 JPA

- Custom `@Query`s marked `@Modifying` must also be `@Transactional` at
  the repository method level. Spring Data's implicit `@Transactional`
  only covers `SimpleJpaRepository` CRUD; `@Modifying` queries on the
  custom interface throw `TransactionRequiredException` without it. See
  `EmailVerificationTokenRepositoryImpl`, `InvitationTokenRepositoryImpl`,
  `PasswordResetTokenRepositoryImpl`, `RefreshTokenRepositoryImpl` for
  the pattern.

---

## 9. Known gaps / backlog

Ordered roughly by value × effort. Pick any and run with it — the
architecture is in place.

### 9.1 Write queues for Teams, Availability, Categories

| Feature      | Estado                                      |
|--------------|---------------------------------------------|
| Availability | ✅ **Shipped** — cola offline completa      |
| Teams        | ✅ **Shipped** — cola offline para CRUD de team y de miembros |
| Categories   | 🚧 **Out of scope** — razón abajo           |

**Availability.** `AvailabilityRepositoryImpl` ahora es offline-first real.
La tabla `Availabilities` tiene `isSynced`, `pendingDelete` y `lastSyncAt`
(schemaVersion subió a 3 con su `onUpgrade`). `markUnavailable` y
`deleteAvailability` escriben local primero (con `id` autoincrement
devuelto inmediatamente a la UI) y luego llaman a
`SyncManager.syncRepository(AvailabilityRepositoryImpl)` para que el
push ocurra en el siguiente microtask si hay red. `pushUnsyncedChanges`
drena dos listas por ciclo (inserts pendientes → POST +
`confirmInsertSynced`; deletes pendientes → DELETE +
`confirmDeleteSynced`) y no aborta por una fila individual fallida —
los errores se loguean y la siguiente iteración reintenta.

El local data source también expone `watchCachedAvailability` y
`watchUnsyncedCount` para consumidores reactivos. El `CalendarBloc`
sigue usando re-despacho manual (no rompemos su patrón existente en
este cambio), pero el hook está listo para que un consumidor nuevo
(o una refactorización del bloc) se enganche directo al stream.

Invariantes protegidas por tests:
  * `cacheAvailability` preserva filas con `isSynced=false` **y** filas
    con `pendingDelete=true` durante un refresh del servidor — si no, un
    pull borraría trabajo del usuario o resucitaría filas ya marcadas
    para borrado.
  * Una fila local sin `serverId` se elimina directamente sin intentar
    un DELETE remoto.
  * `getUnsyncedCountStream` es reactivo (no es `Stream.value(0)`) y
    alimenta el contador del pill.

Cobertura: `availability_repository_impl_test.dart` (21 tests),
`availability_repository_sync_test.dart` (5 tests, contrato syncable),
`availability_local_data_source_test.dart` (14 tests contra BD real en
memoria con Drift `NativeDatabase.memory()`).

**Teams.** `TeamRepositoryImpl` pasa a ser offline-first en todas las
operaciones CRUD realistas sin red: `createTeam`, `updateTeam`,
`deleteTeam`, `addMemberToTeam`, `removeMemberFromTeam` y
`updateMemberRole` escriben local con `isSynced=false` y encolan el
push. `inviteMemberByEmail` **se mantiene síncrona** porque el efecto
secundario es un email real — no hay semántica razonable para una
"invitación diferida" que el usuario no vea salir.

Schema v4 añade a `teams`: `serverId` (nullable), `isSynced` (default
true para filas pre-existentes pulled del servidor), `pendingDelete`,
`lastSyncAt`. Mismas columnas menos `serverId` en `team_members`
(los miembros no tienen su propio UUID server-side; son hijos de un
team).

### Identifier strategy

`teams.teamId` es la PK estable durante **toda la vida de la fila**.
Consumers (`team_members.teamId`, `service_events.teamId`, rutas de
UI) nunca tienen que reconciliar ids. El valor depende de dónde vino
la fila:

  * **Pulled del servidor** → `teamId = serverId = backend UUID`.
    Reutilizamos el UUID del servidor como PK local; no hay nada que
    reconciliar después.
  * **Creado offline** → `teamId = clientMintedUuid`, `serverId = null`
    hasta que el push complete. Cuando el POST devuelve el UUID del
    backend, estampamos `serverId` en la **misma fila** sin tocar
    `teamId`.

Los consumers que empujan una referencia foránea al backend (ej:
`ServiceRepositoryImpl._mapToApi` enviando `teamId` en
`ScheduleServiceRequest`) DEBEN traducir `teamId local → serverId`
antes de ir al wire. Si el team fue creado offline y todavía no tiene
`serverId`, el push dependiente queda pendiente y el `SyncManager` lo
reintenta en el siguiente ciclo — no "rompe" la cola.

La cola de miembros sigue la misma regla: si el parent team no tiene
`serverId`, el push del member se salta y espera.

Invariantes protegidas por tests:
  * `createTeam` escribe local sin hacer HTTP (`verifyNever` sobre
    `dio.post`).
  * `pushUnsyncedChanges` POSTea teams, stampa `serverId`, y luego
    POSTea miembros usando el `serverId` recién obtenido.
  * `pullLatestData` no sobrescribe filas con `isSynced=false` ni con
    `pendingDelete=true`.
  * Un 404 al hacer DELETE de un team/member trata como "ya no existe
    remotamente" y borra localmente para no entrar en loop.
  * `getUnsyncedCountStream` suma pending teams + pending members y es
    reactivo a cambios en ambas tablas.
  * `ServiceRepositoryImpl._resolveTeamServerId` lanza `StateError` si
    el team referenciado está pendiente de push, de modo que el
    service push queda en cola hasta que el team tenga `serverId`.

Cobertura: `team_repository_sync_test.dart` (11 tests del write queue
completo con `AppDatabase.forTesting`), `team_repository_impl_invite_test.dart`
(5 tests del path síncrono de invitación),
`team_repository_impl_property_test.dart` (18 property tests adaptados
al nuevo contrato: local writes no hacen HTTP; aggregados remotos
siguen round-tripping; errores de red en operaciones offline-first
nunca salen al BLoC).

**Categories — fuera del alcance de este commit.** `CategoryRepositoryImpl`
es puramente API (no tiene tabla Drift, no tiene data source local).
Convertirlo en offline-first no es "añadir una cola de escritura" sino
un rediseño completo del repo: introducir data source local, tabla
Drift con CRUD, refactorizar cada consumidor para leer del cache. Es
trabajo de varias sesiones y, dado que categories se editan con muy
poca frecuencia, el ROI es bajo comparado con Availability.

### 9.2 App-level aggregated pill on Home

✅ **Shipped.** `AppSyncStatusPill`
(`lib/presentation/widgets/sync/app_sync_status_pill.dart`) binds to
`SyncManager.snapshots.map((s) => s.toAppViewModel())`, renders the
shared `SyncStatusPill`, and wires its "Sync now" action to
`SyncManager.requestImmediateSync`. It is mounted in the `HomePage`
header via `_HomeSyncPill`, which falls back to `SizedBox.shrink()` when
`SyncManager` is not registered in `sl` (keeps widget tests that bypass
DI from crashing). Tests live at
`test/presentation/widgets/sync/app_sync_status_pill_test.dart`.

### 9.3 Persist `lastSyncAt` across sessions

✅ **Shipped.** `SyncStateStore`
(`lib/core/sync/sync_state_store.dart`) persists each repo's
`lastSuccessAt` under the key
`syncmanager.lastSyncAt.<TypeName>` in `SharedPreferences`. The
`SyncManager` accepts it as an optional constructor parameter:

  * On `registerRepository`, the manager schedules a non-blocking
    rehydration that seeds `lastSuccessAt` from disk only if no fresh
    sync has already won the race (so a `syncAll` that completes before
    the hydration future resolves is never rolled back).
  * After every successful `_syncOne` / `_pullOne` /
    `syncRepositoryScoped`, the new timestamp is written fire-and-forget
    — a disk failure is logged but never degrades the in-memory state.
  * `resetState()` (wired to logout) clears every stored timestamp so
    the next user doesn't inherit the previous session's freshness.

The SharedPreferences-backed implementation
(`SharedPreferencesSyncStateStore`) is registered in
`service_locator.dart` and passed to the manager. Passing `null`
(e.g. in tests) keeps the historic in-memory-only behaviour, so none of
the ~500 pre-existing sync tests needed any change.

Covered by `test/core/sync/sync_state_store_test.dart` and
`test/core/sync/sync_manager_state_store_test.dart` (18 tests including
the race-condition case).

### 9.4 Notification/Profile: upgrade to full sync

These are API-primary today. If either becomes offline-editable (e.g.
mark-as-read working offline), wrap their repo as `SyncableRepository`
and swap `ConnectivityPill` for `SyncStatusPill`.

### 9.5 Chat: replace polling with FCM data messages

The `ChatBloc` still runs a 5-second polling timer that fires
`syncController.requestSyncNow(scope: teamId)`. A better design once FCM
data messages are available: dispatch `ChatRefreshRequested` on the FCM
callback instead. The polling then becomes a fallback for when FCM is
unavailable.

### 9.6 E2E / Patrol tests

The `integration_test/` directory (Patrol) was not touched in the sync
refactor. Someone should run the Patrol suite against a real backend to
verify nothing regressed at the end-to-end level. We skipped this on
purpose in the last session (Patrol is slow to validate).

### 9.7 Backend tests for OAuth2 UserInfo + token transactions

✅ **Shipped.** The `OAuth2ControllerTest` already covers the nested
`user` block on both `/google/callback` and `/accept-invitation`
(`id`, `email`, `firstName`, `lastName`, `role`, `churchId`). A new
integration test `TokenRepositoryTransactionalTest` in
`api/src/test/kotlin/com/worshiphub/api/integration/auth/` exercises
every `@Modifying @Transactional @Query` method on the four
auth-token repositories (`refresh_tokens`, `email_verification_tokens`,
`password_reset_tokens`, `invitation_tokens`) **outside any outer
Spring transaction** and verifies `TokenCleanupJob.cleanup()` can run
from its `@Scheduled` context without a `TransactionRequiredException`.
Pins the fix from commit `a606bd8 fix(jpa): require an active
transaction on token @Modifying queries`.

---

## 10. Architectural history

This section exists so future sessions don't waste time re-evaluating
decisions that were already tried and rejected.

### 10.1 The "cache shows Local when everything is synced" bug

Original rule was `lastSyncAt == null → cached`. That meant on every
app-open the pill showed "Local" despite every row being `isSynced=true`.
**Rejected**: using a sixth phase (`stale`) separate from `cached` — it
adds a colour/label the user has to learn without changing behaviour
(both resolve by syncing). **Accepted**: `null → live`, with a
regression test. Never revert.

### 10.2 Mixins for `SyncableRepository` defaults

Tried `mixin ScopedPullDefaults on SyncableRepository` to provide a
default `pullScopedData` implementation. Dart 3's `with` clause requires
the target class to `extends` a compatible superclass; `implements`
alone isn't enough. We now write the one-liner
`pullScopedData(scope) => pullLatestData()` in every repo explicitly.
Don't try to DRY this again unless Dart grows proper default-method
support on interfaces.

### 10.3 "We don't eagerly fetch on login to avoid hammering the backend"

A previous session had a comment in `main.dart` rationalizing that
post-login fan-out of `Load*` events was bad because it would make N
parallel requests. **That comment contradicted the existence of a
SyncManager with a `_isSyncing` lock** designed for exactly this case.
One coordinated `syncAll()` cycle is strictly better than either N
parallel Load* calls OR no calls at all (which is what the original code
did). Don't reintroduce the "avoid hammering" argument without also
disabling the SyncManager.

### 10.4 Scoped sync signature — `Object scope` vs typed generics

Considered `SyncableRepository<S>` with a typed scope. **Rejected**:
every repo would need to pick a scope type (or `void`), the
`SyncManager` would need `syncRepositoryScoped<S>(Type, S scope)` which
Dart's reified generics make awkward, and the scope is always a
primitive id anyway. `Object scope` with a repo-side cast is the
pragmatic choice.

### 10.5 Re-entrancy guard on `syncAll`

Original code:
```dart
if (_isSyncing) return;
final status = await _connectivityService.checkStatus();
// ... lots more ...
_isSyncing = true;
```
**Bug**: two parallel callers could both pass the guard during each
other's `await checkStatus()`. **Fix**: acquire `_isSyncing = true`
synchronously before any `await`, release in `finally`. Test:
`re-entrancy guard — calls issued DURING an in-flight cycle are
collapsed` in `sync_lifecycle_test.dart`.

### 10.6 Dead widgets deliberately deleted

- `lib/presentation/widgets/sync_status_widget.dart` — never mounted.
- `lib/presentation/widgets/sync_status_indicator.dart` — never mounted.
- `lib/presentation/features/songs/widgets/sync_button.dart` — replaced
  by the shared pill.

If you find yourself resurrecting any of these, you're probably solving
the wrong problem — the shared pill covers every use case.

---

## 11. Session resume cheat-sheet

**You just opened a new session. You've been told "lee el archivo md y
continúa con las mejoras y refactorizaciones".**

### 11.1 Sanity check the environment

```sh
cd D:\Proyectos\WorshipHub\worship_hub_ui
flutter analyze lib test
flutter test
```

Expected: analyze clean, ~746 passed + 11 skipped + 0 failed. If
anything fails, **stop and investigate** before making any change — the
baseline was green at the last commit; a failure means either the
environment is broken or someone else pushed a regression.

### 11.2 Orient yourself

```sh
git log --oneline -10           # inside worship_hub_ui
cd ..\worship_hub_api
git log --oneline -10           # inside worship_hub_api
cd ..
git log --oneline -5             # root monorepo
```

The last frontend commit should be `test: fix drifted tests caused by
sync refactor...` (or later). The last backend commit should be
`chore(build): enable java-library plugin...` (or later). If the history
looks wildly different, the world has moved on; adjust accordingly.

### 11.3 Pick a work item from §9

Each item in §9 is pre-scoped. Recommended order by value:

1. **§9.6** — Patrol E2E against a real backend. Low effort per test
   but catches the integration issues unit tests can't.
2. **§9.5** — FCM-driven chat refresh. Removes the last `Timer.periodic`
   from the BLoC layer.

### 11.4 Before you commit

1. `flutter analyze lib test` — clean.
2. `flutter test` — ≥ 746 passed, 0 failed (skips are OK).
3. Verify your commit compiles **in isolation** by stashing the rest of
   your working tree: `git stash push --keep-index -u && flutter
   analyze lib && git stash pop`. If it doesn't compile standalone, your
   commit is too small — merge it with the next one.
4. Commit messages follow the `<type>(<scope>): <summary>` convention
   used in the recent history; see `git log --oneline -20` for
   examples. Body explains **why**, not what.

### 11.5 What NOT to do

- Do not add a `syncX` method to any repository. Go via `SyncManager`.
- Do not add a `Timer.periodic` that touches the backend. Go via
  `SyncManager.syncRepository` or `syncRepositoryScoped`.
- Do not revive the "avoid hammering the backend on login" argument.
- Do not invert the `null → live` rule in `SyncViewModel.derive`.
- Do not introduce a per-repo TTL (`_isCacheValid` /
  `_lastFetchTime`). The `SyncManager` owns freshness.
- Do not `git commit` inside a submodule without also bumping the
  submodule pointer in the root repo when the change is user-visible.
- Do not skip `flutter test` before committing. Half of the 74 failures
  we had to fix at the end of the last session were introduced because
  someone (me) didn't run the suite after a refactor. Don't be me.

### 11.6 If something is confusing

Re-read sections 1, 2, 10 in that order — section 10 explains the
decisions that are easy to second-guess.
