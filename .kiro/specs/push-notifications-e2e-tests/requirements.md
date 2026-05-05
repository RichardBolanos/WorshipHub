# Documento de Requisitos — Tests E2E de Patrol para Sistema de Notificaciones Push

## Introducción

Este documento define los requisitos para implementar tests E2E con Patrol que validen el sistema de notificaciones push real de WorshipHub en el frontend Flutter. Los tests existentes en `integration_test/tests/notifications/notifications_test.dart` validan la pantalla de notificaciones con datos mock hardcodeados. Este feature los reemplaza con tests que validan el sistema real contra el backend, cubriendo: registro/desregistro de token FCM, visualización de notificaciones con datos reales, marcado como leídas, deep linking, preferencias filtradas por rol, polling de chat post-migración WebSocket, banner in-app, badge de conteo, estados vacíos, manejo de errores, y flujos de notificación por tipo de evento disparador.

Cada test debe estar en su propio archivo dentro de `integration_test/tests/push_notifications/` para permitir ejecución individual al iterar sobre módulos específicos. Los tests siguen la infraestructura existente de Patrol (TestEnvironment, helpers, seeds) y las reglas del steering `e2e-testing`.

## Glosario

- **Test_E2E_Patrol**: Test de integración end-to-end ejecutado con el framework Patrol contra el backend real (localhost:9090 con H2 in-memory)
- **TestEnvironment**: Clase del framework de testing que encapsula setup/teardown, helpers de UI y seed helpers para datos de prueba
- **ApiSeedHelper**: Cliente HTTP para sembrar datos de prueba directamente vía API REST antes de la interacción con la UI
- **NotificationSeed**: Nuevo seed helper específico para crear notificaciones de prueba en el backend vía API
- **FCM_Mock**: Mock del servicio Firebase Cloud Messaging utilizado en tests E2E para simular el registro de tokens sin envíos reales a dispositivos
- **Deep_Link**: Navegación automática desde una notificación a la pantalla relevante según el tipo de notificación (usando go_router)
- **Pantalla_Notificaciones**: Pantalla del frontend que muestra la lista de notificaciones reales del backend ordenadas por fecha descendente
- **Pantalla_Preferencias**: Pantalla del frontend donde el usuario configura qué tipos de notificación desea recibir, filtrada por su rol
- **Banner_InApp**: Componente visual que aparece en la parte superior de la pantalla cuando llega una notificación con la app en primer plano
- **Badge_Notificaciones**: Indicador numérico sobre el ícono de notificaciones en la barra de navegación que muestra el conteo de no leídas
- **Polling_Chat**: Mecanismo de obtención de mensajes de chat mediante peticiones HTTP periódicas (cada 5-10 segundos) que reemplaza WebSocket/STOMP
- **Mapa_Notificaciones_Rol**: Configuración que define qué tipos de notificación son aplicables a cada rol de usuario (Admin, Líder_Equipo, Miembro)
- **AppLocalizations**: Sistema de internacionalización de Flutter usado para obtener strings localizados en los tests (nunca hardcodear texto)

## Requisitos

### Requisito 1: Registro y Desregistro de Token FCM

**User Story:** Como desarrollador, quiero un test E2E que valide que el token FCM se registra al login y se desregistra al logout, para garantizar que los dispositivos se gestionan correctamente en el ciclo de vida de la sesión.

#### Criterios de Aceptación

1. WHEN el Test_E2E_Patrol ejecuta un flujo de login exitoso, THE Test_E2E_Patrol SHALL verificar que se realiza una llamada POST a `/api/v1/devices/token` con el token FCM del dispositivo y la plataforma correspondiente
2. WHEN el Test_E2E_Patrol ejecuta un flujo de logout, THE Test_E2E_Patrol SHALL verificar que se realiza una llamada DELETE a `/api/v1/devices/token` para eliminar el token del dispositivo actual
3. WHEN el Test_E2E_Patrol ejecuta un login en un dispositivo donde el usuario denegó permisos de notificación, THE Test_E2E_Patrol SHALL verificar que se muestra un mensaje informativo sobre los beneficios de las notificaciones
4. THE Test_E2E_Patrol SHALL utilizar un FCM_Mock que provea un token simulado sin realizar conexiones reales a Firebase

### Requisito 2: Visualización de Pantalla de Notificaciones con Datos Reales

**User Story:** Como desarrollador, quiero un test E2E que valide que la pantalla de notificaciones muestra datos reales del backend en lugar de datos mock, para confirmar la integración correcta con el API.

#### Criterios de Aceptación

1. WHEN el Test_E2E_Patrol navega a la Pantalla_Notificaciones después de sembrar notificaciones vía API, THE Test_E2E_Patrol SHALL verificar que se muestran las notificaciones reales del backend con título, mensaje, tipo, indicador de leída/no leída y timestamp
2. WHEN el Test_E2E_Patrol navega a la Pantalla_Notificaciones sin notificaciones existentes, THE Test_E2E_Patrol SHALL verificar que se muestra el estado vacío con ícono y mensaje informativo
3. THE Test_E2E_Patrol SHALL verificar que las notificaciones se muestran ordenadas por fecha descendente (más recientes primero)
4. THE Test_E2E_Patrol SHALL verificar que cada notificación muestra el ícono correspondiente a su tipo (servicio, chat, canción, equipo, etc.)
5. THE Test_E2E_Patrol SHALL utilizar AppLocalizations para todas las aserciones de texto de UI, sin hardcodear strings en español

### Requisito 3: Marcar Notificaciones como Leídas

**User Story:** Como desarrollador, quiero tests E2E que validen el marcado individual y masivo de notificaciones como leídas, para garantizar que la interacción del usuario actualiza correctamente el estado en backend y frontend.

#### Criterios de Aceptación

1. WHEN el Test_E2E_Patrol toca una notificación no leída en la Pantalla_Notificaciones, THE Test_E2E_Patrol SHALL verificar que la notificación cambia su indicador visual a leída y el conteo de no leídas disminuye
2. WHEN el Test_E2E_Patrol toca el botón "Marcar todas como leídas", THE Test_E2E_Patrol SHALL verificar que todas las notificaciones cambian a estado leída, el conteo se reduce a cero y el botón desaparece
3. THE Test_E2E_Patrol SHALL verificar que el marcado como leída persiste al navegar fuera y volver a la Pantalla_Notificaciones (confirmando persistencia en backend)
4. THE Test_E2E_Patrol SHALL sembrar al menos 3 notificaciones no leídas vía NotificationSeed antes de ejecutar las aserciones de marcado

### Requisito 4: Navegación Deep Linking desde Notificaciones

**User Story:** Como desarrollador, quiero tests E2E que validen que al tocar una notificación se navega a la pantalla correcta según el tipo, para garantizar que el deep linking funciona para todos los tipos de notificación.

#### Criterios de Aceptación

1. WHEN el Test_E2E_Patrol toca una notificación de tipo SERVICE_INVITATION, THE Test_E2E_Patrol SHALL verificar que la app navega a la pantalla de detalle del servicio correspondiente
2. WHEN el Test_E2E_Patrol toca una notificación de tipo CHAT_MESSAGE, THE Test_E2E_Patrol SHALL verificar que la app navega a la pantalla de chat del equipo correspondiente
3. WHEN el Test_E2E_Patrol toca una notificación de tipo NEW_COMMENT, THE Test_E2E_Patrol SHALL verificar que la app navega a la pantalla de detalle de la canción correspondiente
4. WHEN el Test_E2E_Patrol toca una notificación de tipo TEAM_ASSIGNMENT, THE Test_E2E_Patrol SHALL verificar que la app navega a la pantalla de detalle del equipo correspondiente
5. WHEN el Test_E2E_Patrol toca una notificación de tipo NEW_SONG, THE Test_E2E_Patrol SHALL verificar que la app navega a la pantalla de detalle de la canción correspondiente
6. THE Test_E2E_Patrol SHALL verificar que la notificación se marca como leída automáticamente al navegar vía deep link

### Requisito 5: Preferencias de Notificación Filtradas por Rol

**User Story:** Como desarrollador, quiero tests E2E que validen que la pantalla de preferencias muestra solo los toggles aplicables al rol del usuario, para garantizar el filtrado correcto del Mapa_Notificaciones_Rol.

#### Criterios de Aceptación

1. WHEN el Test_E2E_Patrol abre la Pantalla_Preferencias con un usuario de rol Admin, THE Test_E2E_Patrol SHALL verificar que se muestran toggles para todos los tipos de notificación definidos en el Mapa_Notificaciones_Rol
2. WHEN el Test_E2E_Patrol abre la Pantalla_Preferencias con un usuario de rol Miembro, THE Test_E2E_Patrol SHALL verificar que solo se muestran los toggles aplicables al rol Miembro y que los tipos exclusivos de Admin y Líder_Equipo no son visibles
3. WHEN el Test_E2E_Patrol abre la Pantalla_Preferencias con un usuario de rol Líder_Equipo, THE Test_E2E_Patrol SHALL verificar que se muestran los toggles del subconjunto de Líder_Equipo (incluyendo respuesta a invitación de servicio y cambios de disponibilidad) pero no los exclusivos de Admin
4. WHEN el Test_E2E_Patrol desactiva un toggle de preferencia y navega fuera y de vuelta, THE Test_E2E_Patrol SHALL verificar que el toggle permanece desactivado (persistencia en backend)
5. THE Test_E2E_Patrol SHALL crear usuarios con roles específicos vía ApiSeedHelper para cada escenario de rol

### Requisito 6: Polling de Chat Post-Migración WebSocket

**User Story:** Como desarrollador, quiero un test E2E que valide que el chat funciona correctamente con polling HTTP después de la migración desde WebSocket, para confirmar que los mensajes se entregan sin la infraestructura STOMP.

#### Criterios de Aceptación

1. WHEN el Test_E2E_Patrol envía un mensaje de chat en la pantalla de chat del equipo, THE Test_E2E_Patrol SHALL verificar que el mensaje aparece en la lista de mensajes después del siguiente ciclo de polling
2. WHEN otro usuario envía un mensaje de chat (sembrado vía API), THE Test_E2E_Patrol SHALL verificar que el mensaje aparece en la pantalla de chat del usuario actual dentro del intervalo de polling (máximo 10 segundos)
3. THE Test_E2E_Patrol SHALL verificar que la pantalla de chat no utiliza WebSocket para la obtención de mensajes (el servicio WebSocket es un no-op en tests)
4. THE Test_E2E_Patrol SHALL verificar que los mensajes se muestran en orden cronológico con nombre del remitente y timestamp

### Requisito 7: Banner In-App para Notificaciones en Primer Plano

**User Story:** Como desarrollador, quiero un test E2E que valide que cuando llega una notificación con la app activa se muestra un banner in-app en lugar de una notificación del sistema, para confirmar el comportamiento correcto en primer plano.

#### Criterios de Aceptación

1. WHEN el Test_E2E_Patrol simula la llegada de una notificación push con la app en primer plano, THE Test_E2E_Patrol SHALL verificar que aparece un banner visual en la parte superior de la pantalla con el título y mensaje de la notificación
2. WHEN el Test_E2E_Patrol toca el Banner_InApp, THE Test_E2E_Patrol SHALL verificar que la app navega a la pantalla relevante según el tipo de notificación (deep link)
3. WHEN el Test_E2E_Patrol no interactúa con el Banner_InApp, THE Test_E2E_Patrol SHALL verificar que el banner se oculta automáticamente después de un tiempo determinado
4. THE Test_E2E_Patrol SHALL utilizar el mecanismo de simulación de notificaciones del FCM_Mock para disparar la notificación en primer plano

### Requisito 8: Badge de Conteo de Notificaciones No Leídas

**User Story:** Como desarrollador, quiero un test E2E que valide que el badge de notificaciones en la barra de navegación muestra el conteo correcto de no leídas, para garantizar la visibilidad del estado de notificaciones.

#### Criterios de Aceptación

1. WHEN el Test_E2E_Patrol tiene notificaciones no leídas sembradas vía API, THE Test_E2E_Patrol SHALL verificar que el Badge_Notificaciones muestra el número correcto de notificaciones no leídas en el ícono de la barra de navegación
2. WHEN el Test_E2E_Patrol marca una notificación como leída, THE Test_E2E_Patrol SHALL verificar que el Badge_Notificaciones decrementa su conteo
3. WHEN el Test_E2E_Patrol marca todas las notificaciones como leídas, THE Test_E2E_Patrol SHALL verificar que el Badge_Notificaciones desaparece o muestra cero
4. WHEN el Test_E2E_Patrol no tiene notificaciones no leídas, THE Test_E2E_Patrol SHALL verificar que el Badge_Notificaciones no se muestra

### Requisito 9: Notificaciones por Asignación a Servicio

**User Story:** Como desarrollador, quiero un test E2E que valide el flujo completo de notificación cuando un miembro es asignado a un servicio, para confirmar la integración end-to-end del tipo SERVICE_INVITATION.

#### Criterios de Aceptación

1. WHEN el Test_E2E_Patrol crea un servicio con miembros asignados vía ApiSeedHelper, THE Test_E2E_Patrol SHALL verificar que aparece una notificación de tipo SERVICE_INVITATION en la Pantalla_Notificaciones del miembro asignado
2. THE Test_E2E_Patrol SHALL verificar que la notificación de asignación incluye el nombre del servicio, la fecha programada y el rol asignado
3. THE Test_E2E_Patrol SHALL verificar que el creador del servicio no recibe la notificación de asignación (exclusión del remitente)

### Requisito 10: Notificaciones por Mensajes de Chat

**User Story:** Como desarrollador, quiero un test E2E que valide que se genera una notificación cuando otro usuario envía un mensaje de chat, para confirmar la integración del tipo CHAT_MESSAGE.

#### Criterios de Aceptación

1. WHEN el Test_E2E_Patrol siembra un mensaje de chat de otro usuario vía API, THE Test_E2E_Patrol SHALL verificar que aparece una notificación de tipo CHAT_MESSAGE en la Pantalla_Notificaciones del usuario actual
2. THE Test_E2E_Patrol SHALL verificar que la notificación de chat incluye el nombre del remitente, el nombre del equipo y un extracto del mensaje
3. THE Test_E2E_Patrol SHALL verificar que el remitente del mensaje no recibe notificación de su propio mensaje

### Requisito 11: Notificaciones por Comentarios en Canciones

**User Story:** Como desarrollador, quiero un test E2E que valide que se genera una notificación cuando alguien comenta en una canción del usuario, para confirmar la integración del tipo NEW_COMMENT.

#### Criterios de Aceptación

1. WHEN el Test_E2E_Patrol siembra un comentario en una canción creada por el usuario actual vía API, THE Test_E2E_Patrol SHALL verificar que aparece una notificación de tipo NEW_COMMENT en la Pantalla_Notificaciones
2. THE Test_E2E_Patrol SHALL verificar que la notificación de comentario incluye el nombre del comentarista, el título de la canción y un extracto del comentario
3. THE Test_E2E_Patrol SHALL verificar que el autor del comentario no recibe notificación de su propio comentario

### Requisito 12: Notificaciones por Cambios en Equipo

**User Story:** Como desarrollador, quiero un test E2E que valide que se generan notificaciones cuando hay cambios en la composición de un equipo, para confirmar la integración del tipo TEAM_ASSIGNMENT.

#### Criterios de Aceptación

1. WHEN el Test_E2E_Patrol agrega un nuevo miembro a un equipo vía API, THE Test_E2E_Patrol SHALL verificar que los miembros existentes del equipo reciben una notificación de tipo TEAM_ASSIGNMENT
2. THE Test_E2E_Patrol SHALL verificar que la notificación de cambio de equipo incluye el nombre del equipo y una descripción del cambio
3. THE Test_E2E_Patrol SHALL verificar que el usuario que realizó el cambio no recibe la notificación

### Requisito 13: Notificaciones por Cancelación de Servicio

**User Story:** Como desarrollador, quiero un test E2E que valide que se genera una notificación cuando un servicio es cancelado, para confirmar que los miembros asignados son informados.

#### Criterios de Aceptación

1. WHEN el Test_E2E_Patrol cancela un servicio vía API (cambia estado a CANCELLED), THE Test_E2E_Patrol SHALL verificar que los miembros asignados reciben una notificación con el nombre del servicio y la fecha original
2. THE Test_E2E_Patrol SHALL verificar que la notificación de cancelación incluye el motivo de cancelación si fue proporcionado
3. THE Test_E2E_Patrol SHALL verificar que el usuario que canceló el servicio no recibe la notificación

### Requisito 14: Notificaciones por Servicios Recurrentes

**User Story:** Como desarrollador, quiero un test E2E que valide que se genera una notificación consolidada cuando se crea un servicio recurrente con miembros asignados, para confirmar la integración del tipo RECURRING_SERVICE.

#### Criterios de Aceptación

1. WHEN el Test_E2E_Patrol crea un servicio recurrente con miembros asignados vía API, THE Test_E2E_Patrol SHALL verificar que cada miembro asignado recibe una sola notificación consolidada con el patrón de recurrencia y las fechas generadas
2. THE Test_E2E_Patrol SHALL verificar que la notificación incluye el nombre del servicio, el patrón de recurrencia y el rol asignado
3. THE Test_E2E_Patrol SHALL verificar que el programador del servicio recurrente no recibe la notificación

### Requisito 15: Notificaciones por Actualización y Eliminación de Canciones

**User Story:** Como desarrollador, quiero tests E2E que validen que se generan notificaciones cuando una canción en un setlist futuro es actualizada o eliminada, para confirmar la integración de los tipos SONG_UPDATED y SONG_DELETED.

#### Criterios de Aceptación

1. WHEN el Test_E2E_Patrol actualiza una canción que está en un setlist de un servicio futuro vía API, THE Test_E2E_Patrol SHALL verificar que los miembros asignados al servicio reciben una notificación de tipo SONG_UPDATED con el título de la canción y los campos modificados
2. WHEN el Test_E2E_Patrol elimina una canción que está en setlists vía API, THE Test_E2E_Patrol SHALL verificar que los usuarios con esa canción en sus setlists reciben una notificación de tipo SONG_DELETED con el título y los setlists afectados
3. THE Test_E2E_Patrol SHALL verificar que el usuario que realizó la actualización o eliminación no recibe la notificación

### Requisito 16: Notificaciones por Invitación Aceptada

**User Story:** Como desarrollador, quiero un test E2E que valide que el administrador recibe una notificación cuando alguien acepta una invitación a la iglesia, para confirmar la integración del tipo INVITATION_ACCEPTED.

#### Criterios de Aceptación

1. WHEN el Test_E2E_Patrol simula la aceptación de una invitación vía API, THE Test_E2E_Patrol SHALL verificar que el administrador que envió la invitación recibe una notificación de tipo INVITATION_ACCEPTED
2. THE Test_E2E_Patrol SHALL verificar que la notificación incluye el nombre del nuevo miembro y el rol aceptado

### Requisito 17: Notificaciones por Cambio de Disponibilidad

**User Story:** Como desarrollador, quiero tests E2E que validen que el líder de equipo recibe notificaciones cuando un miembro cambia su disponibilidad, para confirmar la integración del tipo AVAILABILITY_CHANGE.

#### Criterios de Aceptación

1. WHEN el Test_E2E_Patrol marca una fecha como no disponible para un miembro vía API, THE Test_E2E_Patrol SHALL verificar que el líder del equipo recibe una notificación con el nombre del miembro y la fecha
2. WHEN el Test_E2E_Patrol elimina la indisponibilidad de un miembro vía API, THE Test_E2E_Patrol SHALL verificar que el líder del equipo recibe una notificación de disponibilidad restaurada
3. THE Test_E2E_Patrol SHALL verificar que el miembro que cambió su disponibilidad no recibe notificación de su propia acción

### Requisito 18: Notificaciones por Modificación de Setlist

**User Story:** Como desarrollador, quiero un test E2E que valide que los miembros asignados a un servicio reciben notificación cuando el setlist es modificado, para confirmar la integración del tipo SERVICE_SCHEDULED.

#### Criterios de Aceptación

1. WHEN el Test_E2E_Patrol modifica el setlist de un servicio futuro (agrega o elimina canciones) vía API, THE Test_E2E_Patrol SHALL verificar que los miembros asignados al servicio reciben una notificación con el nombre del servicio y un resumen del cambio
2. THE Test_E2E_Patrol SHALL verificar que el usuario que modificó el setlist no recibe la notificación

### Requisito 19: Notificaciones por Attachment en Canción

**User Story:** Como desarrollador, quiero un test E2E que valide que se genera una notificación cuando se agrega un attachment a una canción, para confirmar la integración del tipo SONG_ATTACHMENT.

#### Criterios de Aceptación

1. WHEN el Test_E2E_Patrol agrega un attachment a una canción vía API, THE Test_E2E_Patrol SHALL verificar que el creador de la canción y los usuarios que comentaron en ella reciben una notificación de tipo SONG_ATTACHMENT
2. THE Test_E2E_Patrol SHALL verificar que la notificación incluye el título de la canción, el tipo de attachment y el nombre del usuario que lo agregó
3. THE Test_E2E_Patrol SHALL verificar que el usuario que agregó el attachment no recibe la notificación

### Requisito 20: Manejo de Errores en Operaciones de Notificación

**User Story:** Como desarrollador, quiero tests E2E que validen el comportamiento del frontend cuando ocurren errores de red durante operaciones de notificación, para garantizar una experiencia de usuario robusta.

#### Criterios de Aceptación

1. WHEN el Test_E2E_Patrol intenta cargar notificaciones y el backend retorna un error, THE Test_E2E_Patrol SHALL verificar que se muestra un estado de error con mensaje informativo y opción de reintentar
2. WHEN el Test_E2E_Patrol intenta marcar una notificación como leída y la operación falla, THE Test_E2E_Patrol SHALL verificar que se muestra un SnackBar de error y la notificación mantiene su estado original
3. WHEN el Test_E2E_Patrol intenta guardar preferencias de notificación y la operación falla, THE Test_E2E_Patrol SHALL verificar que se muestra un mensaje de error y los toggles revierten a su estado anterior

### Requisito 21: Recordatorios de Servicio

**User Story:** Como desarrollador, quiero un test E2E que valide que los miembros asignados reciben recordatorios antes de un servicio, para confirmar la integración del mecanismo de recordatorios programados.

#### Criterios de Aceptación

1. WHEN el Test_E2E_Patrol siembra un servicio con fecha próxima y miembros asignados que aceptaron, THE Test_E2E_Patrol SHALL verificar que se genera una notificación de recordatorio con el nombre del servicio, la hora programada y el setlist asignado
2. THE Test_E2E_Patrol SHALL verificar que solo los miembros que aceptaron la asignación reciben el recordatorio (no los que declinaron o están pendientes)

### Requisito 22: Estructura de Archivos de Test

**User Story:** Como desarrollador, quiero que cada test E2E esté en su propio archivo dentro de un directorio dedicado, para poder ejecutar tests individualmente al iterar sobre módulos específicos.

#### Criterios de Aceptación

1. THE Test_E2E_Patrol SHALL organizar todos los tests en el directorio `integration_test/tests/push_notifications/` con un archivo separado por cada flujo de test
2. THE Test_E2E_Patrol SHALL nombrar cada archivo de test con el patrón `{flujo}_test.dart` (por ejemplo: `fcm_token_registration_test.dart`, `notifications_screen_test.dart`, `mark_as_read_test.dart`)
3. THE Test_E2E_Patrol SHALL crear un NotificationSeed helper en `integration_test/seed/notification_seed.dart` que encapsule la siembra de notificaciones de prueba vía API
4. THE Test_E2E_Patrol SHALL seguir el patrón existente de TestEnvironment con setup/tearDown en cada archivo de test
5. THE Test_E2E_Patrol SHALL importar desde `patrol_base.dart` y utilizar los helpers existentes (LoginHelper, NavigationHelper, WaitHelper, AssertionHelper)

### Requisito 23: Nueva Canción en Catálogo

**User Story:** Como desarrollador, quiero un test E2E que valide que los miembros de la iglesia reciben una notificación cuando se agrega una nueva canción al catálogo, para confirmar la integración del tipo NEW_SONG.

#### Criterios de Aceptación

1. WHEN el Test_E2E_Patrol crea una nueva canción vía API con un usuario diferente al actual, THE Test_E2E_Patrol SHALL verificar que el usuario actual recibe una notificación de tipo NEW_SONG con el título de la canción y el nombre del creador
2. THE Test_E2E_Patrol SHALL verificar que el creador de la canción no recibe notificación de su propia acción
