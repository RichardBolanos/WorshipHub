# Plan de Implementación: Módulo de Equipos

## Visión General

Implementación incremental del módulo de equipos para WorshipHub. Se comienza con los DTOs y endpoints del backend, luego el servicio de aplicación, notificaciones, y finalmente las entidades, use cases, BLoC y páginas del frontend. Cada paso construye sobre el anterior para evitar código huérfano.

## Tareas

- [x] 1. Backend — DTOs de Request/Response y Commands
  - [x] 1.1 Crear DTOs de request: `UpdateTeamRequest`, `UpdateMemberRoleRequest` en `worship_hub_api/api/src/main/kotlin/com/worshiphub/api/organization/`
    - `UpdateTeamRequest` con validaciones Jakarta (`@NotBlank`, `@Size(min=1, max=100)` para nombre, `@Size(max=500)` para descripción, `@NotNull` para leaderId)
    - `UpdateMemberRoleRequest` con `@NotNull` para teamRole de tipo `TeamRole`
    - _Requisitos: 3.3, 5.3, 7.3_
  - [x] 1.2 Crear DTOs de response: `TeamMemberResponse`, `UpcomingServiceResponse`, `MemberAvailabilityResponse`, `UnavailableDateResponse`, `TeamSummaryResponse`, `AssignTeamMemberResponse` en `worship_hub_api/api/src/main/kotlin/com/worshiphub/api/organization/`
    - Incluir Schema annotations de OpenAPI para documentación Swagger
    - _Requisitos: 6.1, 9.2, 10.2, 11.2_
  - [x] 1.3 Crear `UpdateTeamCommand` en `worship_hub_api/application/src/main/kotlin/com/worshiphub/application/organization/`
    - Data class con `teamId: UUID`, `name: String`, `description: String?`, `leaderId: UUID`
    - _Requisitos: 3.5_

- [x] 2. Backend — Nuevos métodos en repositorios de dominio e infraestructura
  - [x] 2.1 Agregar métodos `deleteByTeamId(teamId: UUID)` y `countByTeamId(teamId: UUID): Int` a la interfaz `TeamMemberRepository` y su implementación en `TeamMemberRepositoryImpl`
    - Agregar queries correspondientes en `JpaTeamMemberRepository`
    - _Requisitos: 4.4, 11.2_
  - [x] 2.2 Agregar método `findByUserIdAndDateRange(userId: UUID, startDate: LocalDate, endDate: LocalDate): List<UserAvailability>` a la interfaz `UserAvailabilityRepository` y su implementación
    - _Requisitos: 10.4_

- [x] 3. Backend — Nuevos métodos en OrganizationApplicationService
  - [x] 3.1 Implementar `getTeamsByChurchId(churchId: UUID): Result<List<Team>>` en `OrganizationApplicationService`
    - Usar `teamRepository.findByChurchId(churchId)`
    - _Requisitos: 1.1, 1.2_
  - [x] 3.2 Implementar `getTeamById(teamId: UUID): Result<Team>` en `OrganizationApplicationService`
    - Retornar `NotFoundException` si no existe
    - _Requisitos: 2.1, 2.2, 2.3_
  - [x] 3.3 Implementar `updateTeam(command: UpdateTeamCommand): Result<Team>` en `OrganizationApplicationService`
    - Buscar equipo existente, actualizar campos, guardar. Retornar 404 si no existe
    - Crear notificación `TEAM_LEADER_CHANGED` si el líder cambió
    - _Requisitos: 3.1, 3.5, 12.4_
  - [x] 3.4 Implementar `deleteTeam(teamId: UUID): Result<Unit>` en `OrganizationApplicationService`
    - Eliminar todos los TeamMember con `teamMemberRepository.deleteByTeamId(teamId)` antes de eliminar el equipo
    - _Requisitos: 4.1, 4.4_
  - [x] 3.5 Refactorizar `assignTeamMember` para verificar duplicados (409) y crear notificaciones `TEAM_MEMBER_ADDED`
    - Verificar con `findByTeamIdAndUserId` antes de insertar; lanzar `ConflictException` si ya existe
    - Crear notificación para cada miembro existente del equipo
    - _Requisitos: 5.1, 5.5, 12.1_
  - [x] 3.6 Refactorizar `removeTeamMember` para retornar `Result<Unit>`, verificar existencia (404) y crear notificaciones `TEAM_MEMBER_REMOVED`
    - _Requisitos: 8.1, 8.2, 12.2_
  - [x] 3.7 Refactorizar `updateTeamMemberRole` para retornar `Result<Unit>`, verificar existencia (404) y crear notificación `TEAM_ROLE_CHANGED`
    - _Requisitos: 7.1, 7.2, 12.3_
  - [x] 3.8 Implementar `getUpcomingServices(teamId: UUID): Result<List<UpcomingServiceDTO>>` en `OrganizationApplicationService`
    - Consultar `ServiceEventRepository` para servicios futuros del equipo, ordenar por `scheduledDate` ascendente
    - Incluir conteo de confirmados vs asignados por servicio
    - _Requisitos: 9.1, 9.2, 9.3_
  - [x] 3.9 Implementar `getTeamAvailability(teamId: UUID, startDate: LocalDate, endDate: LocalDate): Result<List<MemberAvailabilityDTO>>` en `OrganizationApplicationService`
    - Obtener miembros del equipo, consultar `UserAvailabilityRepository.findByUserIdAndDateRange` para cada miembro
    - Filtrar fechas estrictamente dentro del rango [startDate, endDate]
    - _Requisitos: 10.1, 10.2, 10.4_
  - [x] 3.10 Implementar `getTeamSummary(teamId: UUID): Result<TeamSummaryDTO>` en `OrganizationApplicationService`
    - Calcular `totalMembers` con `teamMemberRepository.countByTeamId`
    - Calcular `roleDistribution` agrupando miembros por `teamRole`
    - Calcular `recentServicesCount` (últimos 30 días) y `upcomingServicesCount` (futuros) desde `ServiceEventRepository`
    - _Requisitos: 11.1, 11.2, 11.4_

- [x] 4. Backend — Extender TeamController con nuevos endpoints
  - [x] 4.1 Agregar endpoint `GET /api/v1/teams` en `TeamController`
    - `@PreAuthorize` con CHURCH_ADMIN, WORSHIP_LEADER, TEAM_MEMBER
    - Recibir `@RequestHeader("Church-Id") churchId: UUID`
    - Llamar a `organizationApplicationService.getTeamsByChurchId(churchId)`
    - _Requisitos: 1.1, 1.2, 1.3_
  - [x] 4.2 Agregar endpoint `GET /api/v1/teams/{teamId}` en `TeamController`
    - `@PreAuthorize` con CHURCH_ADMIN, WORSHIP_LEADER, TEAM_MEMBER
    - Retornar 404 si no existe
    - _Requisitos: 2.1, 2.2_
  - [x] 4.3 Agregar endpoint `PUT /api/v1/teams/{teamId}` en `TeamController`
    - `@PreAuthorize` con CHURCH_ADMIN, WORSHIP_LEADER
    - Recibir `@Valid @RequestBody UpdateTeamRequest`
    - _Requisitos: 3.1, 3.2, 3.3, 3.4_
  - [x] 4.4 Agregar endpoint `DELETE /api/v1/teams/{teamId}` en `TeamController`
    - `@PreAuthorize` con CHURCH_ADMIN
    - Retornar `HttpStatus.NO_CONTENT`
    - _Requisitos: 4.1, 4.2, 4.3_
  - [x] 4.5 Agregar endpoint `POST /api/v1/teams/{teamId}/members` en `TeamController`
    - `@PreAuthorize` con CHURCH_ADMIN, WORSHIP_LEADER
    - Retornar `HttpStatus.CREATED` con `AssignTeamMemberResponse`
    - Manejar 409 para miembro duplicado
    - _Requisitos: 5.1, 5.2, 5.3, 5.4, 5.5_
  - [x] 4.6 Agregar endpoint `GET /api/v1/teams/{teamId}/members` en `TeamController`
    - `@PreAuthorize` con CHURCH_ADMIN, WORSHIP_LEADER, TEAM_MEMBER
    - Retornar lista de `TeamMemberResponse`
    - _Requisitos: 6.1, 6.2, 6.3_
  - [x] 4.7 Agregar endpoint `PUT /api/v1/teams/{teamId}/members/{userId}/role` en `TeamController`
    - `@PreAuthorize` con CHURCH_ADMIN, WORSHIP_LEADER
    - Recibir `@Valid @RequestBody UpdateMemberRoleRequest`
    - _Requisitos: 7.1, 7.2, 7.3, 7.4_
  - [x] 4.8 Agregar endpoint `DELETE /api/v1/teams/{teamId}/members/{userId}` en `TeamController`
    - `@PreAuthorize` con CHURCH_ADMIN, WORSHIP_LEADER
    - Retornar `HttpStatus.NO_CONTENT`
    - _Requisitos: 8.1, 8.2, 8.3_
  - [x] 4.9 Agregar endpoint `GET /api/v1/teams/{teamId}/upcoming-services` en `TeamController`
    - `@PreAuthorize` con CHURCH_ADMIN, WORSHIP_LEADER, TEAM_MEMBER
    - Retornar lista de `UpcomingServiceResponse`
    - _Requisitos: 9.1, 9.2, 9.3, 9.4_
  - [x] 4.10 Agregar endpoint `GET /api/v1/teams/{teamId}/availability` en `TeamController`
    - `@PreAuthorize` con CHURCH_ADMIN, WORSHIP_LEADER
    - Recibir `@RequestParam startDate` y `endDate` como `LocalDate`
    - Retornar lista de `MemberAvailabilityResponse`
    - _Requisitos: 10.1, 10.2, 10.3_
  - [x] 4.11 Agregar endpoint `GET /api/v1/teams/{teamId}/summary` en `TeamController`
    - `@PreAuthorize` con CHURCH_ADMIN, WORSHIP_LEADER, TEAM_MEMBER
    - Retornar `TeamSummaryResponse`
    - _Requisitos: 11.1, 11.2, 11.3_

- [x] 5. Backend — Extender NotificationType
  - [x] 5.1 Agregar valores `TEAM_MEMBER_ADDED`, `TEAM_MEMBER_REMOVED`, `TEAM_ROLE_CHANGED`, `TEAM_LEADER_CHANGED` al enum `NotificationType`
    - _Requisitos: 12.1, 12.2, 12.3, 12.4_

- [x] 6. Checkpoint — Verificar compilación y tests del backend
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Backend — Tests basados en propiedades (Kotest)
  - [x] 7.1 Escribir test de propiedad para round-trip CRUD de equipos
    - **Propiedad 1: Round-trip de CRUD de equipos**
    - **Valida: Requisitos 2.1, 3.1, 4.1**
  - [x] 7.2 Escribir test de propiedad para validación de restricciones de entrada
    - **Propiedad 2: Validación de restricciones de entrada**
    - **Valida: Requisitos 3.3, 5.3, 7.3**
  - [x] 7.3 Escribir test de propiedad para autorización por endpoint
    - **Propiedad 3: Aplicación de autorización por endpoint**
    - **Valida: Requisitos 1.3, 3.4, 4.3, 5.4, 6.3, 7.4, 8.3, 9.4, 10.3, 11.3**
  - [x] 7.4 Escribir test de propiedad para unicidad de membresía
    - **Propiedad 4: Unicidad de membresía en equipo**
    - **Valida: Requisitos 5.5**
  - [x] 7.5 Escribir test de propiedad para eliminación en cascada
    - **Propiedad 5: Eliminación en cascada de miembros**
    - **Valida: Requisitos 4.4**
  - [x] 7.6 Escribir test de propiedad para round-trip CRUD de miembros
    - **Propiedad 6: Round-trip de CRUD de miembros**
    - **Valida: Requisitos 5.1, 6.1, 7.1, 8.1**
  - [x] 7.7 Escribir test de propiedad para ordenamiento de próximos servicios
    - **Propiedad 7: Ordenamiento de próximos servicios**
    - **Valida: Requisitos 9.1, 9.2**
  - [x] 7.8 Escribir test de propiedad para filtrado de disponibilidad por rango
    - **Propiedad 8: Filtrado de disponibilidad por rango de fechas**
    - **Valida: Requisitos 10.1, 10.2**
  - [x] 7.9 Escribir test de propiedad para consistencia del resumen
    - **Propiedad 9: Consistencia del resumen del equipo**
    - **Valida: Requisitos 11.2**
  - [x] 7.10 Escribir test de propiedad para notificaciones por mutaciones
    - **Propiedad 10: Creación de notificaciones por mutaciones de miembros**
    - **Valida: Requisitos 12.1, 12.2, 12.3, 12.4**
  - [x] 7.11 Escribir test de propiedad para filtrado por iglesia
    - **Propiedad 11: Filtrado de equipos por iglesia**
    - **Valida: Requisitos 1.1**


- [x] 8. Frontend — Nuevas entidades de dominio
  - [x] 8.1 Crear entidad `UpcomingService` en `worship_hub_ui/lib/domain/entities/upcoming_service.dart`
    - Campos: `id`, `name`, `scheduledDate`, `status`, `confirmedCount`, `assignedCount`
    - Incluir `copyWith` y constructor
    - _Requisitos: 9.2, 13.3_
  - [x] 8.2 Crear entidades `MemberAvailability` y `UnavailableDate` en `worship_hub_ui/lib/domain/entities/member_availability.dart`
    - `MemberAvailability`: `userId`, `teamRole`, `unavailableDates`
    - `UnavailableDate`: `date`, `reason`
    - _Requisitos: 10.2, 16.2, 16.3_
  - [x] 8.3 Crear entidad `TeamSummary` en `worship_hub_ui/lib/domain/entities/team_summary.dart`
    - Campos: `totalMembers`, `recentServicesCount`, `upcomingServicesCount`, `roleDistribution`
    - _Requisitos: 11.2, 15.1_

- [x] 9. Frontend — Nuevos use cases
  - [x] 9.1 Crear use cases `UpdateTeamUseCase`, `DeleteTeamUseCase` en `worship_hub_ui/lib/domain/usecases/team_usecases.dart`
    - Validaciones de entrada (teamId no vacío, nombre no vacío para update)
    - _Requisitos: 3.1, 4.1_
  - [x] 9.2 Crear use cases `RemoveMemberFromTeamUseCase`, `UpdateMemberRoleUseCase` en `worship_hub_ui/lib/domain/usecases/team_usecases.dart`
    - Validaciones de entrada (teamId, userId, role no vacíos)
    - _Requisitos: 7.1, 8.1_
  - [x] 9.3 Crear use cases `GetUpcomingServicesUseCase`, `GetTeamAvailabilityUseCase`, `GetTeamSummaryUseCase` en `worship_hub_ui/lib/domain/usecases/team_usecases.dart`
    - Validaciones de entrada (teamId no vacío, fechas válidas para availability)
    - _Requisitos: 9.1, 10.1, 11.1_

- [x] 10. Frontend — Extender TeamRepository interface y TeamRepositoryImpl
  - [x] 10.1 Agregar métodos al interface `TeamRepository` en `worship_hub_ui/lib/domain/repositories/team_repository.dart`
    - `getUpcomingServices(String teamId)`, `getTeamAvailability(String teamId, DateTime startDate, DateTime endDate)`, `getTeamSummary(String teamId)`
    - _Requisitos: 17.4, 17.5, 17.6_
  - [x] 10.2 Implementar sincronización HTTP en `TeamRepositoryImpl` para `updateTeam`
    - Enviar PUT a `/api/v1/teams/{teamId}` antes de actualizar Drift local
    - _Requisitos: 17.1_
  - [x] 10.3 Implementar sincronización HTTP en `TeamRepositoryImpl` para `deleteTeam`
    - Enviar DELETE a `/api/v1/teams/{teamId}` antes de eliminar de Drift local
    - _Requisitos: 17.1_
  - [x] 10.4 Implementar sincronización HTTP en `TeamRepositoryImpl` para `getAllTeams`
    - Obtener datos de GET `/api/v1/teams`, actualizar Drift local, retornar entidades
    - _Requisitos: 17.2_
  - [x] 10.5 Implementar sincronización HTTP en `TeamRepositoryImpl` para `addMemberToTeam`
    - Enviar POST a `/api/v1/teams/{teamId}/members` antes de insertar en Drift local
    - _Requisitos: 17.3_
  - [x] 10.6 Implementar sincronización HTTP en `TeamRepositoryImpl` para `removeMemberFromTeam`
    - Enviar DELETE a `/api/v1/teams/{teamId}/members/{userId}` antes de eliminar de Drift local
    - _Requisitos: 17.3_
  - [x] 10.7 Implementar sincronización HTTP en `TeamRepositoryImpl` para `updateMemberRole`
    - Enviar PUT a `/api/v1/teams/{teamId}/members/{userId}/role` antes de actualizar Drift local
    - _Requisitos: 17.3_
  - [x] 10.8 Implementar nuevos métodos en `TeamRepositoryImpl`: `getUpcomingServices`, `getTeamAvailability`, `getTeamSummary`
    - Llamadas HTTP a los endpoints correspondientes, parseo de respuesta JSON a entidades de dominio
    - Manejo de errores con mensajes descriptivos
    - _Requisitos: 17.4, 17.5, 17.6, 17.7_

- [x] 11. Frontend — Extender TeamBloc con nuevos eventos y estados
  - [x] 11.1 Crear nuevos eventos en `worship_hub_ui/lib/presentation/features/teams/bloc/team_event.dart`
    - `TeamUpdateRequested`, `TeamDeleteRequested`, `TeamMemberRemoveRequested`, `TeamMemberRoleUpdateRequested`, `TeamUpcomingServicesRequested`, `TeamAvailabilityRequested`, `TeamSummaryRequested`, `TeamDetailLoadRequested`
    - _Requisitos: 3.1, 4.1, 7.1, 8.1, 9.1, 10.1, 11.1, 13.1_
  - [x] 11.2 Crear nuevos estados en `worship_hub_ui/lib/presentation/features/teams/bloc/team_state.dart`
    - `TeamUpdated`, `TeamDeleted`, `TeamMemberRemoved`, `TeamMemberRoleUpdated`, `TeamUpcomingServicesLoaded`, `TeamAvailabilityLoaded`, `TeamSummaryLoaded`, `TeamDetailLoaded`
    - `TeamDetailLoaded` como estado combinado con team, members, upcomingServices, summary
    - _Requisitos: 13.1, 14.1, 15.1, 16.1_
  - [x] 11.3 Registrar handlers para los nuevos eventos en `TeamBloc`
    - Inyectar los nuevos use cases en el constructor del BLoC
    - Implementar `_onUpdateRequested`, `_onDeleteRequested`, `_onMemberRemoveRequested`, `_onMemberRoleUpdateRequested`, `_onUpcomingServicesRequested`, `_onAvailabilityRequested`, `_onSummaryRequested`, `_onDetailLoadRequested`
    - `_onDetailLoadRequested` debe cargar team, members, upcoming services y summary en paralelo
    - _Requisitos: 13.1, 13.6, 14.6_

- [x] 12. Checkpoint — Verificar compilación del frontend
  - Ensure all tests pass, ask the user if questions arise.

- [x] 13. Frontend — TeamDetailPage
  - [x] 13.1 Crear `TeamDetailPage` en `worship_hub_ui/lib/presentation/features/teams/pages/team_detail_page.dart`
    - Mostrar nombre, descripción, líder y fecha de creación del equipo
    - Panel de resumen con totalMembers, recentServicesCount, upcomingServicesCount, roleDistribution (chips/badges)
    - Sección de próximos servicios (hasta 3) con nombre, fecha y estado de confirmaciones
    - Botón de navegación a TeamMembersPage y al chat del equipo
    - Opciones de editar/eliminar visibles solo para CHURCH_ADMIN y WORSHIP_LEADER
    - Estado de error con mensaje descriptivo
    - Estado vacío cuando no hay datos de actividad
    - Usar `TeamDetailLoadRequested` para carga combinada
    - _Requisitos: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7, 15.1, 15.2, 15.3, 15.4_

- [x] 14. Frontend — TeamMembersPage
  - [x] 14.1 Crear `TeamMembersPage` en `worship_hub_ui/lib/presentation/features/teams/pages/team_members_page.dart`
    - Lista de miembros con nombre, rol e ícono representativo del rol
    - Estado vacío con mensaje y botón para agregar primer miembro
    - Acción para agregar miembro (selector de usuarios + selector de rol)
    - Acción para remover miembro con diálogo de confirmación
    - Acción para cambiar rol con selector de roles
    - Actualización automática de lista tras agregar/remover miembro con mensaje de éxito
    - Sección de disponibilidad con selector de rango de fechas
    - Indicador visual de disponibilidad por miembro (disponible/no disponible)
    - Mostrar fechas de indisponibilidad y motivo para miembros no disponibles
    - Estado de error para consulta de disponibilidad
    - _Requisitos: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 16.1, 16.2, 16.3, 16.4_

- [x] 15. Frontend — Registrar rutas y proveedores
  - [x] 15.1 Registrar rutas `/teams/{teamId}` y `/teams/{teamId}/members` en el router de la aplicación
    - Proveer `TeamBloc` con los nuevos use cases inyectados
    - _Requisitos: 13.1, 14.1_

- [x] 16. Checkpoint — Verificar compilación completa y flujo end-to-end
  - Ensure all tests pass, ask the user if questions arise.

- [x] 17. Frontend — Tests basados en propiedades (Glados)
  - [x] 17.1 Escribir test de propiedad para sincronización round-trip frontend-backend
    - **Propiedad 12: Sincronización frontend-backend round-trip**
    - **Valida: Requisitos 17.1, 17.2, 17.3, 17.4, 17.5, 17.6**
  - [x] 17.2 Escribir test de propiedad para propagación de errores en frontend
    - **Propiedad 13: Propagación de errores en frontend**
    - **Valida: Requisitos 17.7**

- [x] 18. Tests unitarios
  - [x] 18.1 Escribir tests unitarios para los nuevos endpoints de `TeamController` con MockMvc + SpringMockK
    - Cubrir edge cases: 404, 409, 400 para cada endpoint
    - _Requisitos: 1.1, 2.1, 3.1, 4.1, 5.1, 6.1, 7.1, 8.1, 9.1, 10.1, 11.1_
  - [x] 18.2 Escribir tests unitarios para los nuevos métodos de `OrganizationApplicationService` con MockK
    - Verificar creación de notificaciones por cada operación de mutación
    - _Requisitos: 12.1, 12.2, 12.3, 12.4_
  - [x] 18.3 Escribir tests de BLoC con `bloc_test` + `mocktail` para cada nuevo evento/estado
    - _Requisitos: 13.1, 14.1, 15.1, 16.1_
  - [x] 18.4 Escribir tests de widget para `TeamDetailPage` y `TeamMembersPage`
    - Estados: loading, loaded, empty, error
    - _Requisitos: 13.6, 14.2, 16.4_

- [x] 19. Checkpoint final — Verificar todos los tests y compilación
  - Ensure all tests pass, ask the user if questions arise.

## Notas

- Las tareas marcadas con `*` son opcionales y pueden omitirse para un MVP más rápido
- Cada tarea referencia requisitos específicos para trazabilidad
- Los checkpoints aseguran validación incremental
- Los tests de propiedades validan propiedades universales de correctitud
- Los tests unitarios validan ejemplos específicos y edge cases
