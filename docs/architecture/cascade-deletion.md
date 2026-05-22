# Cascade Deletion — semánticas correctas y contrato offline-first

**Estado:** vigente desde V19 + V20 (backend) y schema v5 (mobile).
**Audiencia:** ingenieros que toquen un `delete*` en cualquier módulo.
**Última actualización:** mayo 2026.

---

## TL;DR — la regla en una frase

> **Cuando borras un agregado, borras lo que le pertenece (composición), nunca lo que solo lo referencia (asociación).**

Esto se traduce en:

| Tipo de relación | Acción al borrar el padre | Ejemplo |
|---|---|---|
| **Composición** (el hijo no existe sin el padre) | `ON DELETE CASCADE` | Song → attachments |
| **Junction M:N** (el join es composición de ambos extremos) | `CASCADE` solo en el join, **nunca** en el otro extremo | Song ↔ setlist_songs ↔ Setlist |
| **Referencia** (el hijo es independiente) | `SET NULL` si la columna es nullable, `RESTRICT` si no | ServiceEvent.setlistId, Team.leaderId |

Si dudas, **lee la tabla canónica** en [§ Matriz de semánticas](#matriz-de-semánticas-por-aggregate) antes de tocar nada.

---

## Tabla de contenidos

1. [Origen del problema](#origen-del-problema)
2. [Matriz de semánticas por aggregate](#matriz-de-semánticas-por-aggregate)
3. [Patrón de implementación — backend](#patrón-de-implementación--backend)
4. [Patrón de implementación — mobile (offline-first)](#patrón-de-implementación--mobile-offline-first)
5. [Idempotencia y manejo de errores](#idempotencia-y-manejo-de-errores)
6. [Tombstones y anti-resurrección](#tombstones-y-anti-resurrección)
7. [Notificación cross-device por FCM](#notificación-cross-device-por-fcm)
8. [Cómo agregar un nuevo aggregate](#cómo-agregar-un-nuevo-aggregate)
9. [Anti-patrones](#anti-patrones)
10. [Tests obligatorios](#tests-obligatorios)
11. [Referencias cruzadas](#referencias-cruzadas)

---

## Origen del problema

En producción se observó este error:

```
Batch entry 0 insert into chat_messages (content, created_at, team_id, user_id, id)
  values (...) was aborted: ERROR: insert or update on table "chat_messages"
  violates foreign key constraint "fk_chat_messages_team_id"
  Detail: Key (team_id)=(eba7d92f-...) is not present in table "teams".
```

Detalle: el cliente mandó un mensaje de chat a un `teamId` que ya no existía. La causa raíz no era un solo bug — era una **clase de bug** repetida en cada módulo del sistema:

1. **Backend:** los `delete*` solo borraban el aggregate root. Sus hijos quedaban como **filas huérfanas** o, peor, las FK con `RESTRICT` por default hacían fallar el borrado a la primera tabla con datos.
2. **Backend:** los DELETE endpoints lanzaban 404 en vez de 204, rompiendo retries idempotentes desde el cliente.
3. **Backend:** no se publicaban eventos de dominio para los borrados, así que otros dispositivos nunca se enteraban.
4. **Mobile:** los repos solo marcaban el padre con `pendingDelete=true`, dejando hijos como huérfanos en Drift.
5. **Mobile:** los `pushXDeletes` solo manejaban éxito y 404. 403/409/5xx hacían que la fila quedara en loop de retry infinito o se borrara silenciosamente sin permiso.
6. **Mobile:** sin tombstones, un pull podía resucitar la entidad borrada.

La solución fue **uniformar el patrón** y aplicarlo a cada aggregate. Este documento es la fuente de verdad de ese patrón.

---

## Matriz de semánticas por aggregate

Esta tabla es la **fuente única de verdad**. Antes de tocar un `delete*` o agregar una FK nueva, busca aquí qué corresponde.

### Borrar **Team**

| Tabla afectada | Acción | Justificación |
|---|---|---|
| `team_members` | **CASCADE** | Composición: la membresía pertenece al equipo. |
| `chat_messages` | **CASCADE** | Composición: los mensajes pertenecen al equipo. |
| `service_events` (con sus `assigned_members`) | **CASCADE** | Composición: el servicio del equipo desaparece. |
| `invitation_tokens` (con `team_id`) | **CASCADE** | Composición: la invitación al equipo. |
| `users` (leader) | **No tocar** | Asociación: el usuario sobrevive al equipo. |

Migración: [`V19__team_cascade_deletion.sql`](../../worship_hub_api/api/src/main/resources/db/migration/V19__team_cascade_deletion.sql).

### Borrar **Song**

| Tabla afectada | Acción | Justificación |
|---|---|---|
| `attachments` | **CASCADE** | Composición: el adjunto pertenece a la canción. |
| `song_comments` | **CASCADE** | Composición: el comentario pertenece a la canción. |
| `setlist_songs` (join M:N) | **CASCADE** | Solo el vínculo. La canción se va, el setlist sobrevive. |
| `song_categories` (join M:N) | **CASCADE** (V8) | Solo el vínculo. La categoría sobrevive. |
| `song_tags` (join M:N) | **CASCADE** (V8) | Solo el vínculo. El tag sobrevive. |
| `setlists` | **No tocar** | El setlist queda con una canción menos, intacto. |
| `categories`, `tags` | **No tocar** | Pueden seguir etiquetando otras canciones. |
| `service_events` | **No tocar** | El servicio sigue programado. |

Migración: [`V20__cascade_deletion_for_aggregates.sql`](../../worship_hub_api/api/src/main/resources/db/migration/V20__cascade_deletion_for_aggregates.sql).

### Borrar **Setlist**

| Tabla afectada | Acción | Justificación |
|---|---|---|
| `setlist_songs` (join M:N) | **CASCADE** | Solo el vínculo. **Las canciones sobreviven en el catálogo.** |
| `service_events.setlist_id` | **SET NULL** | El servicio sigue existiendo, simplemente sin setlist. |
| `songs` | **No tocar** | Cada canción es un agregado independiente. |
| `service_events` | **No tocar** | Solo se le borra la referencia. |

### Borrar **Category** o **Tag**

| Tabla afectada | Acción | Justificación |
|---|---|---|
| `song_categories` o `song_tags` (join M:N) | **CASCADE** (V8) | Solo el vínculo. Las canciones sobreviven. |
| `songs` | **No tocar** | La canción pierde una etiqueta, sigue existiendo. |
| Otras categorías/tags | **No tocar** | Son aggregates independientes. |

### Borrar **ServiceEvent (recurrente)**

| Tabla afectada | Acción | Justificación |
|---|---|---|
| `service_events` (children con `parent_service_id`) | **CASCADE** (composición) | Las instancias hijas pertenecen al recurrente. |
| `assigned_members` | **CASCADE** (V19) | Composición: la asignación pertenece al servicio. |
| `setlists`, `users`, `teams` | **No tocar** | Independientes. |

**Pre-flight rule (P0):** si **cualquier** instancia tiene un miembro con `confirmationStatus = ACCEPTED`, el borrado se rechaza con `409 Conflict`. Los miembros confirmados no deben ser silenciosamente removidos. El cliente debe usar el flujo explícito de cancelación con razón.

### Borrar **User** (futuro — no hay endpoint hoy)

| Tabla afectada | Acción | Justificación |
|---|---|---|
| `team_members`, `assigned_members`, `chat_messages`, `song_comments`, `user_availability`, `notifications` | **CASCADE** (V20) | Sus participaciones se van con el usuario. |
| `device_tokens`, `notification_preferences`, `refresh_tokens`, `email_verification_tokens`, `password_reset_tokens` | **CASCADE** (V14/V15/V16) | Tokens y preferencias del usuario. |
| `teams.leader_id` | **RESTRICT** (default) | El equipo sobrevive al líder. La aplicación debe **reasignar** antes de permitir el borrado del usuario. |
| `songs`, `setlists`, `service_events`, `teams` | **No tocar** | El contenido sobrevive al autor. |

> **Por qué `teams.leader_id` no es `SET NULL`:** la entidad `Team` declara `leaderId: UUID` como no-null. Permitir `SET NULL` rompería Hibernate al hidratar la fila. La invariante de negocio "un equipo siempre tiene líder" se enforce a nivel de aplicación: el flujo de borrar usuario tiene que **reasignar** primero.

---

## Patrón de implementación — backend

El patrón es **uniforme** para cada aggregate que soporta delete. Tiene 5 piezas obligatorias.

### 1. Migración Flyway con la semántica correcta

`ALTER TABLE … DROP CONSTRAINT IF EXISTS … ; ALTER TABLE … ADD CONSTRAINT … FOREIGN KEY … ON DELETE [CASCADE|SET NULL]`. PostgreSQL no tiene `ALTER CONSTRAINT … SET ON DELETE`, así que toca dropear y volver a crear. Va dentro de la transacción de Flyway, es atómico.

Ejemplo: [`V20__cascade_deletion_for_aggregates.sql`](../../worship_hub_api/api/src/main/resources/db/migration/V20__cascade_deletion_for_aggregates.sql) tiene la lista completa con docstring de cada decisión.

### 2. `DomainException` tipada

En [`DomainException.kt`](../../worship_hub_api/domain/src/main/kotlin/com/worshiphub/domain/common/DomainException.kt). Cada aggregate tiene su propio `XNotFound`:

```kotlin
sealed class DomainException(message: String, val errorCode: String) : RuntimeException(message) {
    class TeamNotFound(val teamId: UUID) : DomainException("Team not found: $teamId", "TEAM_NOT_FOUND")
    class SongNotFound(val songId: UUID) : DomainException(...)
    class SetlistNotFound(val setlistId: UUID) : DomainException(...)
    class ServiceEventNotFound(val serviceId: UUID) : DomainException(...)
    class SetlistChurchMismatch(val setlistId: UUID) : DomainException(..., "SETLIST_CHURCH_MISMATCH")
    class RecurringServiceHasAcceptedMembers(val serviceId: UUID) : DomainException(..., "RECURRING_SERVICE_HAS_ACCEPTED_MEMBERS")
}
```

El `GlobalExceptionHandler` mapea cada subclase a su HTTP status correcto (`404`, `403`, `409`).

### 3. `DomainEvent` con snapshot de afectados

```kotlin
sealed class TeamEvent : DomainEvent {
    data class TeamDeleted(
        override val aggregateId: UUID,
        val churchId: UUID,
        val teamName: String,
        val affectedUserIds: Set<UUID>,  // SNAPSHOT antes del borrado
        val deletedBy: UUID
    ) : TeamEvent()
}
```

Crítico: el snapshot se captura **antes** de borrar. Después de la cascada, los miembros ya no existen en la base.

### 4. Application service con cascada explícita + evento

```kotlin
@Transactional
fun deleteTeam(teamId: UUID, requestingUserId: UUID? = null): Result<Unit> {
    return try {
        val team = teamRepository.findById(teamId)
            ?: return Result.failure(DomainException.TeamNotFound(teamId))

        // 1. Snapshot afectados ANTES de la cascada
        val memberIds = teamMemberRepository.findByTeamId(teamId).map { it.userId }.toMutableSet()
        memberIds.add(team.leaderId)
        requestingUserId?.let { memberIds.add(it) }  // sus otros devices

        // 2. Cascada explícita en orden de dependencias
        //    (DB CASCADE es la red de seguridad)
        chatMessageRepository.deleteByTeamId(teamId)
        serviceEventRepository.deleteByTeamId(teamId)
        teamMemberRepository.deleteByTeamId(teamId)
        teamRepository.delete(team)

        // 3. Evento de dominio con snapshot
        eventPublisher.publishEvent(
            TeamEvent.TeamDeleted(
                aggregateId = teamId,
                churchId = team.churchId,
                teamName = team.name,
                affectedUserIds = memberIds.toSet(),
                deletedBy = requestingUserId ?: team.leaderId
            )
        )
        Result.success(Unit)
    } catch (e: Exception) {
        Result.failure(RuntimeException("Failed to delete team: $teamId", e))
    }
}
```

**Por qué cascada explícita + DB CASCADE:** la cascada explícita da control sobre el orden, captura snapshots, dispara eventos, registra métricas. El `ON DELETE CASCADE` es la **red de seguridad** para que un futuro programador que olvide actualizar este código no introduzca un FK violation. Defense in depth.

### 5. Endpoint idempotente (404 → 204)

```kotlin
@DeleteMapping("/{teamId}")
@ResponseStatus(HttpStatus.NO_CONTENT)
fun deleteTeam(@PathVariable teamId: UUID) {
    val result = organizationApplicationService.deleteTeam(teamId, securityContext.getCurrentUserId())
    if (result.isFailure) {
        when (val e = result.exceptionOrNull()) {
            // Idempotent: el cliente offline-first puede reintentar
            // un DELETE que ya completó pero perdió la respuesta en la red.
            is DomainException.TeamNotFound -> return
            is DomainException -> throw e  // 403/409 vía GlobalExceptionHandler
            else -> throw BadRequestException(e?.message ?: "Failed to delete team")
        }
    }
}
```

### 6. Listener `@TransactionalEventListener(AFTER_COMMIT) @Async` para FCM

El listener convierte el `DomainEvent` en un `PushEvent` que la pipeline de FCM ya sabe enviar.

[`CascadeDeletionEventListeners.kt`](../../worship_hub_api/application/src/main/kotlin/com/worshiphub/application/notification/CascadeDeletionEventListeners.kt) tiene los 3 (Team, Song, Setlist):

```kotlin
@Async("pushNotificationExecutor")
@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
fun onTeamDeleted(event: TeamEvent.TeamDeleted) {
    if (event.affectedUserIds.isEmpty()) return
    applicationEventPublisher.publishEvent(
        PushEvent.TeamDeleted(
            recipientUserIds = event.affectedUserIds.toList(),
            teamId = event.aggregateId,
            teamName = event.teamName,
            deletedBy = event.deletedBy
        )
    )
}
```

**Por qué `AFTER_COMMIT`:** si la transacción se rolleó (cualquier excepción tardía), el equipo sigue existiendo. Mandar push diciendo "se borró" sería catastrófico. `AFTER_COMMIT` garantiza que solo se publica si el commit fue real.

**Por qué `@Async`:** el push gateway puede tardar segundos. El usuario que disparó el DELETE no tiene por qué esperar.

---

## Patrón de implementación — mobile (offline-first)

El cliente Flutter es **offline-first** (ver [offline-first.md](../frontend/offline-first.md)). El delete sigue el mismo patrón uniforme.

### 1. Cascada local en el repository

Borrar un team localmente = marcar `pendingDelete=true` en team + members + services, y **hard-delete** los chat messages (que son derivados del server, no tienen edición offline).

```dart
@override
Future<void> deleteTeam(String teamId) async {
  final existing = await (_db.select(_db.teams)
        ..where((t) => t.teamId.equals(teamId))).getSingleOrNull();
  if (existing == null) return;  // idempotent

  await _db.transaction(() async {
    if (existing.serverId == null) {
      // Nunca se sincronizó al server → wipe físico de todo
      await _wipeTeamCascade(teamId);
    } else {
      // Marca padre + hijos para sync
      await (_db.update(_db.teams)..where((t) => t.teamId.equals(teamId)))
          .write(TeamsCompanion(pendingDelete: Value(true), isSynced: Value(false)));
      await (_db.update(_db.teamMembers)..where((m) => m.teamId.equals(teamId)))
          .write(TeamMembersCompanion(pendingDelete: Value(true), isSynced: Value(false)));
      await (_db.update(_db.serviceEvents)..where((s) => s.teamId.equals(teamId)))
          .write(ServiceEventsCompanion(pendingDelete: Value(true), isSynced: Value(false)));
      // Chat: hard-delete local (no hay push de delete por mensaje)
      await (_db.delete(_db.chatMessages)..where((c) => c.teamId.equals(teamId))).go();
    }
  });
  _triggerBackgroundSync();
}
```

### 2. Push robusto con manejo de **todos** los códigos HTTP

```dart
try {
  await dio.delete('/api/v1/teams/$serverId');
  await _writeTombstone('team', serverId);
  await _wipeTeamCascade(row.teamId);
} on DioException catch (e) {
  switch (e.response?.statusCode) {
    case 404:
      // Idempotent success: el server ya no la tiene
      await _writeTombstone('team', serverId);
      await _wipeTeamCascade(row.teamId);
      break;
    case 403:
    case 409:
      // Permanente: revertir pendingDelete, surface al usuario
      await _revertPendingDelete(row.teamId);
      GlobalErrorHandler.logWarning('push delete reverted: $status');
      break;
    default:
      // Transient (5xx, network, timeout): dejar pendingDelete=true
      // y reintentar en el siguiente ciclo del SyncManager
      GlobalErrorHandler.logError('push delete transient failure', e, stack);
  }
}
```

**Por qué tres ramas distintas:** sin esto, un 403 (permiso revocado mientras estaba offline) deja la fila en loop de retry infinito. Y un 5xx no debe revertir, porque el siguiente ciclo puede tener éxito.

### 3. Scrub local de referencias rotas

Los joins M:N en mobile a veces están **denormalizados** (legacy: `Setlists.songIds` es un CSV, `Songs.categories` es un JSON array embebido). Cuando borras la entidad referenciada, hay que limpiar manualmente las referencias.

```dart
/// Cuando borras una Song, los Setlists que la contenían deben dejar
/// de listarla. Mirror del SQL CASCADE en setlist_songs.
Future<void> _scrubSongIdFromSetlists(String songServerId) async {
  final all = await database.select(database.setlists).get();
  for (final row in all) {
    if (!row.songIds.contains(songServerId)) continue;
    final scrubbed = row.songIds.where((id) => id != songServerId).toList();
    await (database.update(database.setlists)
          ..where((tbl) => tbl.id.equals(row.id)))
        .write(SetlistsCompanion(
      songIds: Value(scrubbed),
      isSynced: const Value(false),  // re-sync con el server
      updatedAt: Value(DateTime.now()),
    ));
  }
}
```

Equivalente para `Songs.categories` y `Songs.tags` JSON cuando borras una Category/Tag.

### 4. Tombstone para anti-resurrección

Ver [§ Tombstones](#tombstones-y-anti-resurrección) más abajo.

### 5. Handler FCM `handleRemoteXDeleted(serverId)` para cascada cross-device

Cuando otro usuario borra el team desde su dispositivo, el server manda FCM. El handler:

```dart
Future<void> handleRemoteTeamDeleted(String serverTeamId) async {
  if (serverTeamId.isEmpty) return;
  final row = await (_db.select(_db.teams)
        ..where((t) => t.serverId.equals(serverTeamId))).getSingleOrNull();
  await _writeTombstone('team', serverTeamId, reason: 'remote-team-deleted');
  if (row == null) return;  // ya no estaba localmente, tombstone basta
  await _wipeTeamCascade(row.teamId);
}
```

El [`FcmDataMessageHandler`](../../worship_hub_ui/lib/core/services/fcm_data_message_handler.dart) enrutea cada `type` (`TEAM_DELETED`, `SONG_DELETED`, `SETLIST_DELETED`) al método correspondiente del repo.

---

## Idempotencia y manejo de errores

### Backend → 404 se traduce a 204

| Status del service | HTTP del controller |
|---|---|
| `Result.success` | `204 No Content` |
| `DomainException.XNotFound` | `204 No Content` (idempotente) |
| `DomainException.SetlistChurchMismatch` | `403 Forbidden` |
| `DomainException.RecurringServiceHasAcceptedMembers` | `409 Conflict` |
| `DomainException` genérica | mapeado por `GlobalExceptionHandler` |
| Otra excepción | `400 Bad Request` |

**Por qué 404 → 204:** el cliente offline-first puede tener el DELETE en cola por minutos. Cuando lo manda, puede que el server ya lo procesó (otro device del mismo usuario, o el response del intento previo se perdió en la red). 404 sería un error confuso. 204 dice "está borrado, todo bien".

### Mobile → tres ramas según HTTP

| HTTP de la respuesta | Acción local |
|---|---|
| `204` (success) | tombstone + wipe físico |
| `404` (already gone) | tombstone + wipe físico (idempotente) |
| `403` o `409` (permanente) | revertir `pendingDelete=false`, log warning |
| `5xx`, network, timeout | dejar `pendingDelete=true`, retry próximo ciclo |
| Otro DioException | tratar como transient, log error |

---

## Tombstones y anti-resurrección

### El problema

Borras un team offline. La fila tiene `pendingDelete=true`. Mientras tanto, **otro device** del mismo usuario hace `pullLatestData()` desde el server. El server todavía tiene el team (su DELETE no ha llegado). El pull lo upsertea localmente. El team **resucita**.

### La solución

Una tabla [`Tombstones`](../../worship_hub_ui/lib/core/database/database.dart) con `(entityType, entityId, deletedAt, reason)`. Cuando borras o recibes `XDeleted` por FCM, escribes una tombstone. El `pullLatestData()` filtra cualquier server-id que tenga tombstone:

```dart
@override
Future<void> pullLatestData() async {
  final response = await dio.get('/api/v1/teams');
  final tombstoned = await _tombstonedIds('team');
  for (final item in response.data) {
    final serverId = item['id']?.toString();
    if (serverId != null && tombstoned.contains(serverId)) continue;
    await _upsertTeamFromApi(item);
  }
}
```

Las tombstones tienen un TTL implícito (eventualmente puedes limpiarlas tras N días — hoy quedan ahí, no es problema).

---

## Notificación cross-device por FCM

Cada delete dispara un FCM **silent data message** a todos los `affectedUserIds`. Esto incluye explícitamente los **otros dispositivos del usuario que disparó el delete** (sus otros teléfonos también deben limpiar el cache).

### Payload típico

```json
{
  "data": {
    "type": "TEAM_DELETED",
    "entityId": "eba7d92f-e436-...",
    "silent": "true",
    "teamName": "Domingo",
    "deletedBy": "dcde66a9-..."
  }
}
```

### Tipos soportados hoy

| `type` | Repo handler en mobile | Acción local |
|---|---|---|
| `TEAM_DELETED` | `TeamRepository.handleRemoteTeamDeleted` | tombstone + cascada wipe (chat, services, members, team) |
| `SONG_DELETED` | `SongRepository.handleRemoteSongDeleted` | tombstone + drop song + scrub `Setlists.songIds` |
| `SETLIST_DELETED` | `SetlistRepository.handleRemoteSetlistDeleted` | tombstone + drop setlist + null `ServiceEvents.setlistId` |

El despachador es [`fcm_data_message_handler.dart`](../../worship_hub_ui/lib/core/services/fcm_data_message_handler.dart).

---

## Cómo agregar un nuevo aggregate

Receta paso a paso. Si la sigues completa, es imposible introducir el bug original.

### Backend

1. **Migración Flyway**: agrega FKs `ON DELETE CASCADE | SET NULL | RESTRICT` según [§ Matriz](#matriz-de-semánticas-por-aggregate). Documenta cada decisión en comentarios SQL.
2. **`DomainException.MyAggregateNotFound`**: agrégala al sealed class de `DomainException.kt`.
3. **`MyAggregateEvent.MyAggregateDeleted`**: define el domain event con `affectedUserIds` snapshot, en `DomainEvent.kt`.
4. **`PushEvent.MyAggregateDeleted`**: define el push event en `PushEvent.kt`. Maneja el case en `PushNotificationService.toPayload` y `extractEntityInfo`.
5. **`NotificationType.MY_AGGREGATE_DELETED`**: agrégalo al enum en `Notification.kt`. Mapéalo a la preference correcta en `NotificationPreference.isEnabled` y al rol en `RoleNotificationFilter`.
6. **Application service `deleteMyAggregate`**: `@Transactional`, snapshot, cascada explícita, publish event. Usa el patrón del § anterior.
7. **Handler en `CascadeDeletionEventListeners`**: `@TransactionalEventListener(AFTER_COMMIT) @Async`, traduce a `PushEvent`.
8. **Endpoint `DELETE /api/v1/my-aggregates/{id}`**: `@ResponseStatus(204)`, traduce `DomainException` a 204/403/409, **nunca 404**.
9. **`GlobalExceptionHandler`**: mapea cada subclase nueva de `DomainException` a su HTTP status.

### Mobile

10. **Schema Drift**: si el aggregate vive localmente, agrégalo con `pendingDelete`, `isSynced`, `serverId`, `lastSyncAt`.
11. **`MyAggregateRepositoryImpl.deleteMyAggregate`**: cascada local, distingue `serverId == null` vs sincronizado, marca o wipea.
12. **`_pushMyAggregateDeletes`**: 200/404 = tombstone + wipe; 403/409 = revertir; 5xx/red = retry.
13. **`pullLatestData`**: filtra contra `_tombstonedIds('my_aggregate')`.
14. **`handleRemoteMyAggregateDeleted(serverId)`**: tombstone + cascada wipe local.
15. **`FcmDataMessageHandler`**: agrega el `case 'MY_AGGREGATE_DELETED'` que llama al handler.
16. **Service locator**: si el FCM handler necesita el nuevo repo, inyéctalo.

### Tests

17. Backend: cascada borra hijos correctos, **no toca** independientes, idempotencia 404→204, evento publicado con snapshot.
18. Mobile: cascada local correcta, 204/404/403/409/5xx tienen comportamientos distintos, tombstone bloquea resurrección, FCM handler ejecuta cascada local.

Si el checklist se sigue completo, el patrón queda uniforme y no se reintroduce el bug.

---

## Anti-patrones

### ❌ "Lo arreglo borrando los hijos a mano y ya"

```kotlin
// MAL: no hay snapshot, no hay event, no hay idempotencia
fun deleteTeam(teamId: UUID) {
    teamMemberRepository.deleteByTeamId(teamId)
    teamRepository.delete(teamId)
}
```

Faltan: snapshot de afectados, evento de dominio, manejo de "no existe", `@Transactional`. Este código provoca exactamente el bug original.

### ❌ Cascade en M:N que toca el otro extremo

Si pones `ON DELETE CASCADE` en `setlist_songs.song_id` apuntando a `songs(id)` y **además** un trigger que borra setlists vacías, has roto la semántica: borrar una canción borraría setlists. La regla: las relaciones M:N solo cascadean al join, **nunca al otro extremo**.

### ❌ Mobile que ignora 403/409

```dart
// MAL: 403 deja la fila en loop infinito de retry
catch (e) {
  if (e.response?.statusCode == 404) wipeLocally();
  else logError('will retry', e);
}
```

403 y 409 son **permanentes**. El usuario nunca recuperará el permiso reintentando. La fila debe revertirse y el usuario debe ser notificado.

### ❌ Tombstone sin TTL en el tiempo del proyecto

Hoy las tombstones se acumulan. Está bien por ahora (volumen bajo). Pero si en el futuro llegas a millones de borrados, agrega un TTL (p.ej. 30 días) o un job de limpieza.

### ❌ Borrar entidad y olvidar scrub de denormalización

Si en mobile `Songs.categories` es un JSON embebido y borras una category, las songs se quedan con un objeto huérfano `{id: 'cat-x', name: 'X'}` en su JSON. Hay que **scrubbar** explícitamente. El test que valida esto tiene que ser obligatorio para cualquier delete que toque entidades con denormalizaciones.

### ❌ Eventos antes del `AFTER_COMMIT`

Si publicas el `TeamDeletedEvent` **antes** de que la transacción haga commit, y la transacción se rollea por una excepción tardía, los clientes reciben push diciendo "el team se borró" cuando en realidad sigue ahí. Catastrófico. Siempre `@TransactionalEventListener(AFTER_COMMIT)`.

---

## Tests obligatorios

Cada delete tiene **mínimo 4 tests** en backend y **6 en mobile**.

### Backend (con MockK + Kotest)

```kotlin
"deleteX" - {
    "should cascade-delete children in dependency order"
    "should return XNotFound for non-existent X"  // 404→204 idempotency
    "should publish XDeleted event with affected user snapshot"
    "should NOT touch independent aggregates"  // Y, Z stay alive
}
```

Ejemplos vigentes:
- [`OrganizationApplicationServiceTest`](../../worship_hub_api/application/src/test/kotlin/com/worshiphub/application/organization/OrganizationApplicationServiceTest.kt) — Team
- [`CatalogApplicationServiceTest`](../../worship_hub_api/application/src/test/kotlin/com/worshiphub/application/catalog/CatalogApplicationServiceTest.kt) — Song
- [`SchedulingApplicationServiceTest`](../../worship_hub_api/application/src/test/kotlin/com/worshiphub/application/scheduling/SchedulingApplicationServiceTest.kt) — Setlist + recurring service
- [`ChatApplicationServiceTest`](../../worship_hub_api/application/src/test/kotlin/com/worshiphub/application/chat/ChatApplicationServiceTest.kt) — el bug original (`sendMessage` lanza `TeamNotFound` antes de FK violation)

### Mobile (con mocktail + Drift in-memory)

```dart
group('XRepositoryImpl.deleteX', () {
  test('204 success: tombstone + wipe + scrub references');
  test('404: idempotent success');
  test('403: rethrows + does NOT mutate local state');
  test('5xx: leaves pendingDelete=true for retry');
  test('does NOT touch independent aggregates');
  test('handleRemoteXDeleted: same cascade as local delete');
});
```

Ejemplos vigentes:
- [`team_repository_impl_delete_test.dart`](../../worship_hub_ui/test/data/repositories/team_repository_impl_delete_test.dart) — 14 casos
- [`cascade_delete_test.dart`](../../worship_hub_ui/test/data/repositories/cascade_delete_test.dart) — 11 casos para Song, Setlist, Category, Tag

---

## Referencias cruzadas

### Migraciones

- [`V19__team_cascade_deletion.sql`](../../worship_hub_api/api/src/main/resources/db/migration/V19__team_cascade_deletion.sql) — Team cascade.
- [`V20__cascade_deletion_for_aggregates.sql`](../../worship_hub_api/api/src/main/resources/db/migration/V20__cascade_deletion_for_aggregates.sql) — Song, Setlist, User cascade.
- `V8__redesign_categories_tags.sql` — Joins `song_categories` y `song_tags` ya tenían CASCADE.

### Backend

- [`DomainException.kt`](../../worship_hub_api/domain/src/main/kotlin/com/worshiphub/domain/common/DomainException.kt) — sealed class de excepciones tipadas.
- [`DomainEvent.kt`](../../worship_hub_api/domain/src/main/kotlin/com/worshiphub/domain/common/DomainEvent.kt) — `TeamEvent.TeamDeleted`, `SongEvent.SongDeleted`, `SetlistEvent.SetlistDeleted`.
- [`PushEvent.kt`](../../worship_hub_api/domain/src/main/kotlin/com/worshiphub/domain/collaboration/push/PushEvent.kt) — push events silenciosos.
- [`OrganizationApplicationService.deleteTeam`](../../worship_hub_api/application/src/main/kotlin/com/worshiphub/application/organization/OrganizationApplicationService.kt)
- [`CatalogApplicationService.deleteSong`](../../worship_hub_api/application/src/main/kotlin/com/worshiphub/application/catalog/CatalogApplicationService.kt)
- [`SchedulingApplicationService.deleteSetlist + deleteRecurringService`](../../worship_hub_api/application/src/main/kotlin/com/worshiphub/application/scheduling/SchedulingApplicationService.kt)
- [`ChatApplicationService.sendMessage`](../../worship_hub_api/application/src/main/kotlin/com/worshiphub/application/chat/ChatApplicationService.kt) — pre-flight check que cierra el bug original.
- [`CascadeDeletionEventListeners.kt`](../../worship_hub_api/application/src/main/kotlin/com/worshiphub/application/notification/CascadeDeletionEventListeners.kt) — los 3 listeners FCM.

### Mobile

- [`database.dart`](../../worship_hub_ui/lib/core/database/database.dart) — schema v5, tabla `Tombstones`.
- [`team_repository_impl.dart`](../../worship_hub_ui/lib/data/repositories/team_repository_impl.dart) — referencia canónica del patrón offline-first delete.
- [`song_repository_impl.dart`](../../worship_hub_ui/lib/data/repositories/song_repository_impl.dart) — `_scrubSongIdFromSetlists`.
- [`setlist_repository_impl.dart`](../../worship_hub_ui/lib/data/repositories/setlist_repository_impl.dart) — null de `ServiceEvents.setlistId`.
- [`category_repository_impl.dart`](../../worship_hub_ui/lib/data/repositories/category_repository_impl.dart), [`tag_repository_impl.dart`](../../worship_hub_ui/lib/data/repositories/tag_repository_impl.dart) — scrub de JSON denormalizado.
- [`fcm_data_message_handler.dart`](../../worship_hub_ui/lib/core/services/fcm_data_message_handler.dart) — despachador FCM.

### Otros docs relacionados

- [`offline-first.md`](../frontend/offline-first.md) — base del stack de sincronización.
- [`domain-events.md`](./domain-events.md) — patrón general de eventos.

---

## Changelog

| Fecha | Versión | Cambio |
|---|---|---|
| 2026-05-20 | V19 | Cascade for Team. Cierra el bug `fk_chat_messages_team_id`. |
| 2026-05-20 | V20 | Cascade for Song, Setlist, User. Distinción explícita composición vs M:N vs referencia. |
| 2026-05-22 | docs | Este documento creado consolidando todo el patrón. |
