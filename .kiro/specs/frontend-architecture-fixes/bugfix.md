# Documento de Requisitos de Corrección de Errores - Frontend Architecture Fixes

## Introducción

El proyecto WorshipHub UI (frontend Flutter) presenta 82 problemas identificados mediante análisis estático (flutter analyze) que afectan la estabilidad, seguridad y mantenibilidad de la aplicación. Estos problemas se clasifican en cuatro niveles de severidad:

- **CRÍTICOS - ERRORES DE COMPILACIÓN (38)**: Errores que bloquean la compilación o funcionalidad básica
- **ALTA SEVERIDAD (15)**: Problemas mayores que afectan la experiencia del usuario y la integridad de datos
- **SEVERIDAD MEDIA (15)**: Problemas moderados que afectan la calidad del código y rendimiento
- **BAJA SEVERIDAD - WARNINGS E INFO (14)**: Problemas menores de configuración y mejores prácticas

Este documento define el comportamiento defectuoso actual, el comportamiento correcto esperado, y el comportamiento que debe preservarse para evitar regresiones.

## Resumen de Errores de Compilación (Flutter Analyze)

**Total de problemas encontrados: 82**
- **38 Errores (error)**: Bloquean la compilación
- **6 Advertencias (warning)**: Imports no usados, campos no usados
- **38 Información (info)**: Mejores prácticas, optimizaciones

### Errores Críticos por Categoría:

1. **Dependency Injection (11 errores)**:
   - CategoryBloc constructor con parámetros incorrectos
   - CategoryRepository recibe DatabaseService en lugar de AuthContextService
   - 9 parámetros nombrados no definidos en CategoryBloc

2. **Type Mismatches (5 errores)**:
   - Song tags: List<String> vs List<Tag>
   - Song card: Tag vs String incompatibilidad

3. **Missing Files/Classes (10 errores)**:
   - CategoryRepository, TagRepository no existen en domain
   - Category, Tag entities no existen en domain
   - URIs no existen para imports

4. **Undefined Methods (12 errores)**:
   - CategoryRepository métodos no definidos (createCategory, getAllCategories, etc.)
   - Event constructors no definidos (LoadCategoriesEvent, CreateCategoryEvent, etc.)

## Análisis del Bug

### Errores de Compilación Detallados (Flutter Analyze)

#### ERRORES CRÍTICOS (38 errores que bloquean compilación):

**1. Dependency Injection - service_locator.dart (11 errores)**
- `argument_type_not_assignable`: DatabaseService no puede asignarse a AuthContextService (línea 129:40)
- `not_enough_positional_arguments`: CategoryBloc.new espera 1 argumento posicional pero se encontraron 0 (línea 230:9)
- `undefined_named_parameter`: getAllCategoriesUseCase no está definido (línea 230:9)
- `undefined_named_parameter`: createCategoryUseCase no está definido (línea 231:9)
- `undefined_named_parameter`: updateCategoryUseCase no está definido (línea 232:9)
- `undefined_named_parameter`: deleteCategoryUseCase no está definido (línea 233:9)
- `undefined_named_parameter`: getAllTagsUseCase no está definido (línea 234:9)
- `undefined_named_parameter`: createTagUseCase no está definido (línea 235:9)
- `undefined_named_parameter`: updateTagUseCase no está definido (línea 236:9)
- `undefined_named_parameter`: deleteTagUseCase no está definido (línea 237:9)
- `undefined_named_parameter`: syncCategoriesAndTagsUseCase no está definido (línea 238:9)

**2. Type Mismatches - song_repository_impl.dart (2 errores)**
- `argument_type_not_assignable`: List<String> no puede asignarse a List<Tag>? (línea 543:13)
- `argument_type_not_assignable`: List<Tag> no puede asignarse a List<String> (línea 562:19)

**3. Missing Domain Files - category_bloc.dart (2 errores)**
- `uri_does_not_exist`: '../../../domain/repositories/category_repository.dart' no existe (línea 2:8)
- `undefined_class`: CategoryRepository no está definida (línea 7:9)

**4. Missing Domain Files - category_event.dart (1 error)**
- `uri_does_not_exist`: '../../../domain/entities/category.dart' no existe (línea 1:8)

**5. Missing Domain Files - category_state.dart (2 errores)**
- `uri_does_not_exist`: '../../../domain/entities/category.dart' no existe (línea 1:8)
- `non_type_as_type_argument`: Category no es un tipo válido (línea 10:14)

**6. Missing Domain Files - tag_bloc.dart (2 errores)**
- `uri_does_not_exist`: '../../../domain/repositories/tag_repository.dart' no existe (línea 2:8)
- `undefined_class`: TagRepository no está definida (línea 7:9)

**7. Missing Domain Files - tag_state.dart (2 errores)**
- `uri_does_not_exist`: '../../../domain/entities/tag.dart' no existe (línea 1:8)
- `non_type_as_type_argument`: Tag no es un tipo válido (línea 10:14)

**8. Undefined Methods - category_usecases.dart (10 errores)**
- `undefined_method`: createCategory no está definido en CategoryRepository (línea 20:29)
- `undefined_method`: getAllCategories no está definido en CategoryRepository (línea 31:29)
- `undefined_method`: updateCategory no está definido en CategoryRepository (línea 42:29)
- `undefined_method`: deleteCategory no está definido en CategoryRepository (línea 53:22)
- `undefined_method`: createTag no está definido en CategoryRepository (línea 72:29)
- `undefined_method`: getAllTags no está definido en CategoryRepository (línea 83:29)
- `undefined_method`: updateTag no está definido en CategoryRepository (línea 94:29)
- `undefined_method`: deleteTag no está definido en CategoryRepository (línea 105:22)
- `undefined_method`: syncCategories no está definido en CategoryRepository (línea 117:18)
- `undefined_method`: syncTags no está definido en CategoryRepository (línea 118:18)

**9. Undefined Methods - category_management_page.dart (6 errores)**
- `undefined_method`: LoadCategoriesEvent no está definido (línea 29:38)
- `undefined_method`: SyncCategoriesAndTagsEvent no está definido (línea 47:48)
- `type_test_with_undefined_name`: CategoryOperationSuccess no está definido (línea 68:31)
- `undefined_method`: LoadCategoriesEvent no está definido (línea 111:48)
- `undefined_method`: LoadTagsEvent no está definido (línea 154:48)
- `undefined_method`: DeleteCategoryEvent no está definido (línea 256:48)
- `undefined_method`: DeleteTagEvent no está definido (línea 280:48)

**10. Undefined Getters - category_management_page.dart (3 errores)**
- `undefined_getter`: tags no está definido en CategoryLoaded (línea 144:21)
- `undefined_getter`: tags no está definido en CategoryLoaded (línea 161:33)
- `undefined_getter`: tags no está definido en CategoryLoaded (línea 167:57)

**11. Undefined Methods - create_category_dialog.dart (2 errores)**
- `undefined_method`: UpdateCategoryEvent no está definido (línea 147:42)
- `undefined_method`: CreateCategoryEvent no está definido (línea 150:42)

**12. Undefined Methods - create_tag_dialog.dart (2 errores)**
- `undefined_method`: UpdateTagEvent no está definido (línea 163:42)
- `undefined_method`: CreateTagEvent no está definido (línea 166:42)

**13. Type Mismatches - song_card.dart (3 errores)**
- `list_element_type_not_assignable`: String no puede asignarse a Tag (línea 7:94)
- `list_element_type_not_assignable`: String no puede asignarse a Tag (línea 13:102)
- `argument_type_not_assignable`: Tag no puede asignarse a String (línea 126:25)

**14. Undefined Getter - filter_bottom_sheet.dart (1 error)**
- `undefined_getter`: tags no está definido en CategoryLoaded (línea 190:50)

#### ADVERTENCIAS (6 warnings):

**1. Unused Fields (2 warnings)**
- `unused_field`: _authContext no se usa en category_repository_impl.dart (línea 8:28)
- `unused_field`: _authContext no se usa en tag_repository_impl.dart (línea 8:28)

**2. Unused Imports (4 warnings)**
- `unused_import`: '../bloc/auth_event.dart' en email_verification_page.dart (línea 6:8)
- `unused_import`: '../bloc/category_event.dart' en category_management_page.dart (línea 6:8)
- `unused_import`: '../bloc/category_event.dart' en create_category_dialog.dart (línea 5:8)
- `unused_import`: '../bloc/category_event.dart' en create_tag_dialog.dart (línea 5:8)

#### INFORMACIÓN (38 info):

**1. Production Code Issues (9 info)**
- `avoid_print`: No usar print() en producción - database_web.dart (línea 13:5)
- `avoid_print`: No usar print() en producción - auth_repository_impl.dart (líneas 129:7, 130:7, 131:7, 134:7, 135:7, 328:7)
- `avoid_print`: No usar print() en producción - auth_bloc.dart (líneas 90:7, 91:7)

**2. Deprecated Members (1 info)**
- `deprecated_member_use`: encryptedSharedPreferences está deprecado - secure_storage_service.dart (línea 7:7)

**3. Async Context Issues (3 info)**
- `use_build_context_synchronously`: No usar BuildContext a través de gaps async - forgot_password_page.dart (línea 40:28)
- `use_build_context_synchronously`: No usar BuildContext a través de gaps async - reset_password_page.dart (línea 64:30)
- `use_build_context_synchronously`: No usar BuildContext a través de gaps async - song_detail_page.dart (líneas 363:22, 364:30)

**4. Code Style Issues (25 info)**
- `curly_braces_in_flow_control_structures`: Usar llaves en if - login_page.dart (líneas 162:33, 164:33, 179:33, 181:33)
- `prefer_initializing_formals`: Usar initializing formals - song_state.dart (líneas 12:9, 13:9)
- `use_super_parameters`: Usar super parameters - song_state.dart (líneas 25:9, 32:9, 43:9, 64:9, 77:9)
- `sized_box_for_whitespace`: Usar SizedBox para whitespace - song_list_page.dart (línea 145:40)

### Comportamiento Actual (Defecto)

#### 1. Errores Críticos de Configuración

1.1 CUANDO se inicializa CategoryBloc en service_locator.dart ENTONCES el sistema falla porque el constructor espera parámetros pero no se proporcionan

1.2 CUANDO se registra CategoryRepository en service_locator.dart ENTONCES el sistema falla porque se pasa DatabaseService en lugar de AuthContextService

1.3 CUANDO se importa category_bloc.dart ENTONCES el sistema falla porque la ruta relativa del import es incorrecta

1.4 CUANDO GoogleSignInUseCase se inyecta en AuthBloc ENTONCES el sistema falla porque GoogleSignInUseCase no está registrado en el service locator

1.5 CUANDO se registran repositorios en service_locator.dart ENTONCES el sistema tiene registros duplicados (SongRepository y SongRepositoryImpl, SetlistRepository y SetlistRepositoryImpl)

1.6 CUANDO la aplicación usa flutter_secure_storage v10+ ENTONCES el sistema genera advertencias de deprecación porque el parámetro encryptedSharedPreferences está obsoleto

#### 2. Errores de Tipo y Mapeo de Datos

1.7 CUANDO Song entity recibe datos de la API ENTONCES el sistema falla porque la entidad espera List<Tag> pero la API retorna List<String> para tags

1.8 CUANDO se mapean datos entre API y entidades ENTONCES el sistema tiene inconsistencias porque existen múltiples funciones de mapeo con lógica diferente

1.9 CUANDO se almacenan tags en la base de datos ENTONCES el sistema tiene inconsistencias de esquema porque los tags se guardan como JSON string pero la entidad espera List<Tag>

1.10 CUANDO se validan respuestas de la API ENTONCES el sistema puede fallar porque no hay validación antes del mapeo de datos

#### 3. Manejo de Errores y Logging

1.11 CUANDO ocurren errores en producción ENTONCES el sistema usa print() en lugar de GlobalErrorHandler, lo que dificulta el debugging

1.12 CUANDO se manejan errores de autenticación ENTONCES el sistema tiene manejo inconsistente con mensajes mezclados en español/inglés

1.13 CUANDO se manejan errores 401/403 ENTONCES el sistema tiene lógica duplicada en HttpClientWrapper y AuthInterceptor

1.14 CUANDO BLoC listeners capturan errores en main.dart ENTONCES el sistema suprime todos los errores silenciosamente

1.15 CUANDO se categorizan errores de API ENTONCES el sistema no distingue entre errores de cliente (4xx) y servidor (5xx), ni implementa lógica de reintentos

#### 4. Gestión de Estado y BLoC

1.16 CUANDO se gestionan estados en BLoCs ENTONCES el sistema tiene patrones anti-patrón con gestión de estado excesivamente defensiva y verificación de tipos excesiva

1.17 CUANDO se usan listeners en BLoCs ENTONCES el sistema no limpia los listeners correctamente, causando posibles memory leaks

1.18 CUANDO SetlistBloc emite estados ENTONCES el estado SetlistBuilding no se mantiene correctamente y no hay validación de estados

1.19 CUANDO se generan setlists ENTONCES el sistema no emite un estado de éxito después de la generación

1.20 CUANDO BLoCs se disponen ENTONCES el sistema no libera recursos correctamente

#### 5. Sincronización y Offline-First

1.21 CUANDO SyncManager intenta sincronizar ENTONCES el sistema no implementa exponential backoff para reintentos

1.22 CUANDO la sincronización falla ENTONCES el sistema falla silenciosamente sin notificar al usuario

1.23 CUANDO hay conflictos de datos ENTONCES el sistema no tiene estrategia de resolución de conflictos

1.24 CUANDO se calcula totalUnsyncedCount ENTONCES el sistema crea un nuevo stream cada segundo, lo cual es ineficiente

1.25 CUANDO se implementa estrategia offline-first ENTONCES el sistema no tiene invalidación de caché ni resolución de conflictos

1.26 CUANDO se marca isSynced flag ENTONCES el sistema puede tener valores inexactos

1.27 CUANDO se actualizan datos locales y de API ENTONCES el sistema tiene condiciones de carrera (race conditions)

#### 6. WebSocket y Comunicación en Tiempo Real

1.28 CUANDO la conexión WebSocket se pierde ENTONCES el sistema no implementa reconexión automática

1.29 CUANDO se parsea STOMP ENTONCES el sistema tiene parsing frágil que puede fallar con formatos inesperados

1.30 CUANDO se mantienen conexiones WebSocket ENTONCES el sistema tiene potencial de memory leaks

1.31 CUANDO se usa heartbeat en WebSocket ENTONCES el sistema no implementa timeout de heartbeat

1.32 CUANDO se envía el token en WebSocket ENTONCES el sistema lo envía en el frame STOMP sin encriptación adicional

#### 7. Transacciones y Base de Datos

1.33 CUANDO se ejecutan transacciones de base de datos ENTONCES el sistema no tiene prevención de deadlocks

1.34 CUANDO se consultan datos ENTONCES el sistema no tiene índices, causando problemas de rendimiento

1.35 CUANDO se cargan datos relacionados ENTONCES el sistema tiene problemas N+1 de consultas

1.36 CUANDO se paginan resultados ENTONCES el sistema no implementa paginación en consultas de base de datos

1.37 CUANDO falla la inicialización de la base de datos ENTONCES el sistema no permite reintentar

1.38 CUANDO se definen relaciones en el esquema ENTONCES el sistema no tiene foreign keys definidas

#### 8. Autenticación y Seguridad

1.39 CUANDO se maneja Google Sign-In ENTONCES el sistema tiene flujos diferentes para web/mobile con callback OAuth2 hardcodeado

1.40 CUANDO se gestiona el token ENTONCES el sistema no implementa refresh token ni verifica expiración del token

1.41 CUANDO se almacena el token ENTONCES el sistema no valida expiración ni tiene mecanismo de refresh

1.42 CUANDO se firman requests de API ENTONCES el sistema no implementa firma de requests y Church-Id podría ser spoofed

1.43 CUANDO se aceptan invitaciones ENTONCES el sistema no valida ni verifica expiración de invitaciones

#### 9. Respuestas de API y Manejo de Datos

1.44 CUANDO se reciben respuestas de API ENTONCES el sistema tiene respuestas mixtas (paginadas/directas) sin consistencia

1.45 CUANDO se transpone una canción ENTONCES el sistema no persiste la versión transpuesta localmente

1.46 CUANDO se sincronizan mensajes de chat ENTONCES el sistema puede fallar en sincronizar el estado de lectura y no maneja conflictos de ordenamiento

#### 10. Routing y Navegación

1.47 CUANDO se redirige en el router ENTONCES el sistema llama redirect en cada cambio de ruta innecesariamente

1.48 CUANDO se validan parámetros de ruta ENTONCES el sistema no valida parámetros para song detail y team chat routes

1.49 CUANDO se manejan deep links ENTONCES el sistema no valida deep links correctamente

#### 11. Localización y UI

1.50 CUANDO se muestran mensajes de error ENTONCES el sistema tiene mensajes hardcodeados en español sin usar intl package

1.51 CUANDO se gestionan estados de carga ENTONCES el sistema no distingue entre carga inicial y refresh

1.52 CUANDO se muestra el indicador de conectividad ENTONCES el sistema no refleja la conectividad real de la API

1.53 CUANDO ErrorApp se muestra ENTONCES el sistema no proporciona opciones de recuperación

#### 12. Rendimiento y Recursos

1.54 CUANDO se cargan imágenes/recursos ENTONCES el sistema no tiene estrategia de caché ni lazy loading

1.55 CUANDO se ejecutan operaciones de stream ENTONCES el sistema tiene operaciones ineficientes (totalUnsyncedCount crea stream cada segundo)

#### 13. Configuración y Dependencias

1.56 CUANDO se configuran URLs de API ENTONCES el sistema tiene URLs hardcodeadas para emulator/localhost

1.57 CUANDO se configura Firebase ENTONCES el sistema probablemente contiene credenciales hardcodeadas

1.58 CUANDO se usan dependencias ENTONCES el sistema tiene parámetros deprecados, paquetes faltantes (intl, logger, freezed)

#### 14. Testing y Logging

1.59 CUANDO se ejecutan tests ENTONCES el sistema no tiene cobertura de tests (unit, integration, widget tests)

1.60 CUANDO se registran logs ENTONCES el sistema tiene niveles de logging inconsistentes y potencialmente registra datos sensibles

### Comportamiento Esperado (Correcto)

#### 2. Configuración de Inyección de Dependencias

2.1 CUANDO se inicializa CategoryBloc en service_locator.dart ENTONCES el sistema DEBERÁ registrar CategoryBloc con el constructor correcto que recibe CategoryRepository como único parámetro

2.2 CUANDO se registra CategoryRepository en service_locator.dart ENTONCES el sistema DEBERÁ pasar AuthContextService (o el servicio correcto) en lugar de DatabaseService

2.3 CUANDO se importa category_bloc.dart ENTONCES el sistema DEBERÁ usar la ruta de import correcta

2.4 CUANDO GoogleSignInUseCase se inyecta en AuthBloc ENTONCES el sistema DEBERÁ tener GoogleSignInUseCase registrado en el service locator

2.5 CUANDO se registran repositorios en service_locator.dart ENTONCES el sistema DEBERÁ eliminar registros duplicados y mantener solo las interfaces de repositorio

2.6 CUANDO la aplicación usa flutter_secure_storage v10+ ENTONCES el sistema DEBERÁ actualizar la configuración para eliminar parámetros deprecados

#### 2. Sistema de Tipos y Mapeo de Datos

2.7 CUANDO Song entity recibe datos de la API ENTONCES el sistema DEBERÁ mapear correctamente List<String> de la API a List<Tag> en la entidad, o viceversa según el contrato de API

2.8 CUANDO se mapean datos entre API y entidades ENTONCES el sistema DEBERÁ tener una única función de mapeo centralizada y consistente por entidad

2.9 CUANDO se almacenan tags en la base de datos ENTONCES el sistema DEBERÁ tener consistencia entre el esquema de base de datos y las entidades de dominio

2.10 CUANDO se validan respuestas de la API ENTONCES el sistema DEBERÁ validar la estructura de datos antes de mapear a entidades

#### 2. Manejo de Errores y Logging Profesional

2.11 CUANDO ocurren errores en producción ENTONCES el sistema DEBERÁ usar GlobalErrorHandler o un logger profesional (logger package) en lugar de print()

2.12 CUANDO se manejan errores de autenticación ENTONCES el sistema DEBERÁ tener manejo consistente con mensajes localizados usando intl package

2.13 CUANDO se manejan errores 401/403 ENTONCES el sistema DEBERÁ tener una única ubicación centralizada para manejo de errores de autenticación (AuthInterceptor)

2.14 CUANDO BLoC listeners capturan errores en main.dart ENTONCES el sistema DEBERÁ registrar errores y mostrar feedback apropiado al usuario

2.15 CUANDO se categorizan errores de API ENTONCES el sistema DEBERÁ distinguir entre errores de cliente (4xx) y servidor (5xx), e implementar lógica de reintentos con exponential backoff para errores recuperables

#### 2. Gestión de Estado Robusta

2.16 CUANDO se gestionan estados en BLoCs ENTONCES el sistema DEBERÁ seguir patrones estándar de BLoC sin verificación de tipos excesiva

2.17 CUANDO se usan listeners en BLoCs ENTONCES el sistema DEBERÁ limpiar listeners en el método dispose() o close()

2.18 CUANDO SetlistBloc emite estados ENTONCES el sistema DEBERÁ mantener el estado SetlistBuilding correctamente y validar transiciones de estado

2.19 CUANDO se generan setlists ENTONCES el sistema DEBERÁ emitir un estado de éxito (SetlistGenerated) después de la generación exitosa

2.20 CUANDO BLoCs se disponen ENTONCES el sistema DEBERÁ liberar todos los recursos (streams, controllers, subscriptions) correctamente

#### 2. Sincronización Robusta con Offline-First

2.21 CUANDO SyncManager intenta sincronizar ENTONCES el sistema DEBERÁ implementar exponential backoff para reintentos (1s, 2s, 4s, 8s, etc.)

2.22 CUANDO la sincronización falla ENTONCES el sistema DEBERÁ notificar al usuario con un mensaje apropiado y registrar el error

2.23 CUANDO hay conflictos de datos ENTONCES el sistema DEBERÁ implementar estrategia de resolución de conflictos (last-write-wins, timestamp-based, o user-prompt)

2.24 CUANDO se calcula totalUnsyncedCount ENTONCES el sistema DEBERÁ usar un stream eficiente que combine los streams de repositorios sin crear nuevos streams repetidamente

2.25 CUANDO se implementa estrategia offline-first ENTONCES el sistema DEBERÁ tener invalidación de caché basada en tiempo o eventos, y resolución de conflictos

2.26 CUANDO se marca isSynced flag ENTONCES el sistema DEBERÁ actualizar el flag solo después de confirmación exitosa del servidor

2.27 CUANDO se actualizan datos locales y de API ENTONCES el sistema DEBERÁ usar transacciones y locks para prevenir race conditions

#### 2. WebSocket Resiliente

2.28 CUANDO la conexión WebSocket se pierde ENTONCES el sistema DEBERÁ implementar reconexión automática con exponential backoff

2.29 CUANDO se parsea STOMP ENTONCES el sistema DEBERÁ usar una librería robusta de STOMP o implementar parsing con manejo de errores completo

2.30 CUANDO se mantienen conexiones WebSocket ENTONCES el sistema DEBERÁ limpiar subscripciones y controllers correctamente para evitar memory leaks

2.31 CUANDO se usa heartbeat en WebSocket ENTONCES el sistema DEBERÁ implementar timeout de heartbeat y reconectar si no hay respuesta

2.32 CUANDO se envía el token en WebSocket ENTONCES el sistema DEBERÁ considerar enviar el token en el header de conexión inicial en lugar del frame STOMP

#### 2. Transacciones y Base de Datos Optimizada

2.33 CUANDO se ejecutan transacciones de base de datos ENTONCES el sistema DEBERÁ implementar timeout y manejo de deadlocks

2.34 CUANDO se consultan datos ENTONCES el sistema DEBERÁ crear índices en columnas frecuentemente consultadas (serverId, isSynced, etc.)

2.35 CUANDO se cargan datos relacionados ENTONCES el sistema DEBERÁ usar eager loading o batch queries para evitar problemas N+1

2.36 CUANDO se paginan resultados ENTONCES el sistema DEBERÁ implementar paginación tanto en API como en consultas de base de datos local

2.37 CUANDO falla la inicialización de la base de datos ENTONCES el sistema DEBERÁ mostrar un diálogo de error con opción de reintentar

2.38 CUANDO se definen relaciones en el esquema ENTONCES el sistema DEBERÁ definir foreign keys para mantener integridad referencial

#### 2. Autenticación y Seguridad Mejorada

2.39 CUANDO se maneja Google Sign-In ENTONCES el sistema DEBERÁ unificar el flujo para web/mobile y usar configuración en lugar de callback hardcodeado

2.40 CUANDO se gestiona el token ENTONCES el sistema DEBERÁ implementar refresh token con renovación automática antes de expiración

2.41 CUANDO se almacena el token ENTONCES el sistema DEBERÁ almacenar y validar la fecha de expiración, e implementar refresh automático

2.42 CUANDO se firman requests de API ENTONCES el sistema DEBERÁ considerar implementar firma de requests (HMAC) y validar Church-Id en el backend

2.43 CUANDO se aceptan invitaciones ENTONCES el sistema DEBERÁ validar el token de invitación y verificar que no haya expirado

#### 2. API y Manejo de Datos Consistente

2.44 CUANDO se reciben respuestas de API ENTONCES el sistema DEBERÁ estandarizar el formato de respuesta (siempre paginado o siempre directo) en coordinación con el backend

2.45 CUANDO se transpone una canción ENTONCES el sistema DEBERÁ persistir la versión transpuesta localmente para uso offline

2.46 CUANDO se sincronizan mensajes de chat ENTONCES el sistema DEBERÁ sincronizar el estado de lectura de manera confiable y resolver conflictos de ordenamiento usando timestamps

#### 2. Routing y Navegación Optimizada

2.47 CUANDO se redirige en el router ENTONCES el sistema DEBERÁ optimizar la lógica de redirect para ejecutarse solo cuando sea necesario

2.48 CUANDO se validan parámetros de ruta ENTONCES el sistema DEBERÁ validar todos los parámetros de ruta y mostrar error si son inválidos

2.49 CUANDO se manejan deep links ENTONCES el sistema DEBERÁ validar y sanitizar deep links antes de navegar

#### 2. Localización y UI Mejorada

2.50 CUANDO se muestran mensajes de error ENTONCES el sistema DEBERÁ usar intl package para localización de mensajes

2.51 CUANDO se gestionan estados de carga ENTONCES el sistema DEBERÁ distinguir entre carga inicial (loading) y refresh (refreshing) con UI apropiada

2.52 CUANDO se muestra el indicador de conectividad ENTONCES el sistema DEBERÁ verificar conectividad real de la API, no solo conectividad de red

2.53 CUANDO ErrorApp se muestra ENTONCES el sistema DEBERÁ proporcionar botón de "Reintentar" y opción de "Reportar Error"

#### 2. Rendimiento y Recursos Optimizados

2.54 CUANDO se cargan imágenes/recursos ENTONCES el sistema DEBERÁ implementar caché de imágenes (cached_network_image) y lazy loading

2.55 CUANDO se ejecutan operaciones de stream ENTONCES el sistema DEBERÁ optimizar streams para evitar creación repetida y usar combinadores eficientes

#### 2. Configuración y Dependencias Actualizadas

2.56 CUANDO se configuran URLs de API ENTONCES el sistema DEBERÁ usar variables de entorno o configuración por ambiente (dev, staging, prod)

2.57 CUANDO se configura Firebase ENTONCES el sistema DEBERÁ usar variables de entorno para credenciales sensibles

2.58 CUANDO se usan dependencias ENTONCES el sistema DEBERÁ actualizar dependencias, agregar paquetes faltantes (intl, logger, freezed) y eliminar parámetros deprecados

#### 2. Testing y Logging Profesional

2.59 CUANDO se ejecutan tests ENTONCES el sistema DEBERÁ tener cobertura de tests unitarios para BLoCs, repositorios y use cases, y tests de integración para flujos críticos

2.60 CUANDO se registran logs ENTONCES el sistema DEBERÁ usar niveles de logging consistentes (debug, info, warning, error) y nunca registrar datos sensibles (tokens, passwords)

### Comportamiento Sin Cambios (Prevención de Regresiones)

#### 3. Funcionalidad de Autenticación

3.1 CUANDO un usuario inicia sesión con email/password ENTONCES el sistema DEBERÁ CONTINUAR autenticando correctamente y almacenando el token

3.2 CUANDO un usuario inicia sesión con Google ENTONCES el sistema DEBERÁ CONTINUAR autenticando correctamente (después de unificar el flujo)

3.3 CUANDO un usuario cierra sesión ENTONCES el sistema DEBERÁ CONTINUAR limpiando todos los datos locales y redirigiendo a login

#### 3. Funcionalidad de Canciones

3.4 CUANDO un usuario crea una canción ENTONCES el sistema DEBERÁ CONTINUAR creando la canción en la API y almacenándola localmente

3.5 CUANDO un usuario edita una canción ENTONCES el sistema DEBERÁ CONTINUAR actualizando la canción en la API y localmente

3.6 CUANDO un usuario busca canciones ENTONCES el sistema DEBERÁ CONTINUAR buscando en local y API, retornando resultados relevantes

3.7 CUANDO un usuario filtra canciones por categoría/tags ENTONCES el sistema DEBERÁ CONTINUAR filtrando correctamente

#### 3. Funcionalidad de Setlists

3.8 CUANDO un usuario crea un setlist ENTONCES el sistema DEBERÁ CONTINUAR creando el setlist correctamente

3.9 CUANDO un usuario agrega canciones a un setlist ENTONCES el sistema DEBERÁ CONTINUAR agregando canciones correctamente

3.10 CUANDO un usuario reordena canciones en un setlist ENTONCES el sistema DEBERÁ CONTINUAR reordenando correctamente

3.11 CUANDO un usuario genera un setlist automáticamente ENTONCES el sistema DEBERÁ CONTINUAR generando setlists basados en criterios

#### 3. Funcionalidad de Equipos y Chat

3.12 CUANDO un usuario crea un equipo ENTONCES el sistema DEBERÁ CONTINUAR creando el equipo correctamente

3.13 CUANDO un usuario envía un mensaje de chat ENTONCES el sistema DEBERÁ CONTINUAR enviando el mensaje vía WebSocket o API

3.14 CUANDO un usuario recibe un mensaje de chat ENTONCES el sistema DEBERÁ CONTINUAR recibiendo mensajes en tiempo real

#### 3. Funcionalidad de Invitaciones

3.15 CUANDO un administrador envía una invitación ENTONCES el sistema DEBERÁ CONTINUAR enviando la invitación correctamente

3.16 CUANDO un usuario acepta una invitación ENTONCES el sistema DEBERÁ CONTINUAR procesando la aceptación correctamente

#### 3. Funcionalidad Offline

3.17 CUANDO un usuario está offline y crea/edita datos ENTONCES el sistema DEBERÁ CONTINUAR almacenando cambios localmente para sincronización posterior

3.18 CUANDO un usuario vuelve online ENTONCES el sistema DEBERÁ CONTINUAR sincronizando cambios pendientes automáticamente

#### 3. Funcionalidad de Categorías y Tags

3.19 CUANDO un usuario crea una categoría ENTONCES el sistema DEBERÁ CONTINUAR creando la categoría correctamente

3.20 CUANDO un usuario crea un tag ENTONCES el sistema DEBERÁ CONTINUAR creando el tag correctamente

3.21 CUANDO se sincronizan categorías y tags ENTONCES el sistema DEBERÁ CONTINUAR sincronizando desde la API

#### 3. Funcionalidad de Perfil

3.22 CUANDO un usuario actualiza su perfil ENTONCES el sistema DEBERÁ CONTINUAR actualizando el perfil correctamente

3.23 CUANDO un usuario cambia su contraseña ENTONCES el sistema DEBERÁ CONTINUAR cambiando la contraseña correctamente

3.24 CUANDO un usuario establece una contraseña (OAuth) ENTONCES el sistema DEBERÁ CONTINUAR estableciendo la contraseña correctamente

#### 3. Navegación y UI

3.25 CUANDO un usuario navega entre pantallas ENTONCES el sistema DEBERÁ CONTINUAR navegando correctamente sin perder estado

3.26 CUANDO se muestra el tema oscuro/claro ENTONCES el sistema DEBERÁ CONTINUAR aplicando el tema correctamente

3.27 CUANDO se muestran errores al usuario ENTONCES el sistema DEBERÁ CONTINUAR mostrando mensajes de error comprensibles (mejorados con localización)
