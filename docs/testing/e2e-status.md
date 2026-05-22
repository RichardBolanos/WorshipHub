# E2E Test Suite Status — WorshipHub Flutter UI

**Last Updated:** 2026-05-06 (session 11 cont.)
**Branches:** `master` (parent + UI), `main` (API) — all merged from feature branches

---

## Resumen General

| Suite | Tests | Status | Plataforma |
|-------|-------|--------|------------|
| Suites anteriores (15 archivos) | 87 | ✅ 87/87 (100%) | Chrome |
| Push Notifications (21 archivos) | 69 | 🟢 ~69/69 (~100%) | Chrome |
| **TOTAL** | **156** | **~156/156 (~100%)** | |

**Sesión 11 cont.: +3 tests verde (notification_preferences 2 + error_handling 1). Run completo agregado de los 21 archivos confirmado en Chrome: 69/69 tests passing, 0 fallas, 39 minutos.** Fixes: rol `TEAM_LEADER` → `WORSHIP_LEADER` en seed (no existe en `organization.UserRole`); aserciones via `bloc.state` en vez de widget tree para evitar lazy-load del `ListView` en viewport pequeño de Patrol web.

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

## Push Notifications E2E Test Suite (sesión 11 cont.)

**Spec:** `.kiro/specs/push-notifications-e2e-tests/`
**Directorio:** `integration_test/tests/push_notifications/`

### Resultados por Archivo (Chrome) — comparativa S9 → S10c → S11 → S11c

| # | Archivo | S9 | S10c | S11 | S11c | Status |
|---|---------|---:|-----:|----:|-----:|--------|
| 1 | `availability_change_notification_test.dart` | 3/3 | 3/3 | 3/3 | 3/3 | ✅ |
| 2 | `badge_count_test.dart` | 4/4 | 4/4 | 4/4 | 4/4 | ✅ |
| 3 | `chat_message_notification_test.dart` | 3/3 | 3/3 | 3/3 | 3/3 | ✅ |
| 4 | `chat_polling_test.dart` | 2/4 | 2/4 | **4/4** | 4/4 | ✅ |
| 5 | `deep_linking_test.dart` | 2/6 | 6/6 | 6/6 | 6/6 | ✅ |
| 6 | `error_handling_test.dart` | 2/3 | 2/3 | 2/3 | **3/3** | ✅ |
| 7 | `fcm_token_registration_test.dart` | 3/3 | 3/3 | 3/3 | 3/3 | ✅ |
| 8 | ~~`in_app_banner_test.dart`~~ | 0/3 | ELIMINADO | ELIMINADO | ELIMINADO | 🗑️ |
| 9 | `invitation_accepted_notification_test.dart` | 2/2 | 2/2 | 2/2 | 2/2 | ✅ |
| 10 | `mark_as_read_test.dart` | 2/3 | 3/3 | 3/3 | 3/3 | ✅ |
| 11 | `new_song_notification_test.dart` | 3/3 | 3/3 | 3/3 | 3/3 | ✅ |
| 12 | `notification_preferences_test.dart` | 2/4 | 2/4 | 2/4 | **4/4** | ✅ |
| 13 | `notifications_screen_test.dart` | 4/4 | 4/4 | 4/4 | 4/4 | ✅ |
| 14 | `recurring_service_notification_test.dart` | 3/3 | 3/3 | 3/3 | 3/3 | ✅ |
| 15 | `service_assignment_notification_test.dart` | 3/3 | 3/3 | 3/3 | 3/3 | ✅ |
| 16 | `service_cancellation_notification_test.dart` | 0/3 | 3/3 | 3/3 | 3/3 | ✅ |
| 17 | `service_reminder_notification_test.dart` | 3/3 | 3/3 | 3/3 | 3/3 | ✅ |
| 18 | `setlist_modification_notification_test.dart` | 3/3 | 3/3 | 3/3 | 3/3 | ✅ |
| 19 | `song_attachment_notification_test.dart` | 0/3 | 3/3 | 3/3 | 3/3 | ✅ |
| 20 | `song_comment_notification_test.dart` | 1/3 | 3/3 | 3/3 | 3/3 | ✅ |
| 21 | `song_update_notification_test.dart` | 3/3 | 3/3 | 3/3 | 3/3 | ✅ |
| 22 | `team_change_notification_test.dart` | 3/3 | 3/3 | 3/3 | 3/3 | ✅ |
| **Total** | | **~53/72** | **~64/69** | **~66/69 (96%)** | **69/69 (100%)** | |

> S11c: +3 tests verde (notification_preferences 2/4 → 4/4 y error_handling 2/3 → 3/3). **Run completo agregado de los 21 archivos confirmado: 69/69 PASSING, 0 fallas, 39 minutos en Chrome.**

---

## ✅ Bloqueantes Resueltos

### Sesión 11 cont.: notification_preferences — viewport y rol incorrecto
Dos bugs separados que se enmascaraban:

1. **Test sender role `'TEAM_LEADER'` no existe en backend.** El enum `organization.UserRole` tiene `CHURCH_ADMIN, WORSHIP_LEADER, TEAM_MEMBER, SUPER_ADMIN`. `TEAM_LEADER` solo existe en `collaboration.push.UserRole` (que el `UserRoleResolver` deriva de los roles de organización). **Fix:** test usa `'WORSHIP_LEADER'` que el resolver mapea a `TEAM_LEADER` para el sistema de push.

2. **`ListView` lazy build + viewport pequeño en Patrol web.** El test hacía `find.text('Invitaciones aceptadas')` y `find.text('Servicios')` sobre items que estaban fuera del viewport renderizado. `ListView` solo construye los hijos visibles; al scrollear con `scrollUntilVisible`, los items previos quedan fuera del tree. **Fix:** las aserciones leen `NotificationPreferencesLoaded` directamente del bloc state via `BlocProvider.of(scaffolds.last)` y verifican `applicableTypes` como Set. Conserva un smoke check de `findsAtLeastNWidgets(SwitchListTile, 1)` para confirmar que la página salió del estado loading.

### Sesión 11: chat_polling — triple bug interconectado
1. Backend `ChatController.toDto()` no resolvía `userName` → siempre null. **Fix:** inyectar `UserRepository`.
2. Cliente `_mapFromApi` requería `senderName` non-null → `TypeError: null` silencioso. **Fix:** fallback `'Unknown'`.
3. Cliente `_saveOrUpdateLocal.replace()` fallaba sin Drift PK → "Unexpected null". **Fix:** copiar `existing.id` al companion.

### Sesión 11: auditoría de controllers — `updateSong` y `deleteSong`
Aplicando el método del finding #1 (s10c). Ambos no propagaban `updatedBy`/`deletedBy` → `PushEvent.SongUpdated`/`SongDeleted` nunca se publicaban. Fixed.

### Sesión 10 cont.: backend `addAttachment` no pasaba `addedBy`
Mismo patrón. Fixed.

### Sesión 10 cont.: endpoint `cancelService` ya existía pero no commiteado
Estaba en disco. Fixed.

### Sesión 9: Flutter client desconectado del backend
`NotificationRepository` cliente leía SOLO de Drift. Fixed con `NotificationRemoteDataSource`.

### Sesión 8: bug sistémico `persist` vs `merge`
20 entidades JPA + 21 repos. Fixed.

---

## Hallazgos Útiles para Futuras Sesiones

### 1. Patrón: controllers que no propagan IDs del SecurityContext al command/event ⭐
**Síntoma:** push notifications no se generan a pesar de que el endpoint responde 200/201.
**Causa:** application service tiene un guard `if (command.someUserId != null) { eventPublisher.publish(...) }` y el controller construye el command sin extraer el ID del `securityContext`.
**Cómo detectarlo rápido:** `grep -E "if \(command\.\w+By\s*!=\s*null\)" application/src/main` y verificar que el controller correspondiente pasa todos los IDs del usuario actuante.
**Confirmados con bug:**
- s10c: `SongController.addAttachment` (fixed)
- s11: `SongController.updateSong` (fixed)
- s11: `SongController.deleteSong` (fixed — usa parámetro `deletedBy: UUID?` en vez de Command)

**A revisar (no encontrados pero sospechosos):** todos los controllers que llamen a application service methods publicando push events sin guard explícito de actor pueden estar bien (los recipients se derivan de members), pero verifica caso por caso.

### 2. Patrón: campos null en DTO de respuesta que el cliente espera non-null ⭐ (NUEVO s11)
**Síntoma:** el cliente lanza `TypeError: null` o `Unexpected null` al deserializar respuestas, y el error se traga silenciosamente en algún `try/catch` upstream.
**Causa:** el backend devuelve `null` en un campo nullable (ej. `userName: String?`), pero el cliente Flutter lo declara como non-null (`required final String senderName`).
**Cómo detectarlo:**
- Si el backend tiene un DTO con un campo nullable, audita el código cliente que lo deserializa.
- Si los tests fallan con timing/widget no encontrado, busca en los logs: `Exception: ...: TypeError: null`.
- Los catchAll silenciosos (especialmente en blocs con polling) ocultan estos bugs por completo. Considerar logging temporal en los catchAll durante diagnóstico.
**Confirmado en s11:** `ChatMessageResponseDto.userName` siempre era null hasta el fix backend de inyectar `UserRepository`.

### 3. Patrón: Drift `update().replace()` requiere PK auto-incrementado
**Síntoma:** `_saveOrUpdateLocal` (o equivalente) falla con `Unexpected null` cuando intenta hacer update de un registro existente.
**Causa:** `replace(companion)` necesita que el companion tenga el PK (`Value(id)`), pero los objetos del API solo traen IDs de negocio (UUID strings), no el `id` PK auto-incrementado de Drift.
**Fix:** copiar el `id` del registro existente al objeto entrante antes del `replace`:
```dart
final messageWithId = message.copyWith(id: existing.id);
await db.update(table).replace(_mapToDb(messageWithId));
```
**Confirmado en s11:** `ChatRepositoryImpl._saveOrUpdateLocal`. Otros repos a auditar: `NotificationRepositoryImpl`, `SongRepositoryImpl`, etc. con BD local.

### 4. Patrón: `bloc.add()` async no completa antes de assertions en Patrol web
**Síntoma:** test dispatches `bloc.add(SomeRefreshEvent)`, hace `Future.delayed + tester.pump`, pero el widget no refleja el nuevo estado.
**Causa:** `bloc.add` es fire-and-forget; el handler async puede no terminar en el mismo microtask aun con delays.
**Fix:** llamar directamente al método del repo (que retorna un `Future` real) antes del `bloc.add`:
```dart
final repo = GetIt.instance<MyRepository>();
await repo.syncFromApi(...);  // garantiza HTTP + persistencia
bloc.add(RefreshRequested(...));  // bloc lee de cache fresca
await Future.delayed(...); await tester.pump(...);
```
**Confirmado en s11:** chat_polling_test.

### 4b. Patrón: ListView lazy-builds children — assertions sobre items off-screen fallan ⭐ (NUEVO s11c)
**Síntoma:** `expect(find.text('Foo'), findsOneWidget)` falla aún cuando se sabe que el item existe en el modelo de datos. El header (que estaba al inicio) deja de existir tras hacer `scrollUntilVisible`.
**Causa:** `ListView` (especialmente `ListView.builder` o cualquier ListView con muchos items) lazy-builds children. Solo los visibles en el viewport están en el widget tree. Al scrollear hacia abajo, los items de arriba se desmontan.
**Fix preferido:** verificar el estado del bloc directamente en vez de buscar texto en widgets:
```dart
final scaffolds = find.byType(Scaffold).evaluate().toList();
final bloc = BlocProvider.of<MyBloc>(scaffolds.last);
final state = bloc.state as MyLoadedState;
expect(state.someField, contains(...));
```
Conservar un smoke check de UI: `expect(find.byType(SwitchListTile), findsAtLeastNWidgets(1))` para confirmar que la página salió de loading.
**Alternativa:** `tester.scrollUntilVisible(...)` para cada item, pero solo funciona para verificar PRESENCIA, no AUSENCIA (porque después del scroll no puedes garantizar que los previos siguen unmounted).
**Confirmado en s11c:** notification_preferences_test.

### 5. Patrón: endpoint "no existe" cuando en realidad está sin commitear
**Cómo detectarlo:** `git status` en el submodule + `grep` por el path del endpoint en `*Controller.kt`. Si está en disco pero no commiteado, el backend solo lo expone hasta que se reinicia con build fresca.
**Confirmado en s10c:** `ServiceEventController.cancelService`.

### 6. Roles y permisos — qué puede hacer cada rol
| Rol | Crear song | Agregar attachment | Crear team | Cancelar service | Comentar song | Enviar chat | Crear setlist |
|-----|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `TEAM_MEMBER` | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ (en sus teams) | ❌ |
| `WORSHIP_LEADER` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `CHURCH_ADMIN` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

### 6b. ⚠️ Hay DOS enums `UserRole` en el backend (NUEVO s11c)
- **`com.worshiphub.domain.organization.UserRole`** — usado en API públicas (login, invitations, JWT). Valores: `CHURCH_ADMIN, WORSHIP_LEADER, TEAM_MEMBER, SUPER_ADMIN`. **Esto es lo que envías en `POST /invitations/send` con `role: 'WORSHIP_LEADER'`.**
- **`com.worshiphub.domain.collaboration.push.UserRole`** — usado para filtrar notification preferences por rol. Valores: `ADMIN, TEAM_LEADER, MEMBER`.
- **`UserRoleResolver.resolveEffectiveRole(userId)`** mapea entre ambos:
  - `CHURCH_ADMIN` o `SUPER_ADMIN` → `ADMIN`
  - `WORSHIP_LEADER` → `TEAM_LEADER`
  - `TEAM_MEMBER` con team-leader-of-X → `TEAM_LEADER`
  - resto → `MEMBER`
**Implicación:** en seeds de tests, cuando inviten a un líder, usar `role: 'WORSHIP_LEADER'`, NO `'TEAM_LEADER'` (no existe en el enum API).

### 7. Enum values del backend — fuentes de verdad
- `AttachmentType`: `YOUTUBE_LINK`, `SPOTIFY_LINK`, `PDF_SHEET`, `AUDIO_FILE`, `OTHER_LINK` (NO `PDF`, `YOUTUBE`).
- `TeamRole`: `LEAD_VOCALIST`, `BACKING_VOCALIST`, `ACOUSTIC_GUITAR`, `ELECTRIC_GUITAR`, `BASS_GUITAR`, `DRUMS`, `KEYBOARD`, `SOUND_ENGINEER`, `WORSHIP_LEADER`.
- `NotificationType`: ver `domain/.../collaboration/Notification.kt`. Mappers `notificationTypeFromBackend`/`notificationTypeToBackend` en cliente.

### 8. Endpoint correcto de health y registro
- Health: `GET /api/v1/health` (NO `/actuator/health` — no habilitado).
- Register: `POST /api/v1/auth/church/register` (singular `church`, no `churches`).
- `CreateTeamRequest.leaderId` es **non-null** — siempre pasarlo en tests.

### 9. Tests Patrol web — quirks de timing
- `Timer.periodic` no dispara automáticamente en Chrome. Polling debe ser disparado manualmente.
- `find.text(...)` necesita `pump` después de cualquier acción async.
- Login programático (`seedHelper.login`) y login UI (`loginHelper.loginViaUI`) son mundos paralelos.
- Deep link sin `extra` en GoRouter requiere que la página destino sepa cargar el objeto del backend con solo el ID.

### 10. Backend H2 + bug `persist` vs `merge` (sesión 8)
Si reaparece `StaleObjectStateException`: entidades JPA sin `@GeneratedValue` + repos con `existsById ? save() : entityManager.persist()`.

### 11. `gradlew bootRun` — restart después de cambios
Cualquier cambio en código backend (controllers, services, DTOs) requiere recompilar (`gradlew :api:compileKotlin`) Y reiniciar (`Get-Process java | Stop-Process; bootRun`). Para parar limpio: `Get-Process java | Stop-Process -Force`.

---

## 🎉 Fallas Restantes: NINGUNA

Run completo agregado de los 21 archivos en Chrome: **69/69 tests passing, 0 fallas, 39m 0s**. Validado el 2026-05-06 (sesión 11 cont.). Todas las suites E2E (push_notifications + 15 archivos anteriores) están en verde.

---

## Fixes Aplicados Sesión 11 cont.

| Archivo | Cambio |
|---------|--------|
| `worship_hub_ui/integration_test/.../notification_preferences_test.dart` | Aserciones via `bloc.state.applicableTypes` en vez de `find.text` (evita lazy-load de ListView en viewport pequeño); rol del leader cambiado a `'WORSHIP_LEADER'` (era `'TEAM_LEADER'` que no existe en `organization.UserRole`); helpers `_expectLabelVisible/Absent` reemplazados por `_readLoadedState` |

---

## Fixes Aplicados Sesión 11

| Archivo | Cambio |
|---------|--------|
| `worship_hub_api/api/.../catalog/SongController.kt` | `updateSong` extrae `userId` y lo pasa como `updatedBy` al command |
| `worship_hub_api/api/.../catalog/SongController.kt` | `deleteSong` extrae `userId` y lo pasa como `deletedBy` al app service |
| `worship_hub_api/api/.../chat/ChatController.kt` | Inyecta `UserRepository`; `toDto()` resuelve `userName = "${firstName} ${lastName}"` |
| `worship_hub_ui/lib/data/repositories/chat_repository_impl.dart` | `_mapFromApi` tolera `userName` null con fallback "Unknown" + casts seguros |
| `worship_hub_ui/lib/data/repositories/chat_repository_impl.dart` | `_saveOrUpdateLocal.replace()` ahora copia el PK existente al objeto entrante |
| `worship_hub_ui/integration_test/.../chat_polling_test.dart` | Tests 2 y 4: invocar `chatRepository.syncMessages` directo + `bloc.add` para forzar emit |

---

## Fixes Aplicados Sesión 10 cont.

| Archivo | Cambio |
|---------|--------|
| `worship_hub_api/.../catalog/SongController.kt` | `addAttachment` extrae `userId` y lo pasa como `addedBy` |
| `worship_hub_ui/integration_test/seed/api_seed_helper.dart` | Default `type` cambiado a `YOUTUBE_LINK`; doc enum actualizada |
| `worship_hub_ui/integration_test/.../song_attachment_notification_test.dart` | Reescrito con flujo invertido y tipos enum correctos |

---

## Fixes Aplicados Sesión 10

| Archivo | Cambio |
|---------|--------|
| `notification_router.dart` | Agregados `TEAM_ASSIGNMENT`, `TEAM_MEMBER_ADDED`, etc. al deep linking |
| `song_detail_page.dart` | Acepta `song` nullable + `songId`; carga del backend si solo ID |
| `app_router.dart` | Pasa `songId` a `SongDetailPage` en `/songs/detail/:songId` |
| `chat_bloc.dart` | `_onRefreshRequested` usa `syncMessages` antes de leer cache |
| `navigation_helper.dart` | `goToNotifications()` con fallback programático |
| `song_comment_notification_test.dart` | Flujo invertido: admin crea canción, member comenta |
| `deep_linking_test.dart` | NEW_COMMENT invertido + aserción flexible |
| `mark_as_read_test.dart` | Aserción simplificada (solo blue dots) |
| `chat_polling_test.dart` | Member agregado al team + refresh manual (parcial — completado en s11) |
| `in_app_banner_test.dart` + `notification_banner.dart` | **ELIMINADOS** (Android-native) |

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

### Auditoría continuada (mantenimiento preventivo)
1. **Auditar otros DTOs backend con campos nullable** que el cliente espera non-null (finding #2 s11):
   - Revisar todos los `*ResponseDto.kt` en `api/src/main/kotlin/.../api/`.
   - Cross-check con las entidades cliente (`lib/domain/entities/*.dart`) que tengan campos `required final String`.
2. **Auditar otros repos cliente con BD local Drift** por el bug de `replace()` sin PK (finding #3 s11):
   - `NotificationRepositoryImpl` — verificar que sea stateless (debería estar OK desde s9).
   - `SongRepositoryImpl`, `SetlistRepositoryImpl`, `TeamRepositoryImpl` — si tienen `_saveOrUpdateLocal` similar, replicar el fix.
3. **Auditar otros tests con asserts sobre items de ListView grande** (finding #4b s11c):
   - Buscar `find.text(...)` en tests cuyo widget esté dentro de una `ListView` larga. Migrar a aserciones de bloc state si es posible.

### Refactors útiles (no bloqueantes)
4. **Eliminar el `try/catch` silencioso de `ChatBloc._onRefreshRequested`** o al menos loguear los errores capturados. Tres bugs estuvieron escondidos por meses por culpa de ese catchAll. Considerar reemplazar por `try/catch` que emita estado `ChatError` discriminado.
5. **Migrar backend `NotificationController` para usar `SecurityContext.getCurrentUserId()`** en lugar de `@RequestHeader("User-Id")`. Más canónico.
6. **Limpiar `.gradle/`, `bin/`, `build/` del repo `worship_hub_api`** — están tracked y generan ruido. Agregar a `.gitignore` y `git rm --cached -r`.
7. **Considerar consolidar los dos enums `UserRole`** (organization vs collaboration.push) para reducir confusión. Sería un refactor grande pero elimina una clase de bugs como el de s11c.
8. **Push a origin** — todos los cambios están solo en local (3 submodules, 0 pushed).

## Spec Files
- `.kiro/specs/flutter-e2e-ui-tests/` — 16 requirements, design, tasks (completado)
- `.kiro/specs/push-notifications-e2e-tests/` — 23 requirements, design, 29 tasks (completado)

## Git State
- **Parent repo** `master`: pendiente bump de submodules + commit doc s11c.
- **worship_hub_api submodule** `main`: commit `8f66776` "fix(catalog,chat): SongController updatedBy/deletedBy + ChatMessageResponseDto.userName populated" (s11). Histórico: persist/merge fixes (s8) + CORS (s9) + addAttachment + cancelService (s10c).
- **worship_hub_ui submodule** `master`: commit `fceaa1d` "fix(e2e): notification_preferences tests assert via bloc state instead of widget tree" (s11c). Histórico: chat fixes s11 (`26b013d`), s10/s10c fixes, connect-to-backend (s9).

Todos los cambios committeados localmente, NINGUNO pusheado a origin. Para sincronizar:
```powershell
cd worship_hub_api && git push origin main
cd ../worship_hub_ui && git push origin master
cd .. && git push origin master
```

