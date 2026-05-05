# Plan de Implementación: Sistema de Notificaciones Push

## Visión General

Este plan implementa el sistema completo de notificaciones push para WorshipHub, cubriendo los 30 requisitos del documento de requisitos. La implementación abarca: backend Kotlin/Spring Boot (dominio, infraestructura, servicios de aplicación, controllers API), frontend Flutter (servicio push, deep linking, preferencias, canales Android, categorías iOS, Service Worker web), migración de WebSocket/STOMP a FCM (Requisito 27), eliminación de notificaciones mock del frontend (Requisito 28), cobertura completa de tests unitarios, E2E y property-based tests para todos los tipos de notificación (Requisito 29), y filtrado de notificaciones por rol del usuario con `RoleNotificationFilter`, `UserRole` enum y `UserRoleResolver` (Requisito 30). Se sigue Clean Architecture con capas domain → application → infrastructure → api en el backend, y el patrón feature module en el frontend. Las fases son incrementales: infraestructura fundacional (incluyendo rol de usuario), servicios y eventos (con filtrado por rol), controllers (con respuesta role-aware), eliminación de WebSocket, frontend push, eliminación de mocks, UI de preferencias/canales/categorías (filtrada por rol), y testing comprehensivo (incluyendo propiedades P22-P25).

## Tareas

- [x] 1. Configurar entidades de dominio, interfaces y filtrado por rol del sistema push
  - [x] 1.1 Crear la sealed class `PushEvent` con todos los subtipos de eventos
    - Crear `domain/src/main/kotlin/com/worshiphub/domain/collaboration/push/PushEvent.kt`
    - Implementar los 20 subtipos: ServiceAssignment, ChatMessage, SongComment, TeamMemberChange, InvitationResponse, NewSong, ChurchInvitation, ServiceReminder, SetlistModified, ServiceCancelled, RecurringServiceCreated, RecurrenceRuleUpdated, RecurringServiceDeleted, SongUpdated, SongDeleted, AttachmentAdded, InvitationAccepted, MemberUnavailable, MemberAvailableAgain
    - Cada subtipo debe tener `recipientUserIds` y `notificationType` según el diseño
    - _Requisitos: 2.1, 3.1, 4.1, 5.1, 6.1, 7.1, 8.1, 9.1, 10.1, 16.1, 17.1, 18.1, 19.1, 20.1, 21.1, 22.1, 23.1, 24.1, 25.1_

  - [x] 1.2 Crear la interfaz `PushGateway`, `PushPayload` y `PushResult`
    - Crear `domain/src/main/kotlin/com/worshiphub/domain/collaboration/push/PushGateway.kt`
    - Definir `PushPayload` con title, body, data map, channelId, badge (iOS), sound, category (iOS notification category para acciones rápidas)
    - Definir `PushResult` como sealed class con Success, InvalidToken, TransientError, PermanentError
    - _Requisitos: 13.1, 13.3, 13.4, 13.7, 26.5_

  - [x] 1.3 Crear la entidad `DeviceToken` y su interfaz de repositorio
    - Crear `domain/src/main/kotlin/com/worshiphub/domain/collaboration/push/DeviceToken.kt` con anotaciones JPA
    - Crear enum `DevicePlatform` con valores ANDROID, IOS y WEB
    - Crear `domain/src/main/kotlin/com/worshiphub/domain/collaboration/repository/DeviceTokenRepository.kt` con métodos: save, findByUserId, findByToken, deleteByToken, deleteByUserIdAndToken, deleteAllByUserId
    - _Requisitos: 1.2, 1.3, 1.4, 1.5, 1.7, 26.1_

  - [x] 1.4 Crear la entidad `NotificationPreference` y su interfaz de repositorio
    - Crear `domain/src/main/kotlin/com/worshiphub/domain/collaboration/push/NotificationPreference.kt` con anotaciones JPA
    - Implementar método `isEnabled(type: NotificationType): Boolean` con mapeo de cada tipo
    - Implementar método `enableTypes(types: Set<NotificationType>): NotificationPreference` que retorna copia con los tipos especificados activados (para cambio de rol ascendente)
    - Incluir 16 campos booleanos de preferencia (todos `true` por defecto)
    - Crear `domain/src/main/kotlin/com/worshiphub/domain/collaboration/repository/NotificationPreferenceRepository.kt` con métodos: save, findByUserId, findByUserIdOrDefault
    - _Requisitos: 11.1, 11.2, 11.3, 11.4, 11.6_

  - [x] 1.5 Ampliar el enum `NotificationType` con los nuevos valores
    - Modificar `domain/src/main/kotlin/com/worshiphub/domain/collaboration/Notification.kt`
    - Agregar: RECURRING_SERVICE, SONG_UPDATED, SONG_DELETED, SONG_ATTACHMENT, INVITATION_ACCEPTED, AVAILABILITY_CHANGE, CHAT_MESSAGE, SETLIST_MODIFIED, SERVICE_CANCELLED, CHURCH_INVITATION, INVITATION_RESPONSE
    - Agregar campos opcionales `relatedEntityId: UUID?` y `relatedEntityType: String?` a la entidad Notification para deep linking
    - _Requisitos: 12.3, 12.5_

  - [x] 1.6 Crear el enum `UserRole` con resolución de jerarquía
    - Crear `domain/src/main/kotlin/com/worshiphub/domain/collaboration/push/UserRole.kt`
    - Definir valores: ADMIN, TEAM_LEADER, MEMBER
    - Implementar `companion object` con método `resolveHighest(roles: List<UserRole>): UserRole` que retorna el rol de mayor jerarquía (Admin > Líder_Equipo > Miembro) usando `minByOrNull { it.ordinal }`
    - _Requisitos: 30.5_

  - [x] 1.7 Crear el servicio de dominio `RoleNotificationFilter` (object)
    - Crear `domain/src/main/kotlin/com/worshiphub/domain/collaboration/push/RoleNotificationFilter.kt`
    - Implementar como `object` (singleton) con el `Mapa_Notificaciones_Rol` privado:
      - Admin: todos los tipos de NotificationType
      - TEAM_LEADER: SERVICE_INVITATION, CHAT_MESSAGE, NEW_COMMENT, TEAM_MEMBER_ADDED, TEAM_MEMBER_REMOVED, TEAM_LEADER_CHANGED, TEAM_ROLE_CHANGED, TEAM_ASSIGNMENT, NEW_SONG, SERVICE_SCHEDULED, RECURRING_SERVICE, SONG_UPDATED, SONG_DELETED, SONG_ATTACHMENT, AVAILABILITY_CHANGE
      - MEMBER: SERVICE_INVITATION, CHAT_MESSAGE, NEW_COMMENT, NEW_SONG, SERVICE_SCHEDULED, RECURRING_SERVICE, SONG_UPDATED, SONG_DELETED, SONG_ATTACHMENT
    - Implementar `isApplicableForRole(notificationType, role): Boolean`
    - Implementar `getApplicableTypes(role): Set<NotificationType>`
    - Implementar `filterByRole(userIds, notificationType, roleResolver): List<UUID>` que filtra usuarios cuyo rol no permite el tipo de notificación
    - _Requisitos: 30.1, 30.2, 30.3, 30.4_

- [x] 2. Crear migración de base de datos y repositorios de infraestructura
  - [x] 2.1 Crear migración Flyway V14 para tablas `device_tokens` y `notification_preferences`
    - Crear `api/src/main/resources/db/migration/V14__add_push_notification_tables.sql`
    - Tabla `device_tokens`: id UUID PK, user_id FK, token VARCHAR(500) UNIQUE, platform VARCHAR(20) NOT NULL (ANDROID, IOS, WEB), created_at, last_used_at
    - Tabla `notification_preferences`: id UUID PK, user_id UNIQUE FK, 16 campos booleanos DEFAULT TRUE, updated_at
    - Crear índice `idx_device_tokens_user_id` en user_id
    - _Requisitos: 1.2, 1.7, 11.4_

  - [x] 2.2 Implementar `JpaDeviceTokenRepository` en el módulo infrastructure
    - Crear `infrastructure/src/main/kotlin/com/worshiphub/infrastructure/persistence/repository/JpaDeviceTokenRepository.kt`
    - Implementar la interfaz `DeviceTokenRepository` del dominio usando Spring Data JPA
    - _Requisitos: 1.2, 1.3, 1.4, 1.5_

  - [x] 2.3 Implementar `JpaNotificationPreferenceRepository` en el módulo infrastructure
    - Crear `infrastructure/src/main/kotlin/com/worshiphub/infrastructure/persistence/repository/JpaNotificationPreferenceRepository.kt`
    - Implementar la interfaz `NotificationPreferenceRepository` del dominio
    - El método `findByUserIdOrDefault` debe retornar preferencias con todo activado si no existen
    - _Requisitos: 11.2, 11.4_

- [x] 3. Configurar Firebase Admin SDK e implementar `FirebasePushGateway`
  - [x] 3.1 Agregar dependencias de Firebase Admin SDK y Spring Retry al proyecto
    - Modificar `api/build.gradle.kts` o `infrastructure/build.gradle.kts` para agregar: `com.google.firebase:firebase-admin:9.3.0`, `org.springframework.retry:spring-retry`, `org.springframework.boot:spring-boot-starter-aop`
    - _Requisitos: 13.1_

  - [x] 3.2 Crear configuración de Firebase Admin SDK
    - Crear `api/src/main/kotlin/com/worshiphub/api/config/FirebaseConfig.kt`
    - Inicializar `FirebaseApp` con credenciales desde variable de entorno o archivo JSON
    - Exponer bean `FirebaseMessaging` para inyección
    - Manejar gracefully si las credenciales no están disponibles (log warning, deshabilitar push)
    - _Requisitos: 13.1_

  - [x] 3.3 Implementar `FirebasePushGateway` con soporte Android, iOS (APNs) y Web
    - Crear `infrastructure/src/main/kotlin/com/worshiphub/infrastructure/push/FirebasePushGateway.kt`
    - Implementar `sendToDevice` con construcción de `Message` de FCM incluyendo:
      - `AndroidConfig` con channelId y sound
      - `ApnsConfig` con Aps (alert con título/cuerpo, badge, sound, category para acciones rápidas iOS)
      - `WebpushConfig` con ícono de WorshipHub
    - Mapear excepciones de FCM a `PushResult`: UNREGISTERED/INVALID_ARGUMENT → InvalidToken, UNAVAILABLE/INTERNAL → TransientError, otros → PermanentError
    - Implementar `sendToDevices` iterando sobre tokens
    - _Requisitos: 13.1, 13.3, 13.4, 13.6, 13.7, 26.5_

  - [x] 3.4 Configurar `TaskExecutor` dedicado para envío asíncrono de push
    - Crear `api/src/main/kotlin/com/worshiphub/api/config/AsyncPushConfig.kt`
    - Configurar `ThreadPoolTaskExecutor` con nombre `pushNotificationExecutor`
    - Habilitar `@EnableAsync` y `@EnableRetry`
    - _Requisitos: 13.5_

- [x] 4. Checkpoint — Verificar compilación de capas domain e infrastructure
  - Asegurar que todos los tests existentes pasan, preguntar al usuario si surgen dudas.

- [x] 5. Implementar servicios de aplicación del sistema push (con filtrado por rol)
  - [x] 5.1 Implementar `UserRoleResolver`
    - Crear `application/src/main/kotlin/com/worshiphub/application/notification/UserRoleResolver.kt`
    - Inyectar `ChurchMemberRepository` y `TeamMemberRepository`
    - Implementar `resolveEffectiveRole(userId: UUID): UserRole`:
      - Si el usuario es Admin en alguna iglesia → `UserRole.ADMIN`
      - Si el usuario es líder de algún equipo → `UserRole.TEAM_LEADER`
      - En caso contrario → `UserRole.MEMBER`
    - _Requisitos: 30.5_

  - [x] 5.2 Implementar `PushNotificationService` con filtrado por rol
    - Crear `application/src/main/kotlin/com/worshiphub/application/notification/PushNotificationService.kt`
    - Inyectar `PushGateway`, `DeviceTokenRepository`, `NotificationPreferenceRepository`, `NotificationApplicationService`, `UserRoleResolver`
    - Método `processPushEvent(event: PushEvent)` con `@Async("pushNotificationExecutor")`
    - Flujo para cada recipientUserId:
      1. **Filtrar por rol** usando `RoleNotificationFilter.filterByRole` con `userRoleResolver.resolveEffectiveRole`
      2. Guardar notificación in-app (siempre, para usuarios que pasan filtro de rol)
      3. Verificar preferencias del usuario
      4. Obtener tokens y enviar push
      5. Limpiar tokens inválidos
    - Implementar lógica de reintento con backoff exponencial para errores transitorios (máx 3 reintentos: 1s, 2s, 4s)
    - Implementar método privado `PushEvent.toPayload(userId)` que genera `PushPayload` con título, cuerpo, data map (incluyendo type y entityId para deep linking), channelId para Android, category para iOS
    - _Requisitos: 11.2, 11.3, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7, 30.1, 30.2, 30.4_

  - [x] 5.3 Implementar `PushNotificationEventListener`
    - Crear `application/src/main/kotlin/com/worshiphub/application/notification/PushNotificationEventListener.kt`
    - Usar `@EventListener` para capturar cada subtipo de `PushEvent`
    - Delegar al `PushNotificationService.processPushEvent`
    - _Requisitos: 13.5_

  - [x] 5.4 Implementar `DeviceTokenService`
    - Crear `application/src/main/kotlin/com/worshiphub/application/notification/DeviceTokenService.kt`
    - Métodos: `registerToken(userId, token, platform)` → Result<UUID>, `unregisterToken(userId, token)` → Result<Unit>, `unregisterAllTokens(userId)` → Result<Unit>
    - En `registerToken`: si el token ya existe, actualizar `lastUsedAt` en lugar de crear duplicado
    - Soportar plataforma IOS además de ANDROID y WEB
    - _Requisitos: 1.2, 1.3, 1.5, 1.7_

  - [x] 5.5 Implementar `NotificationPreferencesService` con soporte role-aware
    - Crear `application/src/main/kotlin/com/worshiphub/application/notification/NotificationPreferencesService.kt`
    - Inyectar `NotificationPreferenceRepository` y `UserRoleResolver`
    - Método `getPreferences(userId)` → `Result<NotificationPreferenceResponse>`:
      - Obtener preferencias del usuario
      - Resolver rol efectivo con `UserRoleResolver`
      - Obtener tipos aplicables con `RoleNotificationFilter.getApplicableTypes(effectiveRole)`
      - Retornar `NotificationPreferenceResponse(prefs, applicableTypes)`
    - Método `updatePreferences(userId, command)` → `Result<NotificationPreference>`
    - Método `onRoleChanged(userId, newRole: UserRole)`:
      - Obtener preferencias actuales y tipos aplicables del rol anterior
      - Calcular tipos recién disponibles (`newApplicable - previousApplicable`)
      - Activar por defecto los tipos recién disponibles usando `prefs.enableTypes(newlyAvailable)`
      - Conservar preferencias de tipos no aplicables en BD (no eliminar)
    - Crear `UpdatePreferencesCommand` data class con campos opcionales para cada tipo de preferencia
    - Crear `NotificationPreferenceResponse` data class con `preferences`, `applicableTypes` y método `getVisiblePreferences()`
    - _Requisitos: 11.1, 11.2, 11.4, 11.5, 11.6, 11.7_

  - [x] 5.6 Implementar `ReminderSchedulerJob`
    - Crear `application/src/main/kotlin/com/worshiphub/application/notification/ReminderSchedulerJob.kt`
    - Usar `@Scheduled(fixedRate = 900_000)` para ejecutar cada 15 minutos
    - Buscar servicios con estado PUBLISHED o CONFIRMED en las próximas 24h y 2h
    - Generar `PushEvent.ServiceReminder` solo para miembros con estado ACCEPTED
    - Evitar enviar recordatorios duplicados (trackear recordatorios ya enviados)
    - _Requisitos: 9.1, 9.2, 9.3_

- [x] 6. Integrar publicación de `PushEvent` en los servicios de aplicación existentes
  - [x] 6.1 Publicar eventos push desde `SchedulingApplicationService`
    - Inyectar `ApplicationEventPublisher` en el servicio existente
    - Publicar `PushEvent.ServiceAssignment` al crear/asignar miembros a un servicio
    - Publicar `PushEvent.InvitationResponse` al aceptar/declinar asignación
    - Publicar `PushEvent.SetlistModified` al modificar setlist de servicio futuro
    - Publicar `PushEvent.ServiceCancelled` al cancelar un servicio
    - Publicar `PushEvent.RecurringServiceCreated` al crear servicio recurrente con instancias
    - Publicar `PushEvent.RecurrenceRuleUpdated` al actualizar regla de recurrencia
    - Publicar `PushEvent.RecurringServiceDeleted` al eliminar servicio recurrente
    - _Requisitos: 2.1, 6.1, 6.2, 10.1, 16.1, 17.1, 18.1, 19.1_

  - [x] 6.2 Publicar eventos push desde `CatalogApplicationService`
    - Inyectar `ApplicationEventPublisher` en el servicio existente
    - Publicar `PushEvent.NewSong` al agregar canción (destinatarios = miembros activos de la iglesia excepto creador)
    - Publicar `PushEvent.SongComment` al agregar comentario (destinatarios = creador + comentaristas previos - comentarista actual)
    - Publicar `PushEvent.SongUpdated` al actualizar canción (destinatarios = usuarios con la canción en setlists futuros, excepto actualizador, deduplicados)
    - Publicar `PushEvent.SongDeleted` al eliminar canción (destinatarios = usuarios con la canción en setlists, excepto eliminador)
    - Publicar `PushEvent.AttachmentAdded` al agregar attachment (destinatarios = creador + comentaristas previos - actor)
    - _Requisitos: 4.1, 4.2, 7.1, 20.1, 20.3, 21.1, 22.1_

  - [x] 6.3 Publicar eventos push desde `CommunicationApplicationService`
    - Publicar `PushEvent.ChatMessage` al enviar mensaje de chat (destinatarios = miembros del equipo excepto remitente)
    - Respetar la exclusión de usuarios con la pantalla de chat activa (campo en payload para que el frontend filtre)
    - _Requisitos: 3.1, 3.2, 3.3_

  - [x] 6.4 Publicar eventos push desde `OrganizationApplicationService`
    - Publicar `PushEvent.TeamMemberChange` al agregar/remover miembros o cambiar líder/roles
    - Publicar `PushEvent.ChurchInvitation` al enviar invitación a usuario existente
    - Publicar `PushEvent.InvitationAccepted` al aceptar invitación (destinatario = admin invitador)
    - Publicar `PushEvent.MemberUnavailable` al marcar indisponibilidad (destinatarios = líderes del equipo)
    - Publicar `PushEvent.MemberAvailableAgain` al eliminar indisponibilidad (destinatarios = líderes del equipo)
    - _Requisitos: 5.1, 5.2, 5.3, 5.4, 8.1, 23.1, 24.1, 25.1_

  - [x] 6.5 Invocar `NotificationPreferencesService.onRoleChanged` al cambiar rol de usuario
    - En `OrganizationApplicationService`, al cambiar el rol de un miembro en un equipo o iglesia, invocar `notificationPreferencesService.onRoleChanged(userId, newRole)`
    - Resolver el nuevo rol efectivo con `UserRoleResolver` antes de invocar
    - _Requisitos: 11.6, 11.7_

- [x] 7. Implementar controllers API para registro de tokens y preferencias (role-aware)
  - [x] 7.1 Implementar `DeviceTokenController`
    - Crear `api/src/main/kotlin/com/worshiphub/api/communication/DeviceTokenController.kt`
    - `POST /api/v1/devices/token` → registrar token FCM (requiere autenticación)
    - `DELETE /api/v1/devices/token` → desregistrar token FCM (logout)
    - Crear DTOs: `RegisterTokenRequest(token: String, platform: String)` con validación de plataforma (ANDROID, IOS, WEB), `RegisterTokenResponse(id: UUID)`
    - _Requisitos: 1.2, 1.5, 1.7_

  - [x] 7.2 Implementar `NotificationPreferencesController` con respuesta role-aware
    - Crear `api/src/main/kotlin/com/worshiphub/api/communication/NotificationPreferencesController.kt`
    - `GET /api/v1/notifications/preferences` → obtener preferencias del usuario autenticado, incluyendo `applicableTypes` según rol del usuario y `userRole`
    - `PUT /api/v1/notifications/preferences` → actualizar preferencias
    - Crear DTOs: `NotificationPreferencesResponse` (con campos `preferences`, `applicableTypes: List<String>`, `userRole: String`), `UpdateNotificationPreferencesRequest`
    - La respuesta GET debe incluir solo las preferencias visibles para el rol actual del usuario
    - _Requisitos: 11.1, 11.2, 11.5, 30.3_

- [x] 8. Eliminar infraestructura WebSocket/STOMP y migrar chat a polling + FCM
  - [x] 8.1 Eliminar archivos y clases de WebSocket/STOMP
    - Eliminar `api/src/main/kotlin/com/worshiphub/config/WebSocketConfig.kt`
    - Eliminar `api/src/main/kotlin/com/worshiphub/security/WebSocketAuthInterceptor.kt`
    - Verificar que no existan otras clases que dependan de WebSocket y ajustar si es necesario
    - _Requisitos: 27.1, 27.2_

  - [x] 8.2 Eliminar dependencias de WebSocket del `build.gradle.kts`
    - Eliminar `org.springframework.boot:spring-boot-starter-websocket` de las dependencias
    - Eliminar `org.springframework:spring-messaging` de las dependencias
    - Verificar que el proyecto compila sin estas dependencias
    - _Requisitos: 27.5_

  - [x] 8.3 Eliminar headers CORS de WebSocket de `CorsConfig`
    - Eliminar los headers: "Upgrade", "Connection", "Sec-WebSocket-Key", "Sec-WebSocket-Version", "Sec-WebSocket-Extensions" de la configuración CORS
    - _Requisitos: 27.6_

  - [x] 8.4 Implementar estrategia de chat post-migración (polling + FCM data messages)
    - Asegurar que el endpoint REST de mensajes de chat soporta parámetro `since={timestamp}` para polling incremental
    - Configurar el `PushEvent.ChatMessage` para enviar FCM data messages silenciosos que disparen refresh en el frontend
    - Documentar la estrategia de polling (5-10s configurable) para el frontend
    - _Requisitos: 27.3, 27.4_

- [x] 9. Checkpoint — Verificar compilación completa del backend y tests existentes
  - Asegurar que todos los tests pasan tras la eliminación de WebSocket/STOMP, preguntar al usuario si surgen dudas.

- [x] 10. Implementar servicio de notificaciones push en Flutter (Android, iOS y Web)
  - [x] 10.1 Crear `PushNotificationService` en Flutter
    - Crear `worship_hub_ui/lib/core/services/push_notification_service.dart`
    - Inicializar `FirebaseMessaging`: solicitar permisos (alert, badge, sound), obtener token, escuchar `onTokenRefresh`
    - En iOS: solicitar permisos mediante diálogo nativo de iOS (UNUserNotificationCenter) con `provisional: false`
    - Configurar handlers: `onMessage` (primer plano → banner in-app), `onMessageOpenedApp` (tap desde background), `onBackgroundMessage` (handler top-level)
    - Registrar token en backend via `DeviceTokenRemoteDataSource` con plataforma correcta (ANDROID, IOS o WEB)
    - Desregistrar token en logout
    - _Requisitos: 1.1, 1.5, 1.6, 1.7, 12.4, 12.5, 26.1, 26.2, 26.6_

  - [x] 10.2 Crear `DeviceTokenRemoteDataSource` y repositorio
    - Crear `worship_hub_ui/lib/data/datasources/remote/device_token_remote_data_source.dart`
    - Métodos: `registerToken(token, platform)`, `unregisterToken(token)`
    - Crear `worship_hub_ui/lib/data/repositories/device_token_repository_impl.dart`
    - Manejar error de red: almacenar token localmente y reintentar cuando haya conexión
    - _Requisitos: 1.1, 1.2, 1.5_

  - [x] 10.3 Implementar deep linking desde notificaciones
    - Crear `worship_hub_ui/lib/core/services/notification_router.dart`
    - Mapear `type` del payload FCM a rutas de go_router según tabla del diseño:
      - SERVICE_INVITATION → `/calendar/service/{id}`, CHAT_MESSAGE → `/teams/{id}/chat`, NEW_COMMENT → `/songs/{id}`, TEAM_CHANGE → `/teams/{id}`, NEW_SONG → `/songs/{id}`, SERVICE_REMINDER → `/calendar/service/{id}`, SERVICE_CANCELLED → `/calendar`, RECURRING_SERVICE → `/calendar`, SONG_UPDATED → `/songs/{id}`, SONG_DELETED → `/songs`, SONG_ATTACHMENT → `/songs/{id}`, INVITATION_ACCEPTED → `/teams`, AVAILABILITY_CHANGE → `/calendar/availability`
    - Manejar caso de entidad inexistente: navegar a pantalla principal con mensaje de error
    - _Requisitos: 12.3, 12.5, 15.3, 26.3_

  - [x] 10.4 Implementar banner in-app para notificaciones en primer plano (Android e iOS)
    - Crear widget de banner overlay que se muestra cuando llega una notificación con la app activa
    - Usar `flutter_local_notifications` o un overlay personalizado
    - El banner debe ser tappable y navegar a la pantalla relevante
    - Funcionar tanto en Android como en iOS (interceptar con `FirebaseMessaging.onMessage`)
    - _Requisitos: 12.4, 26.6_

  - [x] 10.5 Integrar `PushNotificationService` en el flujo de autenticación
    - Modificar el flujo de login para llamar `pushNotificationService.initialize()` después de login exitoso
    - Modificar el flujo de logout para llamar `pushNotificationService.unregisterToken()`
    - Registrar `PushNotificationService` en GetIt (dependency injection)
    - _Requisitos: 1.1, 1.5_

  - [x] 10.6 Configurar categorías de notificación iOS para acciones rápidas
    - Crear `worship_hub_ui/lib/core/services/ios_notification_categories.dart`
    - Registrar categoría `SERVICE_ASSIGNMENT` con acciones "Aceptar" y "Declinar" usando `DarwinNotificationCategory`
    - Configurar `flutter_local_notifications` con las categorías iOS al inicializar
    - _Requisitos: 2.2, 15.4, 26.4_

- [x] 11. Eliminar notificaciones mock del frontend e integrar datos reales del backend
  - [x] 11.1 Crear modelo tipado `NotificationItem` para reemplazar Map<String, dynamic>
    - Crear `worship_hub_ui/lib/domain/entities/notification_item.dart`
    - Campos: id, title, body, type (NotificationType), createdAt, isRead, relatedEntityId, relatedEntityType
    - Implementar factory `fromJson` para deserialización desde API REST
    - _Requisitos: 28.4_

  - [x] 11.2 Refactorizar `NotificationsPage` eliminando datos mock
    - Eliminar todos los datos mock hardcodeados (List<Map<String, dynamic>> mockNotifications)
    - Integrar con `NotificationsBloc` usando `BlocBuilder`
    - Implementar estados: NotificationsLoading (spinner), NotificationsError (mensaje + retry), NotificationsEmpty (widget vacío), NotificationsLoaded (lista real)
    - _Requisitos: 28.1, 28.2, 28.3, 28.5_

  - [x] 11.3 Crear widget de estado vacío `EmptyNotificationsWidget`
    - Crear `worship_hub_ui/lib/presentation/features/notifications/widgets/empty_notifications_widget.dart`
    - Mostrar ícono, título "No tienes notificaciones" y subtítulo informativo
    - _Requisitos: 28.3_

  - [x] 11.4 Integrar `NotificationsBloc` con API REST del backend
    - Asegurar que el BLoC de notificaciones obtiene datos reales del endpoint REST existente
    - Mapear respuesta JSON a lista de `NotificationItem` tipados
    - Manejar estados de carga, error y datos vacíos
    - _Requisitos: 28.2, 28.5_

- [x] 12. Implementar pantalla de preferencias (filtrada por rol), canales Android y Service Worker web
  - [x] 12.1 Crear `NotificationPreferencesRemoteDataSource` y repositorio
    - Crear `worship_hub_ui/lib/data/datasources/remote/notification_preferences_remote_data_source.dart`
    - Métodos: `getPreferences()` → retorna objeto con `preferences`, `applicableTypes` y `userRole`, `updatePreferences(Map<String, bool>)`
    - Crear `worship_hub_ui/lib/data/repositories/notification_preferences_repository_impl.dart`
    - _Requisitos: 11.1, 11.5_

  - [x] 12.2 Crear `NotificationPreferencesBloc` con filtrado por rol
    - Crear `worship_hub_ui/lib/presentation/features/notifications/bloc/notification_preferences_bloc.dart`
    - Estados: loading, loaded (con mapa de preferencias Y lista de `applicableTypes`), error
    - Eventos: LoadPreferences, TogglePreference(type, enabled)
    - Al cargar preferencias, filtrar los tipos visibles según `applicableTypes` de la respuesta API
    - _Requisitos: 11.1, 11.5_

  - [x] 12.3 Crear pantalla de preferencias de notificación (filtrada por rol)
    - Crear `worship_hub_ui/lib/presentation/features/notifications/pages/notification_preferences_page.dart`
    - Lista de switches agrupados por categoría (Servicios, Chat, Equipo, Canciones)
    - **Solo mostrar switches para tipos incluidos en `applicableTypes`** de la respuesta del backend
    - Ocultar tipos no aplicables al rol actual del usuario (no mostrar switches deshabilitados, directamente ocultar)
    - Usar strings localizados (i18n) para todos los textos
    - _Requisitos: 11.1, 11.5, 11.7_

  - [x] 12.4 Configurar canales de notificación Android
    - Configurar 4 canales en `AndroidManifest.xml`: services, chat, team, songs
    - Crear canales programáticamente al inicializar `PushNotificationService`
    - Usar `flutter_local_notifications` para la configuración de canales
    - _Requisitos: 15.2_

  - [x] 12.5 Configurar Service Worker para Web Push
    - Crear `worship_hub_ui/web/firebase-messaging-sw.js`
    - Importar Firebase compat scripts y configurar `onBackgroundMessage`
    - Mostrar notificación nativa del navegador con ícono de WorshipHub
    - Manejar click en notificación para enfocar/abrir pestaña y navegar a pantalla relevante
    - _Requisitos: 14.1, 14.2, 14.3, 14.4_

  - [x] 12.6 Implementar polling de chat en el frontend (post-migración WebSocket)
    - Modificar la pantalla de chat para usar polling periódico (5-10s configurable) al endpoint REST `GET /api/v1/teams/{id}/chat/messages?since={timestamp}`
    - Integrar con FCM data messages silenciosos para refresh automático cuando llega un nuevo mensaje
    - _Requisitos: 27.3, 27.4_

- [x] 13. Integrar badge de notificaciones y lista en la navegación existente
  - [x] 13.1 Agregar badge de notificaciones no leídas en la barra de navegación
    - Modificar el widget de navegación principal para mostrar badge con conteo de no leídas
    - Conectar con el BLoC de notificaciones existente
    - _Requisitos: 12.1_

  - [x] 13.2 Verificar ordenamiento de lista de notificaciones por fecha descendente
    - Asegurar que la pantalla de notificaciones ordena por `createdAt` descendente
    - Agregar indicador visual de leída/no leída
    - Al tocar una notificación: marcar como leída y navegar via `NotificationRouter`
    - _Requisitos: 12.2, 12.3_

  - [x] 13.3 Implementar acciones rápidas en notificación de asignación a servicio (Android)
    - Configurar botones "Aceptar" y "Declinar" en la notificación Android de asignación
    - Usar `flutter_local_notifications` para configurar las acciones en el canal `services`
    - _Requisitos: 2.2, 15.4_

- [x] 14. Checkpoint — Verificar compilación completa frontend y backend
  - Asegurar que todos los tests pasan, preguntar al usuario si surgen dudas.

- [x] 15. Tests unitarios del backend — Servicios y componentes core (incluyendo rol)
  - [x] 15.1 Escribir tests unitarios para `DeviceTokenService`
    - Test: registro exitoso crea token en BD
    - Test: registro duplicado actualiza `lastUsedAt` en lugar de crear nuevo
    - Test: registro de token iOS con plataforma IOS
    - Test: desregistro elimina token del usuario
    - Test: desregistro de todos los tokens del usuario
    - _Requisitos: 1.2, 1.3, 1.5, 1.7, 29.1_

  - [x] 15.2 Escribir tests unitarios para `NotificationPreferencesService` (role-aware)
    - Test: preferencias por defecto para nuevo usuario (todo activado)
    - Test: actualización parcial de preferencias
    - Test: getPreferences retorna preferencias existentes
    - Test: getPreferences retorna `applicableTypes` según rol del usuario (Admin → todos, Miembro → subconjunto)
    - Test: onRoleChanged activa por defecto tipos recién disponibles al cambio ascendente (Miembro → Líder)
    - Test: onRoleChanged conserva preferencias de tipos no aplicables en BD al cambio descendente
    - _Requisitos: 11.1, 11.2, 11.4, 11.5, 11.6, 11.7, 29.1_

  - [x] 15.3 Escribir tests unitarios para `PushNotificationEventListener`
    - Test: cada tipo de PushEvent genera la llamada correcta a PushNotificationService
    - _Requisitos: 13.5, 29.1_

  - [x] 15.4 Escribir tests unitarios para `FirebasePushGateway`
    - Test: mapeo correcto de errores FCM a PushResult (UNREGISTERED → InvalidToken, UNAVAILABLE → TransientError, etc.)
    - Test: construcción correcta de Message con AndroidConfig y WebpushConfig
    - Test: construcción de mensaje incluye ApnsConfig con alert, badge, sound para iOS
    - Test: construcción de mensaje incluye categoría iOS `SERVICE_ASSIGNMENT` para asignaciones
    - _Requisitos: 13.1, 13.3, 13.4, 13.7, 26.5, 29.1_

  - [x] 15.5 Escribir tests unitarios para `ReminderSchedulerJob`
    - Test: no genera recordatorio para servicios DRAFT o CANCELLED
    - Test: no genera recordatorio para miembros con estado DECLINED
    - Test: genera recordatorio de 24h y 2h en las ventanas correctas
    - Test: no genera recordatorios duplicados
    - _Requisitos: 9.1, 9.2, 29.1_

  - [x] 15.6 Escribir tests unitarios para `RoleNotificationFilter`
    - Test: `isApplicableForRole` retorna true para Admin con cualquier tipo de notificación
    - Test: `isApplicableForRole` retorna false para Miembro con INVITATION_ACCEPTED
    - Test: `isApplicableForRole` retorna false para Miembro con AVAILABILITY_CHANGE
    - Test: `isApplicableForRole` retorna true para Líder_Equipo con AVAILABILITY_CHANGE
    - Test: `getApplicableTypes(ADMIN)` contiene todos los tipos de NotificationType
    - Test: `getApplicableTypes(TEAM_LEADER)` contiene el subconjunto correcto (15 tipos)
    - Test: `getApplicableTypes(MEMBER)` contiene el subconjunto correcto (9 tipos)
    - Test: `filterByRole` elimina usuarios cuyo rol no permite el tipo de notificación
    - Test: `filterByRole` conserva usuarios cuyo rol sí permite el tipo de notificación
    - _Requisitos: 30.1, 30.2, 30.3, 29.1_

  - [x] 15.7 Escribir tests unitarios para `UserRoleResolver`
    - Test: resuelve ADMIN si usuario es admin en alguna iglesia
    - Test: resuelve TEAM_LEADER si usuario es líder de algún equipo (y no admin)
    - Test: resuelve MEMBER como fallback cuando no es admin ni líder
    - Test: resuelve ADMIN cuando usuario es admin Y líder (mayor jerarquía gana)
    - _Requisitos: 30.5, 29.1_

  - [x] 15.8 Escribir tests unitarios para `UserRole.resolveHighest`
    - Test: `resolveHighest([ADMIN, MEMBER])` retorna ADMIN
    - Test: `resolveHighest([TEAM_LEADER, MEMBER])` retorna TEAM_LEADER
    - Test: `resolveHighest([MEMBER])` retorna MEMBER
    - Test: `resolveHighest([ADMIN, TEAM_LEADER, MEMBER])` retorna ADMIN
    - Test: `resolveHighest(emptyList())` retorna MEMBER (fallback)
    - _Requisitos: 30.5, 29.1_

  - [x] 15.9 Escribir tests unitarios para filtrado por rol en `PushNotificationService`
    - Test: omite push para usuario con rol Miembro cuando tipo es INVITATION_ACCEPTED
    - Test: envía push a usuario con rol Admin para cualquier tipo de notificación
    - Test: omite push para usuario con rol Miembro cuando tipo es AVAILABILITY_CHANGE
    - Test: envía push a usuario con rol Líder_Equipo cuando tipo es AVAILABILITY_CHANGE
    - Test: notificación in-app NO se almacena para usuarios filtrados por rol (no pasan el filtro)
    - _Requisitos: 30.1, 30.2, 30.4, 29.1_

- [x] 16. Tests unitarios del backend — Payloads y destinatarios por tipo de notificación (Requisito 29)
  - [x] 16.1 Escribir tests unitarios para payload de asignación a servicio (R2)
    - Test: payload contiene nombre del servicio, fecha programada y rol asignado
    - Test: destinatarios = miembros asignados al servicio
    - Test: notificación incluye channelId `services` y category `SERVICE_ASSIGNMENT`
    - _Requisitos: 2.1, 2.2, 2.3, 29.4, 29.5_

  - [x] 16.2 Escribir tests unitarios para payload de mensaje de chat (R3)
    - Test: payload contiene nombre del remitente, nombre del equipo y extracto del mensaje (máx 100 chars)
    - Test: destinatarios = miembros del equipo excepto remitente
    - Test: extracto se trunca correctamente a 100 caracteres
    - _Requisitos: 3.1, 3.3, 29.4, 29.5_

  - [x] 16.3 Escribir tests unitarios para payload de comentario en canción (R4)
    - Test: payload contiene nombre del comentarista, título de la canción y extracto del comentario (máx 100 chars)
    - Test: destinatarios = creador de la canción + comentaristas previos - comentarista actual
    - _Requisitos: 4.1, 4.2, 4.3, 29.4, 29.5_

  - [x] 16.4 Escribir tests unitarios para payload de cambios en equipo (R5)
    - Test: payload de nuevo miembro contiene nombre y rol
    - Test: payload de miembro removido notifica a miembros restantes
    - Test: payload de cambio de líder notifica a todos los miembros
    - Test: payload de cambio de rol notifica al miembro afectado
    - _Requisitos: 5.1, 5.2, 5.3, 5.4, 29.4, 29.5_

  - [x] 16.5 Escribir tests unitarios para payload de respuesta a invitación de servicio (R6)
    - Test: payload contiene nombre del miembro, nombre del servicio, fecha y si aceptó/declinó
    - Test: destinatario = líder del equipo
    - _Requisitos: 6.1, 6.2, 6.3, 29.4, 29.5_

  - [x] 16.6 Escribir tests unitarios para payload de nueva canción (R7)
    - Test: payload contiene título, artista y nombre del usuario que la agregó
    - Test: destinatarios = miembros activos de la iglesia excepto creador
    - _Requisitos: 7.1, 7.2, 29.4, 29.5_

  - [x] 16.7 Escribir tests unitarios para payload de invitación a iglesia (R8)
    - Test: payload contiene nombre de la iglesia y rol ofrecido
    - Test: destinatario = usuario existente invitado
    - _Requisitos: 8.1, 8.2, 29.4, 29.5_

  - [x] 16.8 Escribir tests unitarios para payload de recordatorio de servicio (R9)
    - Test: payload contiene nombre del servicio, hora programada y setlist (si existe)
    - Test: destinatarios = miembros asignados con estado ACCEPTED
    - _Requisitos: 9.1, 9.2, 9.3, 29.4, 29.5_

  - [x] 16.9 Escribir tests unitarios para payload de modificación de setlist (R10)
    - Test: payload contiene nombre del servicio, fecha y resumen del cambio
    - Test: destinatarios = miembros asignados al servicio
    - _Requisitos: 10.1, 10.2, 29.4, 29.5_

  - [x] 16.10 Escribir tests unitarios para payload de cancelación de servicio (R16)
    - Test: payload contiene nombre del servicio, fecha original y motivo (si se proporciona)
    - Test: destinatarios = miembros asignados al servicio
    - _Requisitos: 16.1, 16.2, 29.4, 29.5_

  - [x] 16.11 Escribir tests unitarios para payload de servicio recurrente creado (R17)
    - Test: payload contiene nombre del servicio, fechas consolidadas, patrón de recurrencia y rol
    - Test: se envía una sola notificación consolidada por miembro (no una por instancia)
    - Test: destinatarios = miembros asignados excepto programador
    - _Requisitos: 17.1, 17.2, 17.3, 29.4, 29.5_

  - [x] 16.12 Escribir tests unitarios para payload de actualización de regla de recurrencia (R18)
    - Test: payload contiene nombre del servicio padre, nuevo patrón y fechas afectadas
    - Test: payload incluye fechas eliminadas cuando la regla reduce instancias
    - Test: destinatarios = miembros asignados a instancias futuras afectadas excepto actor
    - _Requisitos: 18.1, 18.2, 18.3, 29.4, 29.5_

  - [x] 16.13 Escribir tests unitarios para payload de eliminación de servicio recurrente (R19)
    - Test: payload contiene nombre del servicio, fechas de instancias eliminadas y motivo
    - Test: destinatarios = miembros asignados a instancias eliminadas excepto eliminador
    - _Requisitos: 19.1, 19.2, 29.4, 29.5_

  - [x] 16.14 Escribir tests unitarios para payload de actualización de canción (R20)
    - Test: payload contiene título, campos modificados y nombre del actualizador
    - Test: destinatarios = usuarios con la canción en setlists de servicios futuros, excepto actualizador
    - Test: solo notifica a usuarios con setlists futuros, no pasados (edge case)
    - Test: deduplica cuando usuario tiene canción en múltiples setlists futuros (edge case)
    - _Requisitos: 20.1, 20.2, 20.3, 29.4, 29.5_

  - [x] 16.15 Escribir tests unitarios para payload de eliminación de canción (R21)
    - Test: payload contiene título, nombre del eliminador y nombres de setlists afectados
    - Test: destinatarios = usuarios con la canción en setlists excepto eliminador
    - _Requisitos: 21.1, 21.2, 29.4, 29.5_

  - [x] 16.16 Escribir tests unitarios para payload de attachment agregado (R22)
    - Test: payload contiene título de la canción, tipo de attachment y nombre del agregador
    - Test: destinatarios = creador de la canción + comentaristas previos - actor
    - _Requisitos: 22.1, 22.2, 29.4, 29.5_

  - [x] 16.17 Escribir tests unitarios para payload de invitación aceptada (R23)
    - Test: payload contiene nombre del nuevo miembro, email y rol aceptado
    - Test: destinatario = administrador que envió la invitación
    - _Requisitos: 23.1, 23.2, 29.4, 29.5_

  - [x] 16.18 Escribir tests unitarios para payload de indisponibilidad (R24)
    - Test: payload contiene nombre del miembro, fecha no disponible y motivo
    - Test: destinatarios = líderes del equipo del miembro
    - Test: no notifica si el miembro no pertenece a ningún equipo (edge case)
    - _Requisitos: 24.1, 24.2, 29.4, 29.5_

  - [x] 16.19 Escribir tests unitarios para payload de disponibilidad restaurada (R25)
    - Test: payload contiene nombre del miembro y fecha previamente no disponible
    - Test: destinatarios = líderes del equipo del miembro
    - _Requisitos: 25.1, 25.2, 29.4, 29.5_

  - [x] 16.20 Escribir tests unitarios para filtrado por preferencias de cada tipo
    - Test: para cada tipo de notificación, verificar que push se omite si preferencia desactivada
    - Test: para cada tipo de notificación, verificar que notificación in-app siempre se almacena (para usuarios que pasan filtro de rol)
    - _Requisitos: 11.2, 11.3, 29.6_

- [x] 17. Checkpoint — Verificar que todos los tests unitarios del backend pasan
  - Asegurar que todos los tests pasan, preguntar al usuario si surgen dudas.

- [x] 18. Tests E2E del backend — Flujo completo por tipo de notificación (Requisito 29) y filtrado por rol (Requisito 30)
  - [x] 18.1 Crear infraestructura de tests E2E con `MockPushGateway`
    - Crear `api/src/test/kotlin/com/worshiphub/api/config/TestFcmConfig.kt` con `@TestConfiguration`
    - Implementar `MockPushGateway` que registra mensajes enviados en `sentMessages` y retorna `PushResult.Success`
    - Método `findByType(type)` para filtrar mensajes por tipo de notificación
    - Método `reset()` para limpiar entre tests
    - Usar `Awaitility` para esperar procesamiento asíncrono en tests
    - _Requisitos: 29.7, 29.8_

  - [x] 18.2 Escribir test E2E para asignación a servicio (R2)
    - Setup: crear usuario, equipo, registrar token de dispositivo
    - Action: crear servicio y asignar miembro vía API REST
    - Verify: notificación in-app en BD + mock FCM recibió mensaje con payload correcto
    - _Requisitos: 2.1, 29.7, 29.9_

  - [x] 18.3 Escribir test E2E para mensaje de chat (R3)
    - Setup: crear equipo con miembros, registrar tokens
    - Action: enviar mensaje de chat vía API REST
    - Verify: mock FCM recibió mensajes para todos los miembros excepto remitente
    - _Requisitos: 3.1, 27.3, 29.7, 29.9_

  - [x] 18.4 Escribir test E2E para comentario en canción (R4)
    - Setup: crear canción, agregar comentarios previos, registrar tokens
    - Action: agregar nuevo comentario vía API REST
    - Verify: mock FCM recibió mensajes para creador + comentaristas previos - actor
    - _Requisitos: 4.1, 4.2, 29.7, 29.9_

  - [x] 18.5 Escribir test E2E para cambios en equipo (R5)
    - Setup: crear equipo con miembros, registrar tokens
    - Action: agregar nuevo miembro vía API REST
    - Verify: mock FCM recibió mensajes para miembros existentes
    - _Requisitos: 5.1, 29.7, 29.9_

  - [x] 18.6 Escribir test E2E para respuesta a invitación de servicio (R6)
    - Setup: crear servicio con asignación, registrar token del líder
    - Action: miembro acepta/declina asignación vía API REST
    - Verify: mock FCM recibió mensaje para el líder del equipo
    - _Requisitos: 6.1, 6.2, 29.7, 29.9_

  - [x] 18.7 Escribir test E2E para nueva canción (R7)
    - Setup: crear iglesia con miembros, registrar tokens
    - Action: agregar canción vía API REST
    - Verify: mock FCM recibió mensajes para miembros activos excepto creador
    - _Requisitos: 7.1, 29.7, 29.9_

  - [x] 18.8 Escribir test E2E para invitación a iglesia (R8)
    - Setup: crear usuario existente, registrar token
    - Action: enviar invitación vía API REST
    - Verify: mock FCM recibió mensaje para usuario invitado
    - _Requisitos: 8.1, 29.7, 29.9_

  - [x] 18.9 Escribir test E2E para recordatorio de servicio (R9)
    - Setup: crear servicio futuro con miembros aceptados, registrar tokens
    - Action: ejecutar `ReminderSchedulerJob` manualmente
    - Verify: mock FCM recibió mensajes de recordatorio para miembros aceptados
    - _Requisitos: 9.1, 9.2, 29.7, 29.9_

  - [x] 18.10 Escribir test E2E para modificación de setlist (R10)
    - Setup: crear servicio futuro con miembros, registrar tokens
    - Action: modificar setlist vía API REST
    - Verify: mock FCM recibió mensajes para miembros asignados
    - _Requisitos: 10.1, 29.7, 29.9_

  - [x] 18.11 Escribir test E2E para cancelación de servicio (R16)
    - Setup: crear servicio con miembros, registrar tokens
    - Action: cancelar servicio vía API REST
    - Verify: mock FCM recibió mensajes para miembros asignados
    - _Requisitos: 16.1, 29.7, 29.9_

  - [x] 18.12 Escribir test E2E para servicio recurrente creado (R17)
    - Setup: crear equipo con miembros, registrar tokens
    - Action: crear servicio recurrente con instancias vía API REST
    - Verify: mock FCM recibió exactamente 1 notificación consolidada por miembro
    - _Requisitos: 17.1, 17.2, 29.7, 29.9_

  - [x] 18.13 Escribir test E2E para actualización de regla de recurrencia (R18)
    - Setup: crear servicio recurrente con instancias y miembros, registrar tokens
    - Action: actualizar regla de recurrencia vía API REST
    - Verify: mock FCM recibió mensajes con fechas afectadas para miembros
    - _Requisitos: 18.1, 29.7, 29.9_

  - [x] 18.14 Escribir test E2E para eliminación de servicio recurrente (R19)
    - Setup: crear servicio recurrente con instancias y miembros, registrar tokens
    - Action: eliminar servicio recurrente vía API REST
    - Verify: mock FCM recibió mensajes para miembros de instancias eliminadas
    - _Requisitos: 19.1, 29.7, 29.9_

  - [x] 18.15 Escribir test E2E para actualización de canción (R20)
    - Setup: crear canción en setlists de servicios futuros, registrar tokens
    - Action: actualizar canción vía API REST
    - Verify: mock FCM recibió mensajes solo para usuarios con setlists futuros
    - _Requisitos: 20.1, 29.7, 29.9_

  - [x] 18.16 Escribir test E2E para eliminación de canción (R21)
    - Setup: crear canción en setlists, registrar tokens
    - Action: eliminar canción vía API REST
    - Verify: mock FCM recibió mensajes con setlists afectados
    - _Requisitos: 21.1, 29.7, 29.9_

  - [x] 18.17 Escribir test E2E para attachment agregado (R22)
    - Setup: crear canción con comentarios previos, registrar tokens
    - Action: agregar attachment vía API REST
    - Verify: mock FCM recibió mensajes para creador + comentaristas
    - _Requisitos: 22.1, 29.7, 29.9_

  - [x] 18.18 Escribir test E2E para invitación aceptada (R23)
    - Setup: enviar invitación, registrar token del admin
    - Action: aceptar invitación vía API REST
    - Verify: mock FCM recibió mensaje para admin invitador
    - _Requisitos: 23.1, 29.7, 29.9_

  - [x] 18.19 Escribir test E2E para cambio de disponibilidad — no disponible (R24)
    - Setup: crear equipo con líder, registrar token del líder
    - Action: miembro marca indisponibilidad vía API REST
    - Verify: mock FCM recibió mensaje para líder del equipo
    - _Requisitos: 24.1, 29.7, 29.9_

  - [x] 18.20 Escribir test E2E para cambio de disponibilidad — disponible de nuevo (R25)
    - Setup: crear equipo con líder, miembro con indisponibilidad, registrar token del líder
    - Action: miembro elimina indisponibilidad vía API REST
    - Verify: mock FCM recibió mensaje para líder del equipo
    - _Requisitos: 25.1, 29.7, 29.9_

  - [x] 18.21 Escribir test E2E para flujo de preferencias (filtrado por preferencia)
    - Setup: crear usuario con preferencia de chat desactivada, registrar token
    - Action: enviar mensaje de chat
    - Verify: notificación in-app SÍ se crea en BD, pero mock FCM NO recibió mensaje push
    - _Requisitos: 11.2, 11.3, 29.7_

  - [x] 18.22 Escribir test E2E para registro y desregistro de token (incluye iOS)
    - Test: login → registrar token Android → verificar en BD con plataforma ANDROID
    - Test: login en iOS → registrar token → verificar en BD con plataforma IOS
    - Test: logout → verificar que token se elimina de BD
    - _Requisitos: 1.2, 1.5, 1.7, 29.7_

  - [x] 18.23 Escribir test E2E para envío push con ApnsConfig a dispositivo iOS
    - Setup: registrar token con plataforma IOS
    - Action: crear servicio y asignar miembro
    - Verify: mock FCM recibió mensaje con ApnsConfig (alert, badge, sound, category)
    - _Requisitos: 13.7, 26.5, 29.7_

  - [x] 18.24 Escribir test E2E para filtrado por rol — Admin recibe todo (R30)
    - Setup: crear usuario con rol Admin, registrar token
    - Action: generar notificación de tipo INVITATION_ACCEPTED
    - Verify: mock FCM recibió mensaje para el Admin
    - _Requisitos: 30.1, 30.3, 29.7_

  - [x] 18.25 Escribir test E2E para filtrado por rol — Miembro excluido (R30)
    - Setup: crear usuario con rol Miembro, registrar token
    - Action: generar notificación de tipo INVITATION_ACCEPTED
    - Verify: mock FCM NO recibió mensaje para el Miembro (tipo no aplicable a su rol)
    - _Requisitos: 30.1, 30.2, 29.7_

  - [x] 18.26 Escribir test E2E para filtrado por rol — Líder excluido de tipos solo-Admin (R30)
    - Setup: crear usuario con rol Líder_Equipo, registrar token
    - Action: generar notificación de tipo INVITATION_ACCEPTED (solo Admin)
    - Verify: mock FCM NO recibió mensaje para el Líder_Equipo
    - _Requisitos: 30.1, 30.2, 30.3, 29.7_

  - [x] 18.27 Escribir test E2E para cambio de rol ascendente — activación de preferencias (R30/R11)
    - Setup: crear usuario con rol Miembro, verificar preferencias iniciales
    - Action: cambiar rol a Líder_Equipo vía API REST
    - Verify: GET preferencias retorna nuevos `applicableTypes` y tipos recién disponibles activados por defecto
    - _Requisitos: 11.6, 30.5, 29.7_

  - [x] 18.28 Escribir test E2E para cambio de rol descendente — ocultación de preferencias (R30/R11)
    - Setup: crear usuario con rol Líder_Equipo, configurar preferencias
    - Action: cambiar rol a Miembro
    - Verify: GET preferencias oculta tipos no aplicables al nuevo rol, pero preferencias se conservan en BD
    - _Requisitos: 11.7, 29.7_

  - [x] 18.29 Escribir test E2E para preferencias con rol — respuesta API incluye applicableTypes
    - Setup: crear usuario con rol Miembro
    - Action: GET /api/v1/notifications/preferences
    - Verify: respuesta incluye `applicableTypes` correspondiente al Mapa_Notificaciones_Rol de Miembro y `userRole: "MEMBER"`
    - _Requisitos: 11.5, 30.3, 29.7_

- [x] 19. Tests de propiedades del backend (Kotest Property) — 25 propiedades
  - [x] 19.1 Escribir test de propiedad para round-trip de registro de token
    - **Propiedad 1: Round-trip de registro de token**
    - Generar combinaciones aleatorias de (userId, token, plataforma incluyendo IOS), registrar y verificar que findByUserId retorna el token correcto
    - Generadores: `Arb.uuid()`, `Arb.string(50..300)`, `Arb.enum<DevicePlatform>()`
    - **Valida: Requisitos 1.2**

  - [x] 19.2 Escribir test de propiedad para almacenamiento y entrega multi-dispositivo
    - **Propiedad 2: Almacenamiento y entrega multi-dispositivo**
    - Para un usuario con N tokens distintos (Android, iOS, Web), verificar que se intenta entrega a exactamente N tokens
    - Generadores: `Arb.uuid()`, `Arb.list(Arb.string(), 1..10)`
    - **Valida: Requisitos 1.3, 2.3, 13.6**

  - [x] 19.3 Escribir test de propiedad para limpieza de tokens inválidos
    - **Propiedad 3: Limpieza de tokens inválidos**
    - Simular PushResult.InvalidToken y verificar que el token se elimina de la BD
    - Generadores: `Arb.string(50..300)`
    - **Valida: Requisitos 1.4, 13.3**

  - [x] 19.4 Escribir test de propiedad para exclusión del remitente en chat
    - **Propiedad 4: Exclusión del remitente en chat**
    - Para un equipo con miembros M y remitente S, verificar que recipientUserIds = M \ {S}
    - Generadores: `Arb.set(Arb.uuid(), 2..20)`, selección aleatoria de remitente
    - **Valida: Requisitos 3.1**

  - [x] 19.5 Escribir test de propiedad para truncamiento de extractos de texto
    - **Propiedad 5: Truncamiento de extractos de texto**
    - Para cadenas de longitud arbitraria, verificar que el extracto tiene máximo 100 caracteres y es prefijo de la original
    - Generadores: `Arb.string(0..500)`
    - **Valida: Requisitos 3.3, 4.3**

  - [x] 19.6 Escribir test de propiedad para agregación de destinatarios de comentarios
    - **Propiedad 6: Agregación de destinatarios de comentarios en canciones**
    - Para creador C, comentaristas P, nuevo comentarista N, verificar que destinatarios = (P ∪ {C}) \ {N}
    - Generadores: `Arb.uuid()` creador, `Arb.set(Arb.uuid())` comentaristas, `Arb.uuid()` nuevo comentarista
    - **Valida: Requisitos 4.1, 4.2**

  - [x] 19.7 Escribir test de propiedad para broadcast de cambios de equipo
    - **Propiedad 7: Broadcast de cambios de equipo**
    - Para equipo con miembros M, verificar que todos están en recipientUserIds
    - Generadores: `Arb.set(Arb.uuid(), 1..30)`
    - **Valida: Requisitos 5.1, 5.2, 5.3**

  - [x] 19.8 Escribir test de propiedad para broadcast de nueva canción
    - **Propiedad 8: Broadcast de nueva canción a la iglesia**
    - Para iglesia con miembros A y creador C, verificar que destinatarios = A \ {C}
    - Generadores: `Arb.set(Arb.uuid(), 2..50)`, selección aleatoria de creador
    - **Valida: Requisitos 7.1**

  - [x] 19.9 Escribir test de propiedad para ventana temporal de recordatorios
    - **Propiedad 9: Ventana temporal de recordatorios**
    - Para fecha de servicio D y momento actual T, verificar que recordatorio 24h se genera si 0 < (D-T) ≤ 24h, y recordatorio 2h si 0 < (D-T) ≤ 2h
    - Generadores: `Arb.localDateTime()`
    - **Valida: Requisitos 9.1, 9.2**

  - [x] 19.10 Escribir test de propiedad para broadcast de cambios en servicio
    - **Propiedad 10: Broadcast de cambios en servicio a miembros asignados**
    - Para servicio con miembros asignados AM, verificar que todos están en recipientUserIds
    - Generadores: `Arb.set(Arb.uuid(), 1..20)`
    - **Valida: Requisitos 10.1, 16.1**

  - [x] 19.11 Escribir test de propiedad para filtrado por preferencias
    - **Propiedad 11: Filtrado por preferencias de notificación**
    - Para cada tipo y configuración de preferencia, verificar que push se envía solo si activado, y notificación in-app siempre se almacena
    - Generadores: `Arb.enum<NotificationType>()`, `Arb.boolean()`
    - **Valida: Requisitos 11.2, 11.3**

  - [x] 19.12 Escribir test de propiedad para ordenamiento de notificaciones
    - **Propiedad 12: Ordenamiento de lista de notificaciones**
    - Para lista de notificaciones con fechas arbitrarias, verificar que el resultado está ordenado descendente por createdAt
    - Generadores: `Arb.list(Arb.localDateTime(), 1..50)`
    - **Valida: Requisitos 12.2**

  - [x] 19.13 Escribir test de propiedad para reintento con backoff exponencial
    - **Propiedad 13: Reintento con backoff exponencial para errores transitorios**
    - Simular errores transitorios y verificar que se reintenta máximo 3 veces con delays crecientes
    - Mock de PushGateway que retorna TransientError
    - **Valida: Requisitos 13.4**

  - [x] 19.14 Escribir test de propiedad para consolidación de servicio recurrente
    - **Propiedad 14: Consolidación de notificaciones de servicio recurrente**
    - Para servicio recurrente con N instancias y M miembros, verificar que cada miembro recibe exactamente 1 notificación con N fechas
    - Generadores: `Arb.set(Arb.uuid(), 2..15)`, `Arb.list(Arb.localDateTime(), 1..12)`
    - **Valida: Requisitos 17.1, 17.2**

  - [x] 19.15 Escribir test de propiedad para exclusión del actor en recurrentes
    - **Propiedad 15: Exclusión del actor en eventos de servicio recurrente**
    - Para actor A y miembros asignados, verificar que A no está en recipientUserIds
    - Generadores: `Arb.uuid()` actor, `Arb.set(Arb.uuid(), 2..20)`
    - **Valida: Requisitos 17.1, 18.1, 19.1**

  - [x] 19.16 Escribir test de propiedad para destinatarios limitados a setlists futuros
    - **Propiedad 16: Destinatarios de actualización de canción limitados a setlists futuros**
    - Verificar que solo usuarios con la canción en setlists de servicios futuros reciben notificación
    - Generadores: `Arb.set(Arb.uuid())` usuarios con setlists futuros vs pasados
    - **Valida: Requisitos 20.1**

  - [x] 19.17 Escribir test de propiedad para deduplicación por canción en múltiples setlists
    - **Propiedad 17: Deduplicación de destinatarios por actualización de canción**
    - Para usuario con canción en múltiples setlists futuros, verificar que recibe exactamente 1 notificación
    - Generadores: `Arb.uuid()` usuario, `Arb.list(Arb.uuid(), 2..5)` setlists
    - **Valida: Requisitos 20.3**

  - [x] 19.18 Escribir test de propiedad para destinatarios de eliminación de canción
    - **Propiedad 18: Destinatarios de eliminación de canción incluyen todos los setlists**
    - Para canción en setlists de usuarios U, verificar que todos en U (excepto eliminador) reciben notificación con nombres de setlists
    - Generadores: `Arb.set(Arb.uuid(), 1..20)`
    - **Valida: Requisitos 21.1, 21.2**

  - [x] 19.19 Escribir test de propiedad para destinatarios de attachment
    - **Propiedad 19: Destinatarios de attachment = creador + comentaristas previos**
    - Para creador C, comentaristas P, actor A, verificar que destinatarios = (P ∪ {C}) \ {A}
    - Generadores: `Arb.uuid()` creador, `Arb.set(Arb.uuid())` comentaristas, `Arb.uuid()` actor
    - **Valida: Requisitos 22.1**

  - [x] 19.20 Escribir test de propiedad para invitación aceptada al invitador
    - **Propiedad 20: Notificación de invitación aceptada al invitador correcto**
    - Para admin que envió invitación y usuario que acepta, verificar que el único destinatario es admin
    - Generadores: `Arb.uuid()` admin, `Arb.uuid()` nuevo miembro
    - **Valida: Requisitos 23.1**

  - [x] 19.21 Escribir test de propiedad para disponibilidad notifica al líder
    - **Propiedad 21: Notificación de disponibilidad al líder de equipo**
    - Para miembro M y líderes L, verificar que recipientUserIds = L
    - Generadores: `Arb.uuid()` miembro, `Arb.set(Arb.uuid(), 1..3)` líderes
    - **Valida: Requisitos 24.1, 25.1**

  - [x] 19.22 Escribir test de propiedad para filtrado de notificaciones por rol
    - **Propiedad 22: Filtrado de notificaciones por rol de usuario**
    - Para cualquier tipo de notificación T y rol R, verificar que `RoleNotificationFilter.isApplicableForRole(T, R)` retorna true si y solo si T está en `Mapa_Notificaciones_Rol[R]`
    - Verificar que si T no es aplicable al rol R, el usuario NO recibe push incluso con token registrado y preferencias activadas
    - Generadores: `Arb.enum<NotificationType>()`, `Arb.enum<UserRole>()`
    - **Valida: Requisitos 30.1, 30.2**

  - [x] 19.23 Escribir test de propiedad para resolución de jerarquía de roles
    - **Propiedad 23: Resolución de jerarquía de roles**
    - Para cualquier lista de roles asignados, verificar que `UserRole.resolveHighest` retorna el rol de mayor jerarquía (Admin > Líder_Equipo > Miembro)
    - Verificar que si la lista contiene ADMIN, siempre retorna ADMIN
    - Verificar que si la lista contiene TEAM_LEADER pero no ADMIN, retorna TEAM_LEADER
    - Generadores: `Arb.list(Arb.enum<UserRole>(), 1..3)`
    - **Valida: Requisitos 30.5**

  - [x] 19.24 Escribir test de propiedad para visibilidad de preferencias según rol
    - **Propiedad 24: Visibilidad de preferencias según rol**
    - Para cualquier rol R, verificar que `getApplicableTypes(R)` retorna exactamente los tipos definidos en `Mapa_Notificaciones_Rol[R]`
    - Verificar que la respuesta del endpoint GET de preferencias marca como aplicables exactamente esos tipos
    - Generadores: `Arb.enum<UserRole>()`
    - **Valida: Requisitos 11.5, 11.7**

  - [x] 19.25 Escribir test de propiedad para activación por defecto al cambio de rol ascendente
    - **Propiedad 25: Activación por defecto al cambio de rol ascendente**
    - Para cualquier cambio de rol de R_anterior a R_nuevo (mayor jerarquía), verificar que los tipos recién disponibles (`Mapa_Notificaciones_Rol[R_nuevo] - Mapa_Notificaciones_Rol[R_anterior]`) están activados por defecto en las preferencias
    - Verificar que las preferencias existentes de tipos previamente disponibles no se modifican
    - Generadores: `Arb.enum<UserRole>()` rol anterior, `Arb.enum<UserRole>()` rol nuevo (filtrar para que nuevo > anterior en jerarquía)
    - **Valida: Requisitos 11.6**

- [x] 20. Tests del frontend (Flutter)
  - [x] 20.1 Escribir tests unitarios para `PushNotificationService` (Flutter)
    - Test: inicialización solicita permisos y registra token
    - Test: solicitud de permisos iOS (UNUserNotificationCenter)
    - Test: registro de categorías de notificación iOS
    - Test: `onTokenRefresh` registra nuevo token automáticamente
    - Test: logout desregistra token
    - _Requisitos: 1.1, 1.7, 26.2, 26.4_

  - [x] 20.2 Escribir tests para `NotificationPreferencesBloc` (con filtrado por rol)
    - Test: estado inicial es loading
    - Test: LoadPreferences carga preferencias del API incluyendo `applicableTypes`
    - Test: TogglePreference actualiza preferencia individual
    - Test: manejo de error de red
    - Test: filtra tipos visibles según `applicableTypes` de la respuesta API
    - _Requisitos: 11.1, 11.5_

  - [x] 20.3 Escribir tests para `NotificationsBloc` con datos reales
    - Test: estado loading al iniciar carga
    - Test: estado loaded con lista de NotificationItem del API
    - Test: estado empty cuando no hay notificaciones
    - Test: estado error con opción de retry
    - _Requisitos: 28.2, 28.5_

  - [x] 20.4 Escribir widget tests para `NotificationsPage` refactorizada
    - Test: muestra estado vacío (`EmptyNotificationsWidget`) cuando no hay notificaciones
    - Test: muestra lista de notificaciones reales (no mock)
    - Test: muestra spinner durante carga
    - Test: muestra error con botón de retry
    - _Requisitos: 28.1, 28.3_

  - [x] 20.5 Escribir tests para `NotificationItem` model
    - Test: deserialización correcta desde JSON del API
    - Test: manejo de campos opcionales (relatedEntityId, relatedEntityType)
    - _Requisitos: 28.4_

  - [x] 20.6 Escribir tests para `NotificationRouter` (deep linking)
    - Test: mapeo de cada tipo de notificación a ruta correcta (todos los tipos incluyendo RECURRING_SERVICE, SONG_UPDATED, etc.)
    - Test: manejo de entidad inexistente → pantalla principal con error
    - _Requisitos: 12.3, 12.5_

  - [x] 20.7 Escribir widget tests para banner in-app y badge
    - Test: banner se muestra cuando app está en primer plano (Android e iOS)
    - Test: badge muestra conteo correcto de no leídas
    - _Requisitos: 12.1, 12.4, 26.6_

  - [x] 20.8 Escribir widget tests para pantalla de preferencias filtrada por rol
    - Test: solo muestra toggles de tipos incluidos en `applicableTypes`
    - Test: oculta toggles de tipos no aplicables al rol actual (no muestra switches deshabilitados)
    - Test: al cambiar de rol, la pantalla refleja los nuevos tipos aplicables
    - _Requisitos: 11.5, 11.7_

  - [x] 20.9 Escribir tests de propiedad del frontend (glados)
    - **Propiedad 12: Ordenamiento de lista de notificaciones** — verificar ordenamiento descendente por fecha con generadores de listas de DateTime
    - **Propiedad 5: Truncamiento de extractos de texto** — si se implementa truncamiento en frontend, verificar máximo 100 caracteres y prefijo correcto
    - _Requisitos: 12.2, 3.3, 4.3_

- [x] 21. Checkpoint final — Verificar que todos los tests pasan
  - Asegurar que todos los tests unitarios, E2E y de propiedades pasan en backend y frontend.
  - Verificar cobertura de los 30 requisitos.
  - Preguntar al usuario si surgen dudas.

## Notas

- Las tareas marcadas con `*` son opcionales y pueden omitirse para un MVP más rápido
- Cada tarea referencia requisitos específicos para trazabilidad
- Los checkpoints aseguran validación incremental
- Los tests de propiedades validan las 25 propiedades de correctitud universales del diseño (P1-P25), incluyendo las 4 nuevas propiedades de filtrado por rol (P22-P25)
- Los tests unitarios por tipo de notificación (tarea 16) cubren el Requisito 29 para los 19 tipos de notificación (R2-R25)
- Los tests E2E por tipo de notificación (tarea 18) cubren el Requisito 29 con flujo completo usando MockPushGateway, incluyendo 6 tests E2E nuevos para filtrado por rol (18.24-18.29)
- El soporte iOS (Requisito 26) está integrado transversalmente en las tareas de dominio (DevicePlatform.IOS), infraestructura (ApnsConfig), frontend (categorías iOS, permisos UNUserNotificationCenter) y testing
- La migración de WebSocket/STOMP (Requisito 27) se ejecuta en la tarea 8 como bloque independiente
- La eliminación de mocks del frontend (Requisito 28) se ejecuta en la tarea 11 como bloque independiente
- El filtrado por rol de usuario (Requisito 30) está integrado transversalmente:
  - **Dominio** (tarea 1.6-1.7): `UserRole` enum con resolución de jerarquía y `RoleNotificationFilter` object con `Mapa_Notificaciones_Rol`
  - **Aplicación** (tarea 5.1-5.2, 5.5): `UserRoleResolver` para resolver rol efectivo, `PushNotificationService` con filtrado por rol antes de preferencias, `NotificationPreferencesService` con respuesta role-aware y `onRoleChanged`
  - **Integración** (tarea 6.5): Invocación de `onRoleChanged` al cambiar rol de usuario
  - **API** (tarea 7.2): Respuesta GET de preferencias incluye `applicableTypes` y `userRole`
  - **Frontend** (tareas 12.1-12.3): Pantalla de preferencias filtrada por `applicableTypes`
  - **Testing** (tareas 15.6-15.9, 18.24-18.29, 19.22-19.25, 20.8): Tests unitarios, E2E y de propiedades para todos los componentes de filtrado por rol