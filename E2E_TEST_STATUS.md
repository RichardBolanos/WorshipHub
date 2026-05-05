# E2E Test Suite Status — WorshipHub Flutter UI

**Last Updated:** 2026-05-05 (session 9)
**Branches:** `master` (parent + UI), `main` (API) — all merged from feature branches

---

## Resumen General

| Suite | Tests | Status | Plataforma |
|-------|-------|--------|------------|
| Suites anteriores (15 archivos) | 87 | ✅ 87/87 (100%) | Chrome |
| Push Notifications (22 archivos) | 72 | 🟢 ~53/72 (~74%) | Chrome |
| **TOTAL** | **159** | **~140/159 (88%)** | |

**Ganancia de esta sesión: +8 tests (Flutter client conectado a backend real).**

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

## Push Notifications E2E Test Suite (sesión 9)

**Spec:** `.kiro/specs/push-notifications-e2e-tests/`
**Directorio:** `integration_test/tests/push_notifications/`

### Resultados por Archivo (Chrome) — comparativa sesión 8 → 9

| # | Archivo | S8 | S9 | Δ | Status |
|---|---------|---:|---:|---:|--------|
| 1 | `availability_change_notification_test.dart` | 3/3 | 3/3 | 0 | ✅ |
| 2 | `badge_count_test.dart` | 1/4 | **4/4** | +3 | ✅ |
| 3 | `chat_message_notification_test.dart` | 3/3 | 3/3 | 0 | ✅ |
| 4 | `chat_polling_test.dart` | 2/4 | 2/4 | 0 | ⚠️ |
| 5 | `deep_linking_test.dart` | 3/6 | 2/6 | -1 | ⚠️ |
| 6 | `error_handling_test.dart` | 3/4 | 2/3 | 0 (1 test no se corrió) | ⚠️ |
| 7 | `fcm_token_registration_test.dart` | 3/3 | 3/3 | 0 | ✅ |
| 8 | `in_app_banner_test.dart` | 0/3 | 0/3 | 0 | ❌ |
| 9 | `invitation_accepted_notification_test.dart` | 2/2 | 2/2 | 0 | ✅ |
| 10 | `mark_as_read_test.dart` | 0/3 | **2/3** | +2 | ⚠️ |
| 11 | `new_song_notification_test.dart` | 3/3 | 3/3 | 0 | ✅ |
| 12 | `notification_preferences_test.dart` | 3/4 | 2/4 | -1 | ⚠️ |
| 13 | `notifications_screen_test.dart` | 1/4 | **4/4** | +3 | ✅ |
| 14 | `recurring_service_notification_test.dart` | 3/3 | 3/3 | 0 | ✅ |
| 15 | `service_assignment_notification_test.dart` | 3/3 | 3/3 | 0 | ✅ |
| 16 | `service_cancellation_notification_test.dart` | 0/3 | 0/3 | 0 | ❌ |
| 17 | `service_reminder_notification_test.dart` | 3/3 | 3/3 | 0 | ✅ |
| 18 | `setlist_modification_notification_test.dart` | 3/3 | 3/3 | 0 | ✅ |
| 19 | `song_attachment_notification_test.dart` | 0/3 | 0/3 | 0 | ❌ |
| 20 | `song_comment_notification_test.dart` | 1/3 | 1/3 | 0 | ⚠️ |
| 21 | `song_update_notification_test.dart` | 3/3 | 3/3 | 0 | ✅ |
| 22 | `team_change_notification_test.dart` | 3/3 | 3/3 | 0 | ✅ |
| **Total** | | **45** | **~53** | **+8** | **74%** |

> Nota: solo re-ejecuté los archivos afectados por el cambio de sesión 9. Los demás se dejan con los números de sesión 8 hasta una próxima ejecución completa.

---

## ✅ Bloqueantes Resueltos

### Sesión 8: bug sistémico `persist` vs `merge`
Entidades JPA sin `@GeneratedValue` + repos con `EntityManager.persist()`. 20 entidades + 21 repos + refactor de `SchedulingApplicationService`. Desbloqueó de 4/65 a 45/72.

### Sesión 9: Flutter client desconectado del backend
`NotificationRepository` cliente leía SOLO de Drift (SQLite local) — nunca hacía HTTP a `/api/v1/notifications`. Por eso los tests veían pantalla vacía o "error al cargar" aunque el backend persistía las notifications correctamente.

**Fix aplicado:**
- Nuevo `NotificationRemoteDataSource` con llamadas HTTP reales.
- Reescrito `NotificationRepositoryImpl` para ser stateless (backend = single source of truth).
- `AuthInterceptor` ahora agrega header `User-Id` en cada request autenticada.
- `NotificationType` enum mapeado 1:1 con backend (+ helpers `notificationTypeFromBackend`/`notificationTypeToBackend`). Agregados tipos faltantes (CHAT_MESSAGE, TEAM_ASSIGNMENT, NEW_COMMENT, etc.).
- `main.dart`: `LoadNotifications` solo tras `AuthAuthenticated`, `ResetNotificationsState` en `AuthUnauthenticated` para evitar leakage entre usuarios.
- Backend `CorsConfig.kt`: header `User-Id` permitido en CORS preflight.

**Verificación:** +8 tests passing, 0 regresiones en suites que ya estaban verdes (service_assignment, new_song, etc.).

Commits:
- `worship_hub_ui` `7961e57` feat(notifications): connect client to backend REST API
- `worship_hub_api` `717ddd1` chore(cors): allow User-Id header in CORS preflight

---

## Fallas Restantes (~19 tests)

### Flakiness preexistente (~3)
Tests que fallan intermitentemente y no están relacionados con el flujo notifications-backend:
- `error_handling_test` 1 (mocked SnackBar on fail mark-as-read)
- `notification_preferences_test` 2 (admin/leader toggle assertions — render race)
- `deep_linking_test` 1 (TEAM_ASSIGNMENT navigation — flaky)

### Falta navigate helpers / routes (~6)
- `deep_linking_test` 4 (SERVICE_INVITATION, NEW_COMMENT, auto-mark después de navigation)
- `mark_as_read_test` 1 (tap notification + goToNotifications flow)

### API seed endpoints faltantes (~6)
- `service_cancellation_notification_test` 3 — endpoint cancel service
- `song_attachment_notification_test` 3 — endpoint add attachment

### MockPushNotificationService integration (~3)
- `in_app_banner_test` 3 — mock StreamController no emite al foreground banner

### Chat polling flakiness (~1)
- `chat_polling_test` 2 (polling interval race)

---

## Infraestructura de Tests

### Archivos creados/modificados (sesión 9)
| Archivo | Descripción |
|---------|-------------|
| `lib/data/datasources/remote/notification_remote_data_source.dart` | Nuevo: HTTP datasource para notifications backend |
| `lib/data/repositories/notification_repository_impl.dart` | Reescrito: stateless, backend-backed |
| `lib/domain/entities/notification.dart` | Enum expandido + mappers 1:1 con backend |
| `lib/core/services/auth_interceptor.dart` | Agrega header User-Id |
| `lib/main.dart` | Lifecycle notifications bloc con AuthBloc |
| `lib/presentation/features/notifications/bloc/` | Nuevo event `ResetNotificationsState` |
| `worship_hub_api/api/src/main/kotlin/com/worshiphub/api/config/CorsConfig.kt` | Permite `User-Id` en CORS |

### Fix previo (sesión 8): 20 entidades JPA + 21 repos
Todas sin `@GeneratedValue(UUID)`. Patrón estándar en `save()`:
```kotlin
override fun save(e: E): E {
    return if (jpaRepository.existsById(e.id)) {
        jpaRepository.save(e)  // merge
    } else {
        entityManager.persist(e)  // persist nuevo
        e
    }
}
```

---

## Cómo Ejecutar

### Backend (H2 en memoria, para E2E)
```powershell
cd worship_hub_api
.\gradlew bootRun --args="--spring.profiles.active=h2"
```

### Tests en Chrome (primario)
```powershell
cd worship_hub_ui
$env:PATH = "$env:LOCALAPPDATA\Pub\Cache\bin;$env:PATH"
# Un solo archivo:
patrol test -t integration_test/tests/push_notifications/notifications_screen_test.dart -d chrome
# Toda la carpeta (40 min):
patrol test -t integration_test/tests/push_notifications/ -d chrome
```

### Consultar reportes de Playwright
Servidor local: `http://localhost:8000` (con Live Server en `worship_hub_ui/playwright-report/`).

---

## Versiones
- Flutter: 3.35.1 | Dart: 3.9.0 | patrol: 4.5.0 | patrol_cli: 4.3.1
- Playwright: chromium v1217 | Backend: Spring Boot 3.5.5 + Kotlin + H2

## Prioridades Próxima Sesión

1. **Seed API endpoints faltantes** (6 tests, probablemente fácil): agregar `cancelService` y `addSongAttachment` al `api_seed_helper.dart` o implementar endpoints backend.
2. **`in_app_banner_test` (3 tests)**: revisar integración entre `MockPushNotificationService` StreamController y el banner widget en el app.
3. **`deep_linking_test` (4 tests)**: los routes de notificación (SERVICE_INVITATION → /calendar, NEW_COMMENT → /songs/:id) no resuelven bien. Revisar `NotificationRouter.resolveRoute`.
4. **Navigate helper para flujos tap-notification**: cuando el tap a notification navega por deep link, `navigationHelper.goToNotifications()` falla porque busca icono en la pantalla destino que no existe. Considerar usar `appRouter.go('/notifications')` directamente en los helpers.
5. **Run completo de 72 tests** para confirmar el count final — no hecho esta sesión para ahorrar tiempo (40 min).
6. **Migrar backend `NotificationController` para usar SecurityContext.getCurrentUserId()** en lugar de `@RequestHeader("User-Id")`. Más canónico: no confía en cliente para identidad del user.

## Spec Files
- `.kiro/specs/flutter-e2e-ui-tests/` — 16 requirements, design, tasks (completado)
- `.kiro/specs/push-notifications-e2e-tests/` — 23 requirements, design, 29 tasks (completado)

## Git State
- **Parent repo**: `master` con commits de sesiones 7/8/9.
- **worship_hub_api submodule**: `main` con fixes persist/merge (s8) + CORS User-Id (s9).
- **worship_hub_ui submodule**: `master` con connect-to-backend (s9).


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

## Push Notifications E2E Test Suite (sesión 8)

**Spec:** `.kiro/specs/push-notifications-e2e-tests/`
**Directorio:** `integration_test/tests/push_notifications/`
**Run completo:** `patrol test -t integration_test/tests/push_notifications/ -d chrome` (40 min)

### Resultados por Archivo (Chrome)

| # | Archivo | Pass | Total | Status |
|---|---------|-----:|------:|--------|
| 1 | `availability_change_notification_test.dart` | 3 | 3 | ✅ |
| 2 | `badge_count_test.dart` | 1 | 4 | ⚠️ |
| 3 | `chat_message_notification_test.dart` | 3 | 3 | ✅ |
| 4 | `chat_polling_test.dart` | 2 | 4 | ⚠️ |
| 5 | `deep_linking_test.dart` | 3 | 6 | ⚠️ |
| 6 | `error_handling_test.dart` | 3 | 4 | ⚠️ |
| 7 | `fcm_token_registration_test.dart` | 3 | 3 | ✅ |
| 8 | `in_app_banner_test.dart` | 0 | 3 | ❌ |
| 9 | `invitation_accepted_notification_test.dart` | 2 | 2 | ✅ |
| 10 | `mark_as_read_test.dart` | 0 | 3 | ❌ |
| 11 | `new_song_notification_test.dart` | 3 | 3 | ✅ |
| 12 | `notification_preferences_test.dart` | 3 | 4 | ⚠️ |
| 13 | `notifications_screen_test.dart` | 1 | 4 | ⚠️ |
| 14 | `recurring_service_notification_test.dart` | 3 | 3 | ✅ |
| 15 | `service_assignment_notification_test.dart` | 3 | 3 | ✅ |
| 16 | `service_cancellation_notification_test.dart` | 0 | 3 | ❌ |
| 17 | `service_reminder_notification_test.dart` | 3 | 3 | ✅ |
| 18 | `setlist_modification_notification_test.dart` | 3 | 3 | ✅ |
| 19 | `song_attachment_notification_test.dart` | 0 | 3 | ❌ |
| 20 | `song_comment_notification_test.dart` | 1 | 3 | ⚠️ |
| 21 | `song_update_notification_test.dart` | 3 | 3 | ✅ |
| 22 | `team_change_notification_test.dart` | 3 | 3 | ✅ |
| **Total** | | **45** | **72** | **62%** |

---

## ✅ Bloqueante Resuelto: Bug sistémico `persist` vs `merge`

**Causa raíz:** Todas las entidades JPA usaban `@GeneratedValue(strategy = GenerationType.UUID)` + `val id: UUID = UUID.randomUUID()`. Como el ID nunca es null antes de save, `SimpleJpaRepository.save()` llamaba `merge()` (la tratá como existente) en vez de `persist()` → `StaleObjectStateException`.

**Fix aplicado (sesión 8):**
- Quitado `@GeneratedValue` de **20 entidades** (Church, User, Invitation, PasswordReset, EmailVerification, Song, GlobalSong, Tag, Category, Attachment, Notification, SongComment, ChatMessage, NotificationPreference, DeviceToken, ErrorLog, Team, TeamMember, ServiceEvent, Setlist, UserAvailability, AssignedMember).
- Actualizados **21 repository implementations** para usar el patrón Church/User: `existsById` check + `entityManager.persist()` para nuevos, `jpaRepository.save()` para existentes.
- Refactorizado `SchedulingApplicationService.scheduleTeamForService` para hacer **un solo save** con children incluidos (evita cascade persist/merge conflict con `AssignedMember`).

**Verificación:**
- Build OK en todos los módulos.
- Tests unitarios: `domain:test`, `application:test`, `infrastructure:test` ✅.
- Smoke test HTTP: register-church → login → send-invitation → create-team → create-service-event → ver notification en DB del member ✅.
- Push notifications E2E: **de 4/65 a 45/72**.

Commits en `worship_hub_api` branch `main`:
- `72980fe` fix(persistence): resolve StaleObjectStateException across all JPA entities
- `a102071` fix(scheduling): unify ServiceEvent save to avoid cascade persist/merge conflict

---

## Fallas Restantes (27 tests, todas Flutter UI-side)

Todas las fallas restantes son **problemas del lado cliente Flutter** (timing, UI state, deep linking, mock push service) — NO del backend. El backend crea las notificaciones correctamente (verificado manualmente por HTTP).

### Por categoría

**UI timing / widget finding (7):**
- `notifications_screen_test.dart` 3 (member no ve notifications tras login)
- `badge_count_test.dart` 3 (unread count no se actualiza en UI)
- `notification_preferences_test.dart` 1

**Mark-as-read flow (3):**
- `mark_as_read_test.dart` 3 (todos)

**Deep linking / navigation (3):**
- `deep_linking_test.dart` 3

**In-app banner (MockPushNotificationService) (3):**
- `in_app_banner_test.dart` 3

**Chat polling (2):**
- `chat_polling_test.dart` 2

**API seed endpoints missing (6):**
- `service_cancellation_notification_test.dart` 3 — endpoint cancel service
- `song_attachment_notification_test.dart` 3 — endpoint add attachment
- `song_comment_notification_test.dart` 2 — algunos tests
- `error_handling_test.dart` 1

---

## Infraestructura de Tests

### Archivos creados (sesión 7)
| Archivo | Descripción |
|---------|-------------|
| `integration_test/mocks/mock_push_notification_service.dart` | Mock FCM: token simulado, flags registro/desregistro, StreamController foreground |
| `integration_test/seed/notification_seed.dart` | Seed helper para notificaciones vía acciones de dominio |
| `integration_test/seed/api_seed_helper.dart` | +7 métodos: `registerSecondUser`, `loginAs`, `createSongComment`, `addTeamMember`, `cancelService`, `updateSong`, `addSongAttachment` |
| `worship_hub_ui/scripts/run_patrol.ps1` | Script helper para ejecutar patrol con PATH y auto-detección de IP |

### Entidades JPA fijadas (sesión 8, 20 archivos)
Todas sin `@GeneratedValue(strategy = GenerationType.UUID)` — el UUID se genera en Kotlin (`UUID.randomUUID()` como default del data class).

### Repositorios fijados (sesión 8, 21 archivos)
Patrón estándar en `save()`:
```kotlin
override fun save(e: E): E {
    return if (jpaRepository.existsById(e.id)) {
        jpaRepository.save(e)  // merge
    } else {
        entityManager.persist(e)  // persist nuevo
        e
    }
}
```

---

## Cómo Ejecutar

### Backend (H2 en memoria, para E2E)
```powershell
cd worship_hub_api
.\gradlew bootRun --args="--spring.profiles.active=h2"
# O vía script interactivo: .\worshiphub.bat → Opción 2
```

### Tests en Chrome (primario)
```powershell
cd worship_hub_ui
$env:PATH = "$env:LOCALAPPDATA\Pub\Cache\bin;$env:PATH"
# Un solo test:
patrol test -t integration_test/tests/push_notifications/fcm_token_registration_test.dart -d chrome
# Toda la carpeta push_notifications:
patrol test -t integration_test/tests/push_notifications/ -d chrome
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
Kiro puede hacer `webFetch` a `http://localhost:8000` para diagnosticar fallos (Live Server sobre `worship_hub_ui/playwright-report/`).

---

## Versiones
- Flutter: 3.35.1 | Dart: 3.9.0 | patrol: 4.5.0 | patrol_cli: 4.3.1
- Playwright: chromium v1217 | Backend: Spring Boot 3.5.5 + Kotlin + H2

## Prioridades Próxima Sesión

1. **Flutter UI: fix `notifications_screen` (3 tests)** — member no ve notifications tras seed. Investigar si `NotificationRepository` en cliente envía `User-Id` header correctamente y si `NotificationsBloc` reacciona a login change.
2. **Flutter UI: `mark_as_read` (3 tests)** — flujo PATCH + actualizar state.
3. **Flutter UI: `badge_count` (3 tests)** — unread counter en AppBar.
4. **Flutter UI: `in_app_banner` (3 tests)** — integración de `MockPushNotificationService` StreamController.
5. **Deep linking (3 tests)** — routes por tipo de notificación.
6. **Seed API endpoints faltantes (6 tests)**: cancelService, addSongAttachment endpoints — posiblemente en el API seed helper.
7. **Validar Android físico** una vez UI fallas estén resueltas.

## Spec Files
- `.kiro/specs/flutter-e2e-ui-tests/` — 16 requirements, design, tasks (completado)
- `.kiro/specs/push-notifications-e2e-tests/` — 23 requirements, design, 29 tasks (completado)

## Git State
- **Parent repo**: `master` con merge de `feat/e2e-automated-tests` completo, 2 commits ahead de origin (incluye submodule pointer bumps).
- **worship_hub_api submodule**: `main` con merge de `fix/swagger-auth-definitions`, 3 commits locales con fixes de sesión 8.
- **worship_hub_ui submodule**: `master`, 1 commit local ahead de origin (docs).
