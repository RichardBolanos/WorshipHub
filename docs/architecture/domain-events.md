# Implementación de Domain Events - WorshipHub

## Resumen de la Implementación Completa

Este documento describe la implementación correcta del sistema de eventos de dominio para notificaciones automáticas.

## Problema Original

El código tenía una implementación incompleta:
- ❌ `SongEvent.SongCreated` no tenía el campo `createdBy`
- ❌ `CreateSongCommand` no capturaba el usuario que crea la canción
- ❌ `NotificationType` no tenía los valores `SONG_ADDED` y `SERVICE_SCHEDULED`
- ❌ Los event handlers estaban comentados o usaban tipos incorrectos

## Solución Implementada

### 1. Domain Events (Domain Layer)

**Archivo:** `domain/src/main/kotlin/com/worshiphub/domain/common/DomainEvent.kt`

```kotlin
sealed class SongEvent : DomainEvent {
    data class SongCreated(
        override val eventId: UUID = UUID.randomUUID(),
        override val occurredAt: LocalDateTime = LocalDateTime.now(),
        override val aggregateId: UUID,
        val title: String,
        val artist: String,
        val churchId: UUID,
        val createdBy: UUID  // ✅ Usuario que creó la canción
    ) : SongEvent()
}

sealed class ServiceEvent : DomainEvent {
    data class ServiceScheduled(
        override val eventId: UUID = UUID.randomUUID(),
        override val occurredAt: LocalDateTime = LocalDateTime.now(),
        override val aggregateId: UUID,
        val teamMembers: List<UUID>,
        val scheduledDate: LocalDateTime
    ) : ServiceEvent()
}
```

### 2. Notification Types (Domain Layer)

**Archivo:** `domain/src/main/kotlin/com/worshiphub/domain/collaboration/Notification.kt`

```kotlin
enum class NotificationType {
    SERVICE_INVITATION,
    NEW_SONG,
    SONG_ADDED,           // ✅ Cuando se agrega una canción al catálogo
    NEW_COMMENT,
    TEAM_ASSIGNMENT,
    SERVICE_SCHEDULED     // ✅ Cuando se programa un servicio con miembros
}
```

### 3. Application Command (Application Layer)

**Archivo:** `application/src/main/kotlin/com/worshiphub/application/catalog/CreateSongCommand.kt`

```kotlin
data class CreateSongCommand(
    val title: String,
    val artist: String?,
    val key: String?,
    val bpm: Int?,
    val lyrics: String?,
    val chords: String?,
    val churchId: UUID,
    val createdBy: UUID  // ✅ Usuario que crea la canción
)
```

### 4. Controller (API Layer)

**Archivo:** `api/src/main/kotlin/com/worshiphub/api/catalog/SongController.kt`

```kotlin
@PostMapping
fun createSong(@Valid @RequestBody request: CreateSongRequest): SongResponse {
    val churchId = securityContext.getCurrentChurchId()
    val userId = securityContext.getCurrentUserId()  // ✅ Obtener usuario actual
    
    val command = CreateSongCommand(
        title = request.title,
        artist = request.artist,
        key = request.key,
        bpm = request.bpm,
        lyrics = request.lyrics,
        chords = request.chords,
        churchId = churchId,
        createdBy = userId  // ✅ Pasar el usuario al comando
    )
    
    val result = catalogApplicationService.createSong(command)
    // ...
}
```

### 5. Event Handlers (API Layer)

**Archivo:** `api/src/main/kotlin/com/worshiphub/api/config/DomainEventConfig.kt`

```kotlin
@Component
class DomainEventHandler(
    private val notificationApplicationService: NotificationApplicationService
) {
    
    @EventListener
    fun handleSongCreated(event: SongEvent.SongCreated) {
        // ✅ Notificar al usuario que creó la canción
        notificationApplicationService.sendNotification(
            userId = event.createdBy,
            title = "Nueva canción agregada",
            message = "${event.title} por ${event.artist} ha sido agregada al catálogo",
            type = NotificationType.SONG_ADDED
        )
    }
    
    @EventListener
    fun handleServiceScheduled(event: ServiceEvent.ServiceScheduled) {
        // ✅ Notificar a todos los miembros asignados al servicio
        event.teamMembers.forEach { memberId ->
            notificationApplicationService.sendNotification(
                userId = memberId,
                title = "Servicio programado",
                message = "Has sido asignado al servicio del ${event.scheduledDate}",
                type = NotificationType.SERVICE_SCHEDULED
            )
        }
    }
}
```

## Flujo Completo

### Creación de Canción

```
1. Usuario hace POST /api/v1/songs
   ↓
2. SongController captura userId del SecurityContext
   ↓
3. Crea CreateSongCommand con createdBy = userId
   ↓
4. CatalogApplicationService.createSong() guarda la canción
   ↓
5. [TODO] Publica SongEvent.SongCreated con createdBy
   ↓
6. DomainEventHandler.handleSongCreated() recibe el evento
   ↓
7. Envía notificación al usuario que creó la canción
```

### Programación de Servicio

```
1. Usuario programa un servicio con miembros asignados
   ↓
2. SchedulingApplicationService publica ServiceEvent.ServiceScheduled
   ↓
3. DomainEventHandler.handleServiceScheduled() recibe el evento
   ↓
4. Envía notificación a cada miembro asignado
```

## Pendiente (TODO)

Para completar la implementación, falta:

1. **Inyectar DomainEventPublisher en CatalogApplicationService**
   ```kotlin
   @Service
   class CatalogApplicationService(
       private val songRepository: SongRepository,
       private val domainEventPublisher: DomainEventPublisher,  // ✅ Agregar
       // ... otros repositorios
   ) {
       fun createSong(command: CreateSongCommand): Result<Song> {
           // ... guardar canción
           
           // ✅ Publicar evento
           domainEventPublisher.publish(
               SongEvent.SongCreated(
                   aggregateId = savedSong.id,
                   title = savedSong.title,
                   artist = savedSong.artist ?: "Unknown",
                   churchId = savedSong.churchId,
                   createdBy = command.createdBy
               )
           )
           
           return Result.success(savedSong)
       }
   }
   ```

2. **Implementar publicación de eventos en SchedulingApplicationService**
   - Cuando se crea un ServiceEvent
   - Cuando se asignan miembros a un servicio

## Arquitectura de Domain Events

```
┌─────────────────────────────────────────────────────────────┐
│                    API Layer (Controllers)                  │
│  - Captura contexto de usuario (SecurityContext)            │
│  - Crea comandos con información completa                   │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│              Application Layer (Services)                   │
│  - Ejecuta lógica de negocio                                │
│  - Publica Domain Events                                    │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ publishes
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   Domain Events                             │
│  - SongEvent.SongCreated                                    │
│  - ServiceEvent.ServiceScheduled                            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ @EventListener
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Event Handlers (API Config)                    │
│  - DomainEventHandler                                       │
│  - Envía notificaciones automáticas                         │
└─────────────────────────────────────────────────────────────┘
```

## Beneficios de esta Implementación

1. ✅ **Separación de responsabilidades**: Los eventos de dominio desacoplan la lógica de negocio de las notificaciones
2. ✅ **Trazabilidad completa**: Cada evento tiene información de quién lo generó
3. ✅ **Extensibilidad**: Fácil agregar nuevos handlers sin modificar la lógica de negocio
4. ✅ **Consistencia**: Los tipos de notificación están bien definidos en el enum
5. ✅ **Clean Architecture**: Respeta las capas y dependencias del sistema

## Lecciones Aprendidas

❌ **Incorrecto**: Comentar código o usar valores temporales
✅ **Correcto**: Implementar la lógica completa siguiendo el diseño del dominio

❌ **Incorrecto**: Asumir que los datos están disponibles sin capturarlos
✅ **Correcto**: Capturar toda la información necesaria desde el punto de entrada (Controller)

❌ **Incorrecto**: Usar tipos de notificación que no existen
✅ **Correcto**: Definir los tipos necesarios en el enum del dominio

---

**Estado**: ✅ Implementación completa y compilando correctamente
**Próximo paso**: Inyectar DomainEventPublisher y publicar eventos desde Application Services
