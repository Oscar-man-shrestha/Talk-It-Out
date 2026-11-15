import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/app/shell.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/auth/forgot_password_screen.dart';
import 'package:talk_it_out/features/legal/legal_screen.dart';
import 'package:talk_it_out/features/auth/login_screen.dart';
import 'package:talk_it_out/features/auth/register_screen.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';
import 'package:talk_it_out/features/discovery/interest_picker_screen.dart';
import 'package:talk_it_out/features/discovery/person_profile_screen.dart';
import 'package:talk_it_out/features/discovery/safety_actions.dart';
import 'package:talk_it_out/features/feed/feed_screen.dart';
import 'package:talk_it_out/features/feed/new_post_screen.dart';
import 'package:talk_it_out/features/feed/post_detail_screen.dart';
import 'package:talk_it_out/features/groups/create_group_screen.dart';
import 'package:talk_it_out/features/groups/group_chat_screen.dart';
import 'package:talk_it_out/features/groups/groups_screen.dart';
import 'package:talk_it_out/features/groups/members_screen.dart';
import 'package:talk_it_out/features/groups/my_messages_screen.dart';
import 'package:talk_it_out/features/notifications/notifications_screen.dart';
import 'package:talk_it_out/features/profile/profile_screen.dart';
import 'package:talk_it_out/features/review/review_detail_screen.dart';
import 'package:talk_it_out/features/review/review_queue_screen.dart';
import 'package:talk_it_out/features/invites/join_group_screen.dart';
import 'package:talk_it_out/features/onboarding/welcome_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/groups',
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state.uri),
    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) => Scaffold(
          body: Semantics(
            label: AppStrings.loading,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/legal/:page',
        builder: (context, state) => LegalScreen(
          // A new page when the address changes, not the old text.
          key: ValueKey(state.pathParameters['page']),
          page: state.pathParameters['page']!,
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/people/:userId',
        builder: (context, state) =>
            PersonProfileScreen(userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/join/:code',
        builder: (context, state) => JoinGroupScreen(
          key: ValueKey(state.pathParameters['code']),
          code: state.pathParameters['code']!.toLowerCase(),
        ),
      ),
      GoRoute(
        path: '/blocked',
        builder: (context, state) => const BlockedPeopleScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/groups',
                builder: (context, state) => const GroupsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const CreateGroupScreen(),
                  ),
                  GoRoute(
                    path: ':groupId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => GroupChatScreen(
                      groupId: state.pathParameters['groupId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'members',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => MembersScreen(
                          groupId: state.pathParameters['groupId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'mine',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => MyMessagesScreen(
                          groupId: state.pathParameters['groupId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'review',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => ReviewQueueScreen(
                          groupId: state.pathParameters['groupId']!,
                        ),
                        routes: [
                          GoRoute(
                            path: ':messageId',
                            parentNavigatorKey: rootNavigatorKey,
                            builder: (context, state) => ReviewDetailScreen(
                              groupId: state.pathParameters['groupId']!,
                              messageId: state.pathParameters['messageId']!,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/feed',
                builder: (context, state) => const FeedScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const NewPostScreen(),
                  ),
                  GoRoute(
                    path: 'interests',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => InterestPickerScreen(
                      firstRun: state.uri.queryParameters['first'] == '1',
                    ),
                  ),
                  GoRoute(
                    path: ':postId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => PostDetailScreen(
                      postId: state.pathParameters['postId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notifications',
                builder: (context, state) => const NotificationsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    refresh.dispose();
    router.dispose();
  });
  return router;
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(sessionProvider, (previous, next) => notifyListeners());
  }
}

const _authPaths = {'/login', '/register', '/forgot-password'};

/// Where to go after loading or signing in: an in-app path from `?from=`,
/// never an auth page and never another site.
String? _returnTo(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return null;
  }
  final path = Uri.tryParse(from)?.path;
  if (path == null || path == '/loading' || _authPaths.contains(path)) {
    return null;
  }
  return from;
}

Future<String?> _redirect(Ref ref, Uri uri) async {
  final location = uri.path;
  final session = ref.read(sessionProvider);
  final signingIn = _authPaths.contains(location);
  // Keep the page someone opened (a reload or a shared link) so they land
  // on it after loading or signing in, instead of always on Groups.
  final pending = location == '/loading' || signingIn
      ? _returnTo(uri.queryParameters['from'])
      : _returnTo(uri.toString());
  String via(String target) => pending == null || pending == '/groups'
      ? target
      : Uri(path: target, queryParameters: {'from': pending}).toString();
  if (session.isLoading && !location.startsWith('/legal/')) {
    return location == '/loading' ? null : via('/loading');
  }
  // Legal pages are readable by everyone, signed in or not.
  if (location.startsWith('/legal/')) return null;
  final signedIn = session.asData?.value != null;
  if (!signedIn) {
    if (signingIn) return null;
    return via('/login');
  }
  if (signingIn || location == '/loading') {
    // An invite link or shared page wins; otherwise new accounts get the
    // welcome tour.
    return pending ??
        (ref.read(justRegisteredProvider) ? '/welcome' : '/groups');
  }

  final review = RegExp(r'^/groups/([^/]+)/review(?:/|$)').firstMatch(location);
  if (review == null) return null;
  final groupId = review.group(1)!;
  try {
    final group = await ref.read(groupRepositoryProvider).getGroup(groupId);
    if (group.myRole == GroupRole.controller) return null;
  } catch (_) {
    return '/groups';
  }
  final chat = '/groups/$groupId';
  return location == chat ? null : chat;
}
