# WorshipHub

Monorepo del proyecto **WorshipHub** — una plataforma completa para la gestión de equipos de alabanza y adoración en iglesias. Incluye backend (Spring Boot + Kotlin) y frontend (Flutter).

## Arquitectura general

```
┌─────────────────────────────────────────────────────────────────┐
│                    Clientes (Flutter)                           │
│    Android · Web · Windows · Linux                              │
│    (offline-first con Drift + SyncManager + FCM Push)           │
└──────────────┬────────────────────────────────┬─────────────────┘
               │ HTTPS/REST (JWT)               │ FCM (push)
               │ Polling (chat)                 │
┌──────────────▼────────────────┐   ┌───────────▼─────────────────┐
│   Backend API                 │   │   Firebase Cloud Messaging  │
│   Spring Boot 3.5 + Kotlin    │   │   (notificaciones push)     │
│   Clean Architecture + DDD    │   └─────────────────────────────┘
│   ~90 endpoints REST          │
└──────────────┬────────────────┘
               │ JDBC
┌──────────────▼────────────────┐
│   PostgreSQL 16 + PostGIS 3.5 │
│   Flyway (19 migraciones)     │
└───────────────────────────────┘
```

## Estructura del repositorio

```
WorshipHub/
├── docs/               # Documentación del monorepo (arquitectura, deployment, runbooks)
│                       # → ver docs/README.md como hub de navegación
├── .kiro/              # Configuración de Kiro (specs, steering, hooks, skills)
├── .github/            # Workflows de CI/CD
├── worship_hub_api/    # Backend - Spring Boot + Kotlin (submodule)
├── worship_hub_ui/     # Frontend - Flutter (submodule)
└── skills-lock.json    # Lock de skills de Kiro
```

## Submódulos

Este repositorio usa **git submodules** para los proyectos:

```bash
# Clonar con submódulos
git clone --recurse-submodules <repo-url>

# Si ya clonaste sin submódulos
git submodule update --init --recursive

# Actualizar submódulos a los últimos commits
git submodule update --remote
```

## Proyectos

| Proyecto | Stack | README |
|----------|-------|--------|
| **worship_hub_api** | Spring Boot 3.5.5 · Kotlin 2.1.0 · Java 21 · PostgreSQL 16 · Flyway · JWT · Firebase Admin SDK · GraalVM native-image | [README](worship_hub_api/README.md) |
| **worship_hub_ui** | Flutter 3.6 · Dart 3.6 · flutter_bloc · Drift (SQLite) · Dio · go_router · Firebase · FCM | [README](worship_hub_ui/README.md) |

## Funcionalidades principales

### Gestión organizacional
- Registro de iglesias con administrador (flujo transaccional)
- Equipos de alabanza con roles (CHURCH_ADMIN, WORSHIP_LEADER, TEAM_MEMBER)
- Sistema de invitaciones por email (de iglesia y de equipo)
- Gestión de perfil y cambio de contraseña

### Catálogo de canciones
- CRUD de canciones con soporte ChordPro (`[C]lyrics [G]more lyrics`)
- Transposición cliente (ChordPro) y servidor (`ChordTransposer`)
- Búsqueda, filtrado por categoría y tags, paginación
- Categorías con **slot types** (opening / worship / offering / closing) para generación inteligente
- Tracking de uso: `lastUsedAt`, `usageCount` para rotación de canciones
- Adjuntos (URLs) y comentarios por canción
- Catálogo global compartido con importación por iglesia

### Planificación de servicios
- Creación de setlists con drag & drop
- **Generación automática** basada en slots litúrgicos y rotación por uso
- Programación de servicios (cultos) con asignación de equipos
- **Servicios recurrentes** (WEEKLY / MONTHLY / YEARLY) con cascada
- Confirmación de asistencia por miembro
- Gestión de disponibilidad con cola offline

### Colaboración en tiempo real
- **Chat de equipo** (polling cada 5s + FCM data messages)
- Notificaciones push completas (FCM) con 21 tipos y deep-linking
- Preferencias de notificación por usuario con filtrado por rol
- 15 toggles configurables
- Quick-actions en la bandeja (aceptar/declinar invitación desde la notificación)

### Seguridad
- JWT con **refresh tokens rotativos** (detección de reuso → revoca todo)
- BCrypt strength 12
- Google Sign-In (OAuth2 con verificación id_token vía JWKS)
- Verificación de email (página HTML bilingüe)
- Recuperación de contraseña (tokens 1h, rate-limit por email e IP)
- Política de contraseñas: ≥8 chars, mayús + minús + dígito + especial
- Rate limiting (100 req/min por IP)
- HSTS, CSP, X-Frame-Options: DENY
- Endpoints bajo `@PreAuthorize` con jerarquía de roles

### Offline-first (cliente Flutter)
- Base de datos local con **Drift (SQLite)**, schema v3 con migraciones incrementales
- **SyncManager centralizado** con ciclos periódicos (5 min), push-then-pull, backoff exponencial `[1,2,4,8,16]s`, 5 reintentos
- Cola offline para escrituras (Songs, Setlists, Services, Chat, Availability)
- Resolución de conflictos (`lastWriteWins` por defecto) basada en timestamps
- `SyncStateStore` persiste `lastSuccessAt` cross-sesión
- Pills de estado: `SyncStatusPill` (por feature) + `AppSyncStatusPill` (agregado en Home) + `ConnectivityPill` (API-only)
- Detección de conectividad con 3 estados: `online`, `offline`, `apiUnreachable` (health-check cada 30s)

## Despliegue local con Docker

El backend se puede ejecutar como **imagen nativa (GraalVM)** junto con PostgreSQL y Mailpit usando Docker Compose. No se necesita tener GraalVM instalado localmente — el build ocurre dentro del container.

### Prerrequisitos

- Docker Desktop instalado y corriendo
- Mínimo **8 GB de RAM** asignados a Docker (Settings → Resources → Memory)

### Inicio rápido

Desde `worship_hub_api/`:

```bash
# Build + start de todo el stack
deploy-local.bat

# Solo levantar servicios (si la imagen ya existe)
deploy-local.bat up

# Detener servicios
deploy-local.bat down

# Ver logs del backend
deploy-local.bat logs

# Reconstruir backend sin perder datos
deploy-local.bat rebuild

# Reset completo (borra BD)
deploy-local.bat clean
```

### URLs de acceso

| Servicio | URL |
|----------|-----|
| API REST | http://localhost:9090 |
| Swagger UI | http://localhost:9090/swagger-ui.html |
| OpenAPI spec | http://localhost:9090/v3/api-docs |
| Mailpit (correos de dev) | http://localhost:8025 |
| Health check | http://localhost:9090/api/v1/health |
| Actuator health | http://localhost:9090/actuator/health |
| PostgreSQL | localhost:5442 |

Para documentación completa, troubleshooting y detalles de arquitectura del stack local, ver [docs/deployment/docker-local.md](docs/deployment/docker-local.md).

## Ejecutar el frontend Flutter

Desde `worship_hub_ui/`:

```bash
# Instalar dependencias
flutter pub get

# Generar código Drift
flutter pub run build_runner build --delete-conflicting-outputs

# Ejecutar en dispositivo/emulador
flutter run --dart-define=ENV=local

# Build APK de desarrollo (auto-detecta IP de WiFi)
scripts\build-apk.bat local-auto

# Build APK de producción
scripts\build-apk.bat production api.worshiphub.com
```

Plataformas soportadas: **Android**, **Web**, **Windows**, **Linux** (no hay iOS/macOS por ahora).

Para detalles sobre ambientes y configuración del frontend, ver [docs/deployment/environments.md](docs/deployment/environments.md) y [docs/frontend/offline-first.md](docs/frontend/offline-first.md) (arquitectura de sincronización).

## Documentación

Toda la documentación profunda del proyecto vive en [`docs/`](docs/). Empieza por el hub:

> **[`docs/README.md`](docs/README.md)** — índice navegable por dominio (arquitectura, backend, frontend, deployment, testing, operations).

### Atajos por tema

| Necesito… | Documento |
|---|---|
| Entender cómo se borran cosas en cascada (FK, eventos FCM, tombstones offline) | [`docs/architecture/cascade-deletion.md`](docs/architecture/cascade-deletion.md) |
| La arquitectura de sincronización offline-first del cliente Flutter | [`docs/frontend/offline-first.md`](docs/frontend/offline-first.md) |
| Visión funcional completa del backend | [`docs/backend/overview.md`](docs/backend/overview.md) |
| Optimizaciones de cold start en Render | [`docs/backend/cold-start-optimization.md`](docs/backend/cold-start-optimization.md) |
| Eventos de dominio y la pipeline de push | [`docs/architecture/domain-events.md`](docs/architecture/domain-events.md) |
| Levantar el stack local con Docker | [`docs/deployment/docker-local.md`](docs/deployment/docker-local.md) |
| Construir un APK | [`docs/deployment/apk-build.md`](docs/deployment/apk-build.md) |
| Configurar ambientes Flutter | [`docs/deployment/environments.md`](docs/deployment/environments.md) |
| Estado de la suite E2E | [`docs/testing/e2e-status.md`](docs/testing/e2e-status.md) |

### READMEs operativos

Los `README.md` de cada subproyecto siguen siendo el punto de entrada para "cómo correr/configurar este módulo":

- [`worship_hub_api/README.md`](worship_hub_api/README.md)
- [`worship_hub_ui/README.md`](worship_hub_ui/README.md)
- [`worship_hub_ui/integration_test/README.md`](worship_hub_ui/integration_test/README.md) — tests Patrol

## Licencia

Este proyecto está bajo la Licencia MIT. Ver `LICENSE` en cada subproyecto.

---

**Desarrollado con dedicación para la comunidad de adoración**
