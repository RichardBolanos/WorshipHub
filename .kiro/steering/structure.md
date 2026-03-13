---
inclusion: auto
description: Project organization, module structure, and folder conventions for multi-project repository
---

# WorshipHub Project Structure

## Repository Organization

This is a multi-project repository containing both backend API and frontend UI:

```
/
├── worship_hub_api/     # Backend Spring Boot API
└── worship_hub_ui/      # Frontend Flutter application
```

## Backend API Structure (worship_hub_api)

### Multi-Module Gradle Project

The backend follows Clean Architecture with strict module boundaries:

```
worship_hub_api/
├── api/                 # API Layer (Controllers, DTOs, Security)
├── application/         # Application Layer (Use Cases, Services)
├── domain/             # Domain Layer (Entities, Business Logic)
├── infrastructure/     # Infrastructure Layer (Repositories, External Services)
├── build.gradle.kts    # Root build configuration
└── settings.gradle.kts # Module definitions
```

### Module Dependencies

```
api → application → domain ← infrastructure
```

- **api**: Depends on application, domain, infrastructure
- **application**: Depends on domain only
- **domain**: No dependencies (pure business logic)
- **infrastructure**: Depends on domain (implements domain interfaces)

### API Module Structure

```
api/src/main/
├── kotlin/com/worshiphub/
│   ├── controller/          # REST controllers
│   │   ├── auth/           # Authentication endpoints
│   │   ├── organization/   # Church, user, team management
│   │   ├── catalog/        # Song, category, tag endpoints
│   │   ├── scheduling/     # Service, setlist, availability
│   │   └── communication/  # Notifications, chat
│   ├── dto/                # Request/Response DTOs
│   ├── security/           # JWT, OAuth2, security config
│   ├── config/             # Spring configuration
│   └── WorshipHubApplication.kt
└── resources/
    ├── application.yml              # Base configuration
    ├── application-{profile}.yml    # Profile-specific configs
    └── db/migration/               # Flyway SQL migrations
```

### Domain Module Structure

```
domain/src/main/kotlin/com/worshiphub/domain/
├── organization/       # Organization bounded context
│   ├── Church.kt
│   ├── User.kt
│   ├── Team.kt
│   └── TeamMember.kt
├── catalog/           # Catalog bounded context
│   ├── Song.kt
│   ├── Category.kt
│   ├── Tag.kt
│   ├── Attachment.kt
│   └── ChordTransposer.kt
├── scheduling/        # Scheduling bounded context
│   ├── ServiceEvent.kt
│   ├── Setlist.kt
│   ├── AssignedMember.kt
│   └── UserAvailability.kt
└── communication/     # Communication bounded context
    ├── Notification.kt
    └── ChatMessage.kt
```

### Application Module Structure

```
application/src/main/kotlin/com/worshiphub/application/
├── organization/
│   └── OrganizationApplicationService.kt
├── catalog/
│   └── CatalogApplicationService.kt
├── scheduling/
│   └── SchedulingApplicationService.kt
└── communication/
    └── CommunicationApplicationService.kt
```

### Infrastructure Module Structure

```
infrastructure/src/main/kotlin/com/worshiphub/infrastructure/
├── persistence/
│   ├── entity/        # JPA entities
│   └── repository/    # Spring Data JPA repositories
├── email/            # Email service implementation
└── websocket/        # WebSocket configuration
```

## Frontend UI Structure (worship_hub_ui)

### Flutter Clean Architecture

```
worship_hub_ui/lib/
├── core/
│   ├── config/        # App configuration, constants
│   ├── theme/         # Theme data, colors, typography
│   ├── utils/         # Utility functions, helpers
│   └── di/            # Dependency injection setup (GetIt)
├── features/
│   ├── auth/
│   │   ├── domain/    # Entities, repository interfaces
│   │   ├── data/      # Repository implementations, DTOs
│   │   └── presentation/  # BLoC, pages, widgets
│   ├── songs/
│   │   ├── domain/
│   │   ├── data/
│   │   └── presentation/
│   ├── setlists/
│   │   ├── domain/
│   │   ├── data/
│   │   └── presentation/
│   ├── calendar/
│   │   ├── domain/
│   │   ├── data/
│   │   └── presentation/
│   ├── notifications/
│   │   ├── domain/
│   │   ├── data/
│   │   └── presentation/
│   ├── teams/
│   │   ├── domain/
│   │   ├── data/
│   │   └── presentation/
│   └── chat/
│       ├── domain/
│       ├── data/
│       └── presentation/
└── main.dart
```

### Feature Module Pattern

Each feature follows the same structure:

```
feature_name/
├── domain/
│   ├── entities/          # Business entities
│   ├── repositories/      # Repository interfaces
│   └── usecases/         # Business use cases
├── data/
│   ├── models/           # DTOs and data models
│   ├── datasources/      # API and local data sources
│   └── repositories/     # Repository implementations
└── presentation/
    ├── bloc/             # BLoC state management
    ├── pages/            # Full screen pages
    └── widgets/          # Reusable UI components
```

## Configuration Files

### Backend Configuration

- **application.yml**: Base Spring Boot configuration
- **application-local.yml**: H2 development database
- **application-prod.yml**: Production PostgreSQL
- **build.gradle.kts**: Gradle build configuration with Kotlin DSL

### Frontend Configuration

- **pubspec.yaml**: Flutter dependencies and assets
- **api.json**: API contract definition (source of truth)
- **analysis_options.yaml**: Dart linter configuration

## Database Migrations

Located in `worship_hub_api/api/src/main/resources/db/migration/`:

- Versioned SQL files following Flyway naming convention
- Format: `V{version}__{description}.sql`
- Applied automatically on application startup

## Testing Structure

### Backend Tests

```
api/src/test/kotlin/com/worshiphub/
├── controller/        # Controller integration tests
├── service/          # Service unit tests
└── integration/      # End-to-end tests
```

### Frontend Tests

```
worship_hub_ui/test/
├── features/
│   └── {feature}/
│       ├── domain/    # Use case tests
│       ├── data/      # Repository tests
│       └── presentation/  # BLoC tests
└── widget_test.dart
```

## Key Conventions

- **Naming**: English for all code, Spanish for UI text
- **Package Structure**: Group by feature/bounded context, not by layer
- **File Naming**: PascalCase for classes, snake_case for files (Dart), camelCase for Kotlin files
- **DTOs**: Separate Request/Response DTOs with clear naming (e.g., `CreateSongRequest`, `SongResponse`)
- **Entities**: Pure domain models without framework dependencies in domain layer
- **Repositories**: Interface in domain, implementation in infrastructure/data
