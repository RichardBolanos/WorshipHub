# Tareas de Implementación — Disponibilidad de Servicios

## Tarea 1: Modelo de Dominio — Recurrencia en ServiceEvent
- [x] 1.1 Crear enum `RecurrenceFrequency` (WEEKLY, MONTHLY, YEARLY) en `domain/scheduling/`
- [x] 1.2 Crear value object `RecurrenceRule` con `@Embeddable` (frequency, recurrenceEndDate) en `domain/scheduling/`
- [x] 1.3 Agregar campos `recurrenceRule` (embedded, nullable) y `parentServiceId` (UUID, nullable) a la entidad `ServiceEvent`
- [x] 1.4 Agregar métodos `findByParentServiceId(parentServiceId: UUID)` y `deleteAll(serviceEvents: List<ServiceEvent>)` a `ServiceEventRepository`
- [x] 1.5 Agregar método `deleteByDateAndTeamMembers(date: LocalDate, teamId: UUID)` a `UserAvailabilityRepository`

## Tarea 2: Migración de Base de Datos
- [x] 2.1 Crear migración Flyway `V12__add_recurrence_fields.sql` con columnas `recurrence_frequency`, `recurrence_end_date`, `parent_service_id` en `service_events`, índice `idx_service_events_parent_id`, e índice `idx_user_availability_user_date`

## Tarea 3: Implementación de Repositorios JPA
- [x] 3.1 Implementar `findByParentServiceId` y `deleteAll` en la implementación JPA de `ServiceEventRepository` en `infrastructure/`
- [x] 3.2 Implementar `deleteByDateAndTeamMembers` en la implementación JPA de `UserAvailabilityRepository` en `infrastructure/`

## Tarea 4: Application Service — Lógica de Recurrencia
- [x] 4.1 Crear comandos `CreateRecurringServiceCommand`, `DeleteAvailabilityCommand`, `GetMyAvailabilityCommand` en `application/scheduling/`
- [x] 4.2 Implementar `createRecurringService()` en `SchedulingApplicationService`: validar regla, generar instancias con `parentServiceId`, manejar día 31 en meses cortos
- [x] 4.3 Implementar `updateRecurrenceRule()` en `SchedulingApplicationService`: regenerar solo instancias futuras sin miembros ACCEPTED
- [x] 4.4 Implementar `deleteRecurringService()` en `SchedulingApplicationService`: eliminar instancias DRAFT/PUBLISHED sin miembros ACCEPTED
- [x] 4.5 Implementar `deleteAvailability()` en `SchedulingApplicationService`: validar propiedad del registro (userId), eliminar y manejar 404/403
- [x] 4.6 Implementar `getMyAvailability()` en `SchedulingApplicationService`: filtrar por userId y rango de fechas opcional, ordenar por fecha ascendente

## Tarea 5: API — AvailabilityController
- [x] 5.1 Crear `AvailabilityController` con endpoint DELETE `/api/v1/services/availability/{availabilityId}` (204, 404, 403)
- [x] 5.2 Agregar endpoint GET `/api/v1/services/availability/me` con parámetros opcionales `startDate` y `endDate`
- [x] 5.3 Mover endpoint POST `/api/v1/services/availability/unavailable` del `ServiceEventController` al nuevo `AvailabilityController` (mantener compatibilidad)

## Tarea 6: API — Endpoints de Recurrencia en ServiceEventController
- [x] 6.1 Extender endpoint POST `/api/v1/services` para aceptar `recurrenceRule` opcional en `ScheduleServiceRequest`
- [x] 6.2 Crear endpoint PUT `/api/v1/services/{serviceId}/recurrence` para modificar regla de recurrencia
- [x] 6.3 Crear endpoint DELETE `/api/v1/services/{serviceId}/recurring` para eliminar culto recurrente y sus instancias

## Tarea 7: Backend — Property-Based Tests
- [x] 7.1 Property test: Round-trip de creación de culto recurrente (Propiedad 1) — crear con RecurrenceRule, consultar por parentServiceId, verificar datos
- [x] 7.2 Property test: Generación correcta de instancias recurrentes (Propiedad 2) — verificar conteo y fechas para WEEKLY/MONTHLY/YEARLY
- [x] 7.3 Property test: Regeneración preserva instancias con miembros ACCEPTED (Propiedad 3)
- [x] 7.4 Property test: Eliminación de indisponibilidad round-trip (Propiedad 4)
- [x] 7.5 Property test: Autorización de eliminación de indisponibilidad (Propiedad 5)
- [x] 7.6 Property test: Ordenamiento y filtrado de disponibilidad GET /me (Propiedad 6)
- [x] 7.7 Property test: Disponibilidad solo en fechas con cultos (Propiedad 7)
- [x] 7.8 Property test: Eliminación en cascada de indisponibilidad (Propiedad 8)
- [x] 7.9 Property test: Razón opcional en indisponibilidad (Propiedad 9)

## Tarea 8: Backend — Unit Tests
- [x] 8.1 Unit tests para `RecurrenceRule`: validación de frecuencias, cálculo de día 31 en meses cortos
- [x] 8.2 Unit tests para `AvailabilityController`: integración MockMvc para DELETE 204/404/403, GET /me con filtros
- [x] 8.3 Unit tests para `SchedulingApplicationService`: creación recurrente, modificación de regla, eliminación con cascada

## Tarea 9: Frontend — Data Layer
- [x] 9.1 Crear `AvailabilityRemoteDataSource` con métodos `getMyAvailability()`, `markUnavailable()`, `deleteAvailability()` usando Dio
- [x] 9.2 Extender tabla Drift `ServiceEvents` con campos `recurrenceFrequency`, `recurrenceEndDate`, `parentServiceId`
- [x] 9.3 Crear `AvailabilityLocalDataSource` con Drift para cache local de registros de indisponibilidad
- [x] 9.4 Crear `AvailabilityRepository` (interfaz en domain + implementación en data) con cache-first y TTL de 5 minutos

## Tarea 10: Frontend — BLoC
- [x] 10.1 Crear `AvailabilityEvent` (LoadMyAvailability, MarkUnavailable, DeleteAvailability, LoadServiceEventsForMonth)
- [x] 10.2 Crear `AvailabilityState` (Initial, Loading, Loaded, OperationSuccess, Error)
- [x] 10.3 Implementar `AvailabilityBloc` con manejo de eventos, llamadas al repositorio y emisión de estados

## Tarea 11: Frontend — UI del Calendario de Disponibilidad
- [x] 11.1 Refactorizar `CalendarPage` para usar `AvailabilityBloc` en lugar de datos mock, mostrando cultos reales del equipo
- [x] 11.2 Crear `AvailabilityDialog` con opciones Disponible/No disponible y campo de razón opcional
- [x] 11.3 Implementar indicadores visuales: verde (disponible), naranja (no disponible), fechas con cultos diferenciadas, indicador de carga
- [x] 11.4 Deshabilitar interacción en fechas sin cultos programados con tooltip informativo

## Tarea 12: Frontend — UI de Recurrencia de Cultos
- [x] 12.1 Crear `RecurrenceFormSection` widget con selector de frecuencia (Semanal/Mensual/Anual) y campo de fecha de fin opcional
- [x] 12.2 Crear `RecurrenceDatePreview` widget que muestre las fechas generadas antes de confirmar
- [x] 12.3 Agregar badge/ícono de recurrencia en cultos que pertenecen a una serie recurrente en el calendario

## Tarea 13: Frontend — Tests
- [x] 13.1 BLoC tests para `AvailabilityBloc` con `bloc_test` y `mocktail`
- [x] 13.2 Unit tests para `AvailabilityRepository` con data sources mockeados
- [x] 13.3 Property tests con glados: generación de instancias recurrentes (Propiedad 2), ordenamiento (Propiedad 6), razón opcional (Propiedad 9)
- [x] 13.4 Widget tests para `AvailabilityDialog` y `RecurrenceFormSection`
