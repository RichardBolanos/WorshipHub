# WorshipHub

Monorepo del proyecto WorshipHub que contiene el backend (Spring Boot + Kotlin) y el frontend (Flutter).

## Estructura

```
WorshipHub/
├── .kiro/              # Configuración de Kiro (specs, steering, hooks, skills)
├── worship_hub_api/    # Backend - Spring Boot + Kotlin (submodule)
├── worship_hub_ui/     # Frontend - Flutter (submodule)
└── skills-lock.json    # Lock de skills de Kiro
```

## Submódulos

Este repositorio usa git submodules para los proyectos:

```bash
# Clonar con submódulos
git clone --recurse-submodules <repo-url>

# Si ya clonaste sin submódulos
git submodule update --init --recursive
```

## Proyectos

- **worship_hub_api**: API REST con Spring Boot, Kotlin, PostgreSQL. Ver [README](worship_hub_api/README.md).
- **worship_hub_ui**: App Flutter multiplataforma con Clean Architecture. Ver [README](worship_hub_ui/README.md).

## Despliegue Local con Docker (Backend Nativo)

El backend se puede compilar como imagen nativa de GraalVM y ejecutar junto con PostgreSQL y Mailpit usando Docker Compose. No se necesita tener GraalVM instalado localmente.

### Prerrequisitos

- Docker Desktop instalado y corriendo
- Mínimo **8 GB de RAM** asignados a Docker (Settings → Resources → Memory)

### Inicio Rápido

Desde la carpeta `worship_hub_api/`:

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

# Resetear todo (borra BD)
deploy-local.bat clean
```

### URLs de Acceso

| Servicio | URL |
|----------|-----|
| API REST | http://localhost:9090 |
| Swagger UI | http://localhost:9090/swagger-ui.html |
| Mailpit (correos) | http://localhost:8025 |
| Health Check | http://localhost:9090/actuator/health |
| PostgreSQL | localhost:5442 |

Para documentación completa, troubleshooting y detalles de arquitectura, ver [DOCKER_LOCAL.md](worship_hub_api/DOCKER_LOCAL.md).
