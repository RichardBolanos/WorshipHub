# Diseño de Corrección - Parte 2: Backend Coordination & Testing

## Coordinación con Backend

Algunos problemas requieren cambios en el backend para una solución completa:

### Backend Change 1: Estandarización de Respuestas de API

**Problema**: Respuestas mixtas (paginadas/directas) sin consistencia

**Solución Backend:**
```kotlin
// Estandarizar TODAS las respuestas de lista como paginadas
data class PageResponse<T>(
    val content: List<T>,
    val page: Int,
    val size: Int,
    val totalElements: Long,
    val totalPages: Int
)

// Endpoints:
GET /api/songs -> PageResponse<SongDTO>
GET /api/setlists -> PageResponse<SetlistDTO>
GET /api/categories -> PageResponse<CategoryDTO>
```

**Impacto Frontend**: Simplificar lógica de mapeo en repositorios


### Backend Change 2: Token Refresh Endpoint

**Problema**: No hay mecanismo de refresh token

**Solución Backend:**
```kotlin
POST /api/auth/refresh
Request: { "refreshToken": "..." }
Response: { 
  "accessToken": "...", 
  "refreshToken": "...",
  "expiresIn": 3600 
}
```

**Impacto Frontend**: Implementar auto-refresh en AuthInterceptor

### Backend Change 3: WebSocket Security Improvements

**Problema**: Token enviado en frame STOMP sin encriptación adicional

**Solución Backend:**
```kotlin
// Aceptar token en header de conexión inicial
@Configuration
class WebSocketConfig : WebSocketMessageBrokerConfigurer {
    override fun configureClientInboundChannel(registration: ChannelRegistration) {
        registration.interceptors(object : ChannelInterceptor {
            override fun preSend(message: Message<*>, channel: MessageChannel): Message<*>? {
                val accessor = StompHeaderAccessor.wrap(message)
                if (accessor.command == StompCommand.CONNECT) {
                    val token = accessor.getFirstNativeHeader("Authorization")
                    // Validar token y establecer usuario
                }
                return message
            }
        })
    }
}
```

**Impacto Frontend**: Enviar token en header de conexión en lugar de frame STOMP


### Backend Change 4: Error Response Format Standardization

**Problema**: Formatos de error inconsistentes

**Solución Backend:**
```kotlin
data class ErrorResponse(
    val timestamp: String,
    val status: Int,
    val error: String,
    val message: String,
    val path: String,
    val errorCode: String? = null,  // Para categorización
    val details: Map<String, Any>? = null
)

// Ejemplo de uso:
@ExceptionHandler(ValidationException::class)
fun handleValidation(ex: ValidationException): ResponseEntity<ErrorResponse> {
    return ResponseEntity.badRequest().body(
        ErrorResponse(
            timestamp = Instant.now().toString(),
            status = 400,
            error = "Bad Request",
            message = ex.message ?: "Validation failed",
            path = request.requestURI,
            errorCode = "VALIDATION_ERROR",
            details = ex.errors
        )
    )
}
```

**Impacto Frontend**: Parsing consistente de errores en GlobalErrorHandler


### Backend Change 5: Invitation Validation Endpoint

**Problema**: No hay validación de expiración de invitaciones

**Solución Backend:**
```kotlin
GET /api/invitations/{token}/validate
Response: {
  "valid": true,
  "invitation": { ... },
  "expiresAt": "2024-12-31T23:59:59Z",
  "expired": false
}
```

**Impacto Frontend**: Validar invitación antes de mostrar formulario de aceptación

## Estrategia de Testing

### Validación de Correcciones

La estrategia de testing sigue un enfoque de dos fases:

**Fase 1: Exploratory Testing (Pre-Fix)**
- Ejecutar `flutter analyze` y documentar los 82 problemas
- Ejecutar tests existentes (si los hay) y documentar fallos
- Intentar compilar y ejecutar la aplicación, documentar errores

**Fase 2: Fix Validation (Post-Fix)**
- Verificar que `flutter analyze` no reporte errores críticos
- Verificar que todos los tests pasen
- Verificar que la aplicación compile y ejecute sin errores


### Unit Tests

**Objetivo**: Verificar que cada componente funciona correctamente de forma aislada

**Cobertura mínima requerida:**
- BLoCs: 80% de cobertura
- Repositorios: 70% de cobertura
- Use Cases: 80% de cobertura
- Utilities: 90% de cobertura

**Ejemplo de test para CategoryBloc:**
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

    blocTest<CategoryBloc, CategoryState>(
      'emits [CategoryLoading, CategoryLoaded] when LoadCategoriesEvent succeeds',
      build: () {
        when(() => mockRepository.getAll())
            .thenAnswer((_) async => [Category(id: '1', name: 'Test')]);
        return bloc;
      },
      act: (bloc) => bloc.add(LoadCategoriesEvent()),
      expect: () => [
        isA<CategoryLoading>(),
        isA<CategoryLoaded>()
            .having((s) => s.categories.length, 'categories length', 1),
      ],
    );

    blocTest<CategoryBloc, CategoryState>(
      'emits [CategoryLoading, CategoryError] when LoadCategoriesEvent fails',
      build: () {
        when(() => mockRepository.getAll())
            .thenThrow(Exception('Network error'));
        return bloc;
      },
      act: (bloc) => bloc.add(LoadCategoriesEvent()),
      expect: () => [
        isA<CategoryLoading>(),
        isA<CategoryError>()
            .having((s) => s.message, 'error message', contains('Network error')),
      ],
    );
  });
}
```


### Integration Tests

**Objetivo**: Verificar que los flujos completos funcionan correctamente

**Test Cases Críticos:**

**1. Auth Flow Test**
```dart
testWidgets('User can login with email and password', (tester) async {
  // Arrange
  await tester.pumpWidget(MyApp());
  
  // Act
  await tester.enterText(find.byKey(Key('email_field')), 'test@example.com');
  await tester.enterText(find.byKey(Key('password_field')), 'password123');
  await tester.tap(find.byKey(Key('login_button')));
  await tester.pumpAndSettle();
  
  // Assert
  expect(find.text('Dashboard'), findsOneWidget);
});
```

**2. Song CRUD Flow Test**
```dart
testWidgets('User can create, edit, and delete a song', (tester) async {
  // Setup: Login first
  await loginUser(tester);
  
  // Create song
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(Key('title_field')), 'Amazing Grace');
  await tester.tap(find.byKey(Key('save_button')));
  await tester.pumpAndSettle();
  
  // Verify song appears in list
  expect(find.text('Amazing Grace'), findsOneWidget);
  
  // Edit song
  await tester.tap(find.text('Amazing Grace'));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.edit));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(Key('artist_field')), 'John Newton');
  await tester.tap(find.byKey(Key('save_button')));
  await tester.pumpAndSettle();
  
  // Verify edit
  expect(find.text('John Newton'), findsOneWidget);
  
  // Delete song
  await tester.longPress(find.text('Amazing Grace'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete'));
  await tester.pumpAndSettle();
  
  // Verify deletion
  expect(find.text('Amazing Grace'), findsNothing);
});
```


**3. Sync Flow Test**
```dart
testWidgets('Offline changes sync when connection restored', (tester) async {
  // Setup: Login and go offline
  await loginUser(tester);
  await simulateOffline();
  
  // Create song offline
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(Key('title_field')), 'Offline Song');
  await tester.tap(find.byKey(Key('save_button')));
  await tester.pumpAndSettle();
  
  // Verify unsynced indicator
  expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  
  // Go online
  await simulateOnline();
  await tester.pumpAndSettle(Duration(seconds: 5));
  
  // Verify synced indicator
  expect(find.byIcon(Icons.cloud_done), findsOneWidget);
});
```

### Widget Tests

**Objetivo**: Verificar que los widgets se renderizan correctamente

**Test Cases:**

**1. SongCard Widget Test**
```dart
testWidgets('SongCard displays song information correctly', (tester) async {
  final song = Song(
    title: 'Amazing Grace',
    artist: 'John Newton',
    key: 'G',
    tags: [Tag(id: '1', name: 'Hymn', color: '#FF0000')],
  );
  
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SongCard(song: song),
      ),
    ),
  );
  
  expect(find.text('Amazing Grace'), findsOneWidget);
  expect(find.text('John Newton'), findsOneWidget);
  expect(find.text('G'), findsOneWidget);
  expect(find.text('Hymn'), findsOneWidget);
});
```


### Property-Based Tests

**Objetivo**: Verificar propiedades invariantes del sistema con datos generados aleatoriamente

**Ejemplo: Sync Reliability Property**
```dart
import 'package:test/test.dart';
import 'package:test_api/test_api.dart' as test_api;

void main() {
  group('Sync Manager Property Tests', () {
    test('Property: Exponential backoff delays increase correctly', () {
      final syncManager = SyncManager(mockConnectivity);
      final delays = <int>[];
      
      // Simular 5 fallos consecutivos
      for (int i = 0; i < 5; i++) {
        syncManager.simulateFailure();
        delays.add(syncManager.getNextRetryDelay());
      }
      
      // Verificar que cada delay es mayor o igual al anterior
      for (int i = 1; i < delays.length; i++) {
        expect(delays[i], greaterThanOrEqualTo(delays[i - 1]));
      }
      
      // Verificar que sigue patrón exponencial (aproximadamente)
      expect(delays[0], equals(1));
      expect(delays[1], equals(2));
      expect(delays[2], equals(4));
      expect(delays[3], equals(8));
      expect(delays[4], equals(16));
    });
  });
}
```

### Performance Tests

**Objetivo**: Verificar que las optimizaciones mejoran el rendimiento

**Test Cases:**

**1. Database Query Performance**
```dart
test('Songs query with index is faster than without', () async {
  // Insertar 1000 canciones
  for (int i = 0; i < 1000; i++) {
    await database.insert(Song(title: 'Song $i', serverId: 'id_$i'));
  }
  
  // Medir query con índice
  final stopwatch = Stopwatch()..start();
  await database.select(database.songs)
    ..where((tbl) => tbl.serverId.equals('id_500'))
    .getSingle();
  stopwatch.stop();
  
  // Verificar que es rápido (< 10ms)
  expect(stopwatch.elapsedMilliseconds, lessThan(10));
});
```


**2. Stream Optimization Performance**
```dart
test('Combined stream is more efficient than polling', () async {
  final repository1 = MockRepository();
  final repository2 = MockRepository();
  
  // Método antiguo: polling cada segundo
  int oldMethodCalls = 0;
  final oldStream = Stream.periodic(Duration(seconds: 1), (_) {
    oldMethodCalls++;
    return repository1.getCount() + repository2.getCount();
  });
  
  // Método nuevo: combinar streams
  int newMethodCalls = 0;
  final newStream = Rx.combineLatest2(
    repository1.countStream.doOnData((_) => newMethodCalls++),
    repository2.countStream.doOnData((_) => newMethodCalls++),
    (a, b) => a + b,
  );
  
  // Simular 10 segundos
  await Future.delayed(Duration(seconds: 10));
  
  // Verificar que el nuevo método hace menos llamadas
  expect(newMethodCalls, lessThan(oldMethodCalls));
});
```

### Regression Tests

**Objetivo**: Verificar que las correcciones no rompen funcionalidad existente

**Test Cases:**

**1. Authentication Preservation Test**
```dart
testWidgets('Email/password login still works after fixes', (tester) async {
  await tester.pumpWidget(MyApp());
  
  await tester.enterText(find.byKey(Key('email_field')), 'test@example.com');
  await tester.enterText(find.byKey(Key('password_field')), 'password123');
  await tester.tap(find.byKey(Key('login_button')));
  await tester.pumpAndSettle();
  
  expect(find.text('Dashboard'), findsOneWidget);
});
```


**2. Song CRUD Preservation Test**
```dart
group('Song CRUD Preservation Tests', () {
  test('Creating song still works', () async {
    final repository = SongRepositoryImpl(mockDio, mockDatabase);
    final song = Song(title: 'Test Song', artist: 'Test Artist');
    
    final created = await repository.createSong(song);
    
    expect(created.title, equals('Test Song'));
    expect(created.serverId, isNotNull);
  });

  test('Updating song still works', () async {
    final repository = SongRepositoryImpl(mockDio, mockDatabase);
    final song = Song(id: 1, serverId: '123', title: 'Old Title');
    
    final updated = await repository.updateSong(
      song.copyWith(title: 'New Title')
    );
    
    expect(updated.title, equals('New Title'));
  });

  test('Searching songs still works', () async {
    final repository = SongRepositoryImpl(mockDio, mockDatabase);
    
    final results = await repository.searchSongs('Amazing');
    
    expect(results, isNotEmpty);
    expect(results.first.title, contains('Amazing'));
  });
});
```

### Test Execution Strategy

**Orden de ejecución:**

1. **Pre-Fix Validation**
   ```bash
   flutter analyze > pre_fix_analysis.txt
   flutter test > pre_fix_tests.txt
   ```

2. **Apply Phase 1 Fixes** (Compilation errors)
   ```bash
   flutter analyze
   # Debe mostrar 0 errores críticos
   ```

3. **Apply Phase 2 Fixes** (Architectural issues)
   ```bash
   flutter test test/unit/
   flutter test test/integration/
   # Todos los tests deben pasar
   ```

4. **Apply Phase 3 Fixes** (Code quality)
   ```bash
   flutter analyze
   # Debe mostrar 0 warnings
   ```

5. **Apply Phase 4 Fixes** (Additional improvements)
   ```bash
   flutter test --coverage
   # Cobertura debe ser > 70%
   ```

