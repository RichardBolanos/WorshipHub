# Documento de Requisitos — Tests E2E de UI Flutter para WorshipHub

## Introducción

Este documento define los requisitos para la creación de tests end-to-end (E2E) de interfaz de usuario Flutter para WorshipHub, utilizando **Patrol** como framework de testing. Patrol es el framework E2E más completo para Flutter actualmente, extiende `integration_test` con automatización nativa (diálogos de permisos, notificaciones, navegación del sistema) y ofrece finders más intuitivos.

Los tests existentes en `test/integration/` son tests de BLoC con mocks (mocktail + bloc_test) que validan la lógica de estado pero **no** interactúan con la UI real. Esta nueva suite ejecutará la app completa en un emulador/dispositivo, interactuando con widgets reales, validando navegación, renderizado y flujos de negocio completos desde la perspectiva del usuario.

La app Flutter usa: go_router para navegación, flutter_bloc para estado, Drift para base de datos local, Dio para HTTP, y get_it para inyección de dependencias. Los tests deben configurar un backend mock (servidor HTTP local o interceptores Dio) para simular respuestas de la API sin depender del backend real.

## Glosario

- **Patrol_Test_Suite**: Conjunto completo de tests E2E de UI Flutter que ejecutan la app real en un emulador o dispositivo
- **Patrol**: Framework de testing E2E para Flutter desarrollado por LeanCode que extiende integration_test con automatización nativa y finders mejorados
- **PatrolTester**: Objeto principal de Patrol (referido como `$`) que provee métodos para interactuar con widgets y la plataforma nativa
- **Flutter_App**: La aplicación Flutter de WorshipHub ubicada en `worship_hub_ui/`
- **Mock_API_Server**: Servidor HTTP local o interceptor Dio que simula las respuestas del backend API durante los tests
- **Home_Page**: Pantalla principal de la app que muestra dashboard con estadísticas, grid de features (Canciones, Setlists, Calendario, Equipos, Chat, Categorías) y botones de notificaciones y perfil
- **Login_Page**: Pantalla de autenticación con campos de email y password, botón de login, enlace a registro de iglesia y Google Sign-In
- **Church_Registration_Page**: Pantalla de registro de iglesia con campos para nombre de iglesia, dirección, email, y datos del administrador
- **Song_List_Page**: Pantalla que muestra el catálogo de canciones con búsqueda, filtros por categoría/tag, y paginación
- **Song_Detail_Page**: Pantalla de detalle de canción con letra, acordes ChordPro, barra de transposición, adjuntos y comentarios
- **Create_Song_Page**: Formulario de creación/edición de canción con campos para título, artista, tonalidad, BPM, letra y acordes
- **Setlist_List_Page**: Pantalla que lista los setlists de la iglesia con nombre, duración estimada y fecha
- **Setlist_Builder_Page**: Pantalla de construcción de setlist con drag & drop para reordenar canciones
- **Generate_Setlist_Page**: Pantalla para auto-generar setlists basados en reglas (categoría, duración)
- **Calendar_Page**: Pantalla de calendario con table_calendar que muestra servicios programados y disponibilidad del usuario
- **Team_List_Page**: Pantalla que lista los equipos de la iglesia
- **Team_Detail_Page**: Pantalla de detalle de equipo con información y acceso a miembros y chat
- **Team_Members_Page**: Pantalla que muestra los miembros de un equipo con sus roles
- **Team_Chat_Page**: Pantalla de chat en tiempo real del equipo con historial de mensajes
- **Notifications_Page**: Pantalla que muestra notificaciones del usuario con opciones de marcar como leída y eliminar
- **Send_Invitation_Page**: Formulario para enviar invitaciones a nuevos miembros con email, nombre y rol
- **Accept_Invitation_Page**: Pantalla para aceptar una invitación con token y crear contraseña
- **Profile_Page**: Pantalla de perfil del usuario con información personal y opciones de edición
- **Edit_Profile_Page**: Formulario de edición de perfil con nombre y apellido
- **Password_Management_Page**: Pantalla de gestión de contraseña con opciones de cambiar o establecer contraseña
- **Category_Management_Page**: Pantalla de gestión de categorías y tags del catálogo
- **Welcome_Page**: Pantalla de bienvenida inicial de la app
- **Availability_Dialog**: Diálogo modal para marcar disponibilidad/no disponibilidad en una fecha del calendario
- **BLoC**: Patrón de gestión de estado (Business Logic Component) usado en toda la app con flutter_bloc
- **go_router**: Librería de navegación declarativa usada para todas las rutas de la app
- **get_it**: Service locator usado para inyección de dependencias en la app

## Requisitos

### Requirement 1: Configuración de infraestructura de tests E2E con Patrol

**User Story:** Como desarrollador, quiero una infraestructura de tests E2E configurada con Patrol, para poder ejecutar tests que interactúen con la UI real de la app Flutter.

#### Acceptance Criteria

1. THE Patrol_Test_Suite SHALL incluir la dependencia `patrol` en `pubspec.yaml` como dev_dependency con versión fijada
2. THE Patrol_Test_Suite SHALL incluir un directorio `patrol_test/` en la raíz del proyecto Flutter con la configuración de Patrol
3. THE Patrol_Test_Suite SHALL incluir un archivo de configuración `patrol.yaml` o la sección `patrol` en `pubspec.yaml` con la configuración del test runner
4. THE Patrol_Test_Suite SHALL incluir un Mock_API_Server que intercepte las llamadas HTTP de Dio y retorne respuestas predefinidas para cada endpoint de la API
5. THE Patrol_Test_Suite SHALL incluir un archivo `test_app.dart` que inicialice la Flutter_App con el Mock_API_Server configurado y las dependencias de get_it registradas para testing
6. THE Patrol_Test_Suite SHALL incluir helpers reutilizables para acciones comunes: login, crear iglesia, crear canción, crear setlist, crear equipo, enviar invitación
7. IF la instalación de Patrol CLI falla, THEN THE Patrol_Test_Suite SHALL documentar los pasos manuales de instalación en un README dentro del directorio de tests

### Requirement 2: Tests E2E del flujo de registro de iglesia desde la UI

**User Story:** Como desarrollador, quiero tests E2E que validen el flujo completo de registro de iglesia desde la perspectiva del usuario, para asegurar que el onboarding funciona correctamente en la UI.

#### Acceptance Criteria

1. WHEN the Welcome_Page is displayed, THE Patrol_Test_Suite SHALL verify that the page renders with navigation options to Login_Page and Church_Registration_Page
2. WHEN the user navigates to Church_Registration_Page, THE Patrol_Test_Suite SHALL verify that the form displays fields for church name, church address, church email, admin first name, admin last name, admin email, and admin password
3. WHEN the user fills all required fields with valid data and submits the form, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives the registration request and the app navigates to Home_Page upon success
4. WHEN the user submits the registration form with empty required fields, THE Patrol_Test_Suite SHALL verify that validation error messages are displayed next to the corresponding fields
5. WHEN the user submits the registration form with a password shorter than 8 characters, THE Patrol_Test_Suite SHALL verify that a password validation error is displayed
6. WHEN the Mock_API_Server returns HTTP 409 for duplicate email, THE Patrol_Test_Suite SHALL verify that an error message about duplicate email is displayed to the user

### Requirement 3: Tests E2E del flujo de login y autenticación desde la UI

**User Story:** Como desarrollador, quiero tests E2E que validen el flujo de login desde la perspectiva del usuario, para asegurar que la autenticación funciona correctamente en la UI.

#### Acceptance Criteria

1. WHEN the Login_Page is displayed, THE Patrol_Test_Suite SHALL verify that the page renders with email field, password field, login button, Google Sign-In button, forgot password link, and register church link
2. WHEN the user enters valid credentials and taps the login button, THE Patrol_Test_Suite SHALL verify that a loading indicator is shown, the Mock_API_Server receives the login request, and the app navigates to Home_Page upon success
3. WHEN the user enters invalid credentials and taps the login button, THE Patrol_Test_Suite SHALL verify that an error message about invalid credentials is displayed on the Login_Page
4. WHEN the user taps the forgot password link, THE Patrol_Test_Suite SHALL verify that the app navigates to the forgot password screen
5. WHEN the user taps the register church link, THE Patrol_Test_Suite SHALL verify that the app navigates to Church_Registration_Page
6. WHEN the user submits the login form with empty email or password, THE Patrol_Test_Suite SHALL verify that validation error messages are displayed

### Requirement 4: Tests E2E del flujo de invitación y aceptación de miembros desde la UI

**User Story:** Como desarrollador, quiero tests E2E que validen el flujo completo de invitación de miembros (enviar invitación → aceptar invitación), para asegurar que el onboarding de miembros funciona correctamente en la UI.

#### Acceptance Criteria

1. WHEN an authenticated Church_Admin navigates to Send_Invitation_Page, THE Patrol_Test_Suite SHALL verify that the form displays fields for email, first name, last name, and role selector
2. WHEN the Church_Admin fills the invitation form with valid data and submits, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives the invitation request and a success message is displayed
3. WHEN the Church_Admin submits the invitation form with an email that already exists, THE Patrol_Test_Suite SHALL verify that an error message about duplicate email is displayed
4. WHEN a new user opens Accept_Invitation_Page with a valid token, THE Patrol_Test_Suite SHALL verify that the page displays the invitation details including church name, role, and a password field
5. WHEN the new user enters a valid password and accepts the invitation, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives the acceptance request and the app navigates to Login_Page or Home_Page
6. WHEN the new user enters a password that does not meet complexity requirements, THE Patrol_Test_Suite SHALL verify that a password validation error is displayed
7. WHEN Accept_Invitation_Page is opened with an expired token, THE Patrol_Test_Suite SHALL verify that an error message about expired invitation is displayed

### Requirement 5: Tests E2E del flujo CRUD de canciones desde la UI

**User Story:** Como desarrollador, quiero tests E2E que validen el ciclo completo de vida de canciones (crear, ver lista, ver detalle, editar, eliminar) desde la perspectiva del usuario, para asegurar que la gestión del catálogo funciona correctamente en la UI.

#### Acceptance Criteria

1. WHEN an authenticated user navigates to Song_List_Page from Home_Page, THE Patrol_Test_Suite SHALL verify that the page renders with a list of songs from the Mock_API_Server, showing title and artist for each song
2. WHEN the user taps the create song button on Song_List_Page, THE Patrol_Test_Suite SHALL verify that the app navigates to Create_Song_Page with empty form fields for title, artist, key, BPM, lyrics, and chords
3. WHEN the user fills the song creation form with valid data and submits, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives the creation request and the app navigates back to Song_List_Page with the new song visible
4. WHEN the user taps on a song in Song_List_Page, THE Patrol_Test_Suite SHALL verify that the app navigates to Song_Detail_Page displaying the song title, artist, key, BPM, lyrics, and chords
5. WHEN the user taps the edit button on Song_Detail_Page, THE Patrol_Test_Suite SHALL verify that the app navigates to Create_Song_Page with the song data pre-filled in the form fields
6. WHEN the user modifies song data and submits the edit form, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives the update request and the app reflects the updated data
7. WHEN the user deletes a song, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives the delete request and the song is removed from Song_List_Page
8. WHEN the user submits the song creation form with empty required fields, THE Patrol_Test_Suite SHALL verify that validation error messages are displayed

### Requirement 6: Tests E2E del flujo de búsqueda y filtrado de canciones desde la UI

**User Story:** Como desarrollador, quiero tests E2E que validen la búsqueda y filtrado de canciones, para asegurar que los usuarios pueden encontrar canciones eficientemente en la UI.

#### Acceptance Criteria

1. WHEN the user types a search query in the search field on Song_List_Page, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives the search request and the list updates to show matching songs
2. WHEN the user searches for a term that has no matching songs, THE Patrol_Test_Suite SHALL verify that an empty state message is displayed on Song_List_Page
3. WHEN the user applies a category filter on Song_List_Page, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives the filter request with the categoryId and the list updates to show filtered songs
4. WHEN the user applies a tag filter on Song_List_Page, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives the filter request with tagIds and the list updates to show filtered songs

### Requirement 7: Tests E2E del flujo CRUD de setlists desde la UI

**User Story:** Como desarrollador, quiero tests E2E que validen el ciclo completo de vida de setlists (crear, ver lista, ver detalle, editar, eliminar, agregar/quitar canciones) desde la perspectiva del usuario, para asegurar que la gestión de setlists funciona correctamente en la UI.

#### Acceptance Criteria

1. WHEN an authenticated user navigates to Setlist_List_Page from Home_Page, THE Patrol_Test_Suite SHALL verify that the page renders with a list of setlists from the Mock_API_Server, showing name and estimated duration for each setlist
2. WHEN the user creates a new setlist with name and selected songs, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives the creation request and the new setlist appears in Setlist_List_Page
3. WHEN the user taps on a setlist in Setlist_List_Page, THE Patrol_Test_Suite SHALL verify that the app navigates to the setlist detail view displaying the setlist name, songs in order, and estimated duration
4. WHEN the user edits a setlist by changing its name or modifying songs, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives the update request and the changes are reflected in the UI
5. WHEN the user deletes a setlist, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives the delete request and the setlist is removed from Setlist_List_Page
6. WHEN the user navigates to Generate_Setlist_Page and submits generation rules, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives the generation request and the generated setlist is displayed

### Requirement 8: Tests E2E del flujo de calendario y programación de servicios desde la UI

**User Story:** Como desarrollador, quiero tests E2E que validen el flujo de visualización del calendario, servicios programados y gestión de disponibilidad, para asegurar que la programación funciona correctamente en la UI.

#### Acceptance Criteria

1. WHEN an authenticated user navigates to Calendar_Page from Home_Page, THE Patrol_Test_Suite SHALL verify that the page renders with a table_calendar widget showing the current month, a legend with availability colors, and an events list section
2. WHEN the Calendar_Page loads, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives requests for service events of the current month and user availability records
3. WHEN the user taps on a date that has service events, THE Patrol_Test_Suite SHALL verify that the events list section updates to show the service events for that date with service name and scheduled date
4. WHEN the user taps on a date with services, THE Patrol_Test_Suite SHALL verify that the Availability_Dialog is displayed with options to mark as unavailable with an optional reason
5. WHEN the user marks themselves as unavailable for a date via Availability_Dialog, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives the unavailability request and the calendar cell updates to show the unavailable status color (orange)
6. WHEN the user removes an existing unavailability record via Availability_Dialog, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives the delete request and the calendar cell updates to show the available status color (green)
7. WHEN the user navigates to a different month in the calendar, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives a new request for service events of the selected month

### Requirement 9: Tests E2E del flujo de gestión de equipos desde la UI

**User Story:** Como desarrollador, quiero tests E2E que validen el flujo completo de gestión de equipos (crear, ver lista, ver detalle, gestionar miembros) desde la perspectiva del usuario, para asegurar que la gestión de equipos funciona correctamente en la UI.

#### Acceptance Criteria

1. WHEN an authenticated user navigates to Team_List_Page from Home_Page, THE Patrol_Test_Suite SHALL verify that the page renders with a list of teams from the Mock_API_Server
2. WHEN the user taps the create team button, THE Patrol_Test_Suite SHALL verify that the app navigates to Create_Team_Page with form fields for team name, description, and leader selection
3. WHEN the user fills the team creation form with valid data and submits, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives the creation request and the new team appears in Team_List_Page
4. WHEN the user taps on a team in Team_List_Page, THE Patrol_Test_Suite SHALL verify that the app navigates to Team_Detail_Page displaying team name, description, leader, and navigation to members and chat
5. WHEN the user navigates to Team_Members_Page from Team_Detail_Page, THE Patrol_Test_Suite SHALL verify that the page displays a list of team members with their names and team roles
6. WHEN the user deletes a team, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives the delete request and the team is removed from Team_List_Page

### Requirement 10: Tests E2E del flujo de chat de equipo desde la UI

**User Story:** Como desarrollador, quiero tests E2E que validen el flujo de chat de equipo (enviar mensajes, ver historial) desde la perspectiva del usuario, para asegurar que la comunicación del equipo funciona correctamente en la UI.

#### Acceptance Criteria

1. WHEN an authenticated user navigates to Team_Chat_Page from Team_Detail_Page, THE Patrol_Test_Suite SHALL verify that the page renders with the team name in the header, a message history area, and a message input field with send button
2. WHEN the Team_Chat_Page loads, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives a request for chat history and the messages are displayed in the message area
3. WHEN the user types a message in the input field and taps the send button, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives the message and the new message appears in the chat history
4. WHEN the user sends a message with empty content, THE Patrol_Test_Suite SHALL verify that the send button is disabled or the message is not sent

### Requirement 11: Tests E2E del flujo de notificaciones desde la UI

**User Story:** Como desarrollador, quiero tests E2E que validen el flujo de visualización y gestión de notificaciones, para asegurar que los usuarios pueden ver y gestionar sus notificaciones correctamente en la UI.

#### Acceptance Criteria

1. WHEN an authenticated user taps the notification button on Home_Page, THE Patrol_Test_Suite SHALL verify that the app navigates to Notifications_Page
2. WHEN Notifications_Page loads, THE Patrol_Test_Suite SHALL verify that the page displays a list of notifications with title, message, type icon, read/unread status, and time ago
3. WHEN the user taps on an unread notification, THE Patrol_Test_Suite SHALL verify that the notification is marked as read and the unread count updates
4. WHEN the user taps "Marcar todas como leídas", THE Patrol_Test_Suite SHALL verify that all notifications are marked as read and the unread count becomes zero
5. WHEN there are no notifications, THE Patrol_Test_Suite SHALL verify that an empty state is displayed with an appropriate message

### Requirement 12: Tests E2E del flujo de perfil y gestión de contraseña desde la UI

**User Story:** Como desarrollador, quiero tests E2E que validen el flujo de visualización y edición de perfil, y gestión de contraseña, para asegurar que los usuarios pueden gestionar su información personal correctamente en la UI.

#### Acceptance Criteria

1. WHEN an authenticated user taps the profile button on Home_Page, THE Patrol_Test_Suite SHALL verify that the app navigates to Profile_Page displaying user information including name, email, and role
2. WHEN the user navigates to Edit_Profile_Page, THE Patrol_Test_Suite SHALL verify that the form displays pre-filled fields for first name and last name
3. WHEN the user modifies their name and submits the edit profile form, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives the update request and a success message is displayed
4. WHEN the user navigates to Password_Management_Page, THE Patrol_Test_Suite SHALL verify that the page displays options for changing or setting password based on the user's password status
5. WHEN the user changes their password with correct current password and valid new password, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives the change request and a success message is displayed
6. WHEN the user changes their password with incorrect current password, THE Patrol_Test_Suite SHALL verify that an error message about incorrect current password is displayed

### Requirement 13: Tests E2E del flujo de gestión de categorías y tags desde la UI

**User Story:** Como desarrollador, quiero tests E2E que validen el flujo de gestión de categorías y tags, para asegurar que la clasificación del catálogo funciona correctamente en la UI.

#### Acceptance Criteria

1. WHEN an authenticated user navigates to Category_Management_Page from Home_Page, THE Patrol_Test_Suite SHALL verify that the page renders with sections for categories and tags
2. WHEN the user creates a new category with name and description, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives the creation request and the new category appears in the list
3. WHEN the user creates a new tag with name and color, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives the creation request and the new tag appears in the list
4. WHEN the user edits an existing category, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives the update request and the changes are reflected in the UI
5. WHEN the user deletes a category, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives the delete request and the category is removed from the list
6. WHEN the user deletes a tag, THE Patrol_Test_Suite SHALL verify that the Mock_API_Server receives the delete request and the tag is removed from the list

### Requirement 14: Tests E2E de navegación y estructura de la app desde la UI

**User Story:** Como desarrollador, quiero tests E2E que validen la navegación general de la app y la estructura del Home_Page, para asegurar que los usuarios pueden acceder a todas las funcionalidades correctamente.

#### Acceptance Criteria

1. WHEN an authenticated user is on Home_Page, THE Patrol_Test_Suite SHALL verify that the page displays the WorshipHub title, quick stats section (songs count, setlists count, teams count), and a feature grid with 6 items (Canciones, Setlists, Calendario, Equipos, Chat, Categorías)
2. WHEN the user taps each feature card in the grid, THE Patrol_Test_Suite SHALL verify that the app navigates to the corresponding page: Song_List_Page, Setlist_List_Page, Calendar_Page, Team_List_Page, Team_List_Page (for chat), and Category_Management_Page
3. WHEN the user is on any sub-page and taps the back button, THE Patrol_Test_Suite SHALL verify that the app navigates back to the previous page
4. WHEN an unauthenticated user attempts to access a protected route, THE Patrol_Test_Suite SHALL verify that the app redirects to Login_Page

### Requirement 15: Tests E2E de flujos completos cross-feature desde la UI

**User Story:** Como desarrollador, quiero tests E2E que validen flujos completos que cruzan múltiples features, para asegurar que la integración entre pantallas funciona correctamente desde la perspectiva del usuario.

#### Acceptance Criteria

1. THE Patrol_Test_Suite SHALL include a test that executes the complete worship preparation flow from the UI: login → navigate to songs → create a song → navigate to setlists → create a setlist with the new song → navigate to calendar → verify the service event is visible
2. THE Patrol_Test_Suite SHALL include a test that executes the complete team management flow from the UI: login → navigate to teams → create a team → navigate to team detail → view team members → navigate to team chat → send a message
3. THE Patrol_Test_Suite SHALL include a test that executes the complete catalog organization flow from the UI: login → navigate to categories → create a category → create a tag → navigate to songs → create a song → verify the song appears in the list with search
4. THE Patrol_Test_Suite SHALL include a test that executes the complete member invitation flow from the UI: login as admin → navigate to send invitation → send invitation → verify success → open accept invitation page with token → accept invitation → verify navigation to login

### Requirement 16: Tests E2E de manejo de errores y estados de carga desde la UI

**User Story:** Como desarrollador, quiero tests E2E que validen que la app maneja correctamente los errores de red y estados de carga, para asegurar una experiencia de usuario robusta.

#### Acceptance Criteria

1. WHEN the Mock_API_Server returns HTTP 500 for any request, THE Patrol_Test_Suite SHALL verify that the app displays an error message to the user instead of crashing
2. WHEN the Mock_API_Server simulates a network timeout, THE Patrol_Test_Suite SHALL verify that the app displays a timeout or connection error message
3. WHEN a page is loading data from the Mock_API_Server, THE Patrol_Test_Suite SHALL verify that a loading indicator (shimmer, spinner, or progress indicator) is displayed before the data appears
4. WHEN the Mock_API_Server returns HTTP 401 for an authenticated request, THE Patrol_Test_Suite SHALL verify that the app redirects the user to Login_Page
