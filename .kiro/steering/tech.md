---
inclusion: auto
description: Complete technology stack, libraries, build tools, and common commands for backend and frontend
---

# WorshipHub Technology Stack

## Backend API (worship_hub_api)

### Core Technologies

- **Language**: Kotlin 2.1.0 with JVM target 21 (Java 21 LTS required; Java 25+ NOT compatible)
- **Framework**: Spring Boot 3.5.5
- **Build Tool**: Gradle 8.x with Kotlin DSL
- **Database**: PostgreSQL 16 + PostGIS 3.5 (production), H2 (development)
- **ORM**: Spring Data JPA with Hibernate
- **Migration**: Flyway (9 versioned migrations, auto-applied on startup)
- **Connection Pool**: HikariCP

### Key Libraries

- **Security**: Spring Security with JWT (jjwt 0.12.6), BCrypt, OAuth2 client
- **API Documentation**: SpringDoc OpenAPI (Swagger UI at /swagger-ui.html)
- **WebSocket**: Spring WebSocket with STOMP protocol (heartbeat 30s, timeout 60s)
- **Validation**: Spring Boot Starter Validation
- **JSON**: Jackson with Kotlin module
- **Testing**: JUnit 5, MockK 1.13.8, SpringMockK 4.0.2, Kotest 5.8.0, Spring Security Test
- **Cloud**: GCP Cloud SQL connector
- **Dev Tools**: Docker Compose (PostgreSQL port 5442, Mailpit ports 8025/1025)

### Common Commands

```bash
# Start with local PostgreSQL (recommended)
./gradlew :api:bootRun --args="--spring.profiles.active=local"

# Start with H2 in-memory
./gradlew :api:bootRun --args="--spring.profiles.active=h2"

# Start Docker services (PostgreSQL + Mailpit)
docker-compose up -d
# Or: ./start-database.bat

# Build JAR
./gradlew :api:bootJar
# Output: api/build/libs/api-1.0.0.jar

# Run all tests
./gradlew test

# Run module-specific tests
./gradlew :api:test
./gradlew :domain:test
./gradlew :application:test

# Test coverage report
./gradlew jacocoTestReport
# Output: build/reports/jacoco/test/html/index.html

# Native build (GraalVM)
./gradlew :api:nativeCompile

# Health check
curl http://localhost:9090/api/v1/health
```

### Environment Profiles

| Profile | Database | Port | Use Case |
|---------|----------|------|----------|
| local | PostgreSQL (localhost:5442) | 9090 | Recommended for development |
| h2 | H2 in-memory (console at /h2-console) | 9090 | Quick prototyping |
| neon | Neon cloud PostgreSQL | 9090 | Cloud development |
| prod | PostgreSQL (externalized secrets) | 9090 | Production |
| simple | Any (minimal security) | 9090 | Testing without auth |

### Environment Variables

```bash
SPRING_PROFILES_ACTIVE=local
DATABASE_URL=jdbc:postgresql://localhost:5442/worshiphub
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=postgres
JWT_SECRET=<min-32-chars>
JWT_EXPIRATION=3600000        # 1 hour
JWT_REFRESH_EXPIRATION=86400000  # 24 hours
SERVER_PORT=9090
```

### Security Configuration

- JWT: 1h access token, 24h refresh token, blacklisting for logout
- Passwords: min 8 chars, uppercase + lowercase + numbers, BCrypt hashed
- Email verification: 24h tokens
- Password reset: 1h tokens
- Invitations: 7-day tokens
- Rate limiting: 100 req/min per IP
- Headers: CSP, X-Frame-Options: DENY, nosniff, HSTS
- Method-level: @PreAuthorize with role hierarchy
- Actuator: /actuator/health (liveness + readiness probes)

### Logging

- Console: INFO (prod) / DEBUG (dev)
- File: `api/logs/worshiphub.log` (rotated daily, gzipped)
- Format: JSON structured with correlation IDs

## Frontend UI (worship_hub_ui)

### Core Technologies

- **Framework**: Flutter 3.6.1
- **Language**: Dart 3.6.1
- **State Management**: flutter_bloc 9.1.1 (BLoC pattern) + equatable 2.0.5
- **Local Database**: Drift 2.29.0 (SQLite) with custom type converters
- **Dependency Injection**: get_it 9.2.0 (service locator)
- **Routing**: go_router 17.0.1 (declarative navigation)

### Key Libraries

| Category | Library | Version |
|----------|---------|---------|
| HTTP | dio | 5.7.0 |
| Connectivity | connectivity_plus | 6.1.0 |
| WebSocket | web_socket_channel | 3.0.1 |
| Secure Storage | flutter_secure_storage | 10.0.0 |
| Preferences | shared_preferences | 2.5.3 |
| Animations | flutter_animate | 4.5.0 |
| Shimmer | shimmer | 3.0.0 |
| Staggered Animations | flutter_staggered_animations | 1.1.1 |
| Drag & Drop | flutter_reorderable_list | 1.3.1 |
| Calendar | table_calendar | 3.1.2 |
| Firebase Core | firebase_core | 4.2.1 |
| Firebase Auth | firebase_auth | 6.1.2 |
| Google Sign-In | google_sign_in | 7.2.0 |
| Push Notifications | firebase_messaging | 16.0.4 |
| Toast | fluttertoast | 9.0.0 |
| Logging | logger | 2.0.0 |
| Reactive | rxdart | 0.27.0 |
| Sync Locks | synchronized | 3.3.0+3 |
| i18n | intl | 0.20.2 |

### Dev Dependencies

| Library | Version | Purpose |
|---------|---------|---------|
| bloc_test | 10.0.0 | Declarative BLoC testing |
| mocktail | 1.0.4 | Mocking |
| glados | 1.1.1 | Property-based testing |
| drift_dev | 2.29.0 | Drift code generation |
| build_runner | 2.4.13 | Code generation |
| flutter_lints | 6.0.0 | Linting rules |

### Common Commands

```bash
# Install dependencies
flutter pub get

# Generate code (Drift, serialization)
flutter pub run build_runner build --delete-conflicting-outputs

# Run app
flutter run
flutter run -d chrome    # Web
flutter run -d android   # Android

# Build
flutter build apk --release
flutter build appbundle --release  # Google Play
flutter build ios --release
flutter build web --release

# Tests
flutter test
flutter test --reporter expanded
flutter test --coverage

# Analysis
flutter analyze

# Format
flutter format .

# Configure Firebase
flutterfire configure

# Switch environment (in main.dart or via --dart-define)
flutter run --dart-define=ENV=production
```

### Environment Configuration

| Environment | API URL | WebSocket URL | Log Level |
|-------------|---------|---------------|-----------|
| development | `http://10.0.2.2:9090` (Android) / `http://localhost:9090` (Web) | `ws://.../ws/chat` | debug |
| staging | `https://staging-api.worshiphub.com` | `wss://.../ws/chat` | info |
| production | `https://api.worshiphub.com` | `wss://.../ws/chat` | warning |

Config files: `lib/core/config/environment.dart`, `lib/core/config/app_config.dart`

### Offline-First Architecture

- **Drift database**: SQLite with TagListConverter (List<Tag> ↔ JSON) and StringListConverter
- **Cache TTL**: 5 minutes per entity (configurable in `_isCacheValid()`)
- **Connectivity**: 3 states (online/offline/apiUnreachable), health check every 30s with 5s timeout
- **Sync**: Push-first order, exponential backoff (1s→2s→4s→8s→16s, max 60s, 5 retries)
- **Conflicts**: ConflictResolver with lastWriteWins (default), keepLocal, keepRemote strategies
- **Token validation**: Auto-refresh 5 minutes before expiry via AuthInterceptor
- **WebSocket**: STOMP-compliant with auto-reconnect (exponential backoff, max 10 attempts, heartbeat 30s)

### Error Handling

- **ApiException**: Typed errors with code, message, statusCode, validationErrors
- **ApiErrorParser**: `fromDioException()` → ApiException (handles timeouts, network errors, validation)
- **GlobalErrorHandler**: Categorizes errors (network/server/client/validation/unknown)
- **AppLogger**: Structured logging (debug/info/warning/error) with logger package

### UI/UX

- Material Design 3 with light/dark themes
- Primary: Purple (#6750A4), Secondary: Blue (#625B71), Tertiary: Pink (#7D5260)
- Shimmer loading effects, pull-to-refresh, staggered animations
- ChordPro editor with inline chord badges, transpose bar (+/− semitones)
- SyncStatusIndicator widget (green synced / orange pending)
- i18n: Spanish (es) + English (en) via flutter_localizations + L10nService singleton

## Development Standards

### Code Style

- **Kotlin**: Idiomatic — data classes, sealed classes, extension functions, `val`/`var`, non-null types
- **Dart**: Official Dart style guide, Equatable for entities, copyWith for immutability
- **Documentation**: KDoc for Kotlin, DartDoc for Dart
- **Language**: All code, comments, and documentation in English
- **UI Language**: Spanish for user-facing content (i18n)

### Architecture Principles

- SOLID throughout both projects
- Domain-Driven Design with 4 bounded contexts (backend)
- Clean Architecture with strict layer separation (both)
- Entity identity based on ID only (equals/hashCode override)
- Repository pattern: interface in domain, implementation in infrastructure/data
- Command objects for service input, Result<T> for output (backend)
- BLoC pattern for state management (frontend)

### Testing Strategy

**Backend** (71% coverage):
- Domain: Unit tests with JUnit 5 (ChordTransposer, Song entity)
- Application: Service tests with MockK
- API: Controller integration tests with MockMvc + SpringMockK
- Integration: End-to-end tests

**Frontend**:
- BLoCs: bloc_test + mocktail (SongBloc, SetlistBloc, CategoryBloc)
- Repositories: Unit tests with mocked Dio
- Core: AppLogger tests (8 tests, 100% coverage)
- Widgets: SongCard tag rendering tests
- Integration: Auth flow (11), Song CRUD (7), Setlist flow (10), Sync flow (8)
- Bugfix methodology: Bug Condition Exploration → Fix → Preservation Validation
