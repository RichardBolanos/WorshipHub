# Documento de Requisitos

## Introducción

Esta funcionalidad permite desplegar el backend de WorshipHub (Spring Boot con Kotlin) como imagen nativa de GraalVM en Docker local. El objetivo es proporcionar un flujo completo de compilación nativa multi-stage dentro de Docker y orquestación con docker-compose, de modo que el desarrollador pueda levantar todo el stack (PostgreSQL + Mailpit + Backend nativo) con un solo comando en su máquina local (Windows).

## Glosario

- **Sistema_Build**: El proceso de compilación multi-stage de Docker que genera el ejecutable nativo de GraalVM a partir del código fuente del proyecto.
- **Servicio_Backend**: El contenedor Docker que ejecuta la imagen nativa compilada del backend WorshipHub.
- **Docker_Compose**: La herramienta de orquestación que gestiona los servicios locales (PostgreSQL, Mailpit, Backend).
- **Imagen_Nativa**: El ejecutable binario generado por GraalVM Native Image a partir del proyecto Spring Boot.
- **Script_Despliegue**: El script de automatización (.bat para Windows) que ejecuta el proceso completo de build y despliegue local.
- **Healthcheck**: El mecanismo de verificación de salud que determina si un servicio está listo para recibir peticiones.

## Requisitos

### Requisito 1: Compilación Nativa Multi-Stage en Docker

**User Story:** Como desarrollador, quiero compilar el backend como imagen nativa de GraalVM dentro de Docker, para no necesitar tener GraalVM instalado localmente y garantizar builds reproducibles.

#### Criterios de Aceptación

1. WHEN el desarrollador ejecuta el comando de build Docker, THE Sistema_Build SHALL compilar el código fuente del proyecto completo (módulos api, application, domain, infrastructure) usando una imagen base de GraalVM Community 21 en la etapa de compilación.
2. WHEN la compilación nativa finaliza exitosamente, THE Sistema_Build SHALL generar una imagen Docker final basada en una imagen ligera (distroless o ubuntu minimal) que contenga únicamente el ejecutable nativo.
3. WHEN el Sistema_Build ejecuta la etapa de compilación, THE Sistema_Build SHALL utilizar el wrapper de Gradle (gradlew) con la tarea `:api:nativeCompile` excluyendo tests.
4. IF la compilación nativa falla por falta de memoria, THEN THE Sistema_Build SHALL documentar en la configuración que se requieren al menos 8GB de RAM asignados a Docker.
5. THE Sistema_Build SHALL ejecutar el contenedor resultante con un usuario no-root para cumplir con las mejores prácticas de seguridad.
6. WHEN la imagen final es construida, THE Sistema_Build SHALL exponer el puerto 8080 como puerto del servidor de la aplicación.

### Requisito 2: Servicio Backend en Docker Compose

**User Story:** Como desarrollador, quiero que el backend nativo esté definido como servicio en docker-compose.yml, para poder levantar todo el stack local con un solo comando.

#### Criterios de Aceptación

1. THE Docker_Compose SHALL definir un servicio para el Servicio_Backend que dependa del servicio de base de datos (db) y del servicio de correo (mailpit).
2. WHEN el servicio de base de datos reporta estado saludable mediante su healthcheck, THE Docker_Compose SHALL iniciar el Servicio_Backend.
3. THE Servicio_Backend SHALL conectarse a la base de datos PostgreSQL usando el hostname interno del contenedor de base de datos (db) en el puerto 5432.
4. THE Docker_Compose SHALL mapear el puerto 9090 del host al puerto 8080 del Servicio_Backend.
5. THE Docker_Compose SHALL inyectar las variables de entorno necesarias (SPRING_PROFILES_ACTIVE, DATABASE_URL, DATABASE_USERNAME, DATABASE_PASSWORD, JWT_SECRET, FLYWAY_ENABLED, SERVER_PORT) al Servicio_Backend.
6. WHEN el Servicio_Backend inicia, THE Docker_Compose SHALL configurar un healthcheck que verifique el endpoint de salud de la aplicación.
7. THE Docker_Compose SHALL permitir construir la imagen del Servicio_Backend desde el Dockerfile.native local mediante la directiva `build`.

### Requisito 3: Script de Automatización para Windows

**User Story:** Como desarrollador en Windows, quiero un script que automatice el proceso de build y despliegue local, para no tener que recordar múltiples comandos Docker.

#### Criterios de Aceptación

1. THE Script_Despliegue SHALL proporcionar un archivo .bat ejecutable desde la raíz del proyecto worship_hub_api.
2. WHEN el desarrollador ejecuta el Script_Despliegue, THE Script_Despliegue SHALL verificar que Docker Desktop esté en ejecución antes de proceder.
3. WHEN Docker está disponible, THE Script_Despliegue SHALL ejecutar `docker compose build` para construir la imagen nativa del backend.
4. WHEN la imagen se construye exitosamente, THE Script_Despliegue SHALL ejecutar `docker compose up -d` para levantar todos los servicios en modo detached.
5. WHEN los servicios están iniciando, THE Script_Despliegue SHALL mostrar las URLs de acceso relevantes (API, Swagger, Mailpit, Health).
6. IF Docker no está disponible, THEN THE Script_Despliegue SHALL mostrar un mensaje de error indicando que Docker Desktop debe estar en ejecución.
7. THE Script_Despliegue SHALL ofrecer una opción para reconstruir solo la imagen del backend sin afectar los volúmenes de datos de PostgreSQL.

### Requisito 4: Configuración de Red y Conectividad

**User Story:** Como desarrollador, quiero que los contenedores se comuniquen correctamente entre sí, para que el backend pueda acceder a la base de datos y al servidor de correo.

#### Criterios de Aceptación

1. THE Docker_Compose SHALL definir una red interna compartida entre todos los servicios (db, mailpit, backend).
2. WHEN el Servicio_Backend se conecta a la base de datos, THE Servicio_Backend SHALL usar la URL `jdbc:postgresql://db:5432/worshiphub` como cadena de conexión.
3. WHEN el Servicio_Backend envía correos electrónicos, THE Servicio_Backend SHALL conectarse al servicio mailpit en el host `mailpit` y puerto `1025`.
4. THE Docker_Compose SHALL mantener los puertos externos existentes: 5442 para PostgreSQL y 8025/1025 para Mailpit.

### Requisito 5: Persistencia y Gestión de Datos

**User Story:** Como desarrollador, quiero que los datos de la base de datos persistan entre reinicios del stack, para no perder el estado de desarrollo.

#### Criterios de Aceptación

1. THE Docker_Compose SHALL mantener el volumen existente de PostgreSQL (`./data/db`) para persistir los datos entre reinicios.
2. WHEN el Servicio_Backend inicia por primera vez, THE Servicio_Backend SHALL ejecutar las migraciones de Flyway automáticamente contra la base de datos.
3. IF el desarrollador desea reiniciar con datos limpios, THEN THE Script_Despliegue SHALL ofrecer una opción para eliminar los volúmenes de datos y recrear la base de datos.

### Requisito 6: Documentación del Proceso

**User Story:** Como desarrollador, quiero documentación clara sobre el proceso de despliegue local nativo, para poder configurar mi entorno sin asistencia.

#### Criterios de Aceptación

1. THE Script_Despliegue SHALL incluir un archivo README o sección documentada con los prerrequisitos del sistema (Docker Desktop, RAM mínima de 8GB asignada a Docker).
2. THE Script_Despliegue SHALL documentar los tiempos aproximados de compilación nativa (primera vez vs. builds subsecuentes con caché).
3. WHEN el desarrollador consulta la documentación, THE Script_Despliegue SHALL listar los comandos disponibles para operaciones comunes (build, start, stop, logs, rebuild).
