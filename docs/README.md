# Documentación de WorshipHub

Centro de documentación del monorepo. Aquí vive todo lo que no es código: arquitectura, decisiones técnicas, runbooks de operación, guías de despliegue y testing.

> **Tip:** los `README.md` de la raíz y de cada subproyecto (`worship_hub_api/README.md`, `worship_hub_ui/README.md`) siguen siendo el punto de entrada **operativo** (cómo correr, configurar, etc.). Esta carpeta es la documentación **profunda**, organizada por dominio para que cada lector encuentre rápido lo que busca según su rol.

---

## Por dónde empezar según tu rol

| Si eres… | Empieza por |
|---|---|
| **Nuevo en el proyecto** | [`backend/overview.md`](./backend/overview.md) → [`architecture/project-structure.md`](./architecture/project-structure.md) → README de la raíz. |
| **Vas a tocar un `delete*`** | [`architecture/cascade-deletion.md`](./architecture/cascade-deletion.md) (lectura obligatoria). |
| **Vas a deployar** | [`deployment/docker-local.md`](./deployment/docker-local.md), [`deployment/environments.md`](./deployment/environments.md), [`deployment/apk-build.md`](./deployment/apk-build.md). |
| **Frontend / offline-first** | [`frontend/offline-first.md`](./frontend/offline-first.md). |
| **Tests E2E** | [`testing/e2e-status.md`](./testing/e2e-status.md). |
| **Backend en Render se cae** | [`backend/cold-start-optimization.md`](./backend/cold-start-optimization.md). |
| **Vas a tocar la generación de setlists** | [`backend/setlist-auto-generation.md`](./backend/setlist-auto-generation.md). |
| **Investigando un incidente histórico** | [`operations/`](./operations/). |

---

## Arquitectura

Decisiones que se aplican **a través de varios módulos** o que un nuevo aggregate debe respetar.

| Documento | Qué contiene |
|---|---|
| [`architecture/cascade-deletion.md`](./architecture/cascade-deletion.md) | Semánticas de borrado en cascada (composición vs M:N vs referencia), patrón uniforme backend + mobile, idempotencia, tombstones, FCM cross-device. **Lectura obligatoria** antes de tocar cualquier `delete*`. |
| [`architecture/domain-events.md`](./architecture/domain-events.md) | Implementación de eventos de dominio: `ApplicationEventPublisher`, `@TransactionalEventListener(AFTER_COMMIT) @Async`, `PushEvent` sealed class y la pipeline FCM. |
| [`architecture/project-structure.md`](./architecture/project-structure.md) | Organización de los 4 módulos Gradle del backend (api / application / domain / infrastructure) y de las capas Flutter (presentation / domain / data / core). |

## Backend

Documentación específica del servicio Spring Boot.

| Documento | Qué contiene |
|---|---|
| [`backend/overview.md`](./backend/overview.md) | Visión funcional completa: bounded contexts, ~90 endpoints, modelos de datos, requisitos de producto. |
| [`backend/setlist-auto-generation.md`](./backend/setlist-auto-generation.md) | **Documento canónico** del motor de generación automática de setlists: secciones libres por usuario, filtros globales con override por sección (categorías, tags, BPM, recencia), plantillas reutilizables por iglesia, rotación por uso, shuffle acotado, flujo end-to-end y guía de extensión. |
| [`backend/cold-start-optimization.md`](./backend/cold-start-optimization.md) | Optimizaciones de arranque para Render free tier (Hikari, Flyway, JPA, Firebase `@Lazy`, telemetría). Contiene tests de regresión que **no deben tumbarse**. |

## Frontend

Documentación específica del cliente Flutter.

| Documento | Qué contiene |
|---|---|
| [`frontend/offline-first.md`](./frontend/offline-first.md) | **Documento canónico** del stack de sincronización: `SyncManager`, `SyncableRepository`, fases (`syncing > error > offline > pending > stale-cache > live`), pills de estado, `SyncStateStore`. ~912 líneas. |
| [`frontend/websocket-cleanup-history.md`](./frontend/websocket-cleanup-history.md) | Histórico de la migración desde WebSocket/STOMP a polling + FCM data messages. Incluido como referencia para entender por qué la app hoy no usa WS. |

## Deployment

Cómo correr el sistema en cada ambiente.

| Documento | Qué contiene |
|---|---|
| [`deployment/docker-local.md`](./deployment/docker-local.md) | Stack local con Docker Compose: backend nativo (GraalVM) + PostgreSQL + Mailpit. Comandos del wrapper `deploy-local.bat`, troubleshooting. |
| [`deployment/environments.md`](./deployment/environments.md) | Configuración del frontend por ambiente (`development`, `local`, `staging`, `production`) vía `--dart-define`. |
| [`deployment/apk-build.md`](./deployment/apk-build.md) | Build de APKs Android (debug, release, auto-detect IP, producción). Wrapper `scripts/build-apk.bat`. |

## Testing

| Documento | Qué contiene |
|---|---|
| [`testing/e2e-status.md`](./testing/e2e-status.md) | Estado de la suite end-to-end: backend (Kotest, MockK, Testcontainers), frontend (`flutter_test`, glados, Patrol). Skips conocidos y por qué. |

## Operations / runbooks

Documentos históricos de incidentes, refactors y decisiones operativas. Son útiles como contexto cuando algo se rompe de forma que parece familiar.

| Documento | Qué contiene |
|---|---|
| [`operations/corrections-log.md`](./operations/corrections-log.md) | Bitácora de correcciones acumuladas en backend antes de que cada fix tuviera su propio doc. |
| [`operations/incident-assigned-members.md`](./operations/incident-assigned-members.md) | Postmortem del bug `assigned_members` (orphan rows en cascada de servicios recurrentes). El fix está incorporado en V19+V20 — ver [`architecture/cascade-deletion.md`](./architecture/cascade-deletion.md). |

---

## Convenciones

### Idioma

La documentación profunda (esta carpeta) está en **español**. El código y los comentarios in-source están en **inglés**. Los nombres de aggregates, métodos y clases se mantienen en inglés incluso dentro de párrafos en español (`deleteTeam`, no "borrarTeam") para que `Ctrl+F` siempre funcione contra el código.

### Cómo agregar un nuevo doc

1. Determina su **dominio** (architecture / backend / frontend / deployment / testing / operations).
2. Crea el archivo con kebab-case: `architecture/my-topic.md`.
3. Añade una entrada en este `README.md`, en la tabla del dominio que corresponda.
4. Si es un patrón que cualquier nuevo aggregate debe respetar (como cascade-deletion), añádelo también en la sección "Por dónde empezar según tu rol".
5. Si reemplaza o invalida un doc anterior, deja un nota al inicio del antiguo apuntando al nuevo. **No borres** el viejo: el contexto histórico sirve.

### Links internos

Usa rutas **relativas** desde el archivo actual:

```markdown
[`cascade-deletion.md`](../architecture/cascade-deletion.md)   ✓
[cascade](/docs/architecture/cascade-deletion.md)              ✗ no portable
```

Cuando un doc en `docs/` referencia código fuente del repo, también con rutas relativas:

```markdown
[`OrganizationApplicationService`](../../worship_hub_api/application/src/main/kotlin/.../OrganizationApplicationService.kt)
```

Esto hace que los enlaces funcionen tanto en GitHub como en cualquier visor markdown local.
