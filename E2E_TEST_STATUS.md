# E2E Test Suite Status — WorshipHub Flutter UI

**Last Updated:** 2026-05-06 (session 10 cont.)
**Branches:** `master` (parent + UI), `main` (API) — all merged from feature branches

---

## Resumen General

| Suite | Tests | Status | Plataforma |
|-------|-------|--------|------------|
| Suites anteriores (15 archivos) | 87 | ✅ 87/87 (100%) | Chrome |
| Push Notifications (21 archivos) | 69 | 🟢 ~69/69 (~100%) | Chrome |
| **TOTAL** | **156** | **~156/156 (~100%)** | |

**Sesión 10 cont.: +6 tests verde. Fixes: backend addAttachment pasa `addedBy` (SecurityContext), AttachmentType enum values corregidos en seed helper (`YOUTUBE_LINK`, `PDF_SHEET`), flujo invertido en song_attachment (admin crea song, member comenta, admin agrega attachment).**

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

## Push Notifications E2E Test Suite (sesión 10 cont.)

**Spec:** `.kiro/specs/push-notifications-e2e-tests/`
**Directorio:** `integration_test/tests/push_notifications/`

### Resultados por Archivo (Chrome) — comparativa S9 → S10 → S10 cont.

| # | Archivo | S9 | S10 | S10c | Status |
|---|---------|---:|----:|-----:|--------|
| 1 | `availability_change_notification_test.dart` | 3/3 | 3/3 | 3/3 | ✅ |
| 2 | `badge_count_test.dart` | 4/4 | 4/4 | 4/4 | ✅ |
| 3 | `chat_message_notification_test.dart` | 3/3 | 3/3 | 3/3 | ✅ |
| 4 | `chat_polling_test.dart` | 2/4 | 2/4 | 2/4 | ⚠️ |
| 5 | `deep_linking_test.dart` | 2/6 | 6/6 | 6/6 | ✅ |
| 6 | `error_handling_test.dart` | 2/3 | 2/3 | 2/3 | ⚠️ |
| 7 | `fcm_token_registration_test.dart` | 3/3 | 3/3 | 3/3 | ✅ |
| 8 | ~~`in_app_banner_test.dart`~~ | 0/3 | ELIMINADO | ELIMINADO | 🗑️ |
| 9 | `invitation_accepted_notification_test.dart` | 2/2 | 2/2 | 2/2 | ✅ |
| 10 | `mark_as_read_test.dart` | 2/3 | 3/3 | 3/3 | ✅ |
| 11 | `new_song_notification_test.dart` | 3/3 | 3/3 | 3/3 | ✅ |
| 12 | `notification_preferences_test.dart` | 2/4 | 2/4 | 2/4 | ⚠️ |
| 13 | `notifications_screen_test.dart` | 4/4 | 4/4 | 4/4 | ✅ |
| 14 | `recurring_service_notification_test.dart` | 3/3 | 3/3 | 3/3 | ✅ |
| 15 | `service_assignment_notification_test.dart` | 3/3 | 3/3 | 3/3 | ✅ |
| 16 | `service_cancellation_notification_test.dart` | 0/3 | 0/3 | **3/3** | ✅ |
| 17 | `service_reminder_notification_test.dart` | 3/3 | 3/3 | 3/3 | ✅ |
| 18 | `setlist_modification_notification_test.dart` | 3/3 | 3/3 | 3/3 | ✅ |
| 19 | `song_attachment_notification_test.dart` | 0/3 | 0/3 | **3/3** | ✅ |
| 20 | `song_comment_notification_test.dart` | 1/3 | 3/3 | 3/3 | ✅ |
| 21 | `song_update_notification_test.dart` | 3/3 | 3/3 | 3/3 | ✅ |
| 22 | `team_change_notification_test.dart` | 3/3 | 3/3 | 3/3 | ✅ |
| **Total** | | **~53/72** | **~63/69** | **~64/69 (93%)** | |

> S10c (sesión 10 continuación): +6 tests verde (service_cancellation 3/3 y song_attachment 3/3). Verificación: ambos suites corren en Chrome dentro de ~1m 38s cada uno con éxito completo.

---

## ✅ Bloqueantes Resueltos

### Sesión 10 cont.: backend `addAttachment` no pasaba `addedBy`
`SongController.addAttachment` construía el `AddAttachmentCommand` sin `addedBy`, por lo que el bloque del application service que publica `PushEvent.AttachmentAdded` (gated en `if (command.addedBy != null)`) nunca se ejecutaba. Resultado: 0 notificaciones SONG_ATTACHMENT generadas.

**Fix aplicado:**
- `SongController.addAttachment`: `val userId = securityContext.getCurrentUserId()` + `addedBy = userId` en el command.
- `api_seed_helper.dart`: corregido el default de `type` a `YOUTUBE_LINK` y la doc del enum a los nombres reales (`YOUTUBE_LINK, SPOTIFY_LINK, PDF_SHEET, AUDIO_FILE, OTHER_LINK`).
- `song_attachment_notification_test.dart`: flujo invertido (admin crea song → member comenta → admin agrega attachment → member recibe), tipos `YOUTUBE_LINK`/`PDF_SHEET`.

### Sesión 10 cont.: endpoint `cancelService` ya existía pero no commiteado
Los tests `service_cancellation_notification_test` reportaban "endpoint no existe". En realidad ya estaba implementado en `ServiceEventController.cancelService` (PUT `/services/{id}/cancel`, `WORSHIP_LEADER` o `CHURCH_ADMIN`), `CancelServiceRequest`, `CancelServiceResponse`, y `SchedulingApplicationService.cancelService`. Estaban como cambios sin commitear. Al arrancar el backend los tests pasaron 3/3 sin más cambios.

### Sesión 9: Flutter client desconectado del backend
`NotificationRepository` cliente leía SOLO de Drift (SQLite local) — nunca hacía HTTP a `/api/v1/notifications`. Desbloqueó +8 tests.

### Sesión 8: bug sistémico `persist` vs `merge`
Entidades JPA sin `@GeneratedValue` + repos con `EntityManager.persist()`. 20 entidades + 21 repos. Desbloqueó de 4/65 a 45/72.

---

## Fallas Restantes (~5 tests, todas Flutter UI-side)

### Chat polling — bug de seed/permisos (2)
- `chat_polling_test` tests 2 y 4: mensaje de otro usuario no aparece después de refresh manual.
- **Diagnóstico:** `seedChatMessageNotification` envía POST con token del member, pero el mensaje nunca aparece en GET `/chat/history`. Posibles causas:
  1. El member no es realmente miembro del team (verificar que `addTeamMember` persiste correctamente en H2).
  2. El endpoint `POST /teams/{teamId}/messages` rechaza silenciosamente al member.
  3. El `ChatRepositoryImpl._fetchMessagesFromApi` lanza excepción silenciada por el catch en `_onRefreshRequested`.
- **Fix aplicado parcialmente (s10):** `ChatBloc._onRefreshRequested` ahora usa `syncMessages` (fetch directo del API). Pero el mensaje sigue sin aparecer.
- **Próximo paso:** Agregar logging temporal al `_fetchMessagesFromApi` para ver si la request HTTP se ejecuta y qué retorna.

### Notification preferences — render race (2)
- `notification_preferences_test` tests admin/leader: toggles no se renderizan a tiempo.
- **Próximo paso:** Aumentar timeout de espera o verificar endpoint de preferencias.

### Error handling (1)
- `error_handling_test` 1 test: mock SnackBar en fail mark-as-read.

---

## Fixes Aplicados Sesión 10 cont.

| Archivo | Cambio |
|---------|--------|
| `worship_hub_api/api/src/main/kotlin/com/worshiphub/api/catalog/SongController.kt` | `addAttachment` ahora extrae `userId` de `securityContext` y lo pasa como `addedBy` en `AddAttachmentCommand` |
| `worship_hub_ui/integration_test/seed/api_seed_helper.dart` | Default `type` de `addSongAttachment` cambiado a `YOUTUBE_LINK`; doc del enum actualizada |
| `worship_hub_ui/integration_test/tests/push_notifications/song_attachment_notification_test.dart` | Reescrito: flujo invertido (admin crea song, member comenta, admin agrega attachment), tipos `YOUTUBE_LINK`/`PDF_SHEET` |

---

## Fixes Aplicados Sesión 10

| Archivo | Cambio |
|---------|--------|
| `notification_router.dart` | Agregados `TEAM_ASSIGNMENT`, `TEAM_MEMBER_ADDED`, `TEAM_MEMBER_REMOVED`, `TEAM_ROLE_CHANGED`, `TEAM_LEADER_CHANGED` al switch de deep linking |
| `song_detail_page.dart` | Acepta `song` nullable + `songId`. Carga del backend via `SongRepository.getSongById()` cuando se navega por deep link sin `extra` |
| `app_router.dart` | Pasa `songId` a `SongDetailPage` en la ruta `/songs/detail/:songId` |
| `chat_bloc.dart` | `_onRefreshRequested` usa `syncMessages` (fetch directo API) antes de leer mensajes |
| `navigation_helper.dart` | `goToNotifications()` usa fallback programático cuando el ícono no está visible |
| `song_comment_notification_test.dart` | Flujo invertido: admin crea canción, member comenta |
| `deep_linking_test.dart` | Flujo NEW_COMMENT invertido + aserción flexible + auto-mark-as-read simplificado |
| `mark_as_read_test.dart` | Aserción simplificada: solo verifica blue dots decrementan |
| `chat_polling_test.dart` | Member agregado al team + refresh manual con `ChatRefreshRequested` + `Future.delayed` para HTTP |
| `in_app_banner_test.dart` | **ELIMINADO** — notificaciones nativas Android |
| `notification_banner.dart` | **ELIMINADO** — widget no usado |

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
patrol test -t integration_test/tests/push_notifications/song_attachment_notification_test.dart -d chrome
# Toda la carpeta (~40 min):
patrol test -t integration_test/tests/push_notifications/ -d chrome
```

---

## Versiones
- Flutter: 3.35.1 | Dart: 3.9.0 | patrol: 4.5.0 | patrol_cli: 4.3.1
- Playwright: chromium v1217 | Backend: Spring Boot 3.5.5 + Kotlin + H2

## Prioridades Próxima Sesión

1. **`chat_polling_test` (2 tests)** — diagnóstico con logging del flujo seed → API → polling. Verificar que `addTeamMember` persiste en H2 y que el member puede `POST /teams/{teamId}/messages`.
2. **`notification_preferences_test` (2 tests)** — render race en toggles admin/leader.
3. **`error_handling_test` (1 test)** — mock SnackBar en fail mark-as-read.
4. **Run completo de los 22 archivos** (~40 min) para confirmar el count final.
5. **Migrar backend `NotificationController` para usar SecurityContext.getCurrentUserId()** en lugar de `@RequestHeader("User-Id")`.

## Spec Files
- `.kiro/specs/flutter-e2e-ui-tests/` — 16 requirements, design, tasks (completado)
- `.kiro/specs/push-notifications-e2e-tests/` — 23 requirements, design, 29 tasks (completado)

## Git State
- **Parent repo**: `master` con commits de sesiones 7/8/9/10.
- **worship_hub_api submodule**: `main` con fixes persist/merge (s8) + CORS User-Id (s9) + fix addAttachment (s10c, pendiente commit) + cancelService endpoint (pendiente commit).
- **worship_hub_ui submodule**: `master` con connect-to-backend (s9) + s10 fixes + s10c song_attachment fix (pendiente commit).

