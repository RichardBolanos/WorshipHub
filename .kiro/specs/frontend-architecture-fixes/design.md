# Diseño de Corrección de Arquitectura Frontend - WorshipHub UI

## Resumen Ejecutivo

Este documento define la estrategia técnica para resolver 82 problemas identificados en el frontend Flutter de WorshipHub, organizados en 4 fases de implementación con enfoque en Clean Architecture, SOLID principles y Flutter best practices.

**Alcance**: 38 errores de compilación críticos, 27 problemas arquitectónicos, 6 warnings y 11 problemas de calidad de código.

**Estrategia**: Corrección por dependencias (bottom-up), comenzando con la capa de dominio, seguido por infraestructura, y finalmente presentación.

## Glosario

- **Bug_Condition (C)**: Condición que identifica los 82 problemas que bloquean o degradan la aplicación
- **Property (P)**: Comportamiento correcto esperado después de aplicar las correcciones
- **Preservation**: Funcionalidad existente que debe mantenerse sin cambios (autenticación, CRUD de canciones, setlists, chat, etc.)
- **Clean Architecture**: Arquitectura en capas (Domain → Data → Presentation) con inversión de dependencias
- **Offline-First**: Estrategia donde los datos locales son la fuente de verdad, sincronizados con el backend
- **Type System Consistency**: Coherencia entre tipos de dominio (List<Tag>) y persistencia (List<String>)
- **Dependency Injection**: Patrón de inyección de dependencias usando GetIt para desacoplamiento
- **BLoC Pattern**: Business Logic Component - patrón de gestión de estado reactivo en Flutter

## Detalles del Bug

### Condición del Bug

Los problemas se manifiestan en 4 categorías principales que impiden la compilación y degradan la arquitectura:


**Especificación Formal:**
```
FUNCTION isBugCondition(codebase)
  INPUT: codebase of type FlutterProject
  OUTPUT: boolean
  
  RETURN (hasCompilationErrors(codebase) AND errorCount >= 38)
         OR (hasTypeMismatches(codebase, "Song.tags", List<String>, List<Tag>))
         OR (hasMissingDependencies(codebase, "CategoryBloc", "GoogleSignInUseCase"))
         OR (hasArchitecturalIssues(codebase, ["sync", "websocket", "error_handling"]))
         OR (hasCodeQualityIssues(codebase, ["print_statements", "deprecated_apis"]))
END FUNCTION
```

### Categorías de Problemas

#### Categoría 1: Errores de Compilación Críticos (38 errores)

**1.1 Dependency Injection Misconfiguration (11 errores)**
- CategoryBloc constructor espera 1 parámetro posicional (CategoryRepository) pero recibe 9 parámetros nombrados
- CategoryRepository recibe DatabaseService en lugar del servicio correcto
- 9 use cases no están definidos como parámetros nombrados en CategoryBloc

**Ejemplo concreto:**
```dart
// ACTUAL (INCORRECTO):
sl.registerFactory(() => CategoryBloc(
  getAllCategoriesUseCase: sl(),  // ❌ Parámetro nombrado no definido
  createCategoryUseCase: sl(),    // ❌ Parámetro nombrado no definido
  // ... 7 más
));

// ESPERADO (CORRECTO):
sl.registerFactory(() => CategoryBloc(sl<CategoryRepository>()));
```


**1.2 Type System Inconsistencies (5 errores)**
- Song.tags definido como `List<Tag>` en dominio pero almacenado como `List<String>` en base de datos
- Conversión incorrecta entre tipos en song_repository_impl.dart y song_card.dart

**Ejemplo concreto:**
```dart
// PROBLEMA EN DATABASE:
TextColumn get tags => text().map(const StringListConverter())();  // List<String>

// PROBLEMA EN DOMAIN:
class Song {
  final List<Tag> tags;  // List<Tag> - INCOMPATIBLE
}

// ERROR EN MAPEO:
tags: data.tags,  // ❌ List<String> no puede asignarse a List<Tag>
```

**1.3 Missing Domain Files (10 errores)**
- Imports de archivos que no existen (aunque las entidades SÍ existen en domain/entities/)
- Problema de rutas relativas incorrectas en imports

**1.4 Undefined Methods (12 errores)**
- Métodos de CategoryRepository no definidos en la interfaz
- Event constructors no definidos en category_event.dart y tag_event.dart


#### Categoría 2: Problemas Arquitectónicos (27 problemas)

**2.1 State Management Issues (5 problemas)**
- BLoC listeners no se limpian correctamente (memory leaks)
- SetlistBloc no mantiene estado SetlistBuilding correctamente
- Gestión de estado excesivamente defensiva con verificación de tipos innecesaria
- No se emite estado de éxito después de generar setlist
- BLoCs no liberan recursos en dispose()

**2.2 Sync & Offline-First Issues (7 problemas)**
- No hay exponential backoff para reintentos de sincronización
- Sincronización falla silenciosamente sin notificar al usuario
- No hay estrategia de resolución de conflictos
- totalUnsyncedCount crea nuevo stream cada segundo (ineficiente)
- No hay invalidación de caché
- isSynced flag puede tener valores inexactos
- Race conditions en actualizaciones locales/API

**2.3 WebSocket Issues (5 problemas)**
- No hay reconexión automática cuando se pierde conexión
- Parsing STOMP frágil
- Memory leaks en conexiones WebSocket
- No hay timeout de heartbeat
- Token enviado en frame STOMP sin encriptación adicional

**2.4 Error Handling Issues (5 problemas)**
- print() usado en producción en lugar de logger profesional
- Manejo de errores inconsistente (español/inglés mezclado)
- Lógica duplicada de manejo 401/403 en HttpClientWrapper y AuthInterceptor
- BLoC listeners suprimen errores silenciosamente
- No se distingue entre errores 4xx (cliente) y 5xx (servidor)


**2.5 Database & Transactions Issues (5 problemas)**
- No hay prevención de deadlocks en transacciones
- No hay índices en columnas frecuentemente consultadas
- Problemas N+1 en consultas relacionadas
- No hay paginación en consultas de base de datos local
- No hay foreign keys para integridad referencial

#### Categoría 3: Warnings (6 problemas)

**3.1 Unused Fields (2 warnings)**
- _authContext no usado en category_repository_impl.dart
- _authContext no usado en tag_repository_impl.dart

**3.2 Unused Imports (4 warnings)**
- Imports no usados en email_verification_page.dart, category_management_page.dart, create_category_dialog.dart, create_tag_dialog.dart

#### Categoría 4: Code Quality Issues (11 problemas)

**4.1 Production Code Issues (9 info)**
- print() usado en database_web.dart, auth_repository_impl.dart, auth_bloc.dart

**4.2 Deprecated APIs (1 info)**
- encryptedSharedPreferences deprecado en secure_storage_service.dart

**4.3 Async Context Issues (3 info)**
- BuildContext usado a través de gaps async en forgot_password_page.dart, reset_password_page.dart, song_detail_page.dart

**4.4 Code Style Issues (25 info)**
- Falta de llaves en if statements
- No usar initializing formals
- No usar super parameters
- Usar Container en lugar de SizedBox para whitespace


### Ejemplos de Manifestación del Bug

**Ejemplo 1: Compilación Bloqueada por CategoryBloc**
```dart
// Situación: Al ejecutar flutter analyze o flutter run
// Resultado: Error de compilación
Error: 1 positional argument expected by 'CategoryBloc.new', but 0 found.
Error: The named parameter 'getAllCategoriesUseCase' isn't defined.
```

**Ejemplo 2: Type Mismatch en Song Tags**
```dart
// Situación: Al mapear Song desde API a dominio
// Resultado: Error de compilación
Error: The argument type 'List<String>' can't be assigned to the parameter type 'List<Tag>?'
```

**Ejemplo 3: Sincronización Falla Silenciosamente**
```dart
// Situación: Usuario crea canción offline, vuelve online
// Resultado: Canción no se sincroniza, no hay feedback al usuario
// Esperado: Reintento con exponential backoff y notificación de error
```

**Ejemplo 4: Memory Leak en WebSocket**
```dart
// Situación: Usuario navega entre pantallas con chat activo
// Resultado: Subscripciones WebSocket no se limpian, consumo de memoria aumenta
// Esperado: Limpieza automática de subscripciones en dispose()
```


## Comportamiento Esperado

### Requisitos de Preservación

**Comportamientos Sin Cambios:**
- Autenticación con email/password y Google Sign-In debe continuar funcionando
- CRUD de canciones (crear, editar, buscar, filtrar) debe continuar funcionando
- CRUD de setlists (crear, editar, reordenar, generar) debe continuar funcionando
- Chat en tiempo real y WebSocket debe continuar funcionando (mejorado con reconexión)
- Funcionalidad offline-first debe continuar funcionando (mejorada con resolución de conflictos)
- Gestión de equipos e invitaciones debe continuar funcionando
- Gestión de categorías y tags debe continuar funcionando (después de corregir tipos)
- Navegación y UI debe continuar funcionando

**Alcance:**
Todas las funcionalidades existentes deben preservarse. Las correcciones solo deben:
1. Eliminar errores de compilación
2. Mejorar la arquitectura sin cambiar comportamiento observable
3. Agregar capacidades faltantes (logging, error handling, reconexión)
4. Optimizar rendimiento sin cambiar resultados


## Análisis de Causa Raíz

Basado en el análisis de los 82 problemas, las causas raíz son:

### Causa Raíz 1: Inconsistencia en el Sistema de Tipos

**Problema**: La capa de dominio define `Song.tags` como `List<Tag>` (objetos completos), pero la capa de datos almacena tags como `List<String>` (solo IDs o nombres) en la base de datos local.

**Impacto**: 5 errores de compilación en song_repository_impl.dart y song_card.dart

**Solución**: Decidir una estrategia consistente:
- **Opción A (Recomendada)**: Almacenar tags como JSON en base de datos y mapear a List<Tag>
- **Opción B**: Cambiar dominio a usar List<String> y cargar Tags por separado cuando sea necesario
- **Opción C**: Crear tabla de relación many-to-many entre Songs y Tags

### Causa Raíz 2: Arquitectura de CategoryBloc Incorrecta

**Problema**: CategoryBloc fue diseñado para recibir 9 use cases individuales como parámetros nombrados, pero el patrón correcto en Clean Architecture es inyectar solo el repositorio y que el BLoC llame directamente a los métodos del repositorio.

**Impacto**: 11 errores de compilación en service_locator.dart

**Solución**: Refactorizar CategoryBloc para seguir el mismo patrón que SongBloc y SetlistBloc:
```dart
class CategoryBloc {
  final CategoryRepository _repository;
  CategoryBloc(this._repository);
}
```


### Causa Raíz 3: Falta de Infraestructura de Logging y Error Handling

**Problema**: La aplicación usa `print()` en producción y no tiene un sistema centralizado de logging ni manejo de errores consistente.

**Impacto**: 9 problemas de código de producción, manejo de errores inconsistente

**Solución**: Implementar:
- Logger profesional (package `logger`)
- GlobalErrorHandler mejorado con categorización de errores
- Estrategia de reintentos con exponential backoff
- Notificaciones al usuario para errores recuperables

### Causa Raíz 4: Gestión de Recursos y Lifecycle Inadecuada

**Problema**: BLoCs, WebSocket subscriptions y streams no se limpian correctamente, causando memory leaks.

**Impacto**: 5 problemas de state management, 5 problemas de WebSocket

**Solución**: Implementar:
- Limpieza explícita en dispose()/close() de todos los BLoCs
- StreamSubscription tracking y cancelación
- WebSocket reconnection strategy con cleanup
- Resource pooling para conexiones

### Causa Raíz 5: Estrategia Offline-First Incompleta

**Problema**: La sincronización no tiene manejo robusto de errores, resolución de conflictos ni feedback al usuario.

**Impacto**: 7 problemas de sincronización

**Solución**: Implementar:
- Exponential backoff para reintentos
- Conflict resolution strategy (last-write-wins con timestamps)
- UI feedback para estado de sincronización
- Queue de operaciones pendientes con priorización


### Causa Raíz 6: Falta de Optimización de Base de Datos

**Problema**: No hay índices, foreign keys ni optimización de consultas en la base de datos local.

**Impacto**: 5 problemas de base de datos y transacciones

**Solución**: Implementar:
- Índices en columnas frecuentemente consultadas (serverId, isSynced)
- Foreign keys para integridad referencial
- Eager loading para relaciones
- Paginación en consultas locales

## Propiedades de Corrección

### Property 1: Compilación Exitosa

_Para cualquier_ ejecución de `flutter analyze` o `flutter run` después de aplicar las correcciones, el sistema DEBERÁ compilar sin errores críticos (0 errores de compilación).

**Valida: Requisitos 2.1-2.6 (Configuración de Inyección de Dependencias), 2.7-2.10 (Sistema de Tipos)**

### Property 2: Type Safety

_Para cualquier_ operación de mapeo entre capas (API → Domain, Domain → Database), el sistema DEBERÁ mantener type safety sin conversiones inseguras (no usar `as` sin validación previa).

**Valida: Requisitos 2.7-2.10 (Sistema de Tipos y Mapeo de Datos)**


### Property 3: Resource Cleanup

_Para cualquier_ BLoC, Stream o WebSocket subscription creado durante el ciclo de vida de la aplicación, el sistema DEBERÁ liberar todos los recursos cuando el componente se dispose, sin memory leaks detectables.

**Valida: Requisitos 2.16-2.20 (Gestión de Estado), 2.28-2.32 (WebSocket)**

### Property 4: Sync Reliability

_Para cualquier_ operación de sincronización que falle debido a errores de red temporales, el sistema DEBERÁ reintentar con exponential backoff (1s, 2s, 4s, 8s, 16s, max 60s) y notificar al usuario después de 3 intentos fallidos.

**Valida: Requisitos 2.21-2.27 (Sincronización y Offline-First)**

### Property 5: Error Handling Consistency

_Para cualquier_ error capturado en la aplicación, el sistema DEBERÁ:
- Usar logger profesional (no print())
- Categorizar el error (network, validation, server, client)
- Mostrar mensaje localizado al usuario
- Registrar stack trace para debugging

**Valida: Requisitos 2.11-2.15 (Manejo de Errores y Logging)**

### Property 6: Functional Preservation

_Para cualquier_ funcionalidad existente (autenticación, CRUD de canciones, setlists, chat, equipos), el sistema DEBERÁ producir los mismos resultados observables que antes de las correcciones.

**Valida: Requisitos 3.1-3.27 (Comportamiento Sin Cambios)**


## Implementación de la Corrección

### Estrategia de Implementación

La corrección se realizará en 4 fases secuenciales, siguiendo el principio de dependencias (bottom-up):

**Fase 1: Corrección de Errores de Compilación Críticos (38 errores)**
- Prioridad: CRÍTICA
- Duración estimada: 2-3 días
- Bloquea: Todas las demás fases

**Fase 2: Corrección de Problemas Arquitectónicos (27 problemas)**
- Prioridad: ALTA
- Duración estimada: 3-4 días
- Depende de: Fase 1

**Fase 3: Corrección de Warnings y Code Quality (17 problemas)**
- Prioridad: MEDIA
- Duración estimada: 1-2 días
- Depende de: Fase 1

**Fase 4: Mejoras Adicionales (Testing, Logging, Localización)**
- Prioridad: BAJA
- Duración estimada: 2-3 días
- Depende de: Fases 1-3


### Fase 1: Corrección de Errores de Compilación Críticos

#### 1.1 Corrección de Type System (Song Tags)

**Archivos afectados:**
- `lib/core/database/database.dart` (schema)
- `lib/data/repositories/song_repository_impl.dart` (mapeo)
- `lib/presentation/widgets/song_card.dart` (UI)

**Cambios específicos:**

**Opción A (Recomendada): Almacenar Tags como JSON**
```dart
// database.dart - Crear converter para List<Tag>
class TagListConverter extends TypeConverter<List<Tag>, String> {
  const TagListConverter();
  
  @override
  List<Tag> fromSql(String fromDb) {
    if (fromDb.isEmpty) return [];
    final List<dynamic> jsonList = json.decode(fromDb);
    return jsonList.map((j) => Tag.fromJson(j)).toList();
  }
  
  @override
  String toSql(List<Tag> value) {
    return json.encode(value.map((t) => t.toJson()).toList());
  }
}

// Actualizar schema
TextColumn get tags => text().map(const TagListConverter())();
```


**song_repository_impl.dart - Actualizar mapeo:**
```dart
// Eliminar conversión manual, usar directamente
domain.Song _mapFromDb(Song data) {
  return domain.Song(
    // ... otros campos
    tags: data.tags,  // ✅ Ahora es List<Tag> directamente
  );
}

SongsCompanion _mapToDb(domain.Song song) {
  return SongsCompanion(
    // ... otros campos
    tags: Value(song.tags),  // ✅ Ahora es List<Tag> directamente
  );
}
```

**Migración de datos:**
```dart
// Crear migración para convertir tags existentes de String a JSON
// migration_v2.dart
@override
MigrationStrategy get migration {
  return MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Convertir tags de "tag1,tag2" a JSON [{"id":"1","name":"tag1"},...]
        await customStatement('UPDATE songs SET tags = ...');
      }
    },
  );
}
```


#### 1.2 Corrección de CategoryBloc Architecture

**Archivos afectados:**
- `lib/presentation/features/categories/bloc/category_bloc.dart`
- `lib/core/dependency_injection/service_locator.dart`

**Cambios específicos:**

**category_bloc.dart - Simplificar constructor:**
```dart
class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  final CategoryRepository _repository;

  // ✅ Constructor simplificado - solo recibe repositorio
  CategoryBloc(this._repository) : super(CategoryInitial()) {
    on<LoadCategoriesEvent>(_onLoadCategories);
    on<LoadTagsEvent>(_onLoadTags);
    on<CreateCategoryEvent>(_onCreateCategory);
    on<UpdateCategoryEvent>(_onUpdateCategory);
    on<DeleteCategoryEvent>(_onDeleteCategory);
    on<CreateTagEvent>(_onCreateTag);
    on<UpdateTagEvent>(_onUpdateTag);
    on<DeleteTagEvent>(_onDeleteTag);
    on<SyncCategoriesAndTagsEvent>(_onSync);
  }

  // Llamar directamente a métodos del repositorio
  Future<void> _onLoadCategories(
    LoadCategoriesEvent event,
    Emitter<CategoryState> emit,
  ) async {
    emit(CategoryLoading());
    try {
      final categories = await _repository.getAll();
      emit(CategoryLoaded(categories));
    } catch (e) {
      emit(CategoryError(e.toString()));
    }
  }
}
```


**service_locator.dart - Simplificar registro:**
```dart
// ❌ ELIMINAR todos los use cases de categorías (no son necesarios)
// sl.registerLazySingleton(() => CreateCategoryUseCase(sl()));
// sl.registerLazySingleton(() => GetAllCategoriesUseCase(sl()));
// ... etc

// ✅ Registrar solo el BLoC con el repositorio
sl.registerFactory(() => CategoryBloc(sl<CategoryRepository>()));
```

**Justificación**: En Clean Architecture, los use cases son opcionales cuando la lógica es simple (CRUD básico). CategoryBloc puede llamar directamente al repositorio, siguiendo el mismo patrón que SongBloc y SetlistBloc en el proyecto.

#### 1.3 Corrección de Category/Tag Events y States

**Archivos afectados:**
- `lib/presentation/features/categories/bloc/category_event.dart`
- `lib/presentation/features/categories/bloc/category_state.dart`

**Cambios específicos:**

**category_event.dart - Definir eventos faltantes:**
```dart
abstract class CategoryEvent {}

class LoadCategoriesEvent extends CategoryEvent {}

class LoadTagsEvent extends CategoryEvent {}

class CreateCategoryEvent extends CategoryEvent {
  final String name;
  final String? description;
  CreateCategoryEvent(this.name, {this.description});
}

class UpdateCategoryEvent extends CategoryEvent {
  final String id;
  final String name;
  final String? description;
  UpdateCategoryEvent(this.id, this.name, {this.description});
}

class DeleteCategoryEvent extends CategoryEvent {
  final String id;
  DeleteCategoryEvent(this.id);
}

class CreateTagEvent extends CategoryEvent {
  final String name;
  final String? color;
  CreateTagEvent(this.name, {this.color});
}

class UpdateTagEvent extends CategoryEvent {
  final String id;
  final String name;
  final String? color;
  UpdateTagEvent(this.id, this.name, {this.color});
}

class DeleteTagEvent extends CategoryEvent {
  final String id;
  DeleteTagEvent(this.id);
}

class SyncCategoriesAndTagsEvent extends CategoryEvent {}
```


**category_state.dart - Agregar campo tags:**
```dart
abstract class CategoryState {}

class CategoryInitial extends CategoryState {}

class CategoryLoading extends CategoryState {}

class CategoryLoaded extends CategoryState {
  final List<Category> categories;
  final List<Tag> tags;  // ✅ Agregar campo tags
  
  CategoryLoaded(this.categories, {List<Tag>? tags}) 
    : tags = tags ?? [];
}

class CategoryError extends CategoryState {
  final String message;
  CategoryError(this.message);
}

class CategoryOperationSuccess extends CategoryState {
  final String message;
  CategoryOperationSuccess(this.message);
}
```

#### 1.4 Corrección de GoogleSignInUseCase Registration

**Archivo afectado:**
- `lib/core/dependency_injection/service_locator.dart`

**Cambio específico:**
```dart
// ✅ Agregar registro de GoogleSignInUseCase
sl.registerLazySingleton(() => GoogleSignInUseCase(sl()));
```

**Nota**: Verificar que GoogleSignInUseCase esté definido en `lib/domain/usecases/` y que reciba AuthRepository como dependencia.


#### 1.5 Eliminación de Registros Duplicados

**Archivo afectado:**
- `lib/core/dependency_injection/service_locator.dart`

**Cambios específicos:**
```dart
// ❌ ELIMINAR registros duplicados
// sl.registerLazySingleton<SongRepositoryImpl>(
//   () => sl<SongRepository>() as SongRepositoryImpl,
// );
// sl.registerLazySingleton<SetlistRepositoryImpl>(
//   () => sl<SetlistRepository>() as SetlistRepositoryImpl,
// );

// ✅ MANTENER solo las interfaces
sl.registerLazySingleton<SongRepository>(
  () => SongRepositoryImpl(sl(), sl()),
);
sl.registerLazySingleton<SetlistRepository>(
  () => SetlistRepositoryImpl(sl(), sl()),
);

// ✅ Para SyncManager, obtener implementaciones directamente
void _setupSyncManager() {
  final syncManager = sl<SyncManager>();
  syncManager.registerRepository(sl<SongRepository>() as SongRepositoryImpl);
  syncManager.registerRepository(sl<SetlistRepository>() as SetlistRepositoryImpl);
  syncManager.startPeriodicSync();
}
```


#### 1.6 Actualización de flutter_secure_storage

**Archivo afectado:**
- `lib/core/storage/secure_storage_service.dart`

**Cambio específico:**
```dart
// ❌ ELIMINAR parámetro deprecado
// final storage = FlutterSecureStorage(
//   encryptedSharedPreferences: true,  // DEPRECADO
// );

// ✅ Usar configuración actualizada
final storage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
  ),
);
```

#### 1.7 Corrección de Imports No Usados

**Archivos afectados:**
- `lib/presentation/features/auth/pages/email_verification_page.dart`
- `lib/presentation/features/categories/pages/category_management_page.dart`
- `lib/presentation/features/categories/widgets/create_category_dialog.dart`
- `lib/presentation/features/categories/widgets/create_tag_dialog.dart`

**Cambio específico:**
```dart
// ❌ ELIMINAR imports no usados
// import '../bloc/auth_event.dart';
// import '../bloc/category_event.dart';
```


#### 1.8 Corrección de Campos No Usados

**Archivos afectados:**
- `lib/data/repositories/category_repository_impl.dart`
- `lib/data/repositories/tag_repository_impl.dart`

**Cambio específico:**
```dart
// ❌ ELIMINAR campo no usado
// final AuthContextService _authContext;

// O si es necesario para futuras features:
// ignore: unused_field
final AuthContextService _authContext;
```

### Fase 2: Corrección de Problemas Arquitectónicos

#### 2.1 Implementación de Logger Profesional

**Archivos afectados:**
- `pubspec.yaml` (agregar dependencia)
- `lib/core/logging/app_logger.dart` (nuevo archivo)
- Todos los archivos que usan `print()`

**Cambios específicos:**

**pubspec.yaml:**
```yaml
dependencies:
  logger: ^2.0.0
```


**app_logger.dart (nuevo):**
```dart
import 'package:logger/logger.dart';

class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
    level: Level.debug,  // Cambiar a Level.info en producción
  );

  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
}
```

**Reemplazar print() en todos los archivos:**
```dart
// ❌ ANTES
print('Error: $e');

// ✅ DESPUÉS
AppLogger.error('Error occurred', e, stackTrace);
```


#### 2.2 Mejora de GlobalErrorHandler

**Archivo afectado:**
- `lib/core/error/global_error_handler.dart`

**Cambios específicos:**
```dart
class GlobalErrorHandler {
  static void handleError(dynamic error, StackTrace? stackTrace) {
    final errorType = _categorizeError(error);
    
    switch (errorType) {
      case ErrorType.network:
        AppLogger.warning('Network error', error, stackTrace);
        _showUserMessage('Error de conexión. Verifica tu internet.');
        break;
      case ErrorType.server:
        AppLogger.error('Server error', error, stackTrace);
        _showUserMessage('Error del servidor. Intenta más tarde.');
        break;
      case ErrorType.client:
        AppLogger.warning('Client error', error, stackTrace);
        _showUserMessage('Error en la solicitud. Verifica los datos.');
        break;
      case ErrorType.validation:
        AppLogger.info('Validation error', error, stackTrace);
        _showUserMessage(error.toString());
        break;
      default:
        AppLogger.error('Unknown error', error, stackTrace);
        _showUserMessage('Error inesperado. Contacta soporte.');
    }
  }

  static ErrorType _categorizeError(dynamic error) {
    if (error is DioException) {
      if (error.response == null) return ErrorType.network;
      final statusCode = error.response!.statusCode ?? 0;
      if (statusCode >= 500) return ErrorType.server;
      if (statusCode >= 400) return ErrorType.client;
    }
    return ErrorType.unknown;
  }
}

enum ErrorType { network, server, client, validation, unknown }
```


#### 2.3 Implementación de Exponential Backoff para Sync

**Archivo afectado:**
- `lib/core/sync/sync_manager.dart`

**Cambios específicos:**
```dart
class SyncManager {
  int _retryCount = 0;
  static const int _maxRetries = 5;
  static const List<int> _backoffDelays = [1, 2, 4, 8, 16, 60]; // segundos

  Future<void> syncAll() async {
    try {
      await _performSync();
      _retryCount = 0;  // Reset en éxito
    } catch (e, stack) {
      AppLogger.error('Sync failed', e, stack);
      
      if (_retryCount < _maxRetries) {
        final delay = _backoffDelays[_retryCount];
        _retryCount++;
        
        AppLogger.info('Retrying sync in $delay seconds (attempt $_retryCount)');
        await Future.delayed(Duration(seconds: delay));
        await syncAll();  // Retry recursivo
      } else {
        _retryCount = 0;
        _notifyUserSyncFailed();
      }
    }
  }

  void _notifyUserSyncFailed() {
    // Mostrar SnackBar o notificación al usuario
    GlobalErrorHandler.showMessage(
      'No se pudo sincronizar después de $_maxRetries intentos. '
      'Verifica tu conexión.',
    );
  }
}
```


#### 2.4 Implementación de Conflict Resolution

**Archivo afectado:**
- `lib/core/sync/conflict_resolver.dart` (nuevo archivo)

**Cambios específicos:**
```dart
class ConflictResolver {
  /// Estrategia: Last-Write-Wins basado en timestamps
  static T resolveConflict<T extends SyncableEntity>(
    T local,
    T remote,
  ) {
    // Comparar timestamps de actualización
    if (local.updatedAt.isAfter(remote.updatedAt)) {
      AppLogger.info('Conflict resolved: keeping local version');
      return local;
    } else {
      AppLogger.info('Conflict resolved: keeping remote version');
      return remote;
    }
  }

  /// Para casos complejos, preguntar al usuario
  static Future<T> resolveConflictWithUser<T>(
    T local,
    T remote,
    BuildContext context,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Conflicto de Datos'),
        content: Text('Hay cambios locales y remotos. ¿Qué versión deseas mantener?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Mantener Local'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Usar Remoto'),
          ),
        ],
      ),
    );
    
    return result == true ? local : remote;
  }
}

abstract class SyncableEntity {
  DateTime get updatedAt;
}
```


#### 2.5 Optimización de totalUnsyncedCount Stream

**Archivo afectado:**
- `lib/core/sync/sync_manager.dart`

**Cambio específico:**
```dart
// ❌ ANTES: Crea nuevo stream cada segundo
Stream<int> get totalUnsyncedCount async* {
  while (true) {
    int total = 0;
    for (final repo in _repositories) {
      total += await repo.getUnsyncedCount().first;
    }
    yield total;
    await Future.delayed(Duration(seconds: 1));
  }
}

// ✅ DESPUÉS: Combina streams existentes
Stream<int> get totalUnsyncedCount {
  if (_repositories.isEmpty) {
    return Stream.value(0);
  }
  
  // Combinar todos los streams de repositorios
  return Rx.combineLatest(
    _repositories.map((repo) => repo.getUnsyncedCountStream()),
    (List<int> counts) => counts.fold(0, (sum, count) => sum + count),
  );
}
```

**Nota**: Requiere agregar `rxdart` a `pubspec.yaml`:
```yaml
dependencies:
  rxdart: ^0.27.0
```


#### 2.6 Implementación de WebSocket Reconnection

**Archivo afectado:**
- `lib/core/services/websocket_service.dart`

**Cambios específicos:**
```dart
class WebSocketService {
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  Timer? _heartbeatTimer;
  DateTime? _lastHeartbeat;
  
  Future<void> connect() async {
    try {
      // ... código de conexión existente
      _reconnectAttempts = 0;
      _startHeartbeat();
    } catch (e) {
      AppLogger.error('WebSocket connection failed', e);
      await _attemptReconnect();
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(Duration(seconds: 30), (_) {
      _sendHeartbeat();
      _checkHeartbeatTimeout();
    });
  }

  void _checkHeartbeatTimeout() {
    if (_lastHeartbeat != null) {
      final elapsed = DateTime.now().difference(_lastHeartbeat!);
      if (elapsed.inSeconds > 60) {
        AppLogger.warning('Heartbeat timeout, reconnecting');
        _attemptReconnect();
      }
    }
  }

  Future<void> _attemptReconnect() async {
    if (_isReconnecting || _reconnectAttempts >= _maxReconnectAttempts) {
      return;
    }

    _isReconnecting = true;
    _reconnectAttempts++;
    
    final delay = _backoffDelays[min(_reconnectAttempts - 1, _backoffDelays.length - 1)];
    AppLogger.info('Reconnecting WebSocket in $delay seconds (attempt $_reconnectAttempts)');
    
    await Future.delayed(Duration(seconds: delay));
    _isReconnecting = false;
    await connect();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    // ... cleanup existente
  }
}
```


#### 2.7 Limpieza de Recursos en BLoCs

**Archivos afectados:**
- Todos los BLoCs que usan StreamSubscriptions

**Patrón a seguir:**
```dart
class SongBloc extends Bloc<SongEvent, SongState> {
  final List<StreamSubscription> _subscriptions = [];
  
  SongBloc(...) : super(SongInitial()) {
    // Registrar subscripciones
    _subscriptions.add(
      _connectivityService.onConnectivityChanged.listen(_onConnectivityChanged)
    );
  }

  @override
  Future<void> close() {
    // Cancelar todas las subscripciones
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    return super.close();
  }
}
```

#### 2.8 Optimización de Base de Datos

**Archivo afectado:**
- `lib/core/database/database.dart`

**Cambios específicos:**
```dart
// Agregar índices
class Songs extends Table {
  // ... campos existentes
  
  @override
  List<Set<Column>> get customConstraints => [
    {serverId},  // Índice en serverId para búsquedas rápidas
  ];
}

// Agregar foreign keys
class Setlists extends Table {
  // ... campos existentes
  
  // Nota: songIds es una lista, no se puede hacer FK directo
  // Considerar crear tabla de relación many-to-many
}
```


### Fase 3: Corrección de Code Quality Issues

#### 3.1 Corrección de Async Context Issues

**Archivos afectados:**
- `lib/presentation/features/auth/pages/forgot_password_page.dart`
- `lib/presentation/features/auth/pages/reset_password_page.dart`
- `lib/presentation/features/songs/pages/song_detail_page.dart`

**Patrón a seguir:**
```dart
// ❌ ANTES: BuildContext usado después de async gap
await someAsyncOperation();
Navigator.of(context).pop();  // ⚠️ Warning

// ✅ DESPUÉS: Verificar mounted antes de usar context
await someAsyncOperation();
if (!mounted) return;
Navigator.of(context).pop();

// O capturar navigator antes del async gap
final navigator = Navigator.of(context);
await someAsyncOperation();
navigator.pop();
```

#### 3.2 Corrección de Code Style Issues

**Cambios específicos:**

**Agregar llaves en if statements:**
```dart
// ❌ ANTES
if (condition) doSomething();

// ✅ DESPUÉS
if (condition) {
  doSomething();
}
```


**Usar initializing formals:**
```dart
// ❌ ANTES
class SongState {
  final List<Song> songs;
  SongState(List<Song> songs) : songs = songs;
}

// ✅ DESPUÉS
class SongState {
  final List<Song> songs;
  SongState(this.songs);
}
```

**Usar super parameters:**
```dart
// ❌ ANTES
class SongLoaded extends SongState {
  SongLoaded(List<Song> songs) : super(songs);
}

// ✅ DESPUÉS
class SongLoaded extends SongState {
  SongLoaded(super.songs);
}
```

**Usar SizedBox en lugar de Container para whitespace:**
```dart
// ❌ ANTES
Container(width: 10, height: 10)

// ✅ DESPUÉS
SizedBox(width: 10, height: 10)
```


### Fase 4: Mejoras Adicionales

#### 4.1 Implementación de Localización (i18n)

**Archivos a crear:**
- `lib/l10n/app_es.arb` (español)
- `lib/l10n/app_en.arb` (inglés)

**pubspec.yaml:**
```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: ^0.18.0

flutter:
  generate: true
```

**l10n.yaml:**
```yaml
arb-dir: lib/l10n
template-arb-file: app_es.arb
output-localization-file: app_localizations.dart
```

**Ejemplo de uso:**
```dart
// ❌ ANTES
Text('Error de conexión')

// ✅ DESPUÉS
Text(AppLocalizations.of(context)!.connectionError)
```

#### 4.2 Implementación de Tests

**Estructura de tests:**
```
test/
  unit/
    blocs/
      song_bloc_test.dart
      setlist_bloc_test.dart
      category_bloc_test.dart
    repositories/
      song_repository_test.dart
    usecases/
      login_user_test.dart
  integration/
    auth_flow_test.dart
    song_crud_test.dart
    sync_flow_test.dart
  widget/
    song_card_test.dart
    song_list_page_test.dart
```


**Ejemplo de test unitario para BLoC:**
```dart
void main() {
  group('CategoryBloc', () {
    late CategoryBloc bloc;
    late MockCategoryRepository mockRepository;

    setUp(() {
      mockRepository = MockCategoryRepository();
      bloc = CategoryBloc(mockRepository);
    });

    tearDown(() {
      bloc.close();
    });

    test('emits [CategoryLoading, CategoryLoaded] when LoadCategoriesEvent is added', () {
      // Arrange
      final categories = [Category(id: '1', name: 'Test')];
      when(() => mockRepository.getAll()).thenAnswer((_) async => categories);

      // Assert later
      expectLater(
        bloc.stream,
        emitsInOrder([
          isA<CategoryLoading>(),
          isA<CategoryLoaded>(),
        ]),
      );

      // Act
      bloc.add(LoadCategoriesEvent());
    });
  });
}
```

