# Plan de Implementación: Docker Local Native Deploy

## Resumen

Implementar el flujo completo de compilación nativa GraalVM multi-stage en Docker y la orquestación del stack local (PostgreSQL + Mailpit + Backend nativo) mediante docker-compose, con un script de automatización para Windows.

## Tareas

- [x] 1. Actualizar Dockerfile.native a build multi-stage
  - [x] 1.1 Reescribir `worship_hub_api/Dockerfile.native` como build multi-stage
    - Stage 1 (builder): Usar `ghcr.io/graalvm/graalvm-community:21` como imagen base
    - Copiar `gradlew`, `gradle/`, `build.gradle.kts`, `settings.gradle.kts` y los módulos `api/`, `application/`, `domain/`, `infrastructure/`
    - Instalar `findutils` con `microdnf`
    - Dar permisos de ejecución a `gradlew`
    - Ejecutar `./gradlew :api:nativeCompile -x test --no-daemon`
    - Stage 2 (runtime): Usar `ubuntu:22.04` como imagen base ligera
    - Instalar solo `ca-certificates`, limpiar cache de apt
    - Crear usuario no-root `appuser`
    - Copiar ejecutable nativo desde stage builder: `/workspace/api/build/native/nativeCompile/` a `/app/`
    - Renombrar ejecutable a `worshiphub-api`, dar permisos de ejecución
    - Cambiar a usuario `appuser`
    - Exponer puerto 8080
    - ENTRYPOINT `["/app/worshiphub-api"]`
    - _Requisitos: 1.1, 1.2, 1.3, 1.5, 1.6_

- [x] 2. Actualizar docker-compose.yml con servicio backend y red
  - [x] 2.1 Agregar red `worshiphub-net` y servicio `backend` a `worship_hub_api/docker-compose.yml`
    - Definir red `worshiphub-net` de tipo bridge
    - Asignar la red a los servicios existentes `db` y `mailpit`
    - Agregar servicio `backend` con `build.context: .` y `build.dockerfile: Dockerfile.native`
    - Configurar `container_name: WorshipHubBackend`
    - Mapear puerto `9090:8080`
    - Configurar `depends_on` con `db: condition: service_healthy` y `mailpit: condition: service_started`
    - Inyectar variables de entorno: SPRING_PROFILES_ACTIVE=local, DATABASE_URL=jdbc:postgresql://db:5432/worshiphub, DATABASE_USERNAME=postgres, DATABASE_PASSWORD=postgres, JWT_SECRET, FLYWAY_ENABLED=true, FLYWAY_BASELINE_ON_MIGRATE=true, SERVER_PORT=8080, MAIL_HOST=mailpit, MAIL_PORT=1025
    - Configurar healthcheck del backend: `curl -f http://localhost:8080/actuator/health || exit 1` con interval 15s, timeout 5s, retries 10, start_period 30s
    - Mantener volumen existente `./data/db` para PostgreSQL
    - Mantener puertos existentes: 5442 para db, 8025/1025 para mailpit
    - _Requisitos: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 4.1, 4.2, 4.3, 4.4, 5.1, 5.2_

- [x] 3. Checkpoint - Verificar configuración Docker
  - Asegurar que `Dockerfile.native` y `docker-compose.yml` son sintácticamente correctos. Preguntar al usuario si surgen dudas.

- [x] 4. Crear script de automatización deploy-local.bat
  - [x] 4.1 Crear `worship_hub_api/deploy-local.bat` con comandos de gestión
    - Implementar verificación de Docker Desktop (`docker info`)
    - Implementar comando por defecto (sin args): `docker compose build backend` seguido de `docker compose up -d`
    - Implementar subcomando `build`: solo `docker compose build backend`
    - Implementar subcomando `up`: solo `docker compose up -d`
    - Implementar subcomando `down`: `docker compose down`
    - Implementar subcomando `logs`: `docker compose logs -f backend`
    - Implementar subcomando `rebuild`: `docker compose build --no-cache backend` seguido de `docker compose up -d backend`
    - Implementar subcomando `clean`: `docker compose down -v` seguido de eliminar `./data/db` y luego `docker compose up -d`
    - Mostrar URLs de acceso al finalizar: API (localhost:9090), Swagger (localhost:9090/swagger-ui.html), Mailpit (localhost:8025), Health (localhost:9090/actuator/health)
    - Mostrar mensaje de error claro si Docker no está disponible
    - Incluir cabecera con arte ASCII o banner del proyecto
    - _Requisitos: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 5.3_

- [x] 5. Agregar documentación del proceso de despliegue
  - [x] 5.1 Agregar sección de documentación en `worship_hub_api/deploy-local.bat` o crear `worship_hub_api/DOCKER_LOCAL.md`
    - Documentar prerrequisitos: Docker Desktop instalado, mínimo 8GB RAM asignados a Docker
    - Documentar tiempos aproximados de compilación nativa (primera vez: 10-15 min, subsecuentes con caché: 5-8 min)
    - Listar todos los comandos disponibles del script con descripción
    - Documentar puertos utilizados y URLs de acceso
    - Documentar cómo resetear datos con el comando `clean`
    - Documentar troubleshooting común (OOM, puertos ocupados, errores de Flyway)
    - _Requisitos: 6.1, 6.2, 6.3, 1.4_

- [x] 6. Checkpoint final - Validar implementación completa
  - Asegurar que todos los archivos creados/modificados son consistentes entre sí. Verificar que las variables de entorno del docker-compose coinciden con las esperadas por la aplicación. Preguntar al usuario si surgen dudas.

## Notas

- Las tareas marcadas con `*` son opcionales y pueden omitirse para un MVP más rápido
- Cada tarea referencia requisitos específicos para trazabilidad
- Los checkpoints aseguran validación incremental
- Esta funcionalidad es infraestructura de desarrollo local (Docker, scripts, configuración) — no incluye property-based tests
- La compilación nativa dentro de Docker puede tomar 10-15 minutos la primera vez; se recomienda asignar al menos 8GB de RAM a Docker Desktop
- El Dockerfile.native existente se reescribe completamente como multi-stage (el actual espera un binario pre-compilado)
