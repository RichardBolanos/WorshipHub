# E2E Test Suite Status — WorshipHub Flutter UI

**Last Updated:** 2026-05-04 (session 7)
**Branch:** `feat/e2e-automated-tests`

---

## Resumen General

| Suite | Tests | Status | Plataforma |
|-------|-------|--------|------------|
| Suites anteriores (15 archivos) | 87 | ✅ 87/87 (100%) | Chrome |
| Push Notifications (22 archivos) | ~65 | 🔄 4/~65 verificados | Chrome + Android |
| **TOTAL** | **~152** | **91/~152** | |

---

## Suites Anteriores (87/87 ✅ — verificadas sesión 6)

| File | Tests | Status |
|------|-------|--------|
| auth/login_test.dart | 6 | ✅ |
| auth/church_registration_test.dart | 6 | ✅ |
| songs/song_crud_test.dart | 8 | ✅ |
| songs/song_search_filter_test.dart | 4 | ✅ |
| navigation/app_navigation_test.dart | 4 | ✅ |
| notifications/notifications_test.dart | 5 | ✅ |
| categories/category_tag_test.dart | 6 | ✅ |
| profile/profile_password_test.dart | 6 | ✅ |
| teams/team_management_test.dart | 6 | ✅ |
| setlists/setlist_crud_test.dart | 6 | ✅ |
| error_handling/error_states_test.dart | 4 | ✅ |
| auth/invitation_acceptance_test.dart | 7 | ✅ |
| calendar/calendar_availability_test.dart | 7 | ✅ |
| chat/team_chat_test.dart | 4 | ✅ |
| cross_feature/cross_feature_flows_test.dart | 4 | ✅ |

---

## Push Notifications E2E Test Suite (sesión 7)

**Spec:** `.kiro/specs/push-notifications-e2e-tests/`
**Directorio:** `integration_test/tests/push_notifications/`

### Resultados de Ejecución

| # | Archivo | Tests | Chrome | Android | Notas |
|---|---------|-------|--------|---------|-------|
| 1 | `fcm_token_registration_test.dart` | 3 | ✅ 3/3 | ✅ 2/2 | 3ro en Android crashea por bug semantics Flutter 3.35.1 |
| 2 | `notifications_screen_test.dart` | 4 | ⏳ | ✅ 1/4 | Empty state pasa; 3 fallan por sendInvitation 500 |
| 3 | `mark_as_read_test.dart` | 3 | ⏳ | ⏳ | Bloqueado por sendInvitation |
| 4 | `deep_linking_test.dart` | 6 | ⏳ | ⏳ | Bloqueado por sendInvitation |
| 5 | `notification_preferences_test.dart` | 4 | ⏳ | ⏳ | |
| 6 | `chat_polling_test.dart` | 4 | ⏳ | ⏳ | |
| 7 | `in_app_banner_test.dart` | 3 | ⏳ | ⏳ | |
| 8 | `badge_count_test.dart` | 4 | ⏳ | ⏳ | Bloqueado por sendInvitation |
| 9 | `service_assignment_notification_test.dart` | 3 | ⏳ | ⏳ | Bloqueado por sendInvitation |
| 10 | `chat_message_notification_test.dart` | 3 | ⏳ | ⏳ | |
| 11 | `song_comment_notification_test.dart` | 3 | ⏳ | ⏳ | |
| 12 | `team_change_notification_test.dart` | 3 | ⏳ | ⏳ | |
| 13 | `service_cancellation_notification_test.dart` | 3 | ⏳ | ⏳ | |
| 14 | `recurring_service_notification_test.dart` | 3 | ⏳ | ⏳ | |
| 15 | `song_update_notification_test.dart` | 3 | ⏳ | ⏳ | |
| 16 | `invitation_accepted_notification_test.dart` | 2 | ⏳ | ⏳ | |
| 17 | `availability_change_notification_test.dart` | 3 | ⏳ | ⏳ | |
| 18 | `setlist_modification_notification_test.dart` | 3 | ⏳ | ⏳ | |
| 19 | `song_attachment_notification_test.dart` | 3 | ⏳ | ⏳ | |
| 20 | `error_handling_test.dart` | 3 | ⏳ | ⏳ | |
| 21 | `service_reminder_notification_test.dart` | 3 | ⏳ | ⏳ | |
| 22 | `new_song_notification_test.dart` | 3 | ⏳ | ⏳ | |

### 🔴 Bloqueante: Bug sistémico `persist` vs `merge`

**Causa raíz:** Todas las entidades JPA usan `@GeneratedValue(strategy = GenerationType.UUID)` + `val id: UUID = UUID.randomUUID()`. Como el ID nunca es null, `SimpleJpaRepository.save()` llama `merge()` (piensa que es existente) en vez de `persist()` → `StaleObjectStateException`.

**Repositorios corregidos:**
- ✅ `ChurchRepositoryImpl` — usa `EntityManager.persist()` para nuevos
- ✅ `UserRepositoryImpl` — usa `EntityManager.persist()` para nuevos

**Repositorios pendientes (bloquean tests multi-usuario):**
- ❌ Repositorio de Invitation (bloquea `sendInvitation` → bloquea `registerSecondUser`)
- ❌ Todos los demás con entidades UUID pre-generado

**Fix:** Quitar `@GeneratedValue` + usar `EntityManager.persist()` en el `save()` de cada repositorio para entidades nuevas.

---

## Infraestructura de Tests

### Archivos creados (sesión 7)
| Archivo | Descripción |
|---------|-------------|
| `integration_test/mocks/mock_push_notification_service.dart` | Mock FCM: token simulado, flags registro/desregistro, StreamController foreground |
| `integration_test/seed/notification_seed.dart` | Seed helper para notificaciones vía acciones de dominio |
| `integration_test/seed/api_seed_helper.dart` | +7 métodos: `registerSecondUser`, `loginAs`, `createSongComment`, `addTeamMember`, `cancelService`, `updateSong`, `addSongAttachment` |
| `worship_hub_ui/scripts/run_patrol.ps1` | Script helper para ejecutar patrol con PATH y auto-detección de IP |

### Fixes aplicados (sesión 7)
| Archivo | Cambio |
|---------|--------|
| `test_app.dart` | `AppConfig.initialize(envString: 'local', apiHostString: testHost)` + registrar `NotificationsBloc` + `NotificationRepository` |
| `config/test_config.dart` | Soporte `TEST_API_HOST` via `--dart-define` + default `localhost` con `adb reverse` |
| `android/app/build.gradle.kts` | `isCoreLibraryDesugaringEnabled = true` + dependencia `desugar_jdk_libs:2.1.4` |
| `ChurchRepositoryImpl.kt` | `EntityManager.persist()` para entidades nuevas |
| `UserRepositoryImpl.kt` | `EntityManager.persist()` para entidades nuevas |
| `Church.kt` | Quitado `@GeneratedValue(strategy = GenerationType.UUID)` |
| `User.kt` | Quitado `@GeneratedValue(strategy = GenerationType.UUID)` |

---

## Cómo Ejecutar

### Backend
```powershell
cd worship_hub_api
.\worshiphub.bat  # Opción 2: Desarrollo Rápido (H2 en memoria)
```

### Tests en Chrome (primario)
```powershell
cd worship_hub_ui
$env:PATH = "$env:LOCALAPPDATA\Pub\Cache\bin;$env:PATH"
patrol test -t integration_test/tests/push_notifications/fcm_token_registration_test.dart -d chrome
```

### Tests en Android (dispositivo físico)
```powershell
cd worship_hub_ui
$env:PATH = "$env:LOCALAPPDATA\Pub\Cache\bin;$env:PATH"
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
$env:PATH = "$env:ANDROID_HOME\platform-tools;$env:PATH"
adb -s R5GL1466A2H reverse tcp:9090 tcp:9090
patrol test -t integration_test/tests/push_notifications/fcm_token_registration_test.dart -d R5GL1466A2H
```

### Consultar reportes de Playwright
Kiro puede hacer `webFetch` a `http://127.0.0.1:5500/worship_hub_ui/playwright-report/index.html` para diagnosticar fallos en Chrome sin que el usuario pegue logs. Requiere Live Server activo.

---

## Versiones
- Flutter: 3.35.1 | Dart: 3.9.0 | patrol: 4.5.0 | patrol_cli: 4.3.1
- Playwright: chromium v1217 | Backend: Spring Boot 3.5.5 + Kotlin + H2

## Prioridades Próxima Sesión

1. **🔴 Fix `EntityManager.persist()` en todos los repositorios restantes** — Sin esto, todos los tests multi-usuario fallan con 500.
2. **Ejecutar push notifications E2E completos** — 22 archivos en Chrome y Android.
3. **Migrar strings hardcodeados a AppLocalizations** — páginas pendientes.
4. **Commit session 7.**

## Spec Files
- `.kiro/specs/flutter-e2e-ui-tests/` — 16 requirements, design, tasks (completado)
- `.kiro/specs/push-notifications-e2e-tests/` — 23 requirements, design, 29 tasks (completado)

## Git State
- Branch: `feat/e2e-automated-tests`
- worship_hub_ui submodule: múltiples commits ahead of origin/master
- Parent repo: múltiples commits en la branch
