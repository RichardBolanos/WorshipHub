# Documento de Requisitos — Sistema de Notificaciones Push

## Introducción

Este documento define los requisitos para implementar un sistema completo de notificaciones push en WorshipHub. El sistema enviará notificaciones a nivel de dispositivo (Android push, iOS push y Web push) cuando acciones de otros usuarios generen eventos relevantes. Actualmente, la plataforma tiene notificaciones in-app con datos mock hardcodeados en el frontend y entrega de mensajes de chat vía WebSocket/STOMP. Este feature reemplaza ambos mecanismos: Firebase Cloud Messaging (FCM) será el único mecanismo de entrega push para todas las plataformas (Android, iOS y Web), y las notificaciones mock del frontend serán reemplazadas por datos reales del backend.

El alcance cubre: migración de notificaciones basadas en sockets a FCM, eliminación de notificaciones mock, soporte para iOS (APNs vía FCM), asignaciones y cancelaciones de servicios, mensajes de chat, comentarios en canciones, cambios de equipo, nuevas canciones, invitaciones a la iglesia, recordatorios de servicio, modificaciones de setlist, servicios recurrentes (creación, actualización de regla, eliminación), actualizaciones y eliminaciones de canciones, attachments agregados a canciones, aceptación de invitaciones, y cambios de disponibilidad de miembros.

## Glosario

- **Sistema_Push**: Componente del backend responsable de enviar notificaciones push a dispositivos mediante Firebase Cloud Messaging (FCM)
- **Servicio_Registro_Dispositivos**: Componente del backend que gestiona el registro y desregistro de tokens FCM de dispositivos
- **Cliente_Notificaciones**: Componente del frontend (Flutter) que gestiona la recepción de notificaciones push, permisos y presentación al usuario
- **Token_FCM**: Token único generado por Firebase Cloud Messaging que identifica un dispositivo específico para recibir notificaciones push
- **Token_APNs**: Token de Apple Push Notification service que FCM utiliza internamente para entregar notificaciones a dispositivos iOS
- **Notificación_Push**: Mensaje enviado a un dispositivo a través de FCM que aparece como notificación del sistema operativo (Android notification tray, iOS notification center o Web browser notification)
- **Evento_Disparador**: Acción realizada por un usuario que genera una notificación para otro(s) usuario(s)
- **Preferencias_Notificación**: Configuración por usuario que determina qué tipos de notificaciones desea recibir
- **Servicio_Culto**: Evento de servicio de adoración programado en el calendario (ServiceEvent)
- **Miembro_Asignado**: Usuario asignado a participar en un servicio de adoración con un rol específico
- **Servicio_Recurrente**: Servicio de adoración configurado con una regla de recurrencia que genera múltiples instancias automáticamente
- **Regla_Recurrencia**: Patrón de repetición (semanal, quincenal, mensual) que define cuándo se generan instancias de un servicio recurrente
- **Líder_Equipo**: Usuario con rol de liderazgo en un equipo de alabanza, responsable de gestionar asignaciones y disponibilidad
- **Rol_Usuario**: Rol asignado a un usuario dentro de la iglesia que determina sus permisos y las notificaciones que puede recibir. Los roles definidos son: Admin (administrador de la iglesia), Líder_Equipo (líder de un equipo de alabanza) y Miembro (miembro regular del equipo)
- **Mapa_Notificaciones_Rol**: Configuración que define qué tipos de notificación son aplicables a cada Rol_Usuario, utilizada para filtrar tanto el envío de notificaciones como la visualización de preferencias
- **Setlist_Futuro**: Setlist asociado a un servicio de adoración cuya fecha programada es posterior a la fecha actual
- **Notificación_Mock**: Datos de notificación hardcodeados en el frontend que no provienen del backend y deben ser eliminados
- **WebSocket_STOMP**: Protocolo de comunicación bidireccional actualmente usado para chat en tiempo real que será reemplazado por FCM para la entrega de notificaciones push

## Requisitos

### Requisito 1: Registro de Dispositivos

**User Story:** Como usuario de WorshipHub, quiero que mi dispositivo se registre automáticamente para recibir notificaciones push, para que pueda recibir alertas importantes sin configuración manual.

#### Criterios de Aceptación

1. WHEN un usuario inicia sesión exitosamente, THE Cliente_Notificaciones SHALL solicitar permisos de notificación al sistema operativo y, si se conceden, enviar el Token_FCM al Servicio_Registro_Dispositivos
2. WHEN el Servicio_Registro_Dispositivos recibe un Token_FCM, THE Servicio_Registro_Dispositivos SHALL almacenar el token asociado al usuario, la plataforma (ANDROID, IOS o WEB) y la fecha de registro
3. WHEN un usuario inicia sesión en múltiples dispositivos, THE Servicio_Registro_Dispositivos SHALL almacenar un Token_FCM por cada dispositivo activo del usuario
4. WHEN un Token_FCM es rechazado por FCM como inválido, THE Sistema_Push SHALL eliminar el token de la base de datos
5. WHEN un usuario cierra sesión, THE Cliente_Notificaciones SHALL enviar una solicitud de desregistro al Servicio_Registro_Dispositivos para eliminar el Token_FCM del dispositivo actual
6. IF el usuario deniega los permisos de notificación, THEN THE Cliente_Notificaciones SHALL mostrar un mensaje informativo explicando los beneficios de las notificaciones y permitir activarlas posteriormente desde configuración
7. WHEN un usuario inicia sesión en un dispositivo iOS, THE Cliente_Notificaciones SHALL solicitar permisos de notificación mediante el diálogo nativo de iOS y registrar el Token_APNs a través de FCM

### Requisito 2: Envío de Notificaciones Push por Asignación a Servicio

**User Story:** Como miembro de un equipo de alabanza, quiero recibir una notificación push cuando soy asignado a un servicio de adoración, para que pueda confirmar o declinar mi participación oportunamente.

#### Criterios de Aceptación

1. WHEN un líder de alabanza programa un Servicio_Culto y asigna miembros, THE Sistema_Push SHALL enviar una Notificación_Push a cada Miembro_Asignado con el nombre del servicio, la fecha programada y el rol asignado
2. WHEN un Miembro_Asignado recibe la notificación push de asignación, THE Cliente_Notificaciones SHALL mostrar la notificación con acciones rápidas para "Aceptar" o "Declinar" directamente desde la notificación
3. THE Sistema_Push SHALL enviar la notificación a todos los dispositivos registrados del Miembro_Asignado

### Requisito 3: Envío de Notificaciones Push por Mensajes de Chat

**User Story:** Como miembro de un equipo, quiero recibir una notificación push cuando alguien envía un mensaje en el chat del equipo y no estoy activo en la conversación, para no perder comunicaciones importantes.

#### Criterios de Aceptación

1. WHEN un usuario envía un mensaje en el chat de un equipo, THE Sistema_Push SHALL enviar una Notificación_Push a todos los miembros del equipo excepto al remitente
2. WHILE un usuario tiene la pantalla de chat del equipo activa, THE Sistema_Push SHALL omitir el envío de Notificación_Push de mensajes de ese chat para ese usuario
3. THE Notificación_Push de chat SHALL incluir el nombre del remitente, el nombre del equipo y un extracto del mensaje (máximo 100 caracteres)

### Requisito 4: Envío de Notificaciones Push por Comentarios en Canciones

**User Story:** Como miembro del equipo que contribuye canciones, quiero recibir una notificación push cuando alguien comenta en una canción que yo agregué, para poder responder a discusiones sobre arreglos.

#### Criterios de Aceptación

1. WHEN un usuario agrega un comentario a una canción, THE Sistema_Push SHALL enviar una Notificación_Push al usuario que creó la canción (si es diferente al comentarista)
2. WHEN un usuario agrega un comentario a una canción, THE Sistema_Push SHALL enviar una Notificación_Push a todos los usuarios que previamente comentaron en esa canción (excepto al comentarista)
3. THE Notificación_Push de comentario SHALL incluir el nombre del comentarista, el título de la canción y un extracto del comentario (máximo 100 caracteres)

### Requisito 5: Envío de Notificaciones Push por Cambios en Equipo

**User Story:** Como miembro de un equipo de alabanza, quiero recibir notificaciones push cuando hay cambios en la composición de mi equipo, para estar al tanto de nuevos integrantes o salidas.

#### Criterios de Aceptación

1. WHEN un nuevo miembro es agregado a un equipo, THE Sistema_Push SHALL enviar una Notificación_Push a todos los miembros existentes del equipo con el nombre del nuevo miembro y su rol
2. WHEN un miembro es removido de un equipo, THE Sistema_Push SHALL enviar una Notificación_Push a los miembros restantes del equipo
3. WHEN el líder de un equipo cambia, THE Sistema_Push SHALL enviar una Notificación_Push a todos los miembros del equipo informando el cambio de liderazgo
4. WHEN un miembro cambia de rol dentro del equipo, THE Sistema_Push SHALL enviar una Notificación_Push al miembro afectado con su nuevo rol

### Requisito 6: Envío de Notificaciones Push por Respuesta a Invitación de Servicio

**User Story:** Como líder de alabanza, quiero recibir una notificación push cuando un miembro acepta o declina su asignación a un servicio, para poder gestionar reemplazos si es necesario.

#### Criterios de Aceptación

1. WHEN un Miembro_Asignado acepta su asignación a un Servicio_Culto, THE Sistema_Push SHALL enviar una Notificación_Push al líder del equipo con el nombre del miembro y la confirmación
2. WHEN un Miembro_Asignado declina su asignación a un Servicio_Culto, THE Sistema_Push SHALL enviar una Notificación_Push al líder del equipo con el nombre del miembro y el rechazo
3. THE Notificación_Push de respuesta SHALL incluir el nombre del servicio, la fecha y el nombre del miembro que respondió

### Requisito 7: Envío de Notificaciones Push por Nueva Canción en Catálogo

**User Story:** Como miembro del equipo de alabanza, quiero recibir una notificación push cuando se agrega una nueva canción al catálogo de mi iglesia, para explorar nuevo material musical.

#### Criterios de Aceptación

1. WHEN un usuario agrega una nueva canción al catálogo de la iglesia, THE Sistema_Push SHALL enviar una Notificación_Push a todos los miembros activos de la iglesia excepto al creador
2. THE Notificación_Push de nueva canción SHALL incluir el título de la canción, el artista y el nombre del usuario que la agregó

### Requisito 8: Envío de Notificaciones Push por Invitación a la Iglesia

**User Story:** Como administrador de iglesia, quiero que los usuarios invitados reciban una notificación push cuando son invitados a unirse a la plataforma, para que completen su registro rápidamente.

#### Criterios de Aceptación

1. WHEN un administrador envía una invitación a un email que ya tiene cuenta en la plataforma, THE Sistema_Push SHALL enviar una Notificación_Push al usuario existente informando la invitación pendiente
2. THE Notificación_Push de invitación SHALL incluir el nombre de la iglesia que invita y el rol ofrecido

### Requisito 9: Envío de Notificaciones Push por Recordatorio de Servicio

**User Story:** Como miembro asignado a un servicio, quiero recibir un recordatorio push antes del servicio, para prepararme adecuadamente.

#### Criterios de Aceptación

1. WHEN faltan 24 horas para un Servicio_Culto con estado PUBLISHED o CONFIRMED, THE Sistema_Push SHALL enviar una Notificación_Push de recordatorio a todos los miembros asignados que hayan aceptado
2. WHEN faltan 2 horas para un Servicio_Culto con estado PUBLISHED o CONFIRMED, THE Sistema_Push SHALL enviar una segunda Notificación_Push de recordatorio a todos los miembros asignados que hayan aceptado
3. THE Notificación_Push de recordatorio SHALL incluir el nombre del servicio, la hora programada y el setlist asignado (si existe)

### Requisito 10: Envío de Notificaciones Push por Modificación de Setlist

**User Story:** Como miembro asignado a un servicio, quiero recibir una notificación push cuando el setlist de mi próximo servicio es modificado, para practicar las canciones correctas.

#### Criterios de Aceptación

1. WHEN un líder modifica el setlist asociado a un Servicio_Culto futuro (agrega, elimina o reordena canciones), THE Sistema_Push SHALL enviar una Notificación_Push a todos los miembros asignados al servicio
2. THE Notificación_Push de modificación de setlist SHALL incluir el nombre del servicio, la fecha y un resumen del cambio realizado

### Requisito 11: Preferencias de Notificación del Usuario

**User Story:** Como usuario de WorshipHub, quiero poder configurar qué tipos de notificaciones push deseo recibir según mi rol, para evitar interrupciones innecesarias y ver solo las opciones relevantes para mí.

#### Criterios de Aceptación

1. THE Cliente_Notificaciones SHALL proporcionar una pantalla de Preferencias_Notificación donde el usuario pueda activar o desactivar cada tipo de notificación individualmente
2. WHEN un Evento_Disparador genera una notificación, THE Sistema_Push SHALL verificar las Preferencias_Notificación del usuario destinatario antes de enviar la Notificación_Push
3. IF el usuario tiene desactivado un tipo de notificación en sus preferencias, THEN THE Sistema_Push SHALL almacenar la notificación in-app pero omitir el envío push
4. THE Preferencias_Notificación SHALL tener todos los tipos de notificación aplicables al Rol_Usuario activados por defecto para nuevos usuarios
5. THE Cliente_Notificaciones SHALL mostrar en la pantalla de Preferencias_Notificación únicamente los tipos de notificación aplicables al Rol_Usuario actual del usuario, según el Mapa_Notificaciones_Rol
6. WHEN el Rol_Usuario de un usuario cambia (por ejemplo, de Miembro a Líder_Equipo), THE Sistema_Push SHALL actualizar las Preferencias_Notificación visibles para reflejar los tipos de notificación del nuevo rol, activando por defecto los tipos recién disponibles
7. WHEN el Rol_Usuario de un usuario cambia a un rol con menos tipos de notificación aplicables, THE Sistema_Push SHALL conservar las preferencias previas en la base de datos pero THE Cliente_Notificaciones SHALL ocultar los tipos no aplicables al nuevo rol en la pantalla de preferencias

### Requisito 12: Gestión de Notificaciones en el Frontend

**User Story:** Como usuario de WorshipHub, quiero ver un historial de mis notificaciones y poder interactuar con ellas, para gestionar mis pendientes.

#### Criterios de Aceptación

1. THE Cliente_Notificaciones SHALL mostrar un badge con el conteo de notificaciones no leídas en el ícono de notificaciones de la barra de navegación
2. WHEN el usuario abre la pantalla de notificaciones, THE Cliente_Notificaciones SHALL mostrar la lista de notificaciones ordenadas por fecha descendente con indicador visual de leída/no leída
3. WHEN el usuario toca una notificación, THE Cliente_Notificaciones SHALL marcarla como leída y navegar a la pantalla relevante según el tipo de notificación
4. WHEN el usuario recibe una Notificación_Push con la app en primer plano, THE Cliente_Notificaciones SHALL mostrar un banner in-app en lugar de la notificación del sistema
5. WHEN el usuario toca una Notificación_Push del sistema (app en segundo plano o cerrada), THE Cliente_Notificaciones SHALL abrir la app y navegar directamente a la pantalla relevante

### Requisito 13: Infraestructura Backend de Push

**User Story:** Como equipo de desarrollo, quiero una infraestructura robusta de envío push en el backend, para garantizar la entrega confiable de notificaciones.

#### Criterios de Aceptación

1. THE Sistema_Push SHALL utilizar Firebase Admin SDK para enviar notificaciones a través de FCM
2. WHEN el Sistema_Push envía una notificación, THE Sistema_Push SHALL registrar el resultado del envío (éxito o fallo) en los logs del sistema
3. IF FCM retorna un error de token inválido (UNREGISTERED o INVALID_ARGUMENT), THEN THE Sistema_Push SHALL eliminar el Token_FCM de la base de datos automáticamente
4. IF FCM retorna un error transitorio (UNAVAILABLE o INTERNAL), THEN THE Sistema_Push SHALL reintentar el envío con backoff exponencial (máximo 3 reintentos)
5. THE Sistema_Push SHALL procesar el envío de notificaciones de forma asíncrona para no bloquear las operaciones principales del usuario que genera el evento
6. THE Sistema_Push SHALL soportar el envío a múltiples dispositivos del mismo usuario en una sola operación batch
7. WHEN el Sistema_Push construye un mensaje para un dispositivo iOS, THE Sistema_Push SHALL incluir la configuración APNs adecuada (alert, badge, sound) en el mensaje FCM

### Requisito 14: Notificaciones Push en Plataforma Web

**User Story:** Como usuario que accede a WorshipHub desde un navegador web, quiero recibir notificaciones push del navegador, para estar informado sin tener la pestaña activa.

#### Criterios de Aceptación

1. WHEN un usuario accede a WorshipHub desde un navegador web compatible, THE Cliente_Notificaciones SHALL solicitar permisos de notificación del navegador
2. THE Cliente_Notificaciones SHALL registrar un Service Worker para recibir notificaciones push en segundo plano (pestaña cerrada o navegador minimizado)
3. WHEN una Notificación_Push llega al Service Worker, THE Cliente_Notificaciones SHALL mostrar una notificación nativa del navegador con título, cuerpo e ícono de WorshipHub
4. WHEN el usuario hace clic en la notificación del navegador, THE Cliente_Notificaciones SHALL enfocar la pestaña de WorshipHub (o abrirla si está cerrada) y navegar a la pantalla relevante

### Requisito 15: Notificaciones Push en Plataforma Android

**User Story:** Como usuario que accede a WorshipHub desde un dispositivo Android, quiero recibir notificaciones push nativas, para estar informado incluso con la app cerrada.

#### Criterios de Aceptación

1. WHEN una Notificación_Push llega al dispositivo Android con la app cerrada, THE Cliente_Notificaciones SHALL mostrar una notificación en la bandeja de notificaciones del sistema con título, cuerpo e ícono de WorshipHub
2. THE Cliente_Notificaciones SHALL agrupar las notificaciones por tipo usando canales de notificación de Android (servicios, chat, equipo, canciones)
3. WHEN el usuario toca la notificación en la bandeja de Android, THE Cliente_Notificaciones SHALL abrir la app y navegar directamente a la pantalla relevante
4. THE Cliente_Notificaciones SHALL mostrar acciones rápidas en la notificación de asignación a servicio (botones "Aceptar" y "Declinar")

### Requisito 16: Cancelación de Servicio

**User Story:** Como miembro asignado a un servicio, quiero recibir una notificación push si el servicio es cancelado, para no presentarme innecesariamente.

#### Criterios de Aceptación

1. WHEN un líder cancela un Servicio_Culto (cambia estado a CANCELLED), THE Sistema_Push SHALL enviar una Notificación_Push a todos los miembros asignados al servicio informando la cancelación
2. THE Notificación_Push de cancelación SHALL incluir el nombre del servicio, la fecha original y el motivo de cancelación (si se proporciona)

### Requisito 17: Notificaciones Push por Servicios Recurrentes

**User Story:** Como miembro de un equipo de alabanza, quiero recibir una notificación push cuando se crea un servicio recurrente y soy asignado a sus instancias, para estar informado de mis compromisos futuros.

#### Criterios de Aceptación

1. WHEN un líder crea un Servicio_Recurrente y se generan instancias con miembros asignados, THE Sistema_Push SHALL enviar una Notificación_Push a cada Miembro_Asignado (excepto al programador) con el nombre del servicio, las fechas programadas, el patrón de recurrencia y el rol asignado
2. THE Sistema_Push SHALL enviar una sola notificación consolidada por miembro que resuma todas las instancias generadas, en lugar de una notificación por cada instancia individual
3. THE Notificación_Push de servicio recurrente SHALL incluir el nombre del servicio, el patrón de recurrencia (semanal, quincenal, mensual), las fechas de las instancias generadas y el rol asignado al miembro

### Requisito 18: Notificaciones Push por Actualización de Regla de Recurrencia

**User Story:** Como miembro asignado a un servicio recurrente, quiero recibir una notificación push cuando la regla de recurrencia es modificada, para ajustar mi agenda a las nuevas fechas.

#### Criterios de Aceptación

1. WHEN un líder actualiza la Regla_Recurrencia de un Servicio_Recurrente, THE Sistema_Push SHALL enviar una Notificación_Push a todos los miembros asignados a las instancias futuras afectadas (excepto al usuario que realizó el cambio)
2. THE Notificación_Push de actualización de recurrencia SHALL incluir el nombre del servicio padre, el nuevo patrón de recurrencia y las fechas afectadas
3. IF la actualización de la Regla_Recurrencia elimina instancias futuras a las que un miembro estaba asignado, THEN THE Sistema_Push SHALL incluir en la notificación las fechas eliminadas

### Requisito 19: Notificaciones Push por Eliminación de Servicio Recurrente

**User Story:** Como miembro asignado a un servicio recurrente, quiero recibir una notificación push cuando el servicio recurrente es eliminado, para saber que mis compromisos futuros han sido cancelados.

#### Criterios de Aceptación

1. WHEN un líder elimina un Servicio_Recurrente, THE Sistema_Push SHALL enviar una Notificación_Push a todos los miembros asignados a las instancias eliminadas (excepto al usuario que realizó la eliminación)
2. THE Notificación_Push de eliminación de servicio recurrente SHALL incluir el nombre del servicio, las fechas de las instancias eliminadas y el motivo de eliminación (si se proporciona)

### Requisito 20: Notificaciones Push por Actualización de Canción

**User Story:** Como miembro que tiene una canción en mi setlist para un servicio futuro, quiero recibir una notificación push cuando los detalles de esa canción son actualizados, para practicar con la información correcta.

#### Criterios de Aceptación

1. WHEN un usuario actualiza los detalles de una canción (tonalidad, BPM, letra o acordes), THE Sistema_Push SHALL enviar una Notificación_Push a todos los usuarios que tienen esa canción en setlists asociados a servicios futuros (excepto al usuario que realizó la actualización)
2. THE Notificación_Push de actualización de canción SHALL incluir el título de la canción, los campos que fueron modificados y el nombre del usuario que realizó la actualización
3. THE Sistema_Push SHALL enviar una sola notificación por usuario aunque la canción aparezca en múltiples setlists futuros del mismo usuario

### Requisito 21: Notificaciones Push por Eliminación de Canción

**User Story:** Como miembro que tiene una canción en mi setlist, quiero recibir una notificación push cuando esa canción es eliminada del catálogo, para saber que debo buscar un reemplazo.

#### Criterios de Aceptación

1. WHEN un usuario elimina una canción del catálogo, THE Sistema_Push SHALL enviar una Notificación_Push a todos los usuarios que tienen esa canción en sus setlists (excepto al usuario que realizó la eliminación)
2. THE Notificación_Push de eliminación de canción SHALL incluir el título de la canción, el nombre del usuario que la eliminó y los nombres de los setlists afectados

### Requisito 22: Notificaciones Push por Attachment Agregado a Canción

**User Story:** Como creador de una canción o participante en discusiones sobre ella, quiero recibir una notificación push cuando se agrega un nuevo attachment, para acceder al nuevo recurso.

#### Criterios de Aceptación

1. WHEN un usuario agrega un attachment a una canción (YouTube, PDF, Spotify, audio u otro enlace), THE Sistema_Push SHALL enviar una Notificación_Push al creador de la canción y a todos los usuarios que previamente comentaron en esa canción (excepto al usuario que agregó el attachment)
2. THE Notificación_Push de attachment SHALL incluir el título de la canción, el tipo de attachment agregado y el nombre del usuario que lo agregó

### Requisito 23: Notificaciones Push por Invitación Aceptada

**User Story:** Como administrador de iglesia que envió una invitación, quiero recibir una notificación push cuando alguien acepta mi invitación, para dar la bienvenida al nuevo miembro.

#### Criterios de Aceptación

1. WHEN un usuario acepta una invitación a unirse a la iglesia, THE Sistema_Push SHALL enviar una Notificación_Push al administrador que envió la invitación
2. THE Notificación_Push de invitación aceptada SHALL incluir el nombre del nuevo miembro, su email y el rol aceptado

### Requisito 24: Notificaciones Push por Cambio de Disponibilidad (No Disponible)

**User Story:** Como líder de equipo, quiero recibir una notificación push cuando un miembro de mi equipo se marca como no disponible para una fecha, para gestionar reemplazos con anticipación.

#### Criterios de Aceptación

1. WHEN un miembro del equipo marca una fecha como no disponible, THE Sistema_Push SHALL enviar una Notificación_Push al Líder_Equipo (o líderes) del equipo al que pertenece el miembro
2. THE Notificación_Push de indisponibilidad SHALL incluir el nombre del miembro, la fecha no disponible y el motivo (si se proporcionó)

### Requisito 25: Notificaciones Push por Cambio de Disponibilidad (Disponible de Nuevo)

**User Story:** Como líder de equipo, quiero recibir una notificación push cuando un miembro de mi equipo elimina su indisponibilidad, para saber que está disponible nuevamente.

#### Criterios de Aceptación

1. WHEN un miembro del equipo elimina su registro de indisponibilidad para una fecha, THE Sistema_Push SHALL enviar una Notificación_Push al Líder_Equipo (o líderes) del equipo al que pertenece el miembro
2. THE Notificación_Push de disponibilidad restaurada SHALL incluir el nombre del miembro y la fecha previamente marcada como no disponible

### Requisito 26: Notificaciones Push en Plataforma iOS

**User Story:** Como usuario que accede a WorshipHub desde un dispositivo iOS (iPhone o iPad), quiero recibir notificaciones push nativas, para estar informado incluso con la app cerrada.

#### Criterios de Aceptación

1. WHEN una Notificación_Push llega al dispositivo iOS con la app cerrada o en segundo plano, THE Cliente_Notificaciones SHALL mostrar una notificación en el centro de notificaciones de iOS con título, cuerpo e ícono de WorshipHub
2. THE Cliente_Notificaciones SHALL solicitar permisos de notificación mediante el diálogo nativo de iOS (UNUserNotificationCenter) al primer inicio de sesión
3. WHEN el usuario toca la notificación en el centro de notificaciones de iOS, THE Cliente_Notificaciones SHALL abrir la app y navegar directamente a la pantalla relevante
4. THE Cliente_Notificaciones SHALL configurar las categorías de notificación de iOS para la acción rápida de asignación a servicio (botones "Aceptar" y "Declinar")
5. THE Sistema_Push SHALL incluir la configuración APNs (alert, badge, sound) en los mensajes FCM destinados a dispositivos iOS
6. WHEN la app está en primer plano en iOS, THE Cliente_Notificaciones SHALL interceptar la notificación y mostrar un banner in-app en lugar de la notificación del sistema

### Requisito 27: Migración de Notificaciones Basadas en Sockets a FCM

**User Story:** Como equipo de desarrollo, quiero consolidar toda la entrega de notificaciones push en FCM, para simplificar la arquitectura y garantizar entrega confiable en todas las plataformas incluyendo cuando la app está cerrada.

#### Criterios de Aceptación

1. THE Sistema_Push SHALL utilizar FCM como único mecanismo de entrega de notificaciones push para todas las plataformas (Android, iOS y Web)
2. WHEN se complete la migración, THE Sistema_Push SHALL eliminar la configuración WebSocket_STOMP utilizada para la entrega de notificaciones (WebSocketConfig, WebSocketAuthInterceptor)
3. WHEN un usuario envía un mensaje de chat, THE Sistema_Push SHALL entregar la notificación push exclusivamente a través de FCM en lugar de WebSocket_STOMP
4. THE Sistema_Push SHALL mantener la funcionalidad de chat en tiempo real mediante polling o FCM data messages, reemplazando la conexión WebSocket_STOMP existente
5. WHEN se elimina la infraestructura WebSocket_STOMP, THE Sistema_Push SHALL eliminar las dependencias de Spring WebSocket y STOMP del proyecto (spring-boot-starter-websocket, spring-messaging)
6. THE Sistema_Push SHALL eliminar los headers de CORS relacionados con WebSocket (Upgrade, Connection, Sec-WebSocket-Key, Sec-WebSocket-Version, Sec-WebSocket-Extensions) de la configuración de CorsConfig

### Requisito 28: Eliminación de Notificaciones Mock del Frontend

**User Story:** Como equipo de desarrollo, quiero eliminar las notificaciones mock hardcodeadas del frontend, para que la pantalla de notificaciones muestre datos reales del backend.

#### Criterios de Aceptación

1. THE Cliente_Notificaciones SHALL eliminar todos los datos de Notificación_Mock hardcodeados de la pantalla de notificaciones (NotificationsPage)
2. WHEN el usuario abre la pantalla de notificaciones, THE Cliente_Notificaciones SHALL obtener las notificaciones reales del backend a través del API REST existente
3. WHEN no existen notificaciones para el usuario, THE Cliente_Notificaciones SHALL mostrar un estado vacío con un mensaje informativo
4. THE Cliente_Notificaciones SHALL reemplazar la lista mock de Map<String, dynamic> por modelos tipados que correspondan a la respuesta del API de notificaciones del backend
5. THE Cliente_Notificaciones SHALL integrar la pantalla de notificaciones con el BLoC de notificaciones para gestionar el estado de carga, error y datos reales

### Requisito 29: Cobertura de Tests Unitarios y E2E para Notificaciones

**User Story:** Como equipo de desarrollo, quiero que todos los tipos de notificación push tengan tests unitarios y tests de integración E2E, para garantizar la correctitud del sistema y prevenir regresiones.

#### Criterios de Aceptación

1. THE Sistema_Push SHALL tener tests unitarios para cada tipo de Evento_Disparador que verifiquen la generación correcta del evento push, la construcción del payload, el cálculo de destinatarios y el filtrado por Preferencias_Notificación
2. THE Sistema_Push SHALL tener tests de integración E2E para cada tipo de Evento_Disparador que verifiquen el flujo completo desde la acción del usuario hasta la entrega push (utilizando un mock de FCM)
3. WHEN se agrega un nuevo tipo de notificación al Sistema_Push, THE Sistema_Push SHALL incluir tests unitarios y tests E2E correspondientes antes de considerar la implementación completa
4. THE tests unitarios SHALL verificar que el payload de cada Notificación_Push contiene los campos requeridos según el tipo de notificación (título, cuerpo, datos de navegación y campos específicos del tipo)
5. THE tests unitarios SHALL verificar que el Sistema_Push calcula correctamente la lista de destinatarios para cada tipo de notificación, incluyendo las exclusiones (remitente, usuario que realizó la acción)
6. THE tests unitarios SHALL verificar que el Sistema_Push respeta las Preferencias_Notificación del usuario destinatario, omitiendo el envío push cuando el tipo de notificación está desactivado
7. THE tests E2E SHALL verificar el flujo completo de cada tipo de notificación: ejecutar la acción disparadora vía API REST, verificar la creación de la notificación en la base de datos y confirmar la invocación del envío push al mock de FCM con el payload correcto
8. THE tests E2E SHALL utilizar un mock del servicio FCM para interceptar y verificar los mensajes push sin realizar envíos reales a dispositivos
9. FOR ALL los tipos de notificación definidos en los Requisitos 2 al 25, THE Sistema_Push SHALL tener al menos un test unitario y un test E2E que cubra el escenario principal de cada tipo

### Requisito 30: Filtrado de Notificaciones por Rol del Usuario

**User Story:** Como usuario de WorshipHub, quiero que el sistema solo me envíe notificaciones relevantes a mi rol en la iglesia, para no recibir alertas que no me corresponden y tener una experiencia más limpia.

#### Criterios de Aceptación

1. WHEN un Evento_Disparador genera una notificación, THE Sistema_Push SHALL verificar el Rol_Usuario del destinatario antes de enviar la Notificación_Push, utilizando el Mapa_Notificaciones_Rol
2. IF el tipo de notificación generada no es aplicable al Rol_Usuario del destinatario según el Mapa_Notificaciones_Rol, THEN THE Sistema_Push SHALL omitir el envío de la Notificación_Push a ese usuario, incluso si el usuario tiene un Token_FCM registrado
3. THE Sistema_Push SHALL definir el siguiente Mapa_Notificaciones_Rol:
   - **Admin**: Todos los tipos de notificación (R2–R10, R16–R25)
   - **Líder_Equipo**: Asignación a servicio (R2), mensajes de chat (R3), comentarios en canciones (R4), cambios en equipo (R5), respuesta a invitación de servicio (R6), nueva canción (R7), recordatorio de servicio (R9), modificación de setlist (R10), cancelación de servicio (R16), servicios recurrentes (R17–R19), actualización de canción (R20), eliminación de canción (R21), attachment en canción (R22), cambio de disponibilidad no disponible (R24), cambio de disponibilidad disponible (R25)
   - **Miembro**: Asignación a servicio (R2), mensajes de chat (R3), comentarios en canciones (R4), nueva canción (R7), recordatorio de servicio (R9), modificación de setlist (R10), cancelación de servicio (R16), servicios recurrentes (R17–R19), actualización de canción (R20), eliminación de canción (R21), attachment en canción (R22)
4. THE Sistema_Push SHALL aplicar el filtrado por Rol_Usuario como una verificación adicional posterior al cálculo de destinatarios existente en cada tipo de notificación
5. WHEN un usuario tiene múltiples roles (por ejemplo, es Líder_Equipo en un equipo y Miembro en otro), THE Sistema_Push SHALL utilizar el rol de mayor jerarquía (Admin > Líder_Equipo > Miembro) para determinar los tipos de notificación aplicables
6. THE tests unitarios del Requisito 29 SHALL incluir casos de prueba que verifiquen que el filtrado por Rol_Usuario excluye correctamente a usuarios cuyo rol no corresponde al tipo de notificación
