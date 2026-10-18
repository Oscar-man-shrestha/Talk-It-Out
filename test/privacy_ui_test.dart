import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/app/app.dart';
import 'package:talk_it_out/app/theme.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/auth/data/mock_auth_repository.dart';
import 'package:talk_it_out/features/groups/data/published_message.dart';
import 'package:talk_it_out/features/groups/group_chat_screen.dart';
import 'package:talk_it_out/features/notifications/data/app_notification.dart';
import 'package:talk_it_out/features/notifications/notification_text.dart';
import 'package:talk_it_out/app/repository_providers.dart';

void main() {
  testWidgets('a null sender renders Anonymous user', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          body: PublishedMessageTile(
            message: PublishedMessage(
              id: 'pm2',
              groupId: 'g1',
              text: 'Could we revisit the sprint timeline?',
              publishedAt: DateTime.utc(2026, 10, 10, 12, 5),
            ),
          ),
        ),
      ),
    );

    expect(find.text(AppStrings.anonymousUser), findsOneWidget);
    expect(find.textContaining('original'), findsNothing);
  });

  testWidgets('disclosure sits with the checkbox before send', (tester) async {
    final token = MemoryTokenStore()..value = 'mock-token';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(token),
          mockControlsProvider.overrideWithValue(
            MockControls(delay: Duration.zero),
          ),
        ],
        child: const TalkItOutApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Making NLP notes'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.anonymousCheckbox), findsOneWidget);
    expect(find.text(AppStrings.anonymousDisclosure), findsOneWidget);
    expect(find.text(AppStrings.send), findsOneWidget);
    expect(find.textContaining('original'), findsNothing);

    final disclosure = tester.getTopLeft(
      find.text(AppStrings.anonymousDisclosure),
    );
    final send = tester.getTopLeft(find.text(AppStrings.send));
    expect(disclosure.dy, lessThan(send.dy));
    expect(tester.getTopLeft(find.byType(Checkbox)).dy, lessThan(send.dy));
  });

  testWidgets('controller chat has no composer and review is guarded', (
    tester,
  ) async {
    final token = MemoryTokenStore()..value = 'mock-token';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(token),
          mockControlsProvider.overrideWithValue(
            MockControls(delay: Duration.zero),
          ),
        ],
        child: const TalkItOutApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Making NLP notes'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.anonymousCheckbox), findsOneWidget);

    final routerContext = tester.element(
      find.byType(NavigationBar, skipOffstage: false),
    );
    GoRouter.of(routerContext).go('/groups/${MockIds.notesGroup}/review');
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.reviewTitle), findsNothing);
    expect(find.text(AppStrings.anonymousCheckbox), findsOneWidget);

    GoRouter.of(routerContext).go('/groups/${MockIds.dashboardGroup}');
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.anonymousCheckbox), findsNothing);
    expect(find.byTooltip(AppStrings.reviewTitle), findsOneWidget);
  });

  test('rejection notification text has no reason', () {
    final item = AppNotification(
      id: 'n1',
      type: NotificationType.messageRejected,
      refId: 'm303',
      group: const NotificationGroup(
        id: MockIds.notesGroup,
        agenda: 'Making NLP notes',
      ),
      createdAt: DateTime.utc(2026, 10, 11, 9),
    );
    expect(notificationText(item), isNot(contains('reason')));
    expect(
      notificationText(item.copyWith(type: NotificationType.unknown)),
      AppStrings.notificationGeneric,
    );
  });

  test('mock password constant is the documented sample', () {
    expect(MockAuthRepository.mockPassword, 'secret123');
  });
}
