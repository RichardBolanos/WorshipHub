# Requirements Document

## Introduction

This feature enables users to import song data (title, artist, lyrics, chords) from external websites (lacuerda.net and cifraclub.com) during the song creation flow. The backend scrapes the provided URL, extracts structured song information, and returns it to the frontend so the user can review and edit before persisting the song.

## Glossary

- **Song_Import_Service**: Backend service responsible for fetching a URL, parsing its HTML content, and extracting structured song data (title, artist, lyrics, chords).
- **URL_Validator**: Component that validates whether a provided URL belongs to a supported source (lacuerda.net or cifraclub.com).
- **Song_Parser**: Component that parses HTML from a specific supported source and extracts song fields.
- **Import_Preview**: Frontend screen that displays the extracted song data for user review and editing before song creation.
- **ChordPro_Converter**: Component that converts extracted chord/lyric data into ChordPro format compatible with the existing Song entity.
- **Supported_Source**: An external website from which song import is allowed. Currently: lacuerda.net and www.cifraclub.com.

## Requirements

### Requirement 1: URL Validation

**User Story:** As a worship leader, I want the system to validate that the URL I provide belongs to a supported source, so that I only attempt imports from sites that can be parsed correctly.

#### Acceptance Criteria

1. WHEN a user submits a URL for import, THE URL_Validator SHALL trim leading and trailing whitespace from the input, then verify that the URL domain matches a Supported_Source (lacuerda.net or www.cifraclub.com), accepting URLs up to 2048 characters in length.
2. IF the URL domain does not match any Supported_Source, THEN THE URL_Validator SHALL return an error indicating the source is not supported, distinct from the invalid-format error.
3. IF the URL is empty, exceeds 2048 characters, uses a scheme other than HTTP or HTTPS, or cannot be parsed as a valid URL structure, THEN THE URL_Validator SHALL return an error indicating the URL format is invalid. Length validation applies to all URLs including empty ones, and URLs with a supported domain that pass all format checks SHALL always result in a SUCCESS validation outcome.
4. THE URL_Validator SHALL accept URLs with or without the "www." prefix for both lacuerda.net and cifraclub.com (e.g., "lacuerda.net", "www.lacuerda.net", "cifraclub.com", "www.cifraclub.com" are all valid).
5. THE URL_Validator SHALL accept both HTTP and HTTPS URL schemes and SHALL reject any other scheme (ftp, file, etc.) as invalid format.
6. THE URL_Validator SHALL accept URLs containing path segments, query parameters, and fragment identifiers only if all other format validation requirements are met (non-empty, within length limit, valid scheme, parseable structure).

### Requirement 2: Song Data Extraction from LaCuerda.net

**User Story:** As a worship leader, I want to import songs from lacuerda.net, so that I can quickly add songs with chords to my church catalog without manual transcription.

#### Acceptance Criteria

1. WHEN a valid lacuerda.net song URL is provided, THE Song_Parser SHALL extract the song title from the page as a trimmed, non-empty string of at most 500 characters.
2. WHEN a valid lacuerda.net song URL is provided, THE Song_Parser SHALL extract the artist name from the page as a trimmed string of at most 500 characters.
3. WHEN a valid lacuerda.net song URL is provided, THE Song_Parser SHALL extract the lyrics with chord annotations positioned above corresponding lyric lines, preserving chord-to-syllable alignment.
4. IF the lacuerda.net page does not contain an extractable song title OR does not contain extractable lyrics, THEN THE Song_Parser SHALL return an error indicating extraction failed. Both title and lyrics are required for a successful extraction.
5. IF the lacuerda.net page returns an HTTP error status (4xx or 5xx), THEN THE Song_Import_Service SHALL return an error indicating the page is unavailable.
6. IF the artist name is not found on the lacuerda.net page but title and lyrics are extractable, THEN THE Song_Parser SHALL return the extracted data with an empty artist field.
7. WHEN a valid lacuerda.net song URL is provided, THE Song_Parser SHALL complete the extraction within 10 seconds or return a timeout error.

### Requirement 3: Song Data Extraction from CifraClub

**User Story:** As a worship leader, I want to import songs from cifraclub.com, so that I can access a wide catalog of songs with chords in Portuguese and Spanish.

#### Acceptance Criteria

1. WHEN a valid www.cifraclub.com song URL is provided, THE Song_Parser SHALL extract the song title from the page as a non-empty trimmed string with a maximum length of 200 characters.
2. WHEN a valid www.cifraclub.com song URL is provided, THE Song_Parser SHALL extract the artist name from the page as a non-empty trimmed string with a maximum length of 200 characters.
3. WHEN a valid www.cifraclub.com song URL is provided, THE Song_Parser SHALL extract the lyrics with chord annotations positioned above or inline with the corresponding lyric lines from the page. Lyrics extraction SHALL succeed independently of title and artist extraction, as it is treated as a separate operation.
4. WHEN a valid www.cifraclub.com song URL is provided and a musical key is present on the page, THE Song_Parser SHALL extract the musical key as a standard notation value (e.g., "C", "Am", "F#m").
5. WHEN a valid www.cifraclub.com song URL is provided and no musical key is present on the page, THE Song_Parser SHALL return a null value for the key field without treating it as an error.
6. IF the cifraclub.com page does not contain an extractable song structure (e.g., the URL points to an artist page, search results, or a page with no extractable content), THEN THE Song_Parser SHALL return an error indicating extraction failed. Partial success states (e.g., title found but lyrics not extractable) SHALL be reported with detailed error information indicating which fields were extracted and which failed.
7. IF the cifraclub.com page returns an HTTP error status (4xx or 5xx), THEN THE Song_Import_Service SHALL return an error indicating the page is unavailable.
8. IF the extracted title or artist is empty after trimming, THEN THE Song_Parser SHALL return an error indicating extraction failed.

### Requirement 4: ChordPro Format Conversion

**User Story:** As a worship leader, I want imported chord data converted to ChordPro format, so that it integrates seamlessly with the existing chord rendering and transposition features.

#### Acceptance Criteria

1. WHEN lyrics with chord annotations are extracted, THE ChordPro_Converter SHALL convert them into valid ChordPro format by inserting each chord in square brackets at the character position within the lyric line that corresponds to the chord's column offset in the source text.
2. IF a chord's column offset in the source text exceeds the length of its corresponding lyric line, THEN THE ChordPro_Converter SHALL append the chord in square brackets at the end of that lyric line.
3. THE ChordPro_Converter SHALL preserve section markers (verse, chorus, bridge, intro, outro) as ChordPro directives in the format `{comment: <SectionName>}` when detected in the extracted data.
4. IF extracted data contains chords without associated lyrics, THEN THE ChordPro_Converter SHALL output those chords as a standalone line with each chord wrapped in square brackets separated by spaces.
5. IF the extracted data contains no recognizable chord tokens (matching the pattern root note + optional quality, e.g., Am, G7, F#m), THEN THE ChordPro_Converter SHALL return the lyrics without chord annotations rather than producing invalid ChordPro output.
6. WHEN a valid chord-lyric pair is converted to ChordPro format and then rendered by stripping brackets, THE ChordPro_Converter output SHALL reproduce chord placement within a tolerance of plus or minus one character position relative to the original source alignment.

### Requirement 5: Import API Endpoint

**User Story:** As a frontend developer, I want a backend endpoint that accepts a URL and returns structured song data, so that the import flow can be integrated into the song creation screen.

#### Acceptance Criteria

1. THE Song_Import_Service SHALL expose a POST endpoint at `/api/v1/songs/import-from-url` that accepts a JSON body with a `url` field of maximum 2048 characters.
2. WHEN a valid supported URL is provided, THE Song_Import_Service SHALL return an HTTP 200 response containing a JSON object with fields: title, artist, key (null if not available on source page), lyrics, and chords in ChordPro format.
3. THE Song_Import_Service SHALL require authentication (valid JWT token) to access the import endpoint.
4. THE Song_Import_Service SHALL require WORSHIP_LEADER or CHURCH_ADMIN role to access the import endpoint.
5. WHEN the import process takes longer than 15 seconds, THE Song_Import_Service SHALL abort the request and return an HTTP 504 response with an error message indicating a timeout occurred.
6. IF the response body from the external source exceeds 5 MB, THEN THE Song_Import_Service SHALL immediately abort processing and return an HTTP 413 response with an error message indicating the payload is too large, regardless of how far the request has progressed.
7. IF the request body is missing the `url` field, or the `url` field is empty or exceeds 2048 characters, THEN THE Song_Import_Service SHALL return an HTTP 400 response with an error message indicating the validation failure.
8. IF the provided URL belongs to an unsupported source, THEN THE Song_Import_Service SHALL return an HTTP 422 response with an error message indicating the source is not supported.

### Requirement 6: Frontend Import Flow

**User Story:** As a worship leader, I want to paste a URL during song creation and preview the imported data before saving, so that I can review and correct any extraction errors.

#### Acceptance Criteria

1. WHEN the user is on the song creation screen, THE Import_Preview SHALL provide an option to import from a URL.
2. WHEN the user submits a URL for import, THE Import_Preview SHALL display a loading indicator while the backend processes the request, and SHALL disable the import action until the response is received or the request times out.
3. WHEN the backend returns extracted song data, THE Import_Preview SHALL populate the song creation form fields (title, artist, key, lyrics, chords) with the imported data, overwriting any previously entered values in those fields, and SHALL leave fields empty if the corresponding data is not present in the response.
4. THE Import_Preview SHALL allow the user to edit all populated fields before saving the song, including when the backend returns data alongside an error response.
5. IF the backend returns an error, THEN THE Import_Preview SHALL display an error message indicating the type of failure (unsupported source, network error, timeout, or extraction failed) so the user understands what went wrong.
6. IF the import request fails, THEN THE Import_Preview SHALL retain any data the user had already entered in the form prior to the import attempt.
7. IF the user submits an empty or whitespace-only URL, THEN THE Import_Preview SHALL display a validation error indicating a URL is required, without calling the backend.
8. IF the user submits a malformed URL (not parseable as valid URL structure), THEN THE Import_Preview SHALL display a validation error indicating the URL format is invalid, without calling the backend.

### Requirement 7: Error Handling and Resilience

**User Story:** As a worship leader, I want clear feedback when an import fails, so that I understand what went wrong and can try an alternative approach.

#### Acceptance Criteria

1. IF the external source is unreachable due to network issues, THEN THE Song_Import_Service SHALL return an error indicating a connection failure without retrying the request.
2. IF the external source returns an unexpected HTML structure that cannot be parsed, THEN THE Song_Import_Service SHALL return an error indicating the page format has changed.
3. IF the Song_Parser extracts partial song data (e.g., title is found but lyrics cannot be extracted), THEN THE Song_Import_Service SHALL return an error indicating extraction was incomplete rather than returning partial results.
4. THE Song_Import_Service SHALL log all import attempts including: URL, detected source, outcome (success or failure with error category), and duration in milliseconds.
5. THE Song_Import_Service SHALL sanitize extracted text content by removing all HTML tags, script elements, style elements, event handler attributes, and encoded HTML entities before returning it.
6. IF the sanitized content still contains any HTML tag patterns (e.g., angle-bracket sequences matching tag syntax), THEN THE Song_Import_Service SHALL strip them and return only plain text with ChordPro annotations preserved.

### Requirement 8: Outbound HTTP Security

**User Story:** As a system administrator, I want the outbound HTTP requests to external sources to follow security best practices, so that the server is protected against SSRF attacks, credential leaks, and abuse.

#### Acceptance Criteria

1. WHEN the Song_Import_Service resolves the target URL's hostname, THE service SHALL verify that the resolved IP address is not in a private or reserved range (127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16, ::1, fc00::/7) and SHALL reject the request with an error if it resolves to a private IP.
2. WHEN the external source responds with an HTTP redirect (3xx), THE Song_Import_Service SHALL follow a maximum of 3 redirects and SHALL verify that each redirect target remains within the allowed Supported_Source domains (lacuerda.net or www.cifraclub.com). IF a redirect points to a non-supported domain, THEN the request SHALL be aborted with an error.
3. THE Song_Import_Service SHALL enforce TLS certificate validation on all HTTPS requests to external sources, rejecting connections with invalid, expired, or self-signed certificates.
4. THE Song_Import_Service SHALL send a descriptive User-Agent header (e.g., "WorshipHub/1.0 SongImporter") on all outbound requests to identify the service to external platforms.
5. THE Song_Import_Service SHALL enforce a rate limit of 10 import requests per user per minute. IF the limit is exceeded, THEN the service SHALL return an HTTP 429 response with a Retry-After header indicating when the user can retry.
6. THE Song_Import_Service SHALL NOT send cookies, authentication tokens, or any internal credentials in outbound requests to external sources.
7. THE Song_Import_Service SHALL NOT follow redirects that change the protocol from HTTPS to HTTP (protocol downgrade).
