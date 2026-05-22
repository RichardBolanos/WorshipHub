# Solución: Error "missing table [assigned_members]"

## Problema
Al iniciar la aplicación aparece el error:
```
Schema-validation: missing table [assigned_members]
```

## Causa
La aplicación está configurada con `hibernate.ddl-auto: validate`, lo que significa que Hibernate verifica que todas las tablas existan en la base de datos, pero no las crea. Las tablas deben ser creadas por Flyway, pero estaba deshabilitado en el perfil `local`.

## Solución Aplicada

### 1. Flyway Habilitado
Se habilitó Flyway en `application-local.yml`:
```yaml
flyway:
  enabled: true
  locations: classpath:db/migration
  baseline-on-migrate: true
  baseline-version: 0
```

### 2. Opciones para Iniciar la Aplicación

#### Opción A: Resetear Base de Datos (Recomendado para desarrollo)
```bash
# Windows
reset-and-start.bat

# Linux/Mac
./reset-and-start.sh
```

Este script:
1. Detiene los contenedores Docker
2. Elimina los datos de la base de datos
3. Inicia PostgreSQL y Mailpit
4. Ejecuta la aplicación (Flyway creará las tablas automáticamente)

#### Opción B: Usar Script Existente
```bash
# Windows
cd api\scripts
start-local.bat

# Linux/Mac
cd api/scripts
./start-local.sh
```

**IMPORTANTE**: Si la base de datos ya existe pero no tiene las tablas, primero debes:
1. Detener la aplicación
2. Ejecutar: `docker-compose down -v`
3. Eliminar la carpeta: `data/db`
4. Volver a iniciar

#### Opción C: Ejecutar Flyway Manualmente
Si prefieres ejecutar las migraciones manualmente:
```bash
# Asegúrate de que PostgreSQL esté corriendo
docker-compose up -d db

# Ejecuta las migraciones
./gradlew :api:flywayMigrate -Dflyway.url=jdbc:postgresql://localhost:5442/worshiphub -Dflyway.user=postgres -Dflyway.password=postgres

# Inicia la aplicación
./gradlew :api:bootRun --args='--spring.profiles.active=local'
```

## Verificación

Una vez iniciada la aplicación, deberías ver en los logs:
```
Flyway Community Edition X.X.X by Redgate
Database: jdbc:postgresql://localhost:5442/worshiphub (PostgreSQL X.X)
Successfully validated X migrations
Creating Schema History table "public"."flyway_schema_history" ...
Current version of schema "public": << Empty Schema >>
Migrating schema "public" to version "0 - create database"
Migrating schema "public" to version "1 - create complete schema"
...
Successfully applied X migrations to schema "public"
```

## Estructura de la Base de Datos

Las migraciones de Flyway crean las siguientes tablas principales:
- `churches` - Iglesias
- `users` - Usuarios
- `teams` - Equipos
- `team_members` - Miembros de equipos
- `songs` - Canciones
- `service_events` - Eventos de servicio
- `setlists` - Listas de canciones
- `assigned_members` - Miembros asignados a eventos ✓
- `notifications` - Notificaciones
- `chat_messages` - Mensajes de chat
- Y más...

## Configuración de Hibernate

La aplicación usa `ddl-auto: validate` que es la configuración correcta para producción:
- ✅ **validate**: Verifica que el esquema coincida con las entidades (RECOMENDADO)
- ❌ **create**: Elimina y recrea las tablas (PELIGROSO)
- ❌ **create-drop**: Elimina las tablas al cerrar (SOLO PARA TESTS)
- ❌ **update**: Actualiza el esquema automáticamente (PUEDE CAUSAR PROBLEMAS)

## Troubleshooting

### Error: "Flyway failed to initialize"
- Verifica que PostgreSQL esté corriendo: `docker ps`
- Verifica la conexión: `psql -h localhost -p 5442 -U postgres -d worshiphub`

### Error: "Table already exists"
- La base de datos tiene tablas pero no el historial de Flyway
- Solución: Resetea la base de datos con `reset-and-start.bat`

### Error: "Connection refused"
- PostgreSQL no está corriendo
- Solución: `docker-compose up -d db`

## Comandos Útiles

```bash
# Ver logs de PostgreSQL
docker logs WorshipHubPostgres

# Conectar a PostgreSQL
docker exec -it WorshipHubPostgres psql -U postgres -d worshiphub

# Ver tablas creadas
docker exec -it WorshipHubPostgres psql -U postgres -d worshiphub -c "\dt"

# Ver historial de migraciones
docker exec -it WorshipHubPostgres psql -U postgres -d worshiphub -c "SELECT * FROM flyway_schema_history;"

# Limpiar todo y empezar de cero
docker-compose down -v
rm -rf data/db
docker-compose up -d
```

## Resumen

✅ **Problema resuelto**: Flyway ahora está habilitado y creará todas las tablas automáticamente
✅ **Configuración correcta**: `validate` + Flyway es la mejor práctica
✅ **Scripts listos**: Usa `reset-and-start.bat` para desarrollo
✅ **Documentación**: Este archivo explica todo el proceso
