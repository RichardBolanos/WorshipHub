# Implementation Plan: Song Import from URL

## Overview

Implement song data import from external URLs (lacuerda.net, cifraclub.com) into the WorshipHub catalog. Backend: Kotlin/Spring Boot with URL validation, HTML scraping (Jsoup), ChordPro conversion, and a REST endpoint. Frontend: Flutter BLoC + Dio integration in the song creation flow. Incremental build — domain first, then infrastructure, application service, API layer, and finally frontend integration.

## Tasks

- [x] 1. Backend domain layer — value objects, enums, interfaces
  - [x] 1.1 Create `SupportedSource` enum, `RawSongData`, `LyricLine`, `ChordPosition`, `ImportedSongData` value objects, and `SongParser` interface in `domain/catalog`
    - File: `domain/src/main/kotlin/com/worshiphub/domain/catalog/songimport/`
    - Define `SupportedSource` enum with domain lists and `fromDomain()` companion
    - Define `RawSongData`, `LyricLine`, `ChordPosition` data classes
    - Define `ImportedSongData` data class (title, artist?, key?, lyrics, chords)
    - Define `SongParser` interface with `parse(html: String, url: URI): RawSongData`
    - Define `SongImportException` sealed class hierarchy (InvalidUrlFormat, UnsupportedSource, PageUnavailable, ConnectionFailed, ImportTimeout, PayloadTooLarge, ExtractionFailed, FormatChanged)
    - _Requirements: 1.1, 1.2, 1.3, 2.1–2.4, 3.1–3.6, 7.2, 7.3_

  - [x] 1.2 Implement `UrlValidator` object in domain layer
    - Trim whitespace, check length ≤ 2048, parse URI, verify scheme ∈ {http, https}, match domain against `SupportedSource`
    - Return `Result<Pair<URI, SupportedSource>>` with discriminated errors (InvalidUrlFormat vs UnsupportedSource)
    - Accept www/non-www variants, paths, query params, fragments
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6_

  - [x] 1.3 Implement `ChordProConverter` object in domain layer
    - Insert `[Chord]` at column offset; append at end if column > text length
    - Section markers → `{comment: SectionName}` directives
    - Chord-only lines (empty text) → `[Am] [G] [C]` format
    - No chord tokens detected → return plain lyrics
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

  - [x]* 1.4 Write property tests for `UrlValidator` (Properties 1 & 2)
    - **Property 1: URL validation accepts all valid supported URLs**
    - **Property 2: URL validation error type discrimination**
    - Use Kotest property testing with generated URL strings
    - **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 1.6**

  - [x]* 1.5 Write property tests for `ChordProConverter` (Properties 3, 4, 5, 6)
    - **Property 3: ChordPro conversion position accuracy**
    - **Property 4: Section markers become ChordPro directives**
    - **Property 5: Chord-only lines produce standalone bracketed output**
    - **Property 6: No chord tokens yields plain lyrics**
    - Use Kotest property testing with generated `LyricLine` instances
    - **Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 4.6**

  - [x]* 1.6 Write unit tests for `UrlValidator` and `ChordProConverter`
    - Edge cases: unicode URLs, IDN domains, empty input, max-length boundary
    - ChordPro edge cases: overlapping chords, multiple section markers, chord at position 0
    - _Requirements: 1.1–1.6, 4.1–4.6_

- [x] 2. Backend infrastructure — HTTP fetcher and HTML parsers
  - [x] 2.1 Implement `HttpPageFetcher` component using Spring `RestClient`
    - Configurable connect timeout (5s) and read timeout (10s)
    - Check Content-Length header; abort if > 5MB with `PayloadTooLarge` exception
    - Stream response with byte counter as fallback when no Content-Length
    - Map 4xx/5xx → `PageUnavailable`, network errors → `ConnectionFailed`, timeout → `ImportTimeout`
    - _Requirements: 5.5, 5.6, 7.1_

  - [x] 2.2 Implement `LaCuerdaSongParser` with Jsoup
    - Heuristic content-based extraction (not CSS-selector-dependent)
    - Title: `<h1>` → JS variable `orola` → `<title>` tag pattern
    - Artist: `<h2>` near `<h1>` → breadcrumb links → JS variable `oband` → `<title>` pattern
    - Lyrics: detect `<a>` tags (chord links) → `<b>` tags → plain text chords-above-lyrics in `<pre>`
    - Pair chord-only lines with next lyric line for `ChordPosition` mapping
    - Throw `ExtractionFailed` if title or lyrics missing
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

  - [x] 2.3 Implement `CifraClubSongParser` with Jsoup
    - Heuristic content-based extraction (not CSS-selector-dependent)
    - Title: `<title>` tag pattern → first `<h1>` → `og:title` meta; trim to 200 chars
    - Artist: `<title>` second segment → meta description → URL slug deslug; trim to 200 chars
    - Key: text scan "Tono"/"Tom" pattern + `data-anchor="--chord-tone"` button; null if absent
    - Lyrics: find ALL `<pre>`, pick largest with chord content; detect format (legacy `<b>` tags vs plain text chords-above-lyrics)
    - Filter noise lines ("Continúa después del anuncio", etc.), merge wrapped continuation lines
    - Throw `ExtractionFailed` if title, artist, or lyrics missing after trim
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8_

  - [x]* 2.4 Write unit tests for `LaCuerdaSongParser` and `CifraClubSongParser` with HTML fixtures
    - Create fixture files: `valid-song.html`, `song-no-artist.html`, `non-song-page.html` (LaCuerda)
    - Create fixture files: `valid-song-with-key.html`, `valid-song-no-key.html`, `artist-page.html` (CifraClub)
    - Verify extraction accuracy and error conditions
    - _Requirements: 2.1–2.7, 3.1–3.8_

  - [x]* 2.5 Write property test for partial extraction (Property 8)
    - **Property 8: Partial extraction never returns partial data**
    - Generate HTML structures with missing title/lyrics combinations
    - Verify `SongExtractionException` thrown, never partial `RawSongData`
    - **Validates: Requirements 7.3, 2.4, 3.6**

- [x] 3. Checkpoint — domain and infrastructure tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Backend application and API layers
  - [x] 4.1 Implement `SongImportApplicationService` in application layer
    - Orchestrate: validate URL → fetch HTML → parse → sanitize → convert ChordPro → return `ImportedSongData`
    - HTML sanitization: strip tags, script/style elements, event handlers, decode entities; preserve ChordPro brackets
    - Log import attempts with structured fields (url domain, source, outcome, duration, userId, churchId)
    - Overall timeout 15s wrapping entire pipeline
    - _Requirements: 5.2, 5.5, 7.3, 7.4, 7.5, 7.6_

  - [x]* 4.2 Write property test for HTML sanitization (Property 7)
    - **Property 7: HTML sanitization preserves only plain text and ChordPro**
    - Generate strings with HTML tags, script elements, encoded entities mixed with ChordPro annotations
    - Verify output has no HTML patterns but preserves `[chord]` brackets
    - **Validates: Requirements 7.5, 7.6**

  - [x]* 4.3 Write unit tests for `SongImportApplicationService`
    - Mock `HttpPageFetcher` and parsers
    - Test orchestration flow, error propagation, timeout handling, sanitization
    - _Requirements: 5.2, 5.5, 5.6, 7.1–7.6_

  - [x] 4.4 Implement `SongImportController` and exception handler in API layer
    - POST `/api/v1/songs/import-from-url` with `@PreAuthorize` for WORSHIP_LEADER/CHURCH_ADMIN
    - Request validation: `@NotBlank`, `@Size(max=2048)` on url field
    - Exception handler mapping `SongImportException` subtypes → HTTP status codes + error codes
    - `ImportFromUrlRequest` and `ImportedSongResponse` DTOs
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.7, 5.8_

  - [x]* 4.5 Write integration tests for `SongImportController` (MockMvc)
    - Test auth enforcement (401 without token, 403 wrong role)
    - Test request validation (400 for empty/too-long URL)
    - Test success response shape (200 with correct fields)
    - Test error response mapping (422, 502, 504, 413)
    - _Requirements: 5.1–5.8_

- [x] 5. Checkpoint — backend fully testable end-to-end
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Frontend — data layer and BLoC
  - [x] 6.1 Create `ImportedSongData` model and `SongImportRemoteDataSource` in frontend
    - `ImportedSongData` with `fromJson` factory (title, artist?, key?, lyrics, chords)
    - `SongImportRemoteDataSource` using Dio: POST to `/api/v1/songs/import-from-url`
    - Map Dio errors to typed `ApiException` via existing `ApiErrorParser`
    - _Requirements: 5.2, 6.2_

  - [x] 6.2 Create `SongImportBloc` with events and states
    - Event: `SongImportRequested(url)`
    - States: `SongImportInitial`, `SongImportLoading`, `SongImportSuccess(data)`, `SongImportFailure(errorType, message)`
    - Client-side validation: reject empty/whitespace-only URL without HTTP call
    - On success: emit `SongImportSuccess`; on error: emit `SongImportFailure` with mapped error type
    - _Requirements: 6.2, 6.5, 6.7_

  - [x]* 6.3 Write BLoC tests for `SongImportBloc`
    - Test all state transitions: loading → success, loading → failure
    - Test whitespace-only URL rejection (no HTTP call)
    - Test error type mapping from API exceptions
    - **Property 10: Whitespace-only URL rejected without backend call**
    - **Validates: Requirements 6.2, 6.5, 6.7**

- [x] 7. Frontend — UI integration in CreateSongPage
  - [x] 7.1 Add `ImportFromUrlButton` widget with URL text field in `CreateSongPage`
    - Collapsible section with URL text field + "Importar" button
    - Client-side: disable button + show `CircularProgressIndicator` during loading
    - On success: populate title, artist, key, chordPro controllers; overwrite existing values
    - On error: show localized error SnackBar mapped by `errorType`; retain pre-existing form data
    - On empty URL submission: show inline validation error without calling BLoC
    - Register `SongImportBloc` in get_it / provide via BlocProvider
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_

  - [x]* 7.2 Write widget tests for import UI
    - Verify import button visibility and interaction
    - Verify loading state (spinner visible, button disabled)
    - Verify form population on success (all fields filled)
    - Verify error message display per error type
    - Verify form data retained on failure
    - **Property 9: Form population maps all imported fields**
    - **Validates: Requirements 6.1–6.7**

- [x] 8. Final checkpoint — all backend and frontend tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- HTML fixture files enable deterministic parser testing without hitting external sites
- Backend uses Kotlin + Spring Boot; frontend uses Dart + Flutter (BLoC pattern)
- No new database tables needed — imported data flows into existing `Song` entity via `CreateSongCommand`

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "1.3"] },
    { "id": 2, "tasks": ["1.4", "1.5", "1.6", "2.1"] },
    { "id": 3, "tasks": ["2.2", "2.3"] },
    { "id": 4, "tasks": ["2.4", "2.5"] },
    { "id": 5, "tasks": ["4.1"] },
    { "id": 6, "tasks": ["4.2", "4.3", "4.4"] },
    { "id": 7, "tasks": ["4.5"] },
    { "id": 8, "tasks": ["6.1"] },
    { "id": 9, "tasks": ["6.2"] },
    { "id": 10, "tasks": ["6.3", "7.1"] },
    { "id": 11, "tasks": ["7.2"] }
  ]
}
```

## Post-Implementation Corrections

The following corrections were applied during or after implementation, deviating from the original task descriptions:

### Parser Architecture (Tasks 2.2, 2.3)

Both parsers were refactored from CSS-selector-based extraction to **heuristic content-based extraction**. The original selectors (`.t1`, `.t3`, `.cifra_cnt pre`, `.tone` for CifraClub; specific title/breadcrumb selectors for LaCuerda) proved unreliable across page variants and locales.

- **CifraClubSongParser**: Uses `<title>` tag pattern, `<h1>`, `og:title` for title; text scan for "Tono"/"Tom" for key; largest `<pre>` with chord detection for lyrics. Handles both legacy `<b>`-tag format and current plain-text chords-above-lyrics format. Filters noise lines and merges wrapped continuation lines.
- **LaCuerdaSongParser**: Uses `<h1>` → JS variable `orola` → `<title>` for title; `<h2>` → breadcrumbs → JS variable `oband` for artist. Detects `<a>` tags (real LaCuerda chord links) vs `<b>` tags vs plain text in `<pre>` blocks.

### SupportedSource Domain Expansion (Task 1.1)

Added subdomains not in original design:
- `acordes.lacuerda.net`, `chords.lacuerda.net`, `cifras.lacuerda.net`
- `cifraclub.com.br`, `www.cifraclub.com.br`

`fromDomain()` updated to use subdomain matching (`endsWith`) instead of exact match.

### Spring Configuration (Task 4.1)

Added `SongImportConfig.kt` in infrastructure layer to explicitly register `Map<SupportedSource, SongParser>` bean. Spring could not auto-wire this map by convention.

### ChordProConverter Bug Fix (Task 1.3)

Fixed `coerceAtMost(result.length)` → `coerceAtMost(line.text.length)`. Original code used the growing result string length as the upper bound for insertion index, causing bracket nesting when multiple chords had columns beyond text length.

### Frontend Corrections (Task 7.1)

1. **ChordProEditor `didUpdateWidget`**: Added override so `initialText` changes (post-import) update internal controller. Previously only read in `initState()`.
2. **Song Delete Button**: Added to `SongDetailPage` — red trash icon, confirmation dialog, `SongDeleteRequested` event, BlocListener for success/error, localization keys.
3. **Setlist Presentation Width**: `Align(topLeft)` → `SizedBox(width: double.infinity)`, padding 20→16px for maximum lyrics width.
4. **List Spacing**: Setlist list horizontal padding 16→20px to match app-wide standard (`EdgeInsets.fromLTRB(20, 12, 20, 96)`).
