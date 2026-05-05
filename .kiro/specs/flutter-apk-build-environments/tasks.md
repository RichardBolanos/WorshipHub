# Plan de Implementación: Compilación de APK por Entorno

## Resumen

Implementar la configuración dinámica de entornos en la app Flutter WorshipHub para soportar compilación de APKs diferenciados (local Docker y producción). Los cambios se concentran en los archivos de configuración existentes (`environment.dart`, `app_config.dart`, `api_config.dart`), el punto de entrada (`main.dart`), un script de build `.bat`, y documentación. Se usa Dart con la librería `glados` para property-based testing.

## Tareas

- [x] 1. Actualizar el enum Environment y agregar soporte para entorno `local`
  - [x] 1.1 Modificar `worship_hub_ui/lib/core/config/environment.dart` para agregar el valor `local` al enum `Environment` entre `development` y `staging`
    - Agregar el getter estático `isLocal` a `EnvironmentConfig`
    - _Requisitos: 5.1_
  - [x] 1.2 Crear test unitario en `worship_hub_ui/test/core/config/environment_test.dart`
    - Verificar que el enum contiene los 4 valores: `development`, `local`, `staging`, `production`
    - Verificar que `EnvironmentConfig.isLocal` retorna `true` cuando el entorno es `local`
    - Verificar que `setCurrent` y `current` funcionan correctamente para todos los entornos
    - _Requisitos: 5.1_

- [x] 2. Implementar configuración dinámica de URLs en AppConfig
  - [x] 2.1 Modificar `worship_hub_ui/lib/core/config/app_config.dart` para agregar los métodos `resolveEnvironment` y `resolveApiHost`
    - `resolveEnvironment(String envString)` mapea strings a valores del enum: `'local'` → `Environment.local`, `'production'` → `Environment.production`, `'staging'` → `Environment.staging`, cualquier otro → `Environment.development`
    - `resolveApiHost(Environment env, String apiHostOverride)` retorna el host apropiado: si `apiHostOverride` no está vacío lo usa, si no usa defaults (`10.0.2.2` para local, `api.worshiphub.com` para producción)
    - _Requisitos: 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 3.1, 3.2_
  - [x] 2.2 Actualizar los getters `baseUrl`, `webSocketUrl` y `logLevel` en `AppConfig` para soportar el entorno `local`
    - `baseUrl` para `local`: `http://{API_HOST}:9090`
    - `webSocketUrl` para `local`: `ws://{API_HOST}:9090/ws/chat`
    - `baseUrl` para `production`: `https://{API_HOST}` (dinámico con API_HOST)
    - `webSocketUrl` para `production`: `wss://{API_HOST}/ws/chat` (dinámico con API_HOST)
    - `logLevel` para `local`: `debug`
    - Almacenar el host resuelto en una variable estática privada para uso en los getters
    - _Requisitos: 1.1, 1.2, 1.5, 1.6, 2.3, 3.3, 5.3, 5.4_
  - [x] 2.3 Actualizar el método `initialize()` de `AppConfig` para leer `--dart-define` via `String.fromEnvironment`
    - Aceptar parámetros opcionales `envString` y `apiHostString` para inyección en tests
    - Invocar `resolveEnvironment` y `resolveApiHost` internamente
    - Configurar `EnvironmentConfig.setCurrent` con el entorno resuelto
    - _Requisitos: 1.4, 7.1_
  - [x] 2.4 Escribir property test: Construcción de URLs para entorno local
    - **Propiedad 1: Construcción de URLs para entorno local**
    - Crear archivo `worship_hub_ui/test/core/config/app_config_property_test.dart`
    - Generar IPs aleatorias válidas como `API_HOST` → verificar que `baseUrl` es `http://{ip}:9090` y `webSocketUrl` es `ws://{ip}:9090/ws/chat`
    - Usar librería `glados` con mínimo 100 iteraciones
    - Tag: `Feature: flutter-apk-build-environments, Property 1: Construcción de URLs para entorno local`
    - **Valida: Requisitos 1.1, 1.5, 2.1, 2.3**
  - [x] 2.5 Escribir property test: Construcción de URLs para entorno de producción con seguridad
    - **Propiedad 2: Construcción de URLs para entorno de producción con seguridad**
    - En `worship_hub_ui/test/core/config/app_config_property_test.dart`
    - Generar hostnames aleatorios válidos como `API_HOST` → verificar que `baseUrl` es `https://{host}`, `webSocketUrl` es `wss://{host}/ws/chat`, y todas las URLs usan protocolos seguros
    - Usar librería `glados` con mínimo 100 iteraciones
    - Tag: `Feature: flutter-apk-build-environments, Property 2: Construcción de URLs para entorno de producción con seguridad`
    - **Valida: Requisitos 1.2, 1.6, 3.1, 3.3, 3.4**
  - [x] 2.6 Escribir property test: Resolución de entorno desde string
    - **Propiedad 3: Resolución de entorno desde string**
    - En `worship_hub_ui/test/core/config/app_config_property_test.dart`
    - Generar strings de entorno válidos (`local`, `production`, `staging`) → verificar resolución correcta del enum. Para strings no reconocidos (incluyendo vacío) → verificar que retorna `Environment.development`
    - Usar librería `glados` con mínimo 100 iteraciones
    - Tag: `Feature: flutter-apk-build-environments, Property 3: Resolución de entorno desde string`
    - **Valida: Requisitos 1.3, 1.4, 7.1, 7.2**
  - [x] 2.7 Escribir tests unitarios de AppConfig en `worship_hub_ui/test/core/config/app_config_test.dart`
    - Test: sin `ENV` definido, las URLs son las mismas que antes (Android: `10.0.2.2:9090`, Web: `localhost:9090`)
    - Test: `ENV=local` sin `API_HOST` usa `10.0.2.2` como default
    - Test: `ENV=production` sin `API_HOST` usa `api.worshiphub.com` como default
    - Test: `ENV=staging` sigue funcionando con URLs fijas
    - Test: cada entorno retorna el nivel de log correcto (`development`→`debug`, `local`→`debug`, `staging`→`info`, `production`→`warning`)
    - _Requisitos: 1.3, 2.2, 3.2, 5.2, 5.3, 5.4, 7.1, 7.2_

- [x] 3. Checkpoint — Verificar configuración dinámica
  - Asegurar que todos los tests pasan, preguntar al usuario si surgen dudas.

- [x] 4. Actualizar ApiConfig para delegar a AppConfig
  - [x] 4.1 Modificar `worship_hub_ui/lib/core/config/api_config.dart` para eliminar la URL hardcodeada y delegar a `AppConfig.baseUrl`
    - Cambiar `static const String baseUrl = 'http://10.0.2.2:9090'` por `static String get baseUrl => AppConfig.baseUrl`
    - Mantener los timeouts como constantes (`connectTimeout`, `receiveTimeout`)
    - _Requisitos: 5.5_
  - [x] 4.2 Escribir test unitario en `worship_hub_ui/test/core/config/api_config_test.dart`
    - Verificar que `ApiConfig.baseUrl` retorna el mismo valor que `AppConfig.baseUrl`
    - Verificar que los timeouts siguen siendo 30 segundos
    - _Requisitos: 5.5_

- [x] 5. Actualizar main.dart para leer variables de compilación
  - [x] 5.1 Modificar `worship_hub_ui/lib/main.dart` para reemplazar el hardcode de `Environment.development` por lectura dinámica de `String.fromEnvironment`
    - Agregar `const envString = String.fromEnvironment('ENV')` y `const apiHostString = String.fromEnvironment('API_HOST')`
    - Pasar ambos valores a `AppConfig.initialize(envString: envString, apiHostString: apiHostString)`
    - Eliminar el TODO existente sobre `--dart-define`
    - _Requisitos: 1.4, 7.1, 7.4_

- [x] 6. Checkpoint — Verificar integración de componentes
  - Asegurar que todos los tests pasan y que la app compila sin errores con `flutter build apk`. Preguntar al usuario si surgen dudas.

- [x] 7. Crear script de compilación de APK para Windows
  - [x] 7.1 Crear `worship_hub_ui/scripts/build-apk.bat` con soporte para entornos `local` y `production`
    - Sin argumentos: mostrar ayuda con opciones y ejemplos de uso
    - Argumento `local`: ejecutar `flutter build apk --dart-define=ENV=local --dart-define=API_HOST={ip}`
    - Argumento `local {ip}`: usar la IP proporcionada como `API_HOST`
    - Argumento `production`: ejecutar `flutter build apk --release --dart-define=ENV=production --dart-define=API_HOST=api.worshiphub.com`
    - Argumento `production {host}`: usar el host proporcionado como `API_HOST`
    - Validar que Flutter SDK esté disponible en PATH antes de compilar
    - Mostrar la ruta del APK generado al finalizar exitosamente
    - _Requisitos: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7_

- [x] 8. Crear documentación de flujos de compilación
  - [x] 8.1 Crear `worship_hub_ui/APK_BUILD.md` con documentación completa de los flujos de compilación
    - Prerrequisitos: Flutter SDK, Android SDK, dispositivo/emulador
    - Flujo para pruebas locales: levantar backend Docker (`deploy-local.bat`), obtener IP local (`ipconfig`), compilar APK local con la IP, instalar APK en dispositivo
    - Flujo para pruebas en producción: verificar URL del backend, compilar APK de producción, instalar APK
    - Comandos disponibles con ejemplos concretos para cada entorno
    - Cómo obtener la IP local en Windows con `ipconfig`
    - _Requisitos: 6.1, 6.2, 6.3, 6.4, 6.5_

- [x] 9. Checkpoint final — Verificar implementación completa
  - Asegurar que todos los tests pasan, que el script `build-apk.bat` muestra la ayuda correctamente, y que la documentación está completa. Preguntar al usuario si surgen dudas.

## Notas

- Las tareas marcadas con `*` son opcionales y pueden omitirse para un MVP más rápido
- Cada tarea referencia requisitos específicos para trazabilidad
- Los checkpoints aseguran validación incremental
- Los property tests validan propiedades universales de correctitud usando `glados`
- Los tests unitarios validan ejemplos específicos y casos borde
- El lenguaje de implementación es Dart (Flutter), consistente con el diseño
