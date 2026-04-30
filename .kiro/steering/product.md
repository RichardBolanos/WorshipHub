---
inclusion: auto
description: Overview of WorshipHub platform purpose, features, architecture, and user roles
---

# WorshipHub Product Overview

WorshipHub is a comprehensive worship team management platform designed for churches to streamline their worship ministry operations. The monorepo uses git submodules for both backend and frontend projects.

## Core Purpose

Enable churches to manage worship teams, organize song catalogs with chord transposition, plan services with intelligent setlist generation, facilitate real-time team communication, and track member availability — all with offline-first mobile support.

## Bounded Contexts (DDD)

### 1. Organization Context
Manages churches, users, teams, and invitations.
- Church registration with admin user
- Invitation system with secure tokens (7-day expiry)
- Team creation with specific musical roles (LEAD_VOCALIST, BACKING_VOCALIST, ACOUSTIC_GUITAR, ELECTRIC_GUITAR, BASS_GUITAR, DRUMS, KEYBOARD, SOUND_ENGINEER, WORSHIP_LEADER)
- User profiles with email verification (24h tokens) and password reset (1h tokens)

### 2. Catalog Context
Manages songs, categories, tags, attachments, and the global song repository.
- Songs with ChordPro format, transposition (sharps/flats, minor keys, chord suffixes preserved)
- Many-to-Many: Song ↔ Category, Song ↔ Tag (via join tables)
- Attachments: YOUTUBE_LINK, SPOTIFY_LINK, PDF_SHEET, AUDIO_FILE, OTHER_LINK
- Duplicate prevention: unique by title + artist + churchId
- Song comments for arrangement discussions
- Global catalog (SUPER_ADMIN managed, churches can import)

### 3. Scheduling Context
Manages service events, setlists, member assignments, and availability.
- ServiceEvent lifecycle: DRAFT → PUBLISHED → CONFIRMED → CANCELLED
- AssignedMember confirmation: PENDING → ACCEPTED / DECLINED
- Business rules: future dates only, no conflicts within 2 hours, availability check before assignment, minimum 3 confirmed members for readiness
- Setlists: ordered song list, max 90 min duration, add/remove/reorder songs
- Auto-generation of setlists based on rules (category-based)
- Duration calculation based on BPM (default 4 min/song)
- UserAvailability: date-based unavailability with optional reason

### 4. Collaboration Context
Manages notifications, chat messages, and song comments.
- Notification types: SERVICE_INVITATION, NEW_SONG, SONG_ADDED, NEW_COMMENT, TEAM_ASSIGNMENT, SERVICE_SCHEDULED
- Team chat via WebSocket (STOMP protocol) with message history
- Song comments for per-song discussions

## User Roles & Permissions

| Role | Permissions |
|------|------------|
| SUPER_ADMIN | Full system access, global catalog management |
| CHURCH_ADMIN | Church management, user invitations, team oversight |
| WORSHIP_LEADER | Team creation, setlist planning, service scheduling |
| TEAM_MEMBER | Song contributions, availability, service participation |

Authorization extension functions: `canManageChurch()`, `canManageTeams()`, `canScheduleServices()`, `canManageGlobalCatalog()`

## Key Domain Entities

- **Church**: id, name, address, email (unique)
- **User**: id, email (unique), firstName, lastName, passwordHash?, churchId, role, isActive, isEmailVerified
- **Team**: id, name, description?, churchId, leaderId
- **TeamMember**: id, teamId, userId, teamRole (enum), joinedAt
- **Song**: id, title, artist?, key?, bpm?, chords? (ChordPro TEXT), lyrics? (TEXT), duration?, categories (Set), tags (Set), attachments (List), churchId
- **Category**: id, name, description?, churchId
- **Tag**: id, name, color? (hex 7 chars), churchId
- **Attachment**: id, songId, name, url, type (enum), createdAt
- **ServiceEvent**: id, name, scheduledDate, teamId, setlistId?, assignedMembers (List), status (enum), churchId
- **AssignedMember**: id, serviceEventId, userId, role (String), confirmationStatus (enum), assignedAt, respondedAt?
- **Setlist**: id, name, description?, songIds (ordered List<UUID>), estimatedDuration?, eventDate?, churchId
- **UserAvailability**: id, userId, unavailableDate (LocalDate), reason?
- **Notification**: id, userId, title, message, type (enum), isRead
- **ChatMessage**: id, teamId, userId, content (max 1000 chars)
- **SongComment**: id, songId, userId, content (TEXT)

## Security

- JWT authentication with refresh tokens (1h access, 24h refresh)
- BCrypt password hashing with complexity requirements (min 8 chars, upper+lower+numbers)
- Token blacklisting for secure logout
- Rate limiting: 100 req/min per IP
- Security headers: CSP, X-Frame-Options: DENY, X-Content-Type-Options: nosniff, HSTS
- Email verification and password reset with secure tokens
- Method-level authorization with @PreAuthorize

## Frontend Offline-First Strategy

- Local SQLite database via Drift with SyncableEntity interface (serverId, isSynced, lastSyncAt, updatedAt)
- Cache invalidation: 5-minute TTL per entity type
- Connectivity states: online, offline, apiUnreachable (health check every 30s)
- Conflict resolution strategies: lastWriteWins (default), keepLocal, keepRemote, userDecision
- Exponential backoff for sync retries (1s, 2s, 4s, 8s, 16s, max 60s, 5 attempts)
- Push-first sync order (local changes pushed before pulling remote)

## API Endpoints (60+)

Base path: `/api/v1`
- Auth: login, register, church/register, logout, refresh, verify-email, forgot-password, reset-password
- Churches: CRUD
- Teams: CRUD + members management
- Songs: CRUD + search + attachments + comments
- Setlists: CRUD + generate + add/remove/reorder songs
- Services: CRUD + assignment confirmation
- Invitations: send, get details, accept
- Notifications: list, mark read, delete
- Chat: WebSocket /ws/chat + REST messages/history
- Health: /health, /system/info, /actuator/health

## Current Status

Production-ready. Backend: 60+ REST endpoints, 71% test coverage, 9 Flyway migrations. Frontend: 82 architectural issues resolved, comprehensive BLoC/repository/integration tests, 3 environment configs (dev/staging/prod).
