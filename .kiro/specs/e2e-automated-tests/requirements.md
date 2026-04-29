# Documento de Requisitos — Tests E2E Automatizados para WorshipHub

## Introducción

Este documento define los requisitos para la creación de tests end-to-end (E2E) automatizados que cubran todos los flujos de la API backend de WorshipHub. Los tests actuales son mínimos (solo 2 tests básicos) y no validan los flujos reales de negocio. El objetivo es crear una suite completa de tests E2E que verifique cada flujo de aplicación a través de los 5 bounded contexts: Organization, Auth, Catalog, Scheduling y Collaboration.

Los tests utilizarán la infraestructura existente: JUnit 5 + MockMvc + SpringMockK con `@SpringBootTest`, `@AutoConfigureWebMvc`, y `@WithMockUser` para el contexto de seguridad. Se usará H2 como base de datos en memoria para el perfil de test.

## Glosario

- **E2E_Test_Suite**: Conjunto completo de tests automatizados que validan flujos end-to-end de la API
- **MockMvc**: Framework de Spring para simular peticiones HTTP en tests de integración sin levantar un servidor real
- **Auth_Context**: Bounded context que gestiona autenticación, autorización, tokens JWT y gestión de contraseñas
- **Organization_Context**: Bounded context que gestiona iglesias, equipos, miembros y perfiles de usuario
- **Catalog_Context**: Bounded context que gestiona canciones, categorías, tags, adjuntos y comentarios
- **Scheduling_Context**: Bounded context que gestiona eventos de servicio, setlists, asignaciones y disponibilidad
- **Collaboration_Context**: Bounded context que gestiona notificaciones y chat de equipo
- **Service_Event**: Evento de servicio de adoración con ciclo de vida DRAFT → PUBLISHED → CONFIRMED → CANCELLED
- **Setlist**: Lista ordenada de canciones para un servicio de adoración
- **Church_Admin**: Rol con acceso completo a la gestión de la iglesia
- **Worship_Leader**: Rol que puede gestionar equipos y programar servicios
- **Team_Member**: Rol de participación básica en equipos
- **Super_Admin**: Rol de administrador del sistema con acceso global
- **JWT_Token**: Token de autenticación JSON Web Token usado para autorizar peticiones a la API
- **Confirmation_Flow**: Flujo donde miembros asignados a un servicio aceptan o rechazan la invitación

## Requisitos

### Requirement 1: Tests E2E del flujo de registro de iglesia y usuario administrador

**User Story:** Como desarrollador, quiero tests E2E que validen el flujo completo de registro de una iglesia con su usuario administrador, para asegurar que el onboarding funciona correctamente.

#### Acceptance Criteria

1. WHEN a valid church registration request is submitted with church name, address, email, admin email, admin name, and admin password, THE E2E_Test_Suite SHALL verify that the API returns HTTP 201 with churchId and adminUserId in the response body
2. WHEN a church registration request is submitted with an admin email that already exists, THE E2E_Test_Suite SHALL verify that the API returns HTTP 409 with an appropriate conflict message
3. WHEN a church registration request is submitted with a password shorter than 8 characters, THE E2E_Test_Suite SHALL verify that the API returns HTTP 400 with password validation errors
4. WHEN a church registration request is submitted with missing required fields, THE E2E_Test_Suite SHALL verify that the API returns HTTP 400 with field-specific validation messages
5. WHEN a church is registered successfully, THE E2E_Test_Suite SHALL verify that the church details can be retrieved via GET /api/v1/churches/{churchId}

### Requirement 2: Tests E2E del flujo de autenticación y sesión

**User Story:** Como desarrollador, quiero tests E2E que validen el flujo completo de login, logout y gestión de tokens JWT, para asegurar que la autenticación funciona de forma segura.

#### Acceptance Criteria

1. WHEN valid credentials are submitted to the login endpoint, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with a JWT token, token type "Bearer", expiration time, and user information including id, email, firstName, lastName, role, and churchId
2. WHEN invalid credentials are submitted to the login endpoint, THE E2E_Test_Suite SHALL verify that the API returns HTTP 401 with error code "INVALID_CREDENTIALS"
3. WHEN a login attempt is made for an account with unverified email, THE E2E_Test_Suite SHALL verify that the API returns HTTP 403 with error code "EMAIL_NOT_VERIFIED"
4. WHEN a login attempt is made for an inactive account, THE E2E_Test_Suite SHALL verify that the API returns HTTP 403 with error code "ACCOUNT_INACTIVE"
5. WHEN a valid logout request is submitted with a Bearer token, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with a success message
6. WHEN a user registration request is submitted with valid data, THE E2E_Test_Suite SHALL verify that the API returns HTTP 201 with the userId
7. WHEN a user registration request is submitted with an email that already exists, THE E2E_Test_Suite SHALL verify that the API returns HTTP 409

### Requirement 3: Tests E2E del flujo de verificación de email

**User Story:** Como desarrollador, quiero tests E2E que validen el flujo de verificación de email, para asegurar que los usuarios pueden activar sus cuentas correctamente.

#### Acceptance Criteria

1. WHEN an authenticated user requests email verification via POST /api/v1/auth/email/send-verification, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with a success message
2. WHEN a valid verification token is submitted via GET /api/v1/auth/email/verify/{token}, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with an HTML page containing the success title
3. WHEN an expired verification token is submitted, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with an HTML page containing the expiration error message
4. WHEN an already-used verification token is submitted, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with an HTML page indicating the token was already used
5. WHEN a resend verification request is submitted with a valid email, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200

### Requirement 4: Tests E2E del flujo de reset y gestión de contraseñas

**User Story:** Como desarrollador, quiero tests E2E que validen los flujos de forgot password, reset password, set password y change password, para asegurar que la gestión de contraseñas es segura y funcional.

#### Acceptance Criteria

1. WHEN a forgot password request is submitted with any email, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with a generic message to prevent email enumeration
2. WHEN a valid reset token is validated via GET /api/v1/auth/password/reset/{token}/validate, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with "Token is valid" message
3. WHEN an expired reset token is validated, THE E2E_Test_Suite SHALL verify that the API returns HTTP 400 with "Reset token has expired" message
4. WHEN a valid reset password request is submitted with token and new password, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with "Password reset successfully" message
5. WHEN a reset password request is submitted with a password that does not meet complexity requirements, THE E2E_Test_Suite SHALL verify that the API returns HTTP 400 with specific password validation errors
6. WHEN an authenticated OAuth user sets a password via POST /api/v1/auth/password/set, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with a success message
7. WHEN an authenticated user changes their password via PUT /api/v1/auth/password/change with correct current password, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200
8. WHEN an authenticated user changes their password with incorrect current password, THE E2E_Test_Suite SHALL verify that the API returns HTTP 400 with "Current password is incorrect" message
9. WHEN an authenticated user checks password status via GET /api/v1/auth/password/status, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with hasPassword, canSetPassword, and canChangePassword fields

### Requirement 5: Tests E2E del flujo de invitaciones

**User Story:** Como desarrollador, quiero tests E2E que validen el flujo completo de invitación de usuarios (enviar → consultar → aceptar), para asegurar que el sistema de invitaciones funciona correctamente.

#### Acceptance Criteria

1. WHEN a Church_Admin sends an invitation with valid email, firstName, lastName, and role, THE E2E_Test_Suite SHALL verify that the API returns HTTP 201 with an invitationId
2. WHEN an invitation is sent to an email that already exists in the system, THE E2E_Test_Suite SHALL verify that the API returns HTTP 409
3. WHEN invitation details are retrieved via GET /api/v1/invitations/{token}, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with email, firstName, lastName, churchName, role, and expiresAt
4. WHEN an invitation is accepted with a valid token and password, THE E2E_Test_Suite SHALL verify that the API returns HTTP 201 with a userId and success message
5. WHEN an invitation is accepted with an expired token, THE E2E_Test_Suite SHALL verify that the API returns HTTP 400 with "Invitation has expired" message
6. WHEN an invitation is accepted with a password that does not meet requirements, THE E2E_Test_Suite SHALL verify that the API returns HTTP 400 with password validation errors
7. WHEN an already-used invitation token is submitted for acceptance, THE E2E_Test_Suite SHALL verify that the API returns HTTP 400 with "Invitation has already been used" message

### Requirement 6: Tests E2E del flujo de gestión de roles

**User Story:** Como desarrollador, quiero tests E2E que validen la gestión de roles de usuario, para asegurar que los permisos se aplican correctamente.

#### Acceptance Criteria

1. WHEN a Church_Admin changes a user's role via PUT /api/v1/roles/users/{userId}, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with "User role changed successfully" message
2. WHEN a Church_Admin attempts to demote themselves, THE E2E_Test_Suite SHALL verify that the API returns HTTP 400 with "Cannot demote yourself" message
3. WHEN a user attempts to change a role for a user in a different church, THE E2E_Test_Suite SHALL verify that the API returns HTTP 400
4. WHEN church users are retrieved via GET /api/v1/roles/users, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with a list of users containing userId, email, firstName, lastName, role, isActive, and isEmailVerified
5. WHEN available roles are retrieved via GET /api/v1/roles/available, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with roles excluding SUPER_ADMIN, each containing name, displayName, description, and permission flags

### Requirement 7: Tests E2E del flujo de perfil de usuario

**User Story:** Como desarrollador, quiero tests E2E que validen la consulta y actualización del perfil de usuario, para asegurar que los usuarios pueden gestionar su información personal.

#### Acceptance Criteria

1. WHEN an authenticated user retrieves their profile via GET /api/v1/users/profile, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with id, email, firstName, lastName, role, churchId, isEmailVerified, and hasPassword
2. WHEN an authenticated user updates their profile via PATCH /api/v1/users/profile with firstName and lastName, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with "Profile updated successfully" message

### Requirement 8: Tests E2E del flujo CRUD de equipos

**User Story:** Como desarrollador, quiero tests E2E que validen el ciclo completo de vida de equipos de adoración (crear, listar, actualizar, eliminar), para asegurar que la gestión de equipos funciona correctamente.

#### Acceptance Criteria

1. WHEN a Church_Admin creates a team with name, description, churchId, and leaderId, THE E2E_Test_Suite SHALL verify that the API returns HTTP 201 with a teamId
2. WHEN teams are listed for a church via GET /api/v1/teams, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with a list of teams containing id, name, description, leaderId, leaderName, churchId, and createdAt
3. WHEN a specific team is retrieved via GET /api/v1/teams/{teamId}, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with complete team details
4. WHEN a team is updated via PUT /api/v1/teams/{teamId} with new name, description, and leaderId, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with updated team details
5. WHEN a team is deleted via DELETE /api/v1/teams/{teamId}, THE E2E_Test_Suite SHALL verify that the API returns HTTP 204
6. WHEN a non-existent team is retrieved, THE E2E_Test_Suite SHALL verify that the API returns HTTP 404

### Requirement 9: Tests E2E del flujo de gestión de miembros de equipo

**User Story:** Como desarrollador, quiero tests E2E que validen la asignación, actualización de rol y eliminación de miembros de equipo, para asegurar que la composición de equipos se gestiona correctamente.

#### Acceptance Criteria

1. WHEN a member is assigned to a team via POST /api/v1/teams/{teamId}/members with userId and teamRole, THE E2E_Test_Suite SHALL verify that the API returns HTTP 201 with a memberId
2. WHEN a user who is already a team member is assigned again, THE E2E_Test_Suite SHALL verify that the API returns HTTP 409
3. WHEN team members are listed via GET /api/v1/teams/{teamId}/members, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with a list containing id, userId, userName, teamRole, and joinedAt
4. WHEN a team member's role is updated via PUT /api/v1/teams/{teamId}/members/{userId}/role, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200
5. WHEN a team member is removed via DELETE /api/v1/teams/{teamId}/members/{userId}, THE E2E_Test_Suite SHALL verify that the API returns HTTP 204
6. WHEN a team summary is retrieved via GET /api/v1/teams/{teamId}/summary, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with totalMembers, recentServicesCount, upcomingServicesCount, and roleDistribution

### Requirement 10: Tests E2E del flujo CRUD de canciones

**User Story:** Como desarrollador, quiero tests E2E que validen el ciclo completo de vida de canciones en el catálogo (crear, leer, actualizar, eliminar), para asegurar que la gestión del catálogo funciona correctamente.

#### Acceptance Criteria

1. WHEN a Worship_Leader creates a song with title, artist, key, bpm, lyrics, and chords, THE E2E_Test_Suite SHALL verify that the API returns HTTP 201 with complete song data including id, title, artist, key, bpm, chords, lyrics, categories, tags, and createdAt
2. WHEN all songs are retrieved via GET /api/v1/songs with pagination parameters, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with a PageResponse containing content, page, size, totalElements, totalPages, hasNext, and hasPrevious
3. WHEN songs are searched via GET /api/v1/songs/search with a query parameter, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with matching songs in PageResponse format
4. WHEN songs are filtered via GET /api/v1/songs/filter with categoryId and tagIds, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with filtered results
5. WHEN a song is updated via PUT /api/v1/songs/{id} with new data, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with updated song data
6. WHEN a song is deleted via DELETE /api/v1/songs/{id}, THE E2E_Test_Suite SHALL verify that the API returns HTTP 204
7. WHEN a song creation request is submitted with invalid data, THE E2E_Test_Suite SHALL verify that the API returns HTTP 400

### Requirement 11: Tests E2E del flujo de categorías y tags

**User Story:** Como desarrollador, quiero tests E2E que validen el CRUD de categorías y tags, y su asociación con canciones, para asegurar que la clasificación del catálogo funciona correctamente.

#### Acceptance Criteria

1. WHEN a category is created via POST /api/v1/categories with name and description, THE E2E_Test_Suite SHALL verify that the API returns HTTP 201 with id, name, and description
2. WHEN all categories are listed via GET /api/v1/categories, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with a list of categories
3. WHEN a category is updated via PUT /api/v1/categories/{id}, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with updated data
4. WHEN a category is deleted via DELETE /api/v1/categories/{id}, THE E2E_Test_Suite SHALL verify that the API returns HTTP 204
5. WHEN a tag is created via POST /api/v1/tags with name and color, THE E2E_Test_Suite SHALL verify that the API returns HTTP 201 with id, name, and color
6. WHEN all tags are listed via GET /api/v1/tags, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with a list of tags
7. WHEN a tag is updated via PUT /api/v1/tags/{id}, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with updated data
8. WHEN a tag is deleted via DELETE /api/v1/tags/{id}, THE E2E_Test_Suite SHALL verify that the API returns HTTP 204
9. WHEN categories are assigned to a song via POST /api/v1/songs/{songId}/categories, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with "Categories assigned successfully"
10. WHEN tags are assigned to a song via POST /api/v1/songs/{songId}/tags, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with "Tags assigned successfully"

### Requirement 12: Tests E2E del flujo de adjuntos y comentarios de canciones

**User Story:** Como desarrollador, quiero tests E2E que validen la adición de adjuntos y comentarios a canciones, para asegurar que la colaboración sobre el catálogo funciona correctamente.

#### Acceptance Criteria

1. WHEN an attachment is added to a song via POST /api/v1/songs/{songId}/attachments with name, url, and type, THE E2E_Test_Suite SHALL verify that the API returns HTTP 201 with attachmentId, name, url, and type
2. WHEN an attachment request is submitted with invalid data, THE E2E_Test_Suite SHALL verify that the API returns HTTP 400
3. WHEN a comment is added to a song via POST /api/v1/songs/{songId}/comments with content, THE E2E_Test_Suite SHALL verify that the API returns HTTP 201 with a commentId
4. WHEN comments are retrieved for a song via GET /api/v1/songs/{songId}/comments, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with a list containing id, userId, content, and createdAt

### Requirement 13: Tests E2E del flujo del catálogo global de canciones

**User Story:** Como desarrollador, quiero tests E2E que validen la búsqueda e importación de canciones del catálogo global, para asegurar que las iglesias pueden descubrir y agregar canciones verificadas.

#### Acceptance Criteria

1. WHEN the global song catalog is searched via GET /api/v1/global-songs/search with a query, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with a list of songs containing id, title, artist, key, and isVerified
2. WHEN a global song is imported via POST /api/v1/global-songs/{globalSongId}/import with Church-Id header, THE E2E_Test_Suite SHALL verify that the API returns HTTP 201 with a songId

### Requirement 14: Tests E2E del flujo de ciclo de vida de eventos de servicio

**User Story:** Como desarrollador, quiero tests E2E que validen el ciclo de vida completo de eventos de servicio (crear, listar, asignar miembros, confirmar), para asegurar que la programación de servicios funciona correctamente.

#### Acceptance Criteria

1. WHEN a service event is scheduled via POST /api/v1/services with serviceName, scheduledDate, teamId, and memberAssignments, THE E2E_Test_Suite SHALL verify that the API returns HTTP 201 with a serviceId
2. WHEN service events are listed via GET /api/v1/services with Church-Id header, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with a list of events containing id, serviceName, scheduledDate, teamId, setlistId, and status
3. WHEN a team member responds to a service invitation via PATCH /api/v1/services/{serviceId}/assignments/{assignmentId} with "ACCEPTED", THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with the response status
4. WHEN a team member responds to a service invitation with "DECLINED", THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with the declined status
5. WHEN confirmation status is retrieved via GET /api/v1/services/{serviceId}/confirmations, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with a list of assignments containing userId, role, status, and respondedAt
6. WHEN a service event is scheduled with invalid data, THE E2E_Test_Suite SHALL verify that the API returns HTTP 400

### Requirement 15: Tests E2E del flujo de servicios recurrentes

**User Story:** Como desarrollador, quiero tests E2E que validen la creación, actualización y eliminación de servicios recurrentes, para asegurar que la programación periódica funciona correctamente.

#### Acceptance Criteria

1. WHEN a recurring service is created via POST /api/v1/services with a recurrenceRule containing frequency and recurrenceEndDate, THE E2E_Test_Suite SHALL verify that the API returns HTTP 201 with a serviceId
2. WHEN a recurrence rule is updated via PUT /api/v1/services/{serviceId}/recurrence with new frequency and end date, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200
3. WHEN a recurring service is deleted via DELETE /api/v1/services/{serviceId}/recurring, THE E2E_Test_Suite SHALL verify that the API returns HTTP 204
4. WHEN a recurrence rule update is submitted with an unsupported frequency, THE E2E_Test_Suite SHALL verify that the API returns HTTP 400

### Requirement 16: Tests E2E del flujo CRUD de setlists

**User Story:** Como desarrollador, quiero tests E2E que validen el ciclo completo de vida de setlists (crear, listar, actualizar, eliminar, gestionar canciones), para asegurar que la gestión de setlists funciona correctamente.

#### Acceptance Criteria

1. WHEN a setlist is created via POST /api/v1/setlists with name and songIds, THE E2E_Test_Suite SHALL verify that the API returns HTTP 201 with a setlistId
2. WHEN setlists are listed via GET /api/v1/setlists with Church-Id header, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with content containing id, name, description, songIds, estimatedDuration, eventDate, createdAt, and updatedAt
3. WHEN a setlist is retrieved by ID via GET /api/v1/setlists/{id}, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with complete setlist details
4. WHEN a setlist is updated via PUT /api/v1/setlists/{id} with new name, description, songIds, and estimatedDuration, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200
5. WHEN a setlist is deleted via DELETE /api/v1/setlists/{id}, THE E2E_Test_Suite SHALL verify that the API returns HTTP 204
6. WHEN a song is added to a setlist via POST /api/v1/setlists/{id}/songs with songId and position, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with "Song added to setlist successfully"
7. WHEN a song is removed from a setlist via DELETE /api/v1/setlists/{id}/songs/{songId}, THE E2E_Test_Suite SHALL verify that the API returns HTTP 204

### Requirement 17: Tests E2E del flujo de gestión avanzada de setlists

**User Story:** Como desarrollador, quiero tests E2E que validen las operaciones avanzadas de setlists (reordenar, calcular duración, auto-generar), para asegurar que las funcionalidades avanzadas de setlists funcionan correctamente.

#### Acceptance Criteria

1. WHEN songs in a setlist are reordered via PATCH /api/v1/services/setlists/{setlistId}/songs/reorder with a songOrder list, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with "Setlist reordered successfully"
2. WHEN setlist details are retrieved via GET /api/v1/services/setlists/{setlistId}, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with id, name, songs, totalDuration, and createdAt
3. WHEN setlist duration is calculated via GET /api/v1/services/setlists/{setlistId}/duration, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with durationMinutes
4. WHEN a setlist is auto-generated via POST /api/v1/services/setlists/generate with name and rules, THE E2E_Test_Suite SHALL verify that the API returns HTTP 201 with a setlistId

### Requirement 18: Tests E2E del flujo de disponibilidad de usuarios

**User Story:** Como desarrollador, quiero tests E2E que validen la gestión de disponibilidad de miembros del equipo, para asegurar que los líderes pueden planificar servicios considerando la disponibilidad.

#### Acceptance Criteria

1. WHEN a team member marks unavailability via POST /api/v1/services/availability/unavailable with unavailableDate and reason, THE E2E_Test_Suite SHALL verify that the API returns HTTP 201 with an availabilityId
2. WHEN a user retrieves their unavailability records via GET /api/v1/services/availability/me with User-Id header, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with a list containing id, unavailableDate, reason, and createdAt
3. WHEN a user retrieves their unavailability records filtered by date range, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with only records within the specified startDate and endDate
4. WHEN an unavailability record is deleted via DELETE /api/v1/services/availability/{availabilityId} by the owner, THE E2E_Test_Suite SHALL verify that the API returns HTTP 204
5. WHEN team availability is retrieved via GET /api/v1/teams/{teamId}/availability with startDate and endDate, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with member availability data containing userId, teamRole, and unavailableDates

### Requirement 19: Tests E2E del flujo de notificaciones

**User Story:** Como desarrollador, quiero tests E2E que validen la consulta y gestión de notificaciones, para asegurar que los usuarios reciben y pueden gestionar sus notificaciones.

#### Acceptance Criteria

1. WHEN user notifications are retrieved via GET /api/v1/notifications with User-Id header, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with a list of notifications containing id, title, message, type, isRead, and createdAt
2. WHEN a notification is marked as read via PATCH /api/v1/notifications/{notificationId}/read, THE E2E_Test_Suite SHALL verify that the API returns HTTP 204

### Requirement 20: Tests E2E del flujo de chat de equipo

**User Story:** Como desarrollador, quiero tests E2E que validen el envío de mensajes y la consulta del historial de chat, para asegurar que la comunicación del equipo funciona correctamente.

#### Acceptance Criteria

1. WHEN a chat message is sent via POST /api/v1/teams/{teamId}/messages with content, THE E2E_Test_Suite SHALL verify that the API returns HTTP 201 with id, teamId, userId, content, and createdAt
2. WHEN chat history is retrieved via GET /api/v1/teams/{teamId}/chat/history with optional limit parameter, THE E2E_Test_Suite SHALL verify that the API returns HTTP 200 with a list of messages

### Requirement 21: Tests E2E de control de acceso basado en roles

**User Story:** Como desarrollador, quiero tests E2E que validen que cada endpoint aplica correctamente las restricciones de rol, para asegurar que la seguridad de la API es robusta.

#### Acceptance Criteria

1. WHEN a Team_Member attempts to create a team via POST /api/v1/teams, THE E2E_Test_Suite SHALL verify that the API returns HTTP 403
2. WHEN a Team_Member attempts to create a song via POST /api/v1/songs, THE E2E_Test_Suite SHALL verify that the API returns HTTP 403
3. WHEN a Team_Member attempts to schedule a service via POST /api/v1/services, THE E2E_Test_Suite SHALL verify that the API returns HTTP 403
4. WHEN a Team_Member attempts to change a user's role via PUT /api/v1/roles/users/{userId}, THE E2E_Test_Suite SHALL verify that the API returns HTTP 403
5. WHEN a Team_Member attempts to send an invitation via POST /api/v1/invitations/send, THE E2E_Test_Suite SHALL verify that the API returns HTTP 403
6. WHEN a Worship_Leader attempts to delete a team via DELETE /api/v1/teams/{teamId}, THE E2E_Test_Suite SHALL verify that the API returns HTTP 403
7. WHEN an unauthenticated request is made to a protected endpoint, THE E2E_Test_Suite SHALL verify that the API returns HTTP 401 or HTTP 403

### Requirement 22: Tests E2E de flujos completos cross-context

**User Story:** Como desarrollador, quiero tests E2E que validen flujos completos que cruzan múltiples bounded contexts, para asegurar que la integración entre contextos funciona correctamente.

#### Acceptance Criteria

1. THE E2E_Test_Suite SHALL include a test that executes the complete worship service preparation flow: register church → create team → assign members → create songs → create setlist → schedule service → members respond to invitations → verify confirmation status
2. THE E2E_Test_Suite SHALL include a test that executes the complete member onboarding flow: register church → send invitation → accept invitation → verify user can access team endpoints
3. THE E2E_Test_Suite SHALL include a test that executes the complete catalog management flow: create categories → create tags → create song with categories and tags → add attachment → add comment → search song → filter by category → filter by tags
