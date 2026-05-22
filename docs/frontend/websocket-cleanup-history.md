# WebSocket cleanup plan

> Owner: TBD · Created: 2026-05-07 · Target: complete on next working session.

## Why

The backend no longer exposes any WebSocket / STOMP endpoint. Real-time
features (chat, notifications) have been migrated to:

- **HTTP polling** for chat (`ChatBloc` already drives polling — see
  `lib/presentation/features/chat/bloc/chat_bloc.dart`).
- **Native push notifications** (FCM/APNs) for everything else
  (`PushNotificationService` registered in DI).

The connection-status indicator in the home AppBar was also rewired
(2026-05-07) to read `ConnectivityService` + `NotificationPermissionService`
instead of `WebSocketService.instance`. With that, **no live code path
depends on WebSocketService anymore**; what remains is dead code that we
want to remove for clarity, smaller binary size, and one less failure mode
during startup.

## Scope

A full inventory was produced on 2026-05-07. Summary below — see the inline
comments in each file before editing for exact line numbers.

### Hard removals (real code paths)

1. **Delete** `lib/core/services/websocket_service.dart` entirely.
2. **`lib/core/dependency_injection/service_locator.dart`**
   - Remove import of `websocket_service.dart`.
   - Remove `sl.registerLazySingleton<WebSocketService>(...)`.
3. **`lib/main.dart`**
   - Remove import of `websocket_service.dart`.
   - Remove the `addPostFrameCallback` block that calls
     `sl<WebSocketService>().connect()` at startup.
4. **`lib/data/repositories/chat_repository_impl.dart`**
   - Drop `WebSocketService` import, field, and constructor param.
   - Remove the `webSocketService.sendChatMessage(...)` call inside
     `sendMessage()`.
   - Remove `connectToTeamChat()` body (was returning a WS stream — dead
     code; no caller remains).
   - Remove `disconnect()` body (no caller remains).
5. **`lib/domain/repositories/chat_repository.dart`**
   - Remove abstract `connectToTeamChat()` and `disconnect()` methods.
6. **`lib/core/config/app_config.dart`**
   - Remove `_devAndroidWsUrl`, `_devWebWsUrl`, `_stagingWsUrl` constants.
   - Remove the `webSocketUrl` getter and any log statements that print it.
7. **`integration_test/test_app.dart`**
   - Drop import of `websocket_service.dart`.
   - Remove `sl.registerSingleton<WebSocketService>(_NoOpWebSocketService())`.
   - Delete the entire `_NoOpWebSocketService` class.
   - Update the `ChatRepositoryImpl(sl(), sl(), sl())` registration to
     drop the third positional arg once the constructor is shortened.
8. **`integration_test/tests/push_notifications/chat_polling_test.dart`**
   - Drop import of `websocket_service.dart`.
   - Delete the entire `patrolTest('WebSocket is not used …')` block
     (it asserts against a no-op service that no longer exists).
9. **`integration_test/config/test_config.dart`**
   - Drop `wsWebUrl`, `wsEmulatorUrl` constants and the `webSocketUrl`
     getter.
10. **`test/bugfix/bug_condition_exploration_test.dart`**
    - Delete the stale "Bug 7: WebSocket no implementa reconexión
      automática" test block (always-failing placeholder).
    - Remove the WS line from the summary `print(...)`.
11. **`test/core/config/app_config_test.dart`** &
    **`test/core/config/app_config_property_test.dart`**
    - Remove every assertion involving `AppConfig.webSocketUrl`.
12. **`pubspec.yaml`**
    - Remove `web_socket_channel: ^3.0.1` and its comment header.
    - Run `flutter pub get`.

### Soft cleanup (comments only)

These references are pure documentation drift and can be reworded or
removed without touching behavior:

- `lib/presentation/features/chat/bloc/chat_bloc.dart` (header doc + the
  `ChatConnectRequested` / `ChatDisconnectRequested` comments).
- `lib/presentation/features/chat/bloc/chat_event.dart` (event doc
  comments mentioning WS migration).
- `integration_test/patrol_base.dart` (comments about WS heartbeats).
- `integration_test/mocks/mock_push_notification_service.dart` (header
  comparing itself to `_NoOpWebSocketService`).
- `integration_test/helpers/wait_helper.dart`,
  `integration_test/helpers/form_helper.dart` (comments about WS
  heartbeats blocking `pumpAndSettle`).
- `test/bugfix/preservation_test.dart` (two doc comments mentioning WS).
- `README.md`, `APK_BUILD.md` (feature lists, environment matrix).

### Files NOT to touch

- `pubspec.lock`: regenerated automatically by `flutter pub get`.
- Transitive deps `stream_channel`, `web_socket`, `shelf_web_socket`:
  pulled by `flutter_test` / `shelf` etc., not by us. Leave alone.
- `android/app/src/main/AndroidManifest.xml` and
  `network_security_config.xml`: nothing WS-specific. The cleartext
  exception is still required by HTTP-polling dev URLs.

## Suggested order (so the project compiles after every step)

1. Update `chat_repository.dart` (interface) and `chat_repository_impl.dart`
   (impl) **together**, then update both DI registrations to drop the
   `sl()` arg (`service_locator.dart` and `integration_test/test_app.dart`).
   Run `flutter analyze`.
2. Delete `websocket_service.dart`, then remove every remaining reference
   in `service_locator.dart`, `main.dart`, and `test_app.dart`. Delete
   `_NoOpWebSocketService` class. Run `flutter analyze`.
3. Clean `app_config.dart` and the two `app_config_*_test.dart` files
   together. Run `flutter test test/core/config`.
4. Clean integration-test scaffolding (`chat_polling_test.dart`,
   `test_config.dart`). Run `flutter analyze integration_test`.
5. Delete the stale "Bug 7" test block in
   `test/bugfix/bug_condition_exploration_test.dart`. Run
   `flutter test test/bugfix`.
6. Drop `web_socket_channel` from `pubspec.yaml`, run `flutter pub get`,
   then `flutter analyze` and `flutter test` for a final sanity check.
7. Soft cleanup of comments and docs in a single follow-up commit.

## Verification checklist

- [ ] `flutter analyze` is green.
- [ ] `flutter test` is green (full unit suite).
- [ ] `grep -ri "websocket\|WebSocket\|web_socket_channel" lib/` returns
      no production matches.
- [ ] `flutter pub deps | grep web_socket_channel` no longer lists us as
      the importer (only transitive).
- [ ] App boots without the previous "WebSocket connect failed
      (non-critical)" warning in logs.
- [ ] Connection-status pill in the home AppBar still shows the right
      state and tapping it still opens the permission/info flows.
