# Implementation Plan: Flutter E2E UI Tests con Patrol para WorshipHub

## Overview

Implementar una suite completa de tests E2E de UI Flutter usando Patrol, ejecutándose contra el backend real (Spring Boot + H2 en memoria). Los tasks están ordenados por dependencia: primero la infraestructura y helpers, luego los tests por feature, y finalmente los tests cross-feature y de error handling. Todos los archivos se crean en `worship_hub_ui/patrol_test/`.

## Tasks

- [x] 1. Configurar infraestructura base de Patrol y dependencias
  - [x] 1.1 Agregar dependencia de Patrol y crear `patrol.yaml`
    - Agregar `patrol: ^3.13.0` a `dev_dependencies` en `worship_hub_ui/pubspec.yaml`
    - Crear `worship_hub_ui/patrol.yaml` con la configuración del test runner (app_name, package_name, bundle_id)
    - Ejecutar `flutter pub get` para verificar que la dependencia se resuelve correctamente
    - _Requirements: 1.1, 1.2, 1.3_

  - [x] 1.2 Crear `TestConfig` y constantes de configuración
    - Crear `worship_hub_ui/patrol_test/config/test_config.dart` con `TestConfig` class
    - Incluir `backendBaseUrl` (10.0.2.2:9090 para Android emulator), `wsUrl`, timeouts (apiTimeout: 15s, widgetSettleTimeout: 10s, navigationSettleTimeout: 3s)
    - Incluir método `get baseUrl` para selección de URL por plataforma
    - _Requirements: 1.2, 1.4_

  - [x] 1.3 Crear `MockSecureStorage` y `TestApp`
    - Crear `worship_hub_ui/patrol_test/mocks/mock_secure_storage.dart` con implementación in-memory de SecureStorage (write, read, delete, deleteAll, readAll)
    - Crear `worship_hub_ui/patrol_test/test_app.dart` con `createTestApp()` que inicialice la app con Dio apuntando a `TestConfig.baseUrl`, MockSecureStorage, Drift in-memory, sin Firebase
    - Implementar `initializeTestDependencies()` que registre todas las dependencias en get_it para testing, replicando `service_locator.dart` con overrides de test
    - _Requirements: 1.4, 1.5_

  - [x] 1.4 Crear fixtures: `TestData` y `ApiEndpoints`
    - Crear `worship_hub_ui/patrol_test/fixtures/test_data.dart` con constantes centralizadas (adminEmail, adminPassword, churchName, songTitle, etc.) y `UniqueTestData` con generadores de datos únicos por timestamp
    - Crear `worship_hub_ui/patrol_test/fixtures/api_endpoints.dart` con constantes de paths de API (login, registerChurch, songs, setlists, teams, etc.)
    - _Requirements: 1.4, 1.6_

  - [x] 1.5 Crear `ApiSeedHelper` y seed helpers por dominio
    - Crear `worship_hub_ui/patrol_test/seed/api_seed_helper.dart` con cliente Dio independiente para seeding: `registerChurch()`, `login()`, `createSong()`, `createSetlist()`, `createTeam()`, `createCategory()`, `createTag()`, `sendInvitation()`, `isBackendHealthy()`
    - Crear `worship_hub_ui/patrol_test/seed/auth_seed.dart` con helpers específicos de autenticación (register church, create users)
    - Crear `worship_hub_ui/patrol_test/seed/song_seed.dart` con helpers para crear canciones con datos variados
    - Crear `worship_hub_ui/patrol_test/seed/setlist_seed.dart` con helpers para crear setlists con canciones
    - Crear `worship_hub_ui/patrol_test/seed/team_seed.dart` con helpers para crear equipos
    - Crear `worship_hub_ui/patrol_test/seed/category_seed.dart` con helpers para crear categorías y tags
    - _Requirements: 1.4, 1.6_

  - [x] 1.6 Crear `TestEnvironment` (patrol_base) y UI helpers
    - Crear `worship_hub_ui/patrol_test/patrol_base.dart` con `TestEnvironment` class que encapsule setup (verify backend health, create MockSecureStorage, pump TestApp, create helpers) y tearDown (deleteAll storage, reset get_it)
    - Crear `worship_hub_ui/patrol_test/helpers/login_helper.dart` con `loginViaUI()` y `registerAndLogin()` que interactúen con la UI real de Login_Page
    - Crear `worship_hub_ui/patrol_test/helpers/navigation_helper.dart` con métodos `goToSongs()`, `goToSetlists()`, `goToCalendar()`, `goToTeams()`, `goToCategories()`, `goToNotifications()`, `goToProfile()`, `goBack()`
    - Crear `worship_hub_ui/patrol_test/helpers/form_helper.dart` con `fillField()`, `submitForm()`, `expectValidationError()`, `clearField()`
    - Crear `worship_hub_ui/patrol_test/helpers/wait_helper.dart` con `waitForLoadingToComplete()`, `waitForWidget()`, `waitForNavigation()`
    - Crear `worship_hub_ui/patrol_test/helpers/assertion_helper.dart` con patrones de aserción comunes
    - _Requirements: 1.5, 1.6_

  - [x] 1.7 Crear README de la suite de tests
    - Crear `worship_hub_ui/patrol_test/README.md` con instrucciones de setup: instalar Patrol CLI, iniciar backend con H2, iniciar emulador, ejecutar tests
    - Incluir troubleshooting para problemas comunes (backend no disponible, emulador no conectado, Patrol CLI no instalado)
    - _Requirements: 1.7_

- [x] 2. Checkpoint - Verificar infraestructura base
  - Ensure all tests pass, ask the user if questions arise.
  - Verificar que `flutter pub get` se ejecuta sin errores
  - Verificar que la estructura de directorios `patrol_test/` está completa
  - Verificar que `TestApp` compila correctamente

- [x] 3. Implementar tests E2E de autenticación (Registro, Login, Invitaciones)
  - [x] 3.1 Implementar tests de registro de iglesia (`auth/church_registration_test.dart`)
    - Crear `worship_hub_ui/patrol_test/tests/auth/church_registration_test.dart`
    - Test: Welcome_Page renderiza con opciones de navegación a Login y Registro (Req 2.1)
    - Test: Church_Registration_Page muestra todos los campos requeridos (Req 2.2)
    - Test: Registro exitoso con datos válidos navega a Home_Page (Req 2.3)
    - Test: Validación de campos vacíos muestra errores (Req 2.4)
    - Test: Password corto muestra error de validación (Req 2.5)
    - Test: Email duplicado muestra error 409 (Req 2.6)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

  - [x] 3.2 Implementar tests de login (`auth/login_test.dart`)
    - Crear `worship_hub_ui/patrol_test/tests/auth/login_test.dart`
    - Test: Login_Page renderiza con todos los elementos (email, password, botones, links) (Req 3.1)
    - Test: Login exitoso con credenciales válidas muestra loading y navega a Home_Page (Req 3.2)
    - Test: Login con credenciales inválidas muestra error (Req 3.3)
    - Test: Tap en forgot password navega a pantalla de recuperación (Req 3.4)
    - Test: Tap en register church navega a Church_Registration_Page (Req 3.5)
    - Test: Submit con campos vacíos muestra errores de validación (Req 3.6)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

  - [x] 3.3 Implementar tests de invitación y aceptación (`auth/invitation_acceptance_test.dart`)
    - Crear `worship_hub_ui/patrol_test/tests/auth/invitation_acceptance_test.dart`
    - Test: Send_Invitation_Page muestra campos de email, nombre, apellido, rol (Req 4.1)
    - Test: Enviar invitación con datos válidos muestra éxito (Req 4.2)
    - Test: Enviar invitación con email duplicado muestra error (Req 4.3)
    - Test: Accept_Invitation_Page con token válido muestra detalles (Req 4.4)
    - Test: Aceptar invitación con password válido navega correctamente (Req 4.5)
    - Test: Password que no cumple requisitos muestra error (Req 4.6)
    - Test: Token expirado muestra error de invitación expirada (Req 4.7)
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7_

- [x] 4. Implementar tests E2E de canciones (CRUD y búsqueda/filtrado)
  - [x] 4.1 Implementar tests CRUD de canciones (`songs/song_crud_test.dart`)
    - Crear `worship_hub_ui/patrol_test/tests/songs/song_crud_test.dart`
    - Seed data: registrar iglesia, login, crear canción inicial via API
    - Test: Song_List_Page muestra lista de canciones con título y artista (Req 5.1)
    - Test: Tap en crear canción navega a Create_Song_Page con campos vacíos (Req 5.2)
    - Test: Crear canción con datos válidos y verificar que aparece en lista (Req 5.3)
    - Test: Tap en canción navega a Song_Detail_Page con datos completos (Req 5.4)
    - Test: Tap en editar muestra formulario pre-llenado (Req 5.5)
    - Test: Editar canción y verificar datos actualizados (Req 5.6)
    - Test: Eliminar canción y verificar que desaparece de la lista (Req 5.7)
    - Test: Crear canción con campos vacíos muestra errores de validación (Req 5.8)
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8_

  - [x] 4.2 Implementar tests de búsqueda y filtrado de canciones (`songs/song_search_filter_test.dart`)
    - Crear `worship_hub_ui/patrol_test/tests/songs/song_search_filter_test.dart`
    - Seed data: registrar iglesia, login, crear múltiples canciones y categorías/tags via API
    - Test: Búsqueda por texto actualiza la lista con resultados (Req 6.1)
    - Test: Búsqueda sin resultados muestra estado vacío (Req 6.2)
    - Test: Filtro por categoría actualiza la lista (Req 6.3)
    - Test: Filtro por tag actualiza la lista (Req 6.4)
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [x] 5. Implementar tests E2E de setlists
  - [x] 5.1 Implementar tests CRUD de setlists (`setlists/setlist_crud_test.dart`)
    - Crear `worship_hub_ui/patrol_test/tests/setlists/setlist_crud_test.dart`
    - Seed data: registrar iglesia, login, crear canciones via API para usar en setlists
    - Test: Setlist_List_Page muestra lista con nombre y duración (Req 7.1)
    - Test: Crear setlist con nombre y canciones seleccionadas (Req 7.2)
    - Test: Tap en setlist muestra detalle con canciones en orden (Req 7.3)
    - Test: Editar setlist cambiando nombre o canciones (Req 7.4)
    - Test: Eliminar setlist y verificar que desaparece (Req 7.5)
    - Test: Generar setlist automático con reglas (Req 7.6)
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_

- [x] 6. Implementar tests E2E de calendario y disponibilidad
  - [x] 6.1 Implementar tests de calendario (`calendar/calendar_availability_test.dart`)
    - Crear `worship_hub_ui/patrol_test/tests/calendar/calendar_availability_test.dart`
    - Seed data: registrar iglesia, login, crear servicios programados via API si endpoint disponible
    - Test: Calendar_Page renderiza con table_calendar, leyenda de colores y sección de eventos (Req 8.1)
    - Test: Carga inicial solicita eventos del mes actual y disponibilidad (Req 8.2)
    - Test: Tap en fecha con eventos muestra lista de servicios (Req 8.3)
    - Test: Tap en fecha con servicios muestra Availability_Dialog (Req 8.4)
    - Test: Marcar como no disponible actualiza color del calendario a naranja (Req 8.5)
    - Test: Eliminar no disponibilidad actualiza color a verde (Req 8.6)
    - Test: Navegar a otro mes solicita eventos del mes seleccionado (Req 8.7)
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7_

- [x] 7. Checkpoint - Verificar tests de features principales
  - Ensure all tests pass, ask the user if questions arise.
  - Verificar que los tests de auth, songs, setlists y calendar compilan y ejecutan correctamente contra el backend real

- [x] 8. Implementar tests E2E de equipos y chat
  - [x] 8.1 Implementar tests de gestión de equipos (`teams/team_management_test.dart`)
    - Crear `worship_hub_ui/patrol_test/tests/teams/team_management_test.dart`
    - Seed data: registrar iglesia, login via API
    - Test: Team_List_Page muestra lista de equipos (Req 9.1)
    - Test: Tap en crear equipo navega a formulario con campos (Req 9.2)
    - Test: Crear equipo con datos válidos y verificar en lista (Req 9.3)
    - Test: Tap en equipo navega a Team_Detail_Page con info y navegación a miembros/chat (Req 9.4)
    - Test: Team_Members_Page muestra miembros con nombres y roles (Req 9.5)
    - Test: Eliminar equipo y verificar que desaparece (Req 9.6)
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6_

  - [x] 8.2 Implementar tests de chat de equipo (`chat/team_chat_test.dart`)
    - Crear `worship_hub_ui/patrol_test/tests/chat/team_chat_test.dart`
    - Seed data: registrar iglesia, login, crear equipo via API
    - Test: Team_Chat_Page renderiza con header, área de mensajes e input (Req 10.1)
    - Test: Carga inicial muestra historial de mensajes (Req 10.2)
    - Test: Enviar mensaje y verificar que aparece en el chat (Req 10.3)
    - Test: Mensaje vacío no se envía / botón deshabilitado (Req 10.4)
    - _Requirements: 10.1, 10.2, 10.3, 10.4_

- [x] 9. Implementar tests E2E de notificaciones y perfil
  - [x] 9.1 Implementar tests de notificaciones (`notifications/notifications_test.dart`)
    - Crear `worship_hub_ui/patrol_test/tests/notifications/notifications_test.dart`
    - Seed data: registrar iglesia, login via API (las notificaciones se generan por acciones del sistema)
    - Test: Tap en botón de notificaciones navega a Notifications_Page (Req 11.1)
    - Test: Notifications_Page muestra lista con título, mensaje, icono, estado y tiempo (Req 11.2)
    - Test: Tap en notificación no leída la marca como leída (Req 11.3)
    - Test: "Marcar todas como leídas" actualiza todas y el contador (Req 11.4)
    - Test: Sin notificaciones muestra estado vacío (Req 11.5)
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5_

  - [x] 9.2 Implementar tests de perfil y contraseña (`profile/profile_password_test.dart`)
    - Crear `worship_hub_ui/patrol_test/tests/profile/profile_password_test.dart`
    - Seed data: registrar iglesia, login via API
    - Test: Tap en perfil navega a Profile_Page con nombre, email, rol (Req 12.1)
    - Test: Edit_Profile_Page muestra campos pre-llenados (Req 12.2)
    - Test: Editar nombre y verificar éxito (Req 12.3)
    - Test: Password_Management_Page muestra opciones según estado (Req 12.4)
    - Test: Cambiar contraseña con datos correctos muestra éxito (Req 12.5)
    - Test: Cambiar contraseña con current password incorrecto muestra error (Req 12.6)
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6_

- [x] 10. Implementar tests E2E de categorías, navegación y cross-feature
  - [x] 10.1 Implementar tests de categorías y tags (`categories/category_tag_test.dart`)
    - Crear `worship_hub_ui/patrol_test/tests/categories/category_tag_test.dart`
    - Seed data: registrar iglesia, login via API
    - Test: Category_Management_Page muestra secciones de categorías y tags (Req 13.1)
    - Test: Crear categoría con nombre y descripción (Req 13.2)
    - Test: Crear tag con nombre y color (Req 13.3)
    - Test: Editar categoría existente (Req 13.4)
    - Test: Eliminar categoría (Req 13.5)
    - Test: Eliminar tag (Req 13.6)
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6_

  - [x] 10.2 Implementar tests de navegación (`navigation/app_navigation_test.dart`)
    - Crear `worship_hub_ui/patrol_test/tests/navigation/app_navigation_test.dart`
    - Seed data: registrar iglesia, login via API
    - Test: Home_Page muestra título, stats y grid de 6 features (Req 14.1)
    - Test: Cada card del grid navega a la página correspondiente (Req 14.2)
    - Test: Botón back navega a la página anterior (Req 14.3)
    - Test: Ruta protegida sin autenticación redirige a Login_Page (Req 14.4)
    - _Requirements: 14.1, 14.2, 14.3, 14.4_

  - [x] 10.3 Implementar tests de flujos cross-feature (`cross_feature/cross_feature_flows_test.dart`)
    - Crear `worship_hub_ui/patrol_test/tests/cross_feature/cross_feature_flows_test.dart`
    - Test: Flujo completo de preparación de adoración: login → canciones → crear canción → setlists → crear setlist con canción → calendario → verificar evento (Req 15.1)
    - Test: Flujo completo de gestión de equipo: login → equipos → crear equipo → detalle → miembros → chat → enviar mensaje (Req 15.2)
    - Test: Flujo completo de organización de catálogo: login → categorías → crear categoría → crear tag → canciones → crear canción → buscar canción (Req 15.3)
    - Test: Flujo completo de invitación de miembro: login como admin → enviar invitación → verificar éxito → abrir aceptación con token → aceptar → verificar navegación a login (Req 15.4)
    - _Requirements: 15.1, 15.2, 15.3, 15.4_

- [x] 11. Implementar tests E2E de manejo de errores y estados de carga
  - [x] 11.1 Implementar tests de error handling (`error_handling/error_states_test.dart`)
    - Crear `worship_hub_ui/patrol_test/tests/error_handling/error_states_test.dart`
    - Crear `worship_hub_ui/patrol_test/mocks/error_simulation_interceptor.dart` con `ErrorSimulationInterceptor` que pueda simular timeout y server error en requests específicos
    - Test: HTTP 500 simulado muestra mensaje de error sin crash (Req 16.1) — usar ErrorSimulationInterceptor con `simulateServerError = true`
    - Test: Timeout de red simulado muestra mensaje de error de conexión (Req 16.2) — usar ErrorSimulationInterceptor con `simulateTimeout = true`
    - Test: Estado de carga muestra indicador (shimmer/spinner) antes de que aparezcan los datos (Req 16.3) — verificar loading indicator durante carga real del backend
    - Test: HTTP 401 en request autenticado redirige a Login_Page (Req 16.4) — limpiar token de MockSecureStorage y hacer request
    - _Requirements: 16.1, 16.2, 16.3, 16.4_

- [x] 12. Final checkpoint - Verificar suite completa
  - Ensure all tests pass, ask the user if questions arise.
  - Verificar que todos los archivos de test compilan correctamente
  - Verificar que la suite completa se puede ejecutar con `patrol test`
  - Verificar cobertura de todos los 16 requisitos

## Notes

- No se aplica Property-Based Testing (PBT) — los tests E2E son inherentemente example-based
- Cada test usa datos únicos (timestamps en emails) para evitar colisiones entre tests
- El backend debe estar corriendo con perfil H2 antes de ejecutar: `./gradlew :api:bootRun --args="--spring.profiles.active=h2"`
- Los tests de error handling (task 11) usan `ErrorSimulationInterceptor` para simular HTTP 500 y timeouts ya que no se pueden generar fácilmente con el backend real
- Los checkpoints (tasks 2, 7, 12) aseguran validación incremental
- Todos los tests siguen el patrón: Setup → Seed via API → Login via UI → Navigate → Interact → Assert → Teardown
