---
inclusion: auto
description: Project organization, module structure, and folder conventions for multi-project repository
---

# WorshipHub Project Structure

## Repository Organization

Monorepo with git submodules for backend and frontend:

```
/
├── .kiro/               # Kiro config (specs, steering, hooks, skills)
├── worship_hub_api/     # Backend - Spring Boot + Kotlin (submodule)
├── worship_hub_ui/      # Frontend - Flutter (submodule)
└── skills-lock.json     # Kiro skills lock
```

Clone with: `git clone --recurse-submodules <repo-url>`

## Backend API Structure (worship_hub_api)

### Multi-Module Gradle Project (Clean Architecture + DDD)

```
worship_hub_api/
├── api/                 # API Layer (Controllers, DTOs, Security, WebSocket)
├── application/         # Application Layer (Use Cases, Services, Commands)
├── domain/              # Domain Layer (Entities, Business Logic, Events)
├── infrastructure/      # Infrastructure Layer (JPA Repos, External Services)
├── build.gradle.kts     # Root build config (Kotlin 2.1.0, Spring Boot 3.5.5)
├── settings.gradle.kts  # Module definitions
├── docker-compose.yml   # PostgreSQL + Mailpit
└── Dockerfile
```

### Module Dependencies (strict boundaries)

```
api → application → domain ← infrastructure
```

- **domain**: Zero dependencies — pure business logic, entities, domain services, repository interfaces
- **application**: Depends on domain only — orchestrates use cases
- **infrastructure**: Depends on domain — implements repository interfaces with JPA
- **api**: Depends on all — controllers, DTOs, security, config

### API Module (`api/`)

```
api/src/main/kotlin/com/worshiphub/
├── api/                      # REST Controllers organized by bounded context
│   ├── auth/                 # AuthController, OAuth2Controller
│   ├── organization/         # ChurchController, TeamController, UserController, InvitationController
│   ├── catalog/              # SongController, CategoryController, TagController
│   ├── scheduling/           # ServiceEventController, SetlistController, AvailabilityController
│   └── communication/        # NotificationController, ChatController
├── config/                   # Spring configs (WebSocket, CORS, OpenAPI)
├── security/                 # JwtTokenProvider, SecurityConfig, AuthInterceptor
└── WorshipHubApplication.kt

api/src/main/resources/
├── application.yml           # Base configuration
├── application-local.yml     # PostgreSQL local (port 5442)
├── application-h2.yml        # H2 in-memory
├── application-neon.yml      # Neon cloud PostgreSQL
├── application-prod.yml      # Production
└── db/migration/             # Flyway migrations (V1..V9)
```

### Domain Module (`domain/`) — 4 Bounded Contexts

```
domain/src/main/kotlin/com/worshiphub/domain/
├── organization/              # Church, User, Team, TeamMember, UserRole, TeamRole
│   └── repository/            # ChurchRepository, UserRepository, TeamRepository, TeamMemberRepository
├── catalog/                   # Song, Category, Tag, Attachment, AttachmentType, GlobalSong, ChordTransposer
│   └── repository/            # SongRepository, CategoryRepository, TagRepository, AttachmentRepository
├── scheduling/                # ServiceEvent, Setlist, AssignedMember, UserAvailability, ConfirmationStatus, ServiceEventStatus
│   └── repository/            # ServiceEventRepository, SetlistRepository, UserAvailabilityRepository
├── collaboration/             # Notification, NotificationType, ChatMessage, SongComment
│   └── repository/            # NotificationRepository, ChatMessageRepository, SongCommentRepository
└── shared/                    # Shared kernel
```

### Application Module (`application/`)

```
application/src/main/kotlin/com/worshiphub/application/
├── organization/
│   └── OrganizationApplicationService.kt   # Church registration, team CRUD, member assignment, invitations
├── catalog/
│   └── CatalogApplicationService.kt        # Song CRUD, search, filter, categories, tags, attachments, comments
├── scheduling/
│   └── SchedulingApplicationService.kt     # Service scheduling, setlist CRUD, availability, auto-generation
└── communication/
    └── CommunicationApplicationService.kt  # Notifications, chat
```

Each service uses Command objects (data classes) for input and returns `Result<T>` for error handling.

### Infrastructure Module (`infrastructure/`)

```
infrastructure/src/main/kotlin/com/worshiphub/infrastructure/
├── persistence/
│   ├── entity/                # JPA entity mappings (if separate from domain)
│   └── repository/            # Spring Data JPA repository implementations
├── email/                     # Email service (Mailpit for dev, SMTP for prod)
└── websocket/                 # WebSocket/STOMP configuration
```

## Frontend UI Structure (worship_hub_ui)

### Flutter Clean Architecture with Offline-First

```
worship_hub_ui/lib/
├── core/
│   ├── config/                # ApiConfig, AppConfig, Environment, EnvironmentConfig
│   ├── constants/             # MusicalKeys (key validation, popular keys)
│   ├── database/              # Drift database, type converters (TagListConverter, StringListConverter)
│   ├── dependency_injection/  # GetIt service locator setup
│   ├── error/                 # ApiException, ApiErrorParser, GlobalErrorHandler
│   ├── logging/               # AppLogger (debug/info/warning/error levels)
│   ├── network/               # Dio HTTP client setup
│   ├── router/                # go_router navigation config
│   ├── services/              # AuthInterceptor, ConnectivityService, L10nService, TokenService, WebSocketService
│   ├── storage/               # SecureStorageService (token expiration validation)
│   ├── sync/                  # ConflictResolver (lastWriteWins, keepLocal, keepRemote, userDecision)
│   ├── theme/                 # Material Design 3 themes (light/dark)
│   └── utils/                 # ChordProTransposer (semitone-based transposition)
│
├── data/
│   ├── datasources/
│   │   ├── local/             # Drift local database sources
│   │   └── remote/            # REST API data sources
│   ├── models/                # DTOs and data models
│   └── repositories/          # Repository implementations (cache-first with 5-min TTL)
│
├── domain/
│   ├── entities/              # User, Song, Setlist, ServiceEvent, Team, Invitation, Notification, ChatMessage
│   ├── repositories/          # Repository interfaces
│   └── usecases/              # LoginUser, RegisterChurch, GetAllSongs, TransposeSong, CreateSetlist, GenerateSetlist, TeamUseCases
│
├── presentation/
│   ├── features/
│   │   ├── auth/              # Login, register, Google Sign-In, email verification
│   │   ├── dashboard/         # Main dashboard with stats
│   │   ├── songs/             # Song catalog, ChordPro editor/renderer, transpose bar
│   │   ├── setlists/          # Setlist management with drag & drop
│   │   ├── calendar/          # Service calendar with table_calendar
│   │   ├── teams/             # Team management
│   │   ├── invitations/       # Invitation flow
│   │   ├── chat/              # Real-time WebSocket chat
│   │   ├── notifications/     # Push notifications
│   │   ├── profile/           # User profile, settings
│   │   ├── categories/        # Category/tag management
│   │   └── welcome/           # Onboarding
│   └── widgets/
│       ├── chord_pro/         # ChordProEditor, ChordProController, ChordProRenderer, TransposeBar
│       └── sync_status_indicator.dart  # Sync status chip (green synced / orange pending)
│
├── firebase_options.dart
└── main.dart
```

### Feature Module Pattern

Each feature follows domain/data/presentation separation:

```
feature_name/
├── domain/
│   ├── entities/          # Business entities (Equatable, copyWith)
│   ├── repositories/      # Repository interfaces
│   └── usecases/          # Business use cases
├── data/
│   ├── models/            # DTOs for serialization
│   ├── datasources/       # Remote (API) and Local (Drift) sources
│   └── repositories/      # Implementations with SyncableEntity support
└── presentation/
    ├── bloc/              # BLoC state management (flutter_bloc)
    ├── pages/             # Full screen pages
    └── widgets/           # Reusable UI components
```

## Testing Structure

### Backend Tests
```
api/src/test/kotlin/com/worshiphub/
├── controller/            # Controller integration tests (MockMvc, 12 files)
├── service/               # Service unit tests (MockK, 4 files)
├── integration/           # End-to-end tests (2 files)
domain/src/test/           # Domain logic tests (ChordTransposer, Song, 3 files)
```

### Frontend Tests
```
worship_hub_ui/test/
├── bugfix/                # Bug condition exploration + preservation tests
├── helpers/               # TestLogger, BlocFactory
├── fixtures/              # UserFixtures
├── unit/
│   ├── blocs/             # SongBloc, SetlistBloc, CategoryBloc tests
│   ├── core/logging/      # AppLogger tests (8 tests)
│   └── repositories/      # CategoryRepositoryImpl tests
├── widgets/               # SongCard tag rendering tests
└── integration/           # auth_flow (11), song_crud (7), setlist_flow (10), sync_flow (8) tests
```

## Database Migrations

Located in `worship_hub_api/api/src/main/resources/db/migration/`:
- Flyway naming: `V{version}__{description}.sql` (V1 through V9)
- Applied automatically on startup
- V8: Redesign categories/tags (join tables, indexes, FKs)
- V9: Error logs table

## Key Conventions

- **Language**: English for all code/comments/docs. Spanish for UI text (i18n with flutter_localizations)
- **Package Structure**: Group by bounded context / feature, not by layer
- **File Naming**: PascalCase for Kotlin classes, snake_case for Dart files
- **DTOs**: Separate Request/Response with clear naming (`CreateSongRequest`, `SongResponse`)
- **Entity Identity**: `equals()`/`hashCode()` based on ID only (DDD pattern)
- **Repositories**: Interface in domain, implementation in infrastructure (backend) or data (frontend)
- **Error Handling**: Backend returns `Result<T>`, frontend uses `ApiException` + `ApiErrorParser`
- **Immutability**: Kotlin `data class` with `copy()`, Dart entities with `copyWith()`
