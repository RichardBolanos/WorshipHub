# Despliegue Local con Docker (Compilación Nativa GraalVM)

Guía completa para levantar el stack local de WorshipHub usando Docker Compose con compilación nativa GraalVM multi-stage.

## Prerrequisitos

| Requisito | Detalle |
|-----------|---------|
| Docker Desktop | Instalado y en ejecución ([Descargar](https://www.docker.com/products/docker-desktop)) |
| RAM asignada a Docker | **Mínimo 8 GB** (recomendado 10 GB). Configurar en Docker Desktop → Settings → Resources → Memory |
| Conexión a internet | Necesaria para descargar imágenes base y dependencias en el primer build |
| Sistema operativo | Windows (script `.bat` incluido) |

> **Importante:** La compilación nativa de GraalVM consume mucha memoria. Si Docker tiene menos de 8 GB asignados, el build puede fallar con errores de tipo OOM (Out of Memory).

## Tiempos Aproximados de Compilación

| Escenario | Tiempo estimado |
|-----------|-----------------|
| Primera compilación (sin caché) | 10 – 15 minutos |
| Compilaciones subsecuentes (con caché de Docker) | 5 – 8 minutos |
| Rebuild sin caché (`rebuild`) | 10 – 15 minutos |

Los tiempos varían según los recursos de la máquina. La compilación nativa de GraalVM es intensiva en CPU y memoria.

## Comandos Disponibles

Todos los comandos se ejecutan desde la carpeta `worship_hub_api/`:

```bash
deploy-local.bat [comando]
```

| Comando | Descripción |
|---------|-------------|
| *(ninguno / por defecto)* | Construye la imagen del backend y levanta todos los servicios |
| `build` | Construye solo la imagen Docker del backend (no inicia servicios) |
| `up` | Inicia todos los servicios sin reconstruir la imagen |
| `down` | Detiene todos los servicios |
| `logs` | Muestra los logs del backend en tiempo real (Ctrl+C para salir) |
| `rebuild` | Reconstruye la imagen del backend **sin caché** y reinicia el servicio |
| `clean` | Elimina volúmenes, borra datos de la BD y levanta todo desde cero |

### Ejemplos de Uso

```bash
# Primer despliegue (build + start)
deploy-local.bat

# Solo levantar servicios (si la imagen ya está construida)
deploy-local.bat up

# Ver logs del backend
deploy-local.bat logs

# Detener todo
deploy-local.bat down

# Reconstruir backend sin perder datos de la BD
deploy-local.bat rebuild

# Empezar desde cero (borra toda la BD)
deploy-local.bat clean
```

## Puertos y URLs de Acceso

Una vez que los servicios estén corriendo, se puede acceder a:

| Servicio | URL / Puerto | Descripción |
|----------|-------------|-------------|
| API REST | [http://localhost:9090](http://localhost:9090) | Endpoint principal del backend |
| Swagger UI | [http://localhost:9090/swagger-ui.html](http://localhost:9090/swagger-ui.html) | Documentación interactiva de la API |
| Mailpit UI | [http://localhost:8025](http://localhost:8025) | Interfaz web para ver correos enviados |
| Health Check | [http://localhost:9090/actuator/health](http://localhost:9090/actuator/health) | Estado de salud del backend |
| PostgreSQL | `localhost:5442` | Base de datos (usuario: `postgres`, contraseña: `postgres`) |
| Mailpit SMTP | `localhost:1025` | Servidor SMTP para envío de correos |

## Arquitectura del Stack

```
┌─────────────────────────────────────────────────┐
│              Docker Compose Stack                │
│           (red: worshiphub-net)                  │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │PostgreSQL│  │ Mailpit  │  │   Backend    │   │
│  │  :5432   │  │SMTP:1025 │  │   (nativo)   │   │
│  │          │  │ UI:8025  │  │    :8080     │   │
│  └──────────┘  └──────────┘  └──────────────┘   │
│     :5442         :8025/:1025      :9090         │
└─────────────────────────────────────────────────┘
        ↑               ↑               ↑
        │               │               │
    localhost        localhost        localhost
```

## Cómo Resetear Datos

Si necesitas empezar con una base de datos limpia (por ejemplo, después de cambios en migraciones Flyway o datos corruptos):

```bash
deploy-local.bat clean
```

Este comando realiza los siguientes pasos:

1. Detiene todos los servicios (`docker compose down -v`)
2. Elimina los volúmenes de Docker
3. Borra el directorio `./data/db` con los datos de PostgreSQL
4. Levanta todos los servicios desde cero (`docker compose up -d`)
5. Flyway ejecuta todas las migraciones automáticamente en la nueva BD

> **Advertencia:** El comando `clean` elimina **todos** los datos de la base de datos de forma irreversible.

## Troubleshooting

### OOM durante la compilación nativa

**Síntoma:** El build falla con errores como `java.lang.OutOfMemoryError` o el proceso se termina inesperadamente.

**Solución:**
1. Abrir Docker Desktop → Settings → Resources
2. Aumentar la memoria asignada a **8 GB o más** (recomendado 10 GB)
3. Aplicar cambios y reiniciar Docker Desktop
4. Ejecutar `deploy-local.bat rebuild`

---

### Puertos ya en uso

**Síntoma:** Error al iniciar servicios indicando que el puerto está ocupado (`port is already allocated`).

**Solución:**
1. Verificar qué proceso usa el puerto:
   ```bash
   netstat -ano | findstr :9090
   netstat -ano | findstr :5442
   netstat -ano | findstr :8025
   ```
2. Detener el proceso conflictivo o cambiar el puerto en `docker-compose.yml`
3. Puertos utilizados: `9090` (API), `5442` (PostgreSQL), `8025` (Mailpit UI), `1025` (Mailpit SMTP)

---

### Errores de migración Flyway

**Síntoma:** El backend no inicia y los logs muestran errores de Flyway como `Migration checksum mismatch` o `Found non-empty schema`.

**Solución:**
1. Resetear la base de datos completamente:
   ```bash
   deploy-local.bat clean
   ```
2. Esto elimina todos los datos y permite que Flyway ejecute las migraciones desde cero

---

### Docker no está corriendo

**Síntoma:** El script muestra `[ERROR] Docker is not available`.

**Solución:**
1. Abrir Docker Desktop y esperar a que termine de iniciar (el ícono en la barra de tareas debe estar estable)
2. Verificar que Docker funciona ejecutando:
   ```bash
   docker info
   ```
3. Si Docker Desktop no inicia, reiniciar el equipo e intentar de nuevo

---

### El backend no conecta a la base de datos

**Síntoma:** Logs del backend muestran errores de conexión a PostgreSQL.

**Solución:**
1. Verificar que el servicio de base de datos está saludable:
   ```bash
   docker compose ps
   ```
2. El servicio `db` debe mostrar estado `healthy`
3. Si no está saludable, revisar los logs:
   ```bash
   docker compose logs db
   ```
4. Si persiste, ejecutar `deploy-local.bat clean` para recrear todo

---

### La compilación tarda demasiado

**Síntoma:** El build lleva más de 20 minutos.

**Solución:**
- La compilación nativa de GraalVM es intensiva. En la primera ejecución, 10-15 minutos es normal
- Asignar más CPU y memoria a Docker Desktop puede acelerar el proceso
- Las compilaciones subsecuentes aprovechan la caché de Docker y son más rápidas (5-8 min)
- Evitar usar `rebuild` a menos que sea necesario, ya que ignora la caché
