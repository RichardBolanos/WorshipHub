# Documento de Requisitos: Compilación de APK por Entorno

## Introducción

Esta funcionalidad permite compilar APKs de la aplicación Flutter WorshipHub con configuraciones de entorno diferenciadas. Actualmente la app se ejecuta en web o emulador Android apuntando al backend local (localhost:9090). Con el backend ya compilable como imagen nativa GraalVM en Docker (spec `docker-local-native-deploy`), se necesitan dos configuraciones de compilación APK:

1. **APK de desarrollo local**: Apunta al backend nativo corriendo en Docker en la red local del desarrollador (IP local de la máquina host).
2. **APK de producción**: Apunta al backend desplegado en internet (URL pública HTTPS).

Esto permite escalar las pruebas desde el entorno local con Docker nativo hasta pruebas en producción cuando el contenedor Docker se suba a un servidor en internet.

## Glosario

- **Sistema_Build_APK**: El proceso de compilación de Flutter que genera archivos APK para Android con configuración de entorno específica.
- **Configurador_Entorno**: El módulo de configuración de la app Flutter (`app_config.dart`, `environment.dart`) que determina las URLs del backend según el entorno activo.
- **APK_Local**: El archivo APK compilado con la configuración que apunta al backend Docker corriendo en la red local del desarrollador.
- **APK_Produccion**: El archivo APK compilado con la configuración que apunta al backend desplegado en un servidor público en internet.
- **Script_Build**: El script de automatización (.bat para Windows) que ejecuta los comandos de compilación de APK con los parámetros de entorno correctos.
- **URL_Base**: La dirección HTTP/HTTPS del backend a la que la app Flutter envía peticiones API y conexiones WebSocket.
- **Dart_Define**: El mecanismo de Flutter (`--dart-define`) para inyectar variables de configuración en tiempo de compilación.

## Requisitos

### Requisito 1: Lectura dinámica del entorno en tiempo de compilación

**User Story:** Como desarrollador, quiero que la app Flutter lea el entorno configurado mediante `--dart-define` al compilar, para que el APK generado apunte automáticamente al backend correcto.

#### Criterios de Aceptación

1. WHEN el desarrollador compila la app con `--dart-define=ENV=local`, THE Configurador_Entorno SHALL configurar la URL_Base apuntando a la IP de la red local del desarrollador en el puerto 9090 usando protocolo HTTP.
2. WHEN el desarrollador compila la app con `--dart-define=ENV=production`, THE Configurador_Entorno SHALL configurar la URL_Base apuntando a la URL pública del backend en internet usando protocolo HTTPS.
3. WHEN el desarrollador compila la app sin especificar `--dart-define=ENV`, THE Configurador_Entorno SHALL usar el entorno `development` como valor por defecto, manteniendo el comportamiento actual (emulador Android: `10.0.2.2:9090`, web: `localhost:9090`).
4. THE Configurador_Entorno SHALL leer el valor de `ENV` desde `String.fromEnvironment('ENV')` durante la inicialización de la app.
5. WHEN el entorno es `local`, THE Configurador_Entorno SHALL configurar la URL de WebSocket usando protocolo `ws://` con la misma IP y puerto que la URL_Base, en la ruta `/ws/chat`.
6. WHEN el entorno es `production`, THE Configurador_Entorno SHALL configurar la URL de WebSocket usando protocolo `wss://` con el mismo host que la URL_Base, en la ruta `/ws/chat`.

### Requisito 2: Configuración de URL base para entorno local (Docker nativo)

**User Story:** Como desarrollador, quiero que el APK local apunte al backend Docker corriendo en mi máquina, para poder probar la app en un dispositivo físico Android contra el backend nativo local.

#### Criterios de Aceptación

1. WHEN el entorno es `local`, THE Configurador_Entorno SHALL permitir configurar la IP del host mediante `--dart-define=API_HOST` para soportar diferentes redes locales.
2. IF el desarrollador no proporciona `--dart-define=API_HOST` en entorno `local`, THEN THE Configurador_Entorno SHALL usar `10.0.2.2` como IP por defecto (estándar de emulador Android para acceder al host).
3. THE Configurador_Entorno SHALL construir la URL_Base del entorno local con el formato `http://{API_HOST}:9090`.
4. WHEN un dispositivo físico Android se conecta al backend local, THE Configurador_Entorno SHALL usar la IP de la red WiFi local del desarrollador (proporcionada via `API_HOST`) en lugar de `10.0.2.2`.

### Requisito 3: Configuración de URL base para entorno de producción

**User Story:** Como desarrollador, quiero que el APK de producción apunte al backend desplegado en internet, para poder probar la app con el servidor real.

#### Criterios de Aceptación

1. WHEN el entorno es `production`, THE Configurador_Entorno SHALL permitir configurar la URL del backend mediante `--dart-define=API_HOST` para soportar diferentes dominios de despliegue.
2. IF el desarrollador no proporciona `--dart-define=API_HOST` en entorno `production`, THEN THE Configurador_Entorno SHALL usar `api.worshiphub.com` como host por defecto.
3. THE Configurador_Entorno SHALL construir la URL_Base del entorno de producción con el formato `https://{API_HOST}`.
4. WHEN el entorno es `production`, THE Configurador_Entorno SHALL usar exclusivamente conexiones seguras (HTTPS para API, WSS para WebSocket).

### Requisito 4: Script de compilación de APK para Windows

**User Story:** Como desarrollador en Windows, quiero un script que automatice la compilación de APKs para cada entorno, para no tener que recordar los parámetros de `--dart-define` cada vez.

#### Criterios de Aceptación

1. THE Script_Build SHALL proporcionar un archivo `.bat` ejecutable desde la raíz del proyecto `worship_hub_ui`.
2. WHEN el desarrollador ejecuta el Script_Build con el argumento `local`, THE Script_Build SHALL ejecutar `flutter build apk` con `--dart-define=ENV=local` y los parámetros de API_HOST correspondientes.
3. WHEN el desarrollador ejecuta el Script_Build con el argumento `production`, THE Script_Build SHALL ejecutar `flutter build apk` con `--dart-define=ENV=production` y el flag `--release`.
4. WHEN la compilación finaliza exitosamente, THE Script_Build SHALL mostrar la ruta del archivo APK generado.
5. IF Flutter SDK no está disponible en el PATH, THEN THE Script_Build SHALL mostrar un mensaje de error indicando que Flutter debe estar instalado y configurado.
6. THE Script_Build SHALL permitir pasar un parámetro opcional de IP/host para sobrescribir el API_HOST por defecto (ejemplo: `build-apk.bat local 192.168.1.100`).
7. WHEN el desarrollador ejecuta el Script_Build sin argumentos, THE Script_Build SHALL mostrar las opciones disponibles con ejemplos de uso.

### Requisito 5: Actualización del módulo de configuración existente

**User Story:** Como desarrollador, quiero que el módulo de configuración existente (`app_config.dart`) soporte el nuevo entorno `local` sin romper la configuración actual, para mantener compatibilidad con el flujo de desarrollo en emulador.

#### Criterios de Aceptación

1. THE Configurador_Entorno SHALL agregar el valor `local` al enum `Environment` existente, además de los valores actuales (`development`, `staging`, `production`).
2. THE Configurador_Entorno SHALL mantener el comportamiento actual del entorno `development` sin modificaciones (emulador Android usa `10.0.2.2:9090`, web usa `localhost:9090`).
3. WHEN el entorno es `local`, THE Configurador_Entorno SHALL configurar el nivel de log como `debug`, igual que el entorno `development`.
4. WHEN el entorno es `production`, THE Configurador_Entorno SHALL configurar el nivel de log como `warning`.
5. THE Configurador_Entorno SHALL actualizar la clase `ApiConfig` para que use las URLs dinámicas de `AppConfig` en lugar de la URL hardcodeada actual (`http://10.0.2.2:9090`).

### Requisito 6: Documentación de los flujos de compilación

**User Story:** Como desarrollador, quiero documentación clara sobre cómo compilar APKs para cada entorno, para poder configurar y distribuir las builds sin asistencia.

#### Criterios de Aceptación

1. THE Script_Build SHALL incluir documentación (en el propio script o en un archivo README asociado) con los prerrequisitos: Flutter SDK instalado, Android SDK configurado, dispositivo Android o emulador disponible.
2. THE Script_Build SHALL documentar el flujo completo para pruebas locales: levantar backend Docker (`deploy-local.bat`), obtener IP local, compilar APK local con la IP, instalar APK en dispositivo.
3. THE Script_Build SHALL documentar el flujo completo para pruebas en producción: verificar URL del backend desplegado, compilar APK de producción, instalar APK en dispositivo.
4. THE Script_Build SHALL documentar cómo obtener la IP local de la máquina en Windows (comando `ipconfig`).
5. WHEN el desarrollador consulta la documentación, THE Script_Build SHALL listar los comandos disponibles con ejemplos concretos para cada entorno.

### Requisito 7: Compatibilidad con el flujo de desarrollo existente

**User Story:** Como desarrollador, quiero que los cambios no afecten el flujo actual de `flutter run` para desarrollo en emulador o web, para seguir trabajando sin interrupciones.

#### Criterios de Aceptación

1. WHEN el desarrollador ejecuta `flutter run` sin parámetros `--dart-define`, THE Configurador_Entorno SHALL mantener el comportamiento actual: entorno `development` con URLs de emulador Android o web localhost.
2. THE Configurador_Entorno SHALL mantener la compatibilidad con el parámetro existente `--dart-define=ENV=staging` para el entorno de staging.
3. WHEN el desarrollador ejecuta `flutter run --dart-define=ENV=local --dart-define=API_HOST=192.168.1.100`, THE Configurador_Entorno SHALL apuntar al backend en la IP especificada, permitiendo probar desde el emulador contra el Docker local usando la IP de red.
4. THE Configurador_Entorno SHALL funcionar correctamente tanto en modo debug (`flutter run`) como en modo release (`flutter build apk --release`).
