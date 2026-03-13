---
inclusion: auto
description: Complete technology stack, libraries, build tools, and common commands for backend and frontend
---

# WorshipHub Technology Stack

## Backend API (worship_hub_api)

### Core Technologies

- **Language**: Kotlin 2.1.0 with JVM target 21
- **Framework**: Spring Boot 3.3.5
- **Build Tool**: Gradle 8.x with Kotlin DSL
- **Database**: PostgreSQL (production), H2 (development/testing)
- **ORM**: Spring Data JPA with Hibernate
- **Migration**: Flyway for database versioning

### Key Libraries

- **Security**: Spring Security with JWT (jjwt 0.12.3), OAuth2 client support
- **API Documentation**: SpringDoc OpenAPI 2.6.0
- **WebSocket**: Spring WebSocket with STOMP protocol
- **Validation**: Spring Boot Starter Validation
- **JSON**: Jackson with Kotlin module
- **Connection Pool**: HikariCP
- **Cloud**: GCP Cloud SQL connector for production deployment

### Architecture Pattern

Clean Architecture with Domain-Driven Design (DDD):
- **api**: REST controllers, DTOs, security configuration
- **application**: Use cases and application services
- **domain**: Pure business logic, entities, domain services
- **infrastructure**: JPA repositories, external service implementations

### Common Commands

```bash
# Start local development with H2 database
./gradlew bootRun --args='--spring.profiles.active=local'

# Run with PostgreSQL (Neon profile)
./gradlew bootRun --args='--spring.profiles.active=neon'

# Build JAR
./gradlew bootJar

# Run tests
./gradlew test

# Run Flyway migrations
./gradlew flywayMigrate

# Build native image with GraalVM
./gradlew nativeCompile

# Start H2 console (development only)
# Access at http://localhost:8080/h2-console
```

### Environment Profiles

- **local**: H2 in-memory database for rapid development
- **h2**: H2 file-based database with console enabled
- **neon**: PostgreSQL cloud database (Neon)
- **prod**: Production configuration with externalized secrets
- **simple**: Minimal security for testing
- **oauth**: OAuth2 authentication enabled

### Security Configuration

- JWT-based authentication with secure token management
- 4-tier role system: SUPER_ADMIN, CHURCH_ADMIN, WORSHIP_LEADER, TEAM_MEMBER
- Method-level security with @PreAuthorize annotations
- Password policies with complexity requirements
- Token blacklisting for secure logout
- Rate limiting (100 requests/minute per IP)

## Frontend UI (worship_hub_ui)

### Core Technologies

- **Framework**: Flutter 3.x
- **Language**: Dart
- **State Management**: BLoC pattern with flutter_bloc
- **Local Database**: Drift (SQLite wrapper)
- **Dependency Injection**: GetIt
- **Routing**: go_router with custom transitions

### Key Libraries

- **Animations**: flutter_animate (primary), Lottie/Rive for complex animations
- **HTTP**: dio for API communication
- **WebSocket**: web_socket_channel for real-time features
- **Calendar**: table_calendar for scheduling
- **Haptics**: flutter_vibrate for tactile feedback

### Architecture Pattern

Clean Architecture with offline-first strategy:
- **domain**: Business entities and repository interfaces
- **data**: Repository implementations with cache-first strategy
- **presentation**: BLoC state management and UI components

### Common Commands

```bash
# Run the app
flutter run

# Build for production
flutter build apk --release
flutter build ios --release

# Run tests
flutter test

# Generate code (Drift, JSON serialization)
flutter pub run build_runner build

# Clean and get dependencies
flutter clean && flutter pub get
```

## Development Standards

### Code Style

- **Kotlin**: Idiomatic Kotlin with data classes, sealed classes, extension functions
- **Dart**: Follow official Dart style guide
- **Documentation**: KDoc for Kotlin, DartDoc for Dart
- **Language**: All code, comments, and documentation in English
- **UI Language**: Spanish for user-facing content

### Principles

- SOLID principles throughout
- Domain-Driven Design for backend
- Clean Architecture for both frontend and backend
- Security-first approach
- Performance optimization (60/120 FPS for animations)
- Comprehensive error handling with proper HTTP status codes

### Testing

- Unit tests for domain logic
- Integration tests for API endpoints
- Controller tests with MockMvc
- Repository tests with test containers
- Target: 70%+ code coverage
