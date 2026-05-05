# Documento de Requisitos — Módulo de Equipos

## Introducción

El módulo de equipos de WorshipHub permite a las iglesias gestionar sus equipos de alabanza de forma completa: crear, consultar, editar y eliminar equipos, así como administrar los miembros de cada equipo (asignar, remover, cambiar roles). Además, integra funcionalidades de alto valor como la consulta de próximos servicios del equipo, disponibilidad de miembros, resumen de actividad del equipo y notificaciones automáticas ante cambios relevantes. Actualmente existen capas de dominio e infraestructura implementadas tanto en backend como en frontend, pero faltan endpoints REST en el API y páginas de presentación en la UI para completar el flujo funcional.

## Glosario

- **TeamController**: Controlador REST de Spring Boot que expone los endpoints de gestión de equipos en el backend.
- **OrganizationApplicationService**: Servicio de aplicación que orquesta las operaciones de dominio para equipos y miembros.
- **TeamBloc**: Componente BLoC de Flutter que gestiona el estado de equipos en el frontend.
- **Team**: Entidad de dominio que representa un equipo de alabanza con nombre, descripción, iglesia y líder.
- **TeamMember**: Entidad de dominio que representa la membresía de un usuario en un equipo con un rol específico.
- **TeamRole**: Enumeración de roles dentro de un equipo (LEAD_VOCALIST, BACKING_VOCALIST, ACOUSTIC_GUITAR, ELECTRIC_GUITAR, BASS_GUITAR, DRUMS, KEYBOARD, SOUND_ENGINEER, WORSHIP_LEADER).
- **Church-Id**: Header HTTP que identifica la iglesia del usuario autenticado.
- **TeamDetailPage**: Página de Flutter que muestra los detalles de un equipo específico.
- **TeamMembersPage**: Página de Flutter que muestra y gestiona los miembros de un equipo.
- **ServiceEvent**: Entidad de dominio que representa un servicio de alabanza programado, vinculado a un equipo.
- **UserAvailability**: Entidad de dominio que registra las fechas en que un usuario no está disponible.
- **AssignedMember**: Entidad de dominio que representa la asignación de un miembro a un servicio con estado de confirmación (PENDING, ACCEPTED, DECLINED).
- **TeamDashboardPage**: Página de Flutter que muestra un resumen de actividad y estado del equipo.

## Requisitos

### Requisito 1: Listar equipos por iglesia

**Historia de Usuario:** Como administrador de iglesia, quiero ver todos los equipos de mi iglesia, para poder gestionar la organización de los equipos de alabanza.

#### Criterios de Aceptación

1. WHEN un usuario autenticado envía una solicitud GET a /api/v1/teams con el header Church-Id, THE TeamController SHALL retornar la lista de equipos pertenecientes a esa iglesia con código HTTP 200.
2. WHEN no existen equipos para la iglesia indicada, THE TeamController SHALL retornar una lista vacía con código HTTP 200.
3. THE TeamController SHALL restringir el acceso al endpoint de listar equipos a usuarios con autoridad CHURCH_ADMIN, WORSHIP_LEADER o TEAM_MEMBER.

### Requisito 2: Obtener detalle de un equipo

**Historia de Usuario:** Como líder de alabanza, quiero ver los detalles de un equipo específico, para conocer su información y gestionar sus miembros.

#### Criterios de Aceptación

1. WHEN un usuario autenticado envía una solicitud GET a /api/v1/teams/{teamId}, THE TeamController SHALL retornar los datos del equipo con código HTTP 200.
2. IF el equipo solicitado no existe, THEN THE TeamController SHALL retornar un error con código HTTP 404 y un mensaje descriptivo.
3. THE OrganizationApplicationService SHALL exponer un método getTeamById que busque un equipo por su identificador UUID.

### Requisito 3: Actualizar un equipo

**Historia de Usuario:** Como administrador de iglesia, quiero editar el nombre y la descripción de un equipo, para mantener la información actualizada.

#### Criterios de Aceptación

1. WHEN un usuario autenticado envía una solicitud PUT a /api/v1/teams/{teamId} con datos válidos, THE TeamController SHALL actualizar el equipo y retornar los datos actualizados con código HTTP 200.
2. IF el equipo a actualizar no existe, THEN THE TeamController SHALL retornar un error con código HTTP 404.
3. THE TeamController SHALL validar que el nombre del equipo tenga entre 1 y 100 caracteres y la descripción no exceda 500 caracteres.
4. THE TeamController SHALL restringir el acceso al endpoint de actualización a usuarios con autoridad CHURCH_ADMIN o WORSHIP_LEADER.
5. THE OrganizationApplicationService SHALL exponer un método updateTeam que actualice nombre, descripción y líder de un equipo existente.

### Requisito 4: Eliminar un equipo

**Historia de Usuario:** Como administrador de iglesia, quiero eliminar un equipo que ya no está activo, para mantener la organización limpia.

#### Criterios de Aceptación

1. WHEN un usuario autenticado envía una solicitud DELETE a /api/v1/teams/{teamId}, THE TeamController SHALL eliminar el equipo y retornar código HTTP 204.
2. IF el equipo a eliminar no existe, THEN THE TeamController SHALL retornar un error con código HTTP 404.
3. THE TeamController SHALL restringir el acceso al endpoint de eliminación a usuarios con autoridad CHURCH_ADMIN.
4. THE OrganizationApplicationService SHALL eliminar todos los miembros asociados al equipo antes de eliminar el equipo.

### Requisito 5: Asignar miembro a un equipo

**Historia de Usuario:** Como líder de alabanza, quiero agregar miembros a mi equipo con un rol específico, para organizar las responsabilidades del equipo.

#### Criterios de Aceptación

1. WHEN un usuario autenticado envía una solicitud POST a /api/v1/teams/{teamId}/members con userId y teamRole válidos, THE TeamController SHALL asignar el miembro al equipo y retornar el identificador de la membresía con código HTTP 201.
2. IF el equipo indicado no existe, THEN THE TeamController SHALL retornar un error con código HTTP 404.
3. THE TeamController SHALL validar que el teamRole proporcionado sea un valor válido del enum TeamRole.
4. THE TeamController SHALL restringir el acceso al endpoint de asignación a usuarios con autoridad CHURCH_ADMIN o WORSHIP_LEADER.
5. IF el usuario ya es miembro del equipo, THEN THE TeamController SHALL retornar un error con código HTTP 409 indicando que el miembro ya existe.

### Requisito 6: Listar miembros de un equipo

**Historia de Usuario:** Como líder de alabanza, quiero ver todos los miembros de un equipo, para conocer la composición y roles del equipo.

#### Criterios de Aceptación

1. WHEN un usuario autenticado envía una solicitud GET a /api/v1/teams/{teamId}/members, THE TeamController SHALL retornar la lista de miembros del equipo con código HTTP 200.
2. WHEN no existen miembros en el equipo, THE TeamController SHALL retornar una lista vacía con código HTTP 200.
3. THE TeamController SHALL restringir el acceso al endpoint de listar miembros a usuarios con autoridad CHURCH_ADMIN, WORSHIP_LEADER o TEAM_MEMBER.

### Requisito 7: Actualizar rol de un miembro

**Historia de Usuario:** Como líder de alabanza, quiero cambiar el rol de un miembro dentro del equipo, para reasignar responsabilidades según las necesidades.

#### Criterios de Aceptación

1. WHEN un usuario autenticado envía una solicitud PUT a /api/v1/teams/{teamId}/members/{userId}/role con un teamRole válido, THE TeamController SHALL actualizar el rol del miembro y retornar código HTTP 200.
2. IF el miembro no existe en el equipo indicado, THEN THE TeamController SHALL retornar un error con código HTTP 404.
3. THE TeamController SHALL validar que el nuevo teamRole sea un valor válido del enum TeamRole.
4. THE TeamController SHALL restringir el acceso al endpoint de actualización de rol a usuarios con autoridad CHURCH_ADMIN o WORSHIP_LEADER.

### Requisito 8: Remover miembro de un equipo

**Historia de Usuario:** Como líder de alabanza, quiero remover un miembro de mi equipo, para gestionar la composición del equipo.

#### Criterios de Aceptación

1. WHEN un usuario autenticado envía una solicitud DELETE a /api/v1/teams/{teamId}/members/{userId}, THE TeamController SHALL remover al miembro del equipo y retornar código HTTP 204.
2. IF el miembro no existe en el equipo indicado, THEN THE TeamController SHALL retornar un error con código HTTP 404.
3. THE TeamController SHALL restringir el acceso al endpoint de remoción a usuarios con autoridad CHURCH_ADMIN o WORSHIP_LEADER.

### Requisito 9: Consultar próximos servicios del equipo

**Historia de Usuario:** Como miembro de un equipo de alabanza, quiero ver los próximos servicios programados para mi equipo, para prepararme con anticipación y conocer mis asignaciones.

#### Criterios de Aceptación

1. WHEN un usuario autenticado envía una solicitud GET a /api/v1/teams/{teamId}/upcoming-services, THE TeamController SHALL retornar la lista de servicios futuros del equipo ordenados por fecha ascendente con código HTTP 200.
2. EACH servicio retornado SHALL incluir el nombre del servicio, fecha programada, estado del servicio y la cantidad de miembros confirmados versus asignados.
3. IF el equipo no tiene servicios futuros programados, THEN THE TeamController SHALL retornar una lista vacía con código HTTP 200.
4. THE TeamController SHALL restringir el acceso al endpoint a usuarios con autoridad CHURCH_ADMIN, WORSHIP_LEADER o TEAM_MEMBER.

### Requisito 10: Consultar disponibilidad de miembros del equipo

**Historia de Usuario:** Como líder de alabanza, quiero ver la disponibilidad de los miembros de mi equipo para una fecha específica, para planificar los servicios con los miembros disponibles.

#### Criterios de Aceptación

1. WHEN un usuario autenticado envía una solicitud GET a /api/v1/teams/{teamId}/availability con parámetros de fecha inicio y fecha fin, THE TeamController SHALL retornar la lista de miembros del equipo con su estado de disponibilidad para ese rango de fechas con código HTTP 200.
2. EACH miembro en la respuesta SHALL incluir el userId, nombre, rol en el equipo y una lista de fechas en las que no está disponible dentro del rango solicitado.
3. THE TeamController SHALL restringir el acceso al endpoint a usuarios con autoridad CHURCH_ADMIN o WORSHIP_LEADER.
4. THE OrganizationApplicationService SHALL consultar el UserAvailabilityRepository para obtener las fechas de indisponibilidad de cada miembro del equipo.

### Requisito 11: Obtener resumen de actividad del equipo

**Historia de Usuario:** Como líder de alabanza, quiero ver un resumen de la actividad de mi equipo, para evaluar la participación y planificar mejor.

#### Criterios de Aceptación

1. WHEN un usuario autenticado envía una solicitud GET a /api/v1/teams/{teamId}/summary, THE TeamController SHALL retornar un resumen del equipo con código HTTP 200.
2. THE resumen SHALL incluir: cantidad total de miembros, cantidad de servicios realizados en los últimos 30 días, cantidad de próximos servicios programados y la distribución de roles del equipo.
3. THE TeamController SHALL restringir el acceso al endpoint a usuarios con autoridad CHURCH_ADMIN, WORSHIP_LEADER o TEAM_MEMBER.
4. THE OrganizationApplicationService SHALL consultar el ServiceEventRepository para calcular las estadísticas de servicios del equipo.

### Requisito 12: Notificaciones automáticas por cambios en el equipo

**Historia de Usuario:** Como miembro de un equipo de alabanza, quiero recibir notificaciones cuando haya cambios en mi equipo, para estar informado sobre nuevos miembros, cambios de roles o servicios próximos.

#### Criterios de Aceptación

1. WHEN un nuevo miembro es asignado a un equipo, THE OrganizationApplicationService SHALL crear una notificación para todos los miembros existentes del equipo informando la incorporación.
2. WHEN un miembro es removido de un equipo, THE OrganizationApplicationService SHALL crear una notificación para los miembros restantes del equipo informando la salida.
3. WHEN el rol de un miembro es actualizado, THE OrganizationApplicationService SHALL crear una notificación para el miembro afectado informando el cambio de rol.
4. WHEN el líder del equipo es cambiado, THE OrganizationApplicationService SHALL crear una notificación para todos los miembros del equipo informando el nuevo líder.

### Requisito 13: Página de detalle de equipo en el frontend

**Historia de Usuario:** Como usuario de la aplicación móvil, quiero ver los detalles de un equipo al seleccionarlo de la lista, para conocer su información completa incluyendo próximos servicios y actividad.

#### Criterios de Aceptación

1. WHEN el usuario navega a la ruta /teams/{teamId}, THE TeamDetailPage SHALL mostrar el nombre, descripción, líder y fecha de creación del equipo.
2. WHEN el equipo tiene miembros asignados, THE TeamDetailPage SHALL mostrar la cantidad de miembros del equipo agrupados por rol.
3. THE TeamDetailPage SHALL mostrar una sección con los próximos servicios programados del equipo, incluyendo nombre, fecha y estado de confirmaciones.
4. THE TeamDetailPage SHALL proveer un botón para navegar a la página de gestión de miembros del equipo.
5. THE TeamDetailPage SHALL proveer un botón para acceder al chat del equipo.
6. IF ocurre un error al cargar los datos del equipo, THEN THE TeamDetailPage SHALL mostrar un mensaje de error descriptivo al usuario.
7. WHERE el usuario tiene autoridad CHURCH_ADMIN o WORSHIP_LEADER, THE TeamDetailPage SHALL mostrar opciones para editar y eliminar el equipo.

### Requisito 14: Página de gestión de miembros en el frontend

**Historia de Usuario:** Como líder de alabanza, quiero gestionar los miembros de mi equipo desde la aplicación móvil, para agregar, remover y cambiar roles de los miembros.

#### Criterios de Aceptación

1. WHEN el usuario navega a la ruta /teams/{teamId}/members, THE TeamMembersPage SHALL mostrar la lista de miembros del equipo con su nombre, rol e ícono representativo del rol.
2. WHEN no existen miembros en el equipo, THE TeamMembersPage SHALL mostrar un estado vacío con un mensaje indicativo y un botón para agregar el primer miembro.
3. THE TeamMembersPage SHALL proveer una acción para agregar un nuevo miembro al equipo mediante un selector de usuarios de la iglesia y un selector de rol.
4. THE TeamMembersPage SHALL proveer una acción para remover un miembro existente del equipo con un diálogo de confirmación.
5. THE TeamMembersPage SHALL proveer una acción para cambiar el rol de un miembro del equipo mediante un selector de roles.
6. WHEN se agrega o remueve un miembro exitosamente, THE TeamMembersPage SHALL actualizar la lista de miembros automáticamente y mostrar un mensaje de éxito.

### Requisito 15: Panel de resumen del equipo en el frontend

**Historia de Usuario:** Como líder de alabanza, quiero ver un panel con el resumen de actividad de mi equipo desde la aplicación móvil, para tener una visión rápida del estado del equipo.

#### Criterios de Aceptación

1. THE TeamDetailPage SHALL incluir un panel de resumen que muestre la cantidad total de miembros, servicios recientes y próximos servicios.
2. THE panel de resumen SHALL mostrar la distribución de roles del equipo de forma visual mediante chips o badges con el nombre de cada rol y la cantidad de miembros en ese rol.
3. WHEN el equipo tiene próximos servicios, THE panel SHALL mostrar los próximos 3 servicios con fecha, nombre y estado de confirmaciones.
4. IF no hay datos de actividad disponibles, THEN THE panel SHALL mostrar un estado vacío con un mensaje indicativo.

### Requisito 16: Vista de disponibilidad de miembros en el frontend

**Historia de Usuario:** Como líder de alabanza, quiero consultar la disponibilidad de los miembros de mi equipo desde la aplicación móvil, para planificar los servicios con los miembros disponibles.

#### Criterios de Aceptación

1. THE TeamMembersPage SHALL incluir una acción para consultar la disponibilidad de los miembros del equipo para un rango de fechas seleccionable.
2. WHEN el usuario selecciona un rango de fechas, THE TeamMembersPage SHALL mostrar cada miembro con un indicador visual de disponibilidad (disponible/no disponible) para las fechas seleccionadas.
3. EACH miembro no disponible SHALL mostrar las fechas específicas de indisponibilidad y el motivo si fue proporcionado.
4. IF ocurre un error al consultar la disponibilidad, THEN THE TeamMembersPage SHALL mostrar un mensaje de error descriptivo.

### Requisito 17: Sincronización frontend-backend para equipos

**Historia de Usuario:** Como usuario de la aplicación móvil, quiero que las operaciones de equipos se sincronicen con el servidor, para que los datos estén actualizados en todos los dispositivos.

#### Criterios de Aceptación

1. WHEN el usuario crea un equipo en el frontend, THE TeamRepositoryImpl SHALL enviar la solicitud POST al endpoint /api/v1/teams y almacenar la respuesta en la base de datos local.
2. WHEN el usuario consulta la lista de equipos, THE TeamRepositoryImpl SHALL obtener los datos del endpoint GET /api/v1/teams y actualizar la base de datos local.
3. WHEN el usuario agrega un miembro a un equipo, THE TeamRepositoryImpl SHALL enviar la solicitud POST al endpoint /api/v1/teams/{teamId}/members.
4. WHEN el usuario consulta los próximos servicios del equipo, THE TeamRepositoryImpl SHALL obtener los datos del endpoint GET /api/v1/teams/{teamId}/upcoming-services.
5. WHEN el usuario consulta la disponibilidad de miembros, THE TeamRepositoryImpl SHALL obtener los datos del endpoint GET /api/v1/teams/{teamId}/availability.
6. WHEN el usuario consulta el resumen del equipo, THE TeamRepositoryImpl SHALL obtener los datos del endpoint GET /api/v1/teams/{teamId}/summary.
7. IF la solicitud al servidor falla, THEN THE TeamRepositoryImpl SHALL retornar un error descriptivo al usuario.

## Propiedades de Correctitud

### CP-1: Integridad de membresía
Un usuario no puede ser miembro del mismo equipo más de una vez. Si se intenta asignar un usuario que ya es miembro, el sistema debe rechazar la operación con error 409.

### CP-2: Eliminación en cascada
Cuando un equipo es eliminado, todos los registros de TeamMember asociados a ese equipo deben ser eliminados antes de eliminar el equipo. No deben quedar registros huérfanos de TeamMember.

### CP-3: Validación de roles
Todo teamRole asignado o actualizado debe ser un valor válido del enum TeamRole. El sistema no debe aceptar roles arbitrarios fuera de la enumeración definida.

### CP-4: Consistencia de autorización
Los endpoints de modificación (crear, actualizar, eliminar equipos; asignar, remover, cambiar roles de miembros) solo deben ser accesibles por usuarios con autoridad CHURCH_ADMIN o WORSHIP_LEADER. Los endpoints de solo lectura deben ser accesibles también por TEAM_MEMBER.

### CP-5: Consistencia de datos del resumen
La cantidad de miembros reportada en el resumen del equipo debe coincidir con la cantidad real de registros TeamMember asociados al equipo. La cantidad de servicios debe coincidir con los registros ServiceEvent vinculados al teamId.
