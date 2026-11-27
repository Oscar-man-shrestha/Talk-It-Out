import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/app/providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/mock/mock_board.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/features/auth/data/api_auth_repository.dart';
import 'package:talk_it_out/features/auth/data/auth_repository.dart';
import 'package:talk_it_out/features/auth/data/mock_auth_repository.dart';
import 'package:talk_it_out/features/discovery/data/api_discovery_repository.dart';
import 'package:talk_it_out/features/discovery/data/discovery_repository.dart';
import 'package:talk_it_out/features/discovery/data/mock_discovery_repository.dart';
import 'package:talk_it_out/features/feed/data/api_feed_repository.dart';
import 'package:talk_it_out/features/feed/data/feed_repository.dart';
import 'package:talk_it_out/features/feed/data/mock_feed_repository.dart';
import 'package:talk_it_out/features/groups/data/api_group_repository.dart';
import 'package:talk_it_out/features/groups/data/group_repository.dart';
import 'package:talk_it_out/features/groups/data/mock_group_repository.dart';
import 'package:talk_it_out/features/groups/data/mock_message_bridge.dart';
import 'package:talk_it_out/features/notifications/data/api_notification_repository.dart';
import 'package:talk_it_out/features/notifications/data/mock_notification_repository.dart';
import 'package:talk_it_out/features/notifications/data/notification_repository.dart';
import 'package:talk_it_out/features/profile/data/api_profile_repository.dart';
import 'package:talk_it_out/features/profile/data/mock_profile_repository.dart';
import 'package:talk_it_out/features/profile/data/profile_repository.dart';
import 'package:talk_it_out/features/review/data/api_review_repository.dart';
import 'package:talk_it_out/features/review/data/mock_review_repository.dart';
import 'package:talk_it_out/features/review/data/review_repository.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/features/invites/invite_repository.dart';
import 'package:talk_it_out/features/premium/data/billing_repository.dart';

final mockControlsProvider = Provider<MockControls>((ref) => MockControls());

final mockBoardProvider = Provider<MockBoard>((ref) => MockBoard());

final mockMessageBridgeProvider = Provider<MockMessageBridge>(
  (ref) => MockMessageBridge(),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (_useMock(ref)) {
    return MockAuthRepository(
      ref.watch(mockControlsProvider),
      ref.watch(mockBoardProvider),
    );
  }
  return ApiAuthRepository(ref.watch(dioProvider));
});

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  if (_useMock(ref)) {
    return MockGroupRepository(
      ref.watch(mockControlsProvider),
      ref.watch(mockBoardProvider),
      ref.watch(mockMessageBridgeProvider),
    );
  }
  return ApiGroupRepository(ref.watch(dioProvider));
});

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  if (_useMock(ref)) {
    return MockReviewRepository(
      ref.watch(mockControlsProvider),
      ref.watch(mockMessageBridgeProvider),
      ref.watch(mockBoardProvider),
    );
  }
  return ApiReviewRepository(ref.watch(dioProvider));
});

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  if (_useMock(ref)) {
    return MockFeedRepository(
      ref.watch(mockControlsProvider),
      ref.watch(mockBoardProvider),
    );
  }
  return ApiFeedRepository(ref.watch(dioProvider));
});

/// Group invite links (`API.md` 61).
final inviteRepositoryProvider = Provider<InviteRepository>((ref) {
  if (_useMock(ref)) {
    return MockInviteRepository(
      ref.watch(mockControlsProvider),
      ref.watch(mockBoardProvider),
      MockIds.priya,
    );
  }
  return ApiInviteRepository(ref.watch(dioProvider));
});

final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  if (_useMock(ref)) {
    return MockDiscoveryRepository(
      ref.watch(mockControlsProvider),
      ref.watch(mockBoardProvider),
      ref.watch(feedRepositoryProvider),
    );
  }
  return ApiDiscoveryRepository(ref.watch(dioProvider));
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  if (_useMock(ref)) {
    return MockNotificationRepository(ref.watch(mockControlsProvider));
  }
  return ApiNotificationRepository(ref.watch(dioProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  if (_useMock(ref)) {
    return MockProfileRepository(
      ref.watch(mockControlsProvider),
      ref.watch(authRepositoryProvider),
      ref.watch(mockBoardProvider),
    );
  }
  return ApiProfileRepository(ref.watch(dioProvider));
});

/// Premium state and Premium-only data (`API.md` 71).
final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  if (_useMock(ref)) {
    return MockBillingRepository(ref.watch(mockControlsProvider));
  }
  return ApiBillingRepository(ref.watch(dioProvider));
});

bool _useMock(Ref ref) => ref.watch(appConfigProvider).useMock;
