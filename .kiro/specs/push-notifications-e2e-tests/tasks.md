# Implementation Plan: Push Notifications E2E Tests

## Overview

This plan implements a comprehensive Patrol E2E test suite for the push notifications system. The implementation follows an incremental approach: first building the shared infrastructure (seed helper, mock service, TestEnvironment extension), then implementing test files grouped by complexity — starting with infrastructure validation tests, then core interaction tests, and finally per-notification-type tests.

All tests run against the real backend (localhost:9090 with H2 in-memory) and follow existing Patrol conventions (no pumpAndSettle, unique test data, AppLocalizations for UI text, try/finally with tearDown).

## Tasks

- [x] 1. Create MockPushNotificationService
  - [x] 1.1 Create `integration_test/mocks/mock_push_notification_service.dart`
    - Implement `PushNotificationService` interface as a no-op mock
    - Provide a static `mockToken` constant for simulated FCM token
    - Track `tokenRegistered` and `tokenUnregistered` boolean flags
    - Implement `simulateForegroundMessage()` method with a StreamController for foreground notifications
    - Implement `initialize()`, `unregisterToken()`, `currentToken`, `isInitialized` getters
    - _Requirements: 1.4, 7.4, 22.3_

- [x] 2. Create NotificationSeed helper
  - [x] 2.1 Create `integration_test/seed/notification_seed.dart`
    - Accept `ApiSeedHelper` in constructor (same pattern as AuthSeed, SongSeed, etc.)
    - Implement `seedServiceAssignmentNotification()` — creates a service with member assignments to trigger SERVICE_INVITATION
    - Implement `seedChatMessageNotification()` — sends a chat message as another user to trigger CHAT_MESSAGE
    - Implement `seedUnreadNotifications()` — creates N notifications via domain actions
    - Implement `getNotifications()` — GET `/api/v1/notifications` for current user
    - Implement `markAsRead(notificationId)` — PUT to mark single notification as read
    - Implement `markAllAsRead()` — PUT to mark all notifications as read
    - Implement `getNotificationPreferences()` — GET notification preferences
    - Implement `updateNotificationPreferences()` — PUT notification preferences
    - _Requirements: 2.1, 3.4, 9.1, 10.1, 22.3_

  - [x] 2.2 Extend `ApiSeedHelper` with notification-related API methods
    - Add `registerSecondUser()` — register a second user (member) in the same church via invitation flow
    - Add `loginAs()` — login as a specific user and store their token (for multi-user tests)
    - Add `createSongComment()` — POST comment on a song (triggers NEW_COMMENT)
    - Add `addTeamMember()` — POST add member to team (triggers TEAM_ASSIGNMENT)
    - Add `cancelService()` — PUT cancel a service (triggers SERVICE_CANCELLED)
    - Add `updateSong()` — PUT update a song (triggers SONG_UPDATED)
    - Add `addSongAttachment()` — POST attachment to a song (triggers SONG_ATTACHMENT)
    - _Requirements: 11.1, 12.1, 13.1, 15.1, 19.1_

- [x] 3. Integrate infrastructure into TestEnvironment and test_app
  - [x] 3.1 Register `MockPushNotificationService` in `test_app.dart`
    - Add import for `MockPushNotificationService`
    - Register as singleton in `initializeTestDependencies()` replacing the real `PushNotificationService`
    - _Requirements: 1.4, 7.4_

  - [x] 3.2 Add `NotificationSeed` to `TestEnvironment` in `patrol_base.dart`
    - Add `notificationSeed` field to `TestEnvironment`
    - Instantiate `NotificationSeed(seedHelper)` in `setup()` method
    - _Requirements: 22.3, 22.4_

- [x] 4. Checkpoint — Ensure infrastructure compiles
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Implement FCM token registration test
  - [x] 5.1 Create `integration_test/tests/push_notifications/fcm_token_registration_test.dart`
    - Test: login triggers POST to `/api/v1/devices/token` with mock FCM token
    - Test: logout triggers DELETE to `/api/v1/devices/token`
    - Test: verify MockPushNotificationService flags are set correctly
    - Use patrolTest pattern with TestEnvironment setup/tearDown
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 6. Implement notifications screen test
  - [x] 6.1 Create `integration_test/tests/push_notifications/notifications_screen_test.dart`
    - Test: after seeding notifications via domain actions, navigate to notifications screen and verify real data is displayed (title, message, type icon, read/unread indicator, timestamp)
    - Test: empty state when no notifications exist (icon + informative message)
    - Test: notifications are ordered by date descending (most recent first)
    - Test: each notification shows the correct icon for its type
    - Use AppLocalizations for all UI text assertions
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

- [x] 7. Implement mark as read test
  - [x] 7.1 Create `integration_test/tests/push_notifications/mark_as_read_test.dart`
    - Seed at least 3 unread notifications via NotificationSeed before assertions
    - Test: tap unread notification changes visual indicator to read and decrements unread count
    - Test: tap "Mark all as read" changes all to read, count goes to zero, button disappears
    - Test: mark as read persists after navigating away and back (backend persistence)
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [x] 8. Implement deep linking test
  - [x] 8.1 Create `integration_test/tests/push_notifications/deep_linking_test.dart`
    - Test: tap SERVICE_INVITATION notification navigates to service detail screen
    - Test: tap CHAT_MESSAGE notification navigates to team chat screen
    - Test: tap NEW_COMMENT notification navigates to song detail screen
    - Test: tap TEAM_ASSIGNMENT notification navigates to team detail screen
    - Test: tap NEW_SONG notification navigates to song detail screen
    - Test: notification is automatically marked as read after deep link navigation
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

- [x] 9. Implement notification preferences test
  - [x] 9.1 Create `integration_test/tests/push_notifications/notification_preferences_test.dart`
    - Test: Admin user sees all notification type toggles
    - Test: Member user sees only member-applicable toggles (admin-exclusive types hidden)
    - Test: Team Leader user sees leader-applicable toggles (admin-exclusive hidden)
    - Test: disabling a toggle persists after navigating away and back
    - Create users with specific roles via ApiSeedHelper for each scenario
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 10. Checkpoint — Ensure core tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 11. Implement chat polling test
  - [x] 11.1 Create `integration_test/tests/push_notifications/chat_polling_test.dart`
    - Test: send a chat message and verify it appears after polling cycle
    - Test: message sent by another user (seeded via API) appears within polling interval (max 10s)
    - Test: WebSocket is not used (no-op service in tests)
    - Test: messages display in chronological order with sender name and timestamp
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [x] 12. Implement in-app banner test
  - [x] 12.1 Create `integration_test/tests/push_notifications/in_app_banner_test.dart`
    - Test: simulating foreground notification via MockPushNotificationService shows banner with title and message
    - Test: tapping banner navigates to relevant screen (deep link)
    - Test: banner auto-hides after timeout if not interacted with
    - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [x] 13. Implement badge count test
  - [x] 13.1 Create `integration_test/tests/push_notifications/badge_count_test.dart`
    - Test: badge shows correct unread count after seeding notifications
    - Test: marking one notification as read decrements badge
    - Test: marking all as read makes badge disappear or show zero
    - Test: no unread notifications means no badge displayed
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

- [x] 14. Implement service assignment notification test
  - [x] 14.1 Create `integration_test/tests/push_notifications/service_assignment_notification_test.dart`
    - Test: creating a service with assigned members generates SERVICE_INVITATION notification for each member
    - Test: notification includes service name, scheduled date, and assigned role
    - Test: service creator does not receive the notification (sender exclusion)
    - Uses two users: admin creates service, member receives notification
    - _Requirements: 9.1, 9.2, 9.3_

- [x] 15. Implement chat message notification test
  - [x] 15.1 Create `integration_test/tests/push_notifications/chat_message_notification_test.dart`
    - Test: chat message from another user generates CHAT_MESSAGE notification
    - Test: notification includes sender name, team name, and message excerpt
    - Test: message sender does not receive notification of their own message
    - _Requirements: 10.1, 10.2, 10.3_

- [x] 16. Implement song comment notification test
  - [x] 16.1 Create `integration_test/tests/push_notifications/song_comment_notification_test.dart`
    - Test: comment on a song generates NEW_COMMENT notification for song creator
    - Test: notification includes commenter name, song title, and comment excerpt
    - Test: comment author does not receive notification of their own comment
    - _Requirements: 11.1, 11.2, 11.3_

- [x] 17. Implement team change notification test
  - [x] 17.1 Create `integration_test/tests/push_notifications/team_change_notification_test.dart`
    - Test: adding a new member to a team generates TEAM_ASSIGNMENT notification for existing members
    - Test: notification includes team name and description of change
    - Test: user who made the change does not receive the notification
    - _Requirements: 12.1, 12.2, 12.3_

- [x] 18. Checkpoint — Ensure notification type tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 19. Implement service cancellation notification test
  - [x] 19.1 Create `integration_test/tests/push_notifications/service_cancellation_notification_test.dart`
    - Test: cancelling a service generates notification for assigned members with service name and original date
    - Test: notification includes cancellation reason if provided
    - Test: user who cancelled does not receive the notification
    - _Requirements: 13.1, 13.2, 13.3_

- [x] 20. Implement recurring service notification test
  - [x] 20.1 Create `integration_test/tests/push_notifications/recurring_service_notification_test.dart`
    - Test: creating a recurring service generates consolidated notification for each assigned member
    - Test: notification includes service name, recurrence pattern, and assigned role
    - Test: scheduler does not receive the notification
    - _Requirements: 14.1, 14.2, 14.3_

- [x] 21. Implement song update notification test
  - [x] 21.1 Create `integration_test/tests/push_notifications/song_update_notification_test.dart`
    - Test: updating a song in a future service setlist generates SONG_UPDATED notification for assigned members
    - Test: notification includes song title and modified fields
    - Test: user who updated does not receive the notification
    - _Requirements: 15.1, 15.2, 15.3_

- [x] 22. Implement invitation accepted notification test
  - [x] 22.1 Create `integration_test/tests/push_notifications/invitation_accepted_notification_test.dart`
    - Test: accepting an invitation generates INVITATION_ACCEPTED notification for the admin who sent it
    - Test: notification includes new member name and accepted role
    - _Requirements: 16.1, 16.2_

- [x] 23. Implement availability change notification test
  - [x] 23.1 Create `integration_test/tests/push_notifications/availability_change_notification_test.dart`
    - Test: marking a date as unavailable generates notification for team leader with member name and date
    - Test: removing unavailability generates notification of restored availability
    - Test: member who changed availability does not receive notification of their own action
    - _Requirements: 17.1, 17.2, 17.3_

- [x] 24. Implement setlist modification notification test
  - [x] 24.1 Create `integration_test/tests/push_notifications/setlist_modification_notification_test.dart`
    - Test: modifying a future service's setlist generates notification for assigned members
    - Test: notification includes service name and summary of change
    - Test: user who modified the setlist does not receive the notification
    - _Requirements: 18.1, 18.2_

- [x] 25. Implement song attachment notification test
  - [x] 25.1 Create `integration_test/tests/push_notifications/song_attachment_notification_test.dart`
    - Test: adding an attachment to a song generates SONG_ATTACHMENT notification for song creator and commenters
    - Test: notification includes song title, attachment type, and uploader name
    - Test: user who added the attachment does not receive the notification
    - _Requirements: 19.1, 19.2, 19.3_

- [x] 26. Implement error handling test
  - [x] 26.1 Create `integration_test/tests/push_notifications/error_handling_test.dart`
    - Test: backend error when loading notifications shows error state with retry option
    - Test: failed mark-as-read shows SnackBar error and notification keeps original state
    - Test: failed preference save shows error message and toggles revert to previous state
    - Use temporary Dio interceptor to simulate 500 errors
    - _Requirements: 20.1, 20.2, 20.3_

- [x] 27. Implement service reminder notification test
  - [x] 27.1 Create `integration_test/tests/push_notifications/service_reminder_notification_test.dart`
    - Test: service with upcoming date and accepted members generates reminder notification
    - Test: notification includes service name, scheduled time, and assigned setlist
    - Test: only members who accepted the assignment receive the reminder
    - _Requirements: 21.1, 21.2_

- [x] 28. Implement new song notification test
  - [x] 28.1 Create `integration_test/tests/push_notifications/new_song_notification_test.dart`
    - Test: creating a new song generates NEW_SONG notification for other church members
    - Test: notification includes song title and creator name
    - Test: song creator does not receive notification of their own action
    - _Requirements: 23.1, 23.2_

- [x] 29. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- All tests use the existing Patrol infrastructure (TestEnvironment, patrolTest, helpers)
- Each test file is independent and can be run individually via `patrol test integration_test/tests/push_notifications/{file}.dart`
- Tests use unique data (timestamps in emails/names) to avoid collisions
- No pumpAndSettle — always pump with explicit durations in loops
- Multi-user tests create two users (admin + member) to validate sender exclusion
- The design explicitly states PBT does not apply (E2E tests are example-based by nature)
- Checkpoints are placed after infrastructure setup, core tests, and notification-type tests
