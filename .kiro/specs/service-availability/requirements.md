# Documento de Requisitos — Disponibilidad de Servicios

## Introducción

Esta funcionalidad permite a los miembros de equipo de WorshipHub gestionar su disponibilidad para cultos (servicios de adoración) programados. Actualmente la página de miembros del equipo solo consulta la disponibilidad existente, pero no permite marcarla ni eliminarla. Además, los cultos se crean de forma individual sin soporte de recurrencia. Esta feature abarca: (1) programación de cultos recurrentes por parte del líder de alabanza, (2) UI para que cada usuario marque su disponibilidad o indisponibilidad por culto, y (3) endpoint DELETE para eliminar registros de indisponibilidad.

## Glosario

- **Sistema**: La plataforma WorshipHub (backend + frontend).
- **Líder_de_Alabanza**: Usuario con rol WORSHIP_LEADER o CHURCH_ADMIN.
- **Miembro_de_Equipo**: Usuario con rol TEAM_MEMBER, WORSHIP_LEADER o CHURCH_ADMIN.
- **Culto**: Entidad ServiceEvent que representa un servicio de adoración programado.
- **Culto_Recurrente**: Culto que se repite según una regla de recurrencia (semanal, mensual o anual).
- **Regla_de_Recurrencia**: Configuración que define la frecuencia (WEEKLY, MONTHLY, YEARLY), el día/fecha de repetición y una fecha de fin opcional.
- **Disponibilidad**: Registro que indica si un Miembro_de_Equipo está disponible o no disponible para un Culto específico.
- **Registro_de_Indisponibilidad**: Entidad UserAvailability que marca una fecha en la que el usuario no está disponible, con razón opcional.
- **Calendario_de_Disponibilidad**: Vista en la UI que muestra los cultos programados y permite al usuario marcar su disponibilidad para cada uno.
- **API_Backend**: Capa REST del backend Spring Boot (ServiceEventController, SchedulingApplicationService).

## Requisitos

### Requisito 1: Programación de Cultos Recurrentes

**Historia de Usuario:** Como Líder_de_Alabanza, quiero programar cultos que se repitan semanalmente, mensualmente o anualmente, para no tener que crear cada culto de forma individual.

#### Criterios de Aceptación

1. WHEN el Líder_de_Alabanza crea un Culto con una Regla_de_Recurrencia, THE API_Backend SHALL persistir el Culto original junto con la Regla_de_Recurrencia asociada (frecuencia, día de repetición, fecha de fin).
2. WHEN el API_Backend persiste un Culto_Recurrente, THE API_Backend SHALL generar automáticamente las instancias individuales de Culto hasta la fecha de fin especificada o hasta un horizonte máximo de 52 semanas si no se especifica fecha de fin.
3. THE Regla_de_Recurrencia SHALL soportar exactamente tres frecuencias: WEEKLY (semanal), MONTHLY (mensual) y YEARLY (anual).
4. WHEN el Líder_de_Alabanza modifica la Regla_de_Recurrencia de un Culto_Recurrente, THE API_Backend SHALL regenerar las instancias futuras de Culto que aún no tengan miembros asignados con estado ACCEPTED.
5. WHEN el Líder_de_Alabanza elimina un Culto_Recurrente, THE API_Backend SHALL eliminar todas las instancias futuras de Culto que estén en estado DRAFT o PUBLISHED sin miembros con estado ACCEPTED.
6. IF la fecha de fin de la Regla_de_Recurrencia es anterior a la fecha del Culto original, THEN THE API_Backend SHALL rechazar la solicitud con un mensaje de error descriptivo.
7. IF la frecuencia de la Regla_de_Recurrencia es MONTHLY y el día de repetición no existe en un mes dado (por ejemplo, día 31 en febrero), THEN THE API_Backend SHALL programar el Culto en el último día de ese mes.

### Requisito 2: Endpoint DELETE para Eliminar Indisponibilidad

**Historia de Usuario:** Como Miembro_de_Equipo, quiero poder eliminar un registro de indisponibilidad previamente marcado, para actualizar mi disponibilidad cuando mis planes cambien.

#### Criterios de Aceptación

1. WHEN el Miembro_de_Equipo envía una solicitud DELETE a `/api/v1/services/availability/{availabilityId}` con su User-Id en el header, THE API_Backend SHALL eliminar el Registro_de_Indisponibilidad correspondiente y retornar HTTP 204 No Content.
2. IF el Registro_de_Indisponibilidad no existe, THEN THE API_Backend SHALL retornar HTTP 404 Not Found con un mensaje descriptivo.
3. IF el User-Id del header no coincide con el userId del Registro_de_Indisponibilidad, THEN THE API_Backend SHALL retornar HTTP 403 Forbidden.
4. THE API_Backend SHALL requerir que el usuario tenga rol TEAM_MEMBER, WORSHIP_LEADER o CHURCH_ADMIN para acceder al endpoint DELETE.

### Requisito 3: Consulta de Disponibilidad del Usuario Actual

**Historia de Usuario:** Como Miembro_de_Equipo, quiero consultar mis propios registros de indisponibilidad, para ver en qué fechas me he marcado como no disponible.

#### Criterios de Aceptación

1. WHEN el Miembro_de_Equipo envía una solicitud GET a `/api/v1/services/availability/me` con su User-Id en el header, THE API_Backend SHALL retornar la lista de Registros_de_Indisponibilidad del usuario ordenados por fecha ascendente.
2. WHERE se proporcionan parámetros opcionales `startDate` y `endDate`, THE API_Backend SHALL filtrar los registros al rango de fechas especificado.
3. THE API_Backend SHALL retornar cada registro con los campos: id, unavailableDate, reason y createdAt.

### Requisito 4: UI del Calendario de Disponibilidad

**Historia de Usuario:** Como Miembro_de_Equipo, quiero ver un calendario con los cultos programados y marcar mi disponibilidad para cada uno, para que el líder sepa con quién puede contar.

#### Criterios de Aceptación

1. THE Calendario_de_Disponibilidad SHALL mostrar los Cultos programados del equipo del usuario en una vista de calendario mensual.
2. WHEN el Miembro_de_Equipo selecciona un Culto en el Calendario_de_Disponibilidad, THE Sistema SHALL mostrar un diálogo que permita marcar "Disponible" o "No disponible" para ese Culto.
3. WHEN el Miembro_de_Equipo marca "No disponible" para un Culto, THE Sistema SHALL enviar una solicitud POST a `/api/v1/services/availability/unavailable` con la fecha del Culto y una razón opcional.
4. WHEN el Miembro_de_Equipo marca "Disponible" para un Culto en el que previamente se marcó como no disponible, THE Sistema SHALL enviar una solicitud DELETE a `/api/v1/services/availability/{availabilityId}` para eliminar el Registro_de_Indisponibilidad.
5. THE Calendario_de_Disponibilidad SHALL indicar visualmente el estado de disponibilidad del usuario para cada Culto usando colores diferenciados (verde para disponible, naranja para no disponible).
6. IF no existen Cultos programados en el rango visible del calendario, THEN THE Calendario_de_Disponibilidad SHALL mostrar un mensaje indicando que no hay cultos programados.
7. THE Calendario_de_Disponibilidad SHALL ser accesible desde la página de miembros del equipo y desde el perfil del usuario.
8. WHILE el Sistema está procesando una solicitud de cambio de disponibilidad, THE Calendario_de_Disponibilidad SHALL mostrar un indicador de carga en el Culto afectado.

### Requisito 5: UI para Programación de Cultos Recurrentes

**Historia de Usuario:** Como Líder_de_Alabanza, quiero una interfaz para crear cultos recurrentes especificando la frecuencia y fecha de fin, para planificar los servicios de adoración de forma eficiente.

#### Criterios de Aceptación

1. WHEN el Líder_de_Alabanza accede al formulario de creación de Culto, THE Sistema SHALL mostrar una opción para habilitar recurrencia con un selector de frecuencia (Semanal, Mensual, Anual) y un campo de fecha de fin opcional.
2. WHEN el Líder_de_Alabanza habilita la recurrencia y envía el formulario, THE Sistema SHALL enviar la solicitud al API_Backend incluyendo la Regla_de_Recurrencia.
3. THE Sistema SHALL mostrar una vista previa de las fechas generadas antes de confirmar la creación del Culto_Recurrente.
4. WHEN el Líder_de_Alabanza visualiza un Culto_Recurrente en el calendario, THE Sistema SHALL indicar visualmente que el Culto pertenece a una serie recurrente mediante un ícono o badge distintivo.
5. IF el Líder_de_Alabanza intenta crear un Culto_Recurrente sin seleccionar un equipo, THEN THE Sistema SHALL mostrar un mensaje de validación indicando que el equipo es obligatorio.

### Requisito 6: Disponibilidad Vinculada a Cultos Existentes

**Historia de Usuario:** Como Miembro_de_Equipo, quiero que la disponibilidad que marco esté vinculada a cultos programados, para que solo pueda indicar disponibilidad cuando existan servicios planificados.

#### Criterios de Aceptación

1. THE Calendario_de_Disponibilidad SHALL permitir marcar disponibilidad únicamente en fechas que tengan al menos un Culto programado para el equipo del usuario.
2. WHEN el Miembro_de_Equipo intenta marcar disponibilidad en una fecha sin Cultos programados, THE Sistema SHALL deshabilitar la interacción y mostrar un tooltip indicando que no hay cultos en esa fecha.
3. WHEN se eliminan todos los Cultos de una fecha, THE API_Backend SHALL eliminar automáticamente los Registros_de_Indisponibilidad asociados a esa fecha para los miembros del equipo correspondiente.
4. THE Calendario_de_Disponibilidad SHALL distinguir visualmente las fechas con Cultos programados de las fechas sin Cultos.

### Requisito 7: Razón Opcional en Indisponibilidad

**Historia de Usuario:** Como Miembro_de_Equipo, quiero poder marcar mi indisponibilidad sin estar obligado a dar una razón, para agilizar el proceso de gestión de mi disponibilidad semanal.

#### Criterios de Aceptación

1. WHEN el Miembro_de_Equipo marca "No disponible" para un Culto, THE Sistema SHALL mostrar un campo de texto opcional para la razón de indisponibilidad.
2. THE API_Backend SHALL aceptar solicitudes POST de indisponibilidad con el campo `reason` vacío o nulo.
3. THE Calendario_de_Disponibilidad SHALL mostrar la razón de indisponibilidad junto a la fecha solo cuando el usuario haya proporcionado una.

### Requisito 8: Modelo de Dominio para Recurrencia de Servicios

**Historia de Usuario:** Como desarrollador, quiero que el modelo de dominio soporte recurrencia en ServiceEvent, para que la lógica de negocio de generación de instancias sea clara y mantenible.

#### Criterios de Aceptación

1. THE API_Backend SHALL extender la entidad ServiceEvent con un campo opcional `recurrenceRule` que contenga: frecuencia (WEEKLY, MONTHLY, YEARLY), día de la semana o día del mes, y fecha de fin opcional.
2. THE API_Backend SHALL agregar un campo `parentServiceId` opcional a ServiceEvent para vincular instancias generadas con el Culto_Recurrente original.
3. THE API_Backend SHALL crear una migración Flyway que agregue las columnas `recurrence_frequency`, `recurrence_end_date` y `parent_service_id` a la tabla `service_events`.
4. FOR ALL Cultos generados a partir de una Regla_de_Recurrencia, crear el Culto y luego consultar por `parentServiceId` SHALL retornar el Culto creado (propiedad de ida y vuelta).
