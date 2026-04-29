# Plan de Implementación: Tests E2E Automatizados para WorshipHub

## Overview

Plan de implementación para la suite completa de tests E2E que cubre los 5 bounded contexts de WorshipHub (Auth, Organization, Catalog, Scheduling, Collaboration) más tests cross-cutting de RBAC y flujos multi-context. Los tests se implementan en Kotlin con JUnit 5, MockMvc y SpringBootTest contra H2 en memoria. La infraestructura (clase base, helpers) se construye primero, seguida de los tests por bounded context en orden de dependencia, y finalmente los tests cross-cutting.

## Tasks

- [x] 1. Crear infraestructura base de tests E2E
  - [x] 1.1 Crear `TestConstants.kt` con constantes compartidas de datos de test
    - Crear archivo en `api/src/test/kotlin/com/worshiphub/api/integration/TestConstants.kt`
    - Definir constantes: `VALID_PASSWORD`, `WEAK_PASSWORD`, `VALID_EMAIL`, `CHURCH_NAME`, `CHURCH_ADDRESS`, `CHURCH_EMAIL`, y otros valores reutilizables
    - _Requirements: Todas (infraestructura compartida)_

  - [x] 1.2 Crear `TestSecurityHelper.kt` con utilidades de contexto de seguridad
    - Crear archivo en `api/src/test/kotlin/com/worshiphub/api/integration/TestSecurityHelper.kt`
    - Implementar `mockSecurityContext(userId, churchId, roles)` que configure `SecurityContextHolder` con `authentication.principal` y `authentication.details`
    - Implementar `withAuth(userId, churchId, roles)` como `RequestPostProcessor` para MockMvc
    - _Requirements: 6.1, 6.2, 7.1, 7.2, 21.1-21.7_

  - [x] 1.3 Crear `TestDataHelper.kt` con métodos para crear datos prerequisito vía API
    - Crear archivo en `api/src/test/kotlin/com/worshiphub/api/integration/TestDataHelper.kt`
    - Implementar `registerChurch()` que llame a `POST /api/v1/auth/church/register` y retorne `ChurchRegistrationResult(churchId, adminUserId)`
    - Implementar `createTeam(churchId, name)` que llame a `POST /api/v1/teams` y retorne `teamId`
    - Implementar `createSong(title, artist)` que llame a `POST /api/v1/songs` y retorne `songId`
    - Implementar `createSetlist(churchId, name, songIds)` que llame a `POST /api/v1/setlists` y retorne `setlistId`
    - Implementar `createCategory(name)` y `createTag(name)` que retornen sus IDs
    - Usar `@WithMockUser` o `TestSecurityHelper` internamente para autenticar las llamadas
    - _Requirements: Todas (infraestructura compartida)_

  - [x] 1.4 Crear `BaseE2ETest.kt` como clase base abstracta
    - Crear archivo en `api/src/test/kotlin/com/worshiphub/api/integration/BaseE2ETest.kt`
    - Anotar con `@SpringBootTest`, `@AutoConfigureWebMvc`, `@ActiveProfiles("h2")`, `@Transactional`
    - Inyectar `MockMvc` y `ObjectMapper` con `@Autowired`
    - Inicializar `TestDataHelper` en `@BeforeEach`
    - Definir extension functions de assertions: `expectCreated()`, `expectOk()`, `expectNoContent()`, `expectBadRequest()`, `expectForbidden()`, `expectConflict()`, `expectNotFound()`
    - Definir helpers `extractUUID(jsonPath)` y `extractString(jsonPath)`
    - _Requirements: Todas (infraestructura compartida)_

  - [x] 1.5 Eliminar o refactorizar `EndToEndWorkflowTest.kt` existente
    - Eliminar el archivo `api/src/test/kotlin/com/worshiphub/api/integration/EndToEndWorkflowTest.kt` ya que será reemplazado por la nueva suite
    - _Requirements: Todas_

- [x] 2. Checkpoint - Verificar que la infraestructura compila
  - Ejecutar `./gradlew :api:test --tests "com.worshiphub.api.integration.*"` para verificar que la infraestructura compila correctamente
  - Ensure all tests pass, ask the user if questions arise.

- [x] 3. Implementar tests E2E del bounded context Auth
  - [x] 3.1 Crear `AuthE2ETest.kt` con tests de registro de iglesia (Req 1)
    - Crear archivo en `api/src/test/kotlin/com/worshiphub/api/integration/auth/AuthE2ETest.kt`
    - Extender `BaseE2ETest`
    - Test: registro exitoso con datos válidos → HTTP 201 con `churchId` y `adminUserId`
    - Test: registro con email duplicado → HTTP 409
    - Test: registro con password corto → HTTP 400
    - Test: registro con campos faltantes → HTTP 400
    - Test: verificar que la iglesia registrada se puede consultar vía `GET /api/v1/churches/{churchId}`
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

  - [x] 3.2 Agregar tests de autenticación y sesión a `AuthE2ETest.kt` (Req 2)
    - Test: login con credenciales válidas → HTTP 200 con token JWT, tokenType, expiresIn, y user info
    - Test: login con credenciales inválidas → HTTP 401 con `INVALID_CREDENTIALS`
    - Test: login con email no verificado → HTTP 403 con `EMAIL_NOT_VERIFIED`
    - Test: login con cuenta inactiva → HTTP 403 con `ACCOUNT_INACTIVE`
    - Test: logout con Bearer token → HTTP 200
    - Test: registro de usuario con datos válidos → HTTP 201 con userId
    - Test: registro con email duplicado → HTTP 409
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_

  - [x] 3.3 Agregar tests de verificación de email a `AuthE2ETest.kt` (Req 3)
    - Test: enviar verificación de email → HTTP 200
    - Test: verificar email con token válido → HTTP 200 con HTML de éxito
    - Test: verificar email con token expirado → HTTP 200 con HTML de error
    - Test: verificar email con token ya usado → HTTP 200 con HTML indicando token usado
    - Test: reenviar verificación → HTTP 200
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

  - [x] 3.4 Agregar tests de gestión de contraseñas a `AuthE2ETest.kt` (Req 4)
    - Test: forgot password → HTTP 200 con mensaje genérico (prevención de enumeración)
    - Test: validar reset token válido → HTTP 200
    - Test: validar reset token expirado → HTTP 400
    - Test: reset password con token y nueva contraseña → HTTP 200
    - Test: reset password con contraseña débil → HTTP 400
    - Test: set password para usuario OAuth → HTTP 200
    - Test: change password con contraseña actual correcta → HTTP 200
    - Test: change password con contraseña actual incorrecta → HTTP 400
    - Test: consultar password status → HTTP 200 con `hasPassword`, `canSetPassword`, `canChangePassword`
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9_

  - [x] 3.5 Agregar tests de invitaciones a `AuthE2ETest.kt` (Req 5)
    - Test: enviar invitación con datos válidos → HTTP 201 con `invitationId`
    - Test: enviar invitación a email existente → HTTP 409
    - Test: consultar detalles de invitación → HTTP 200 con email, firstName, lastName, churchName, role, expiresAt
    - Test: aceptar invitación con token y password válidos → HTTP 201 con userId
    - Test: aceptar invitación con token expirado → HTTP 400
    - Test: aceptar invitación con password débil → HTTP 400
    - Test: aceptar invitación con token ya usado → HTTP 400
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_

- [x] 4. Checkpoint - Verificar tests Auth
  - Ejecutar `./gradlew :api:test --tests "com.worshiphub.api.integration.auth.*"` para verificar que los tests de Auth compilan y pasan
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Implementar tests E2E del bounded context Organization
  - [x] 5.1 Crear `OrganizationE2ETest.kt` con tests de gestión de roles (Req 6)
    - Crear archivo en `api/src/test/kotlin/com/worshiphub/api/integration/organization/OrganizationE2ETest.kt`
    - Extender `BaseE2ETest`
    - Test: Church_Admin cambia rol de usuario → HTTP 200
    - Test: Church_Admin intenta auto-degradarse → HTTP 400
    - Test: cambiar rol de usuario en otra iglesia → HTTP 400
    - Test: listar usuarios de la iglesia → HTTP 200 con lista de usuarios
    - Test: listar roles disponibles → HTTP 200 sin SUPER_ADMIN
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

  - [x] 5.2 Agregar tests de perfil de usuario a `OrganizationE2ETest.kt` (Req 7)
    - Test: obtener perfil de usuario autenticado → HTTP 200 con id, email, firstName, lastName, role, churchId, isEmailVerified, hasPassword
    - Test: actualizar perfil con firstName y lastName → HTTP 200
    - _Requirements: 7.1, 7.2_

  - [x] 5.3 Agregar tests CRUD de equipos a `OrganizationE2ETest.kt` (Req 8)
    - Test: crear equipo con name, description, churchId, leaderId → HTTP 201 con teamId
    - Test: listar equipos de una iglesia → HTTP 200 con lista de equipos
    - Test: obtener equipo por ID → HTTP 200 con detalles completos
    - Test: actualizar equipo → HTTP 200 con datos actualizados
    - Test: eliminar equipo → HTTP 204
    - Test: obtener equipo inexistente → HTTP 404
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6_

  - [x] 5.4 Agregar tests de miembros de equipo a `OrganizationE2ETest.kt` (Req 9)
    - Test: asignar miembro a equipo → HTTP 201 con memberId
    - Test: asignar miembro duplicado → HTTP 409
    - Test: listar miembros de equipo → HTTP 200 con lista
    - Test: actualizar rol de miembro → HTTP 200
    - Test: eliminar miembro de equipo → HTTP 204
    - Test: obtener resumen de equipo → HTTP 200 con totalMembers, recentServicesCount, upcomingServicesCount, roleDistribution
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6_

- [x] 6. Checkpoint - Verificar tests Organization
  - Ejecutar `./gradlew :api:test --tests "com.worshiphub.api.integration.organization.*"` para verificar que los tests de Organization compilan y pasan
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Implementar tests E2E del bounded context Catalog
  - [x] 7.1 Crear `CatalogE2ETest.kt` con tests CRUD de canciones (Req 10)
    - Crear archivo en `api/src/test/kotlin/com/worshiphub/api/integration/catalog/CatalogE2ETest.kt`
    - Extender `BaseE2ETest`
    - Test: crear canción con title, artist, key, bpm, lyrics, chords → HTTP 201 con datos completos
    - Test: listar canciones con paginación → HTTP 200 con PageResponse
    - Test: buscar canciones por query → HTTP 200 con resultados
    - Test: filtrar canciones por categoryId y tagIds → HTTP 200
    - Test: actualizar canción → HTTP 200 con datos actualizados
    - Test: eliminar canción → HTTP 204
    - Test: crear canción con datos inválidos → HTTP 400
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7_

  - [x] 7.2 Agregar tests de categorías y tags a `CatalogE2ETest.kt` (Req 11)
    - Test: crear categoría → HTTP 201 con id, name, description
    - Test: listar categorías → HTTP 200
    - Test: actualizar categoría → HTTP 200
    - Test: eliminar categoría → HTTP 204
    - Test: crear tag → HTTP 201 con id, name, color
    - Test: listar tags → HTTP 200
    - Test: actualizar tag → HTTP 200
    - Test: eliminar tag → HTTP 204
    - Test: asignar categorías a canción → HTTP 200
    - Test: asignar tags a canción → HTTP 200
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.7, 11.8, 11.9, 11.10_

  - [x] 7.3 Agregar tests de adjuntos y comentarios a `CatalogE2ETest.kt` (Req 12)
    - Test: agregar adjunto a canción → HTTP 201 con attachmentId, name, url, type
    - Test: agregar adjunto con datos inválidos → HTTP 400
    - Test: agregar comentario a canción → HTTP 201 con commentId
    - Test: listar comentarios de canción → HTTP 200 con lista
    - _Requirements: 12.1, 12.2, 12.3, 12.4_

  - [x] 7.4 Agregar tests del catálogo global a `CatalogE2ETest.kt` (Req 13)
    - Test: buscar en catálogo global → HTTP 200 con lista de canciones con id, title, artist, key, isVerified
    - Test: importar canción del catálogo global → HTTP 201 con songId
    - _Requirements: 13.1, 13.2_

- [x] 8. Checkpoint - Verificar tests Catalog
  - Ejecutar `./gradlew :api:test --tests "com.worshiphub.api.integration.catalog.*"` para verificar que los tests de Catalog compilan y pasan
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Implementar tests E2E del bounded context Scheduling
  - [x] 9.1 Crear `SchedulingE2ETest.kt` con tests de ciclo de vida de servicios (Req 14)
    - Crear archivo en `api/src/test/kotlin/com/worshiphub/api/integration/scheduling/SchedulingE2ETest.kt`
    - Extender `BaseE2ETest`
    - Test: programar servicio con serviceName, scheduledDate, teamId, memberAssignments → HTTP 201 con serviceId
    - Test: listar eventos de servicio → HTTP 200 con lista
    - Test: miembro responde ACCEPTED a invitación de servicio → HTTP 200
    - Test: miembro responde DECLINED a invitación de servicio → HTTP 200
    - Test: consultar estado de confirmaciones → HTTP 200 con lista de assignments
    - Test: programar servicio con datos inválidos → HTTP 400
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6_

  - [x] 9.2 Agregar tests de servicios recurrentes a `SchedulingE2ETest.kt` (Req 15)
    - Test: crear servicio recurrente con recurrenceRule → HTTP 201
    - Test: actualizar regla de recurrencia → HTTP 200
    - Test: eliminar servicio recurrente → HTTP 204
    - Test: actualizar recurrencia con frecuencia no soportada → HTTP 400
    - _Requirements: 15.1, 15.2, 15.3, 15.4_

  - [x] 9.3 Agregar tests CRUD de setlists a `SchedulingE2ETest.kt` (Req 16)
    - Test: crear setlist con name y songIds → HTTP 201 con setlistId
    - Test: listar setlists → HTTP 200 con content
    - Test: obtener setlist por ID → HTTP 200
    - Test: actualizar setlist → HTTP 200
    - Test: eliminar setlist → HTTP 204
    - Test: agregar canción a setlist → HTTP 200
    - Test: eliminar canción de setlist → HTTP 204
    - _Requirements: 16.1, 16.2, 16.3, 16.4, 16.5, 16.6, 16.7_

  - [x] 9.4 Agregar tests de gestión avanzada de setlists a `SchedulingE2ETest.kt` (Req 17)
    - Test: reordenar canciones en setlist → HTTP 200
    - Test: obtener detalles de setlist → HTTP 200 con id, name, songs, totalDuration, createdAt
    - Test: calcular duración de setlist → HTTP 200 con durationMinutes
    - Test: auto-generar setlist → HTTP 201 con setlistId
    - _Requirements: 17.1, 17.2, 17.3, 17.4_

  - [x] 9.5 Agregar tests de disponibilidad a `SchedulingE2ETest.kt` (Req 18)
    - Test: marcar indisponibilidad → HTTP 201 con availabilityId
    - Test: consultar registros de indisponibilidad propios → HTTP 200 con lista
    - Test: consultar indisponibilidad filtrada por rango de fechas → HTTP 200
    - Test: eliminar registro de indisponibilidad → HTTP 204
    - Test: consultar disponibilidad del equipo → HTTP 200 con datos de miembros
    - _Requirements: 18.1, 18.2, 18.3, 18.4, 18.5_

- [x] 10. Checkpoint - Verificar tests Scheduling
  - Ejecutar `./gradlew :api:test --tests "com.worshiphub.api.integration.scheduling.*"` para verificar que los tests de Scheduling compilan y pasan
  - Ensure all tests pass, ask the user if questions arise.

- [x] 11. Implementar tests E2E del bounded context Collaboration
  - [x] 11.1 Crear `CollaborationE2ETest.kt` con tests de notificaciones (Req 19)
    - Crear archivo en `api/src/test/kotlin/com/worshiphub/api/integration/collaboration/CollaborationE2ETest.kt`
    - Extender `BaseE2ETest`
    - Test: obtener notificaciones del usuario → HTTP 200 con lista conteniendo id, title, message, type, isRead, createdAt
    - Test: marcar notificación como leída → HTTP 204
    - _Requirements: 19.1, 19.2_

  - [x] 11.2 Agregar tests de chat de equipo a `CollaborationE2ETest.kt` (Req 20)
    - Test: enviar mensaje de chat vía REST → HTTP 201 con id, teamId, userId, content, createdAt
    - Test: obtener historial de chat → HTTP 200 con lista de mensajes
    - _Requirements: 20.1, 20.2_

- [x] 12. Implementar tests E2E cross-cutting
  - [x] 12.1 Crear `RoleBasedAccessE2ETest.kt` con tests de control de acceso (Req 21)
    - Crear archivo en `api/src/test/kotlin/com/worshiphub/api/integration/security/RoleBasedAccessE2ETest.kt`
    - Extender `BaseE2ETest`
    - Test: TEAM_MEMBER intenta crear equipo → HTTP 403
    - Test: TEAM_MEMBER intenta crear canción → HTTP 403
    - Test: TEAM_MEMBER intenta programar servicio → HTTP 403
    - Test: TEAM_MEMBER intenta cambiar rol → HTTP 403
    - Test: TEAM_MEMBER intenta enviar invitación → HTTP 403
    - Test: WORSHIP_LEADER intenta eliminar equipo → HTTP 403
    - Test: request no autenticado a endpoint protegido → HTTP 401 o 403
    - _Requirements: 21.1, 21.2, 21.3, 21.4, 21.5, 21.6, 21.7_

  - [x] 12.2 Crear `CrossContextE2ETest.kt` con tests de flujos multi-context (Req 22)
    - Crear archivo en `api/src/test/kotlin/com/worshiphub/api/integration/crosscontext/CrossContextE2ETest.kt`
    - Extender `BaseE2ETest`
    - Test: flujo completo de preparación de servicio de adoración (register church → create team → assign members → create songs → create setlist → schedule service → members respond → verify confirmations)
    - Test: flujo completo de onboarding de miembro (register church → send invitation → accept invitation → verify acceso a endpoints de equipo)
    - Test: flujo completo de gestión de catálogo (create categories → create tags → create song → assign categories/tags → add attachment → add comment → search → filter)
    - _Requirements: 22.1, 22.2, 22.3_

- [x] 13. Checkpoint final - Verificar suite completa
  - Ejecutar `./gradlew :api:test --tests "com.worshiphub.api.integration.*"` para verificar que toda la suite compila y pasa
  - Verificar que no hay tests rotos en el resto del proyecto con `./gradlew :api:test`
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- No se aplica Property-Based Testing para esta feature (documentado en el diseño). Todos los tests son example-based integration tests.
- Cada task referencia los requirements específicos que valida para trazabilidad.
- Los checkpoints aseguran validación incremental después de cada bounded context.
- El lenguaje de implementación es Kotlin, consistente con el proyecto existente.
- Los tests usan H2 en memoria con `@ActiveProfiles("h2")` y `@Transactional` para aislamiento.
- La estructura de directorios sigue el diseño: subdirectorios por bounded context dentro de `integration/`.
