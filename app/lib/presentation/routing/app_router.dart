import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers/auth_providers.dart';
import '../../domain/enums/subscription_status.dart';
import '../screens/auth/invite_landing_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/catches/catch_detail_screen.dart';
import '../screens/catches/catch_form_screen.dart';
import '../screens/catches/repository_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/groups/create_group_screen.dart';
import '../screens/groups/group_chat_screen.dart';
import '../screens/groups/group_feed_screen.dart';
import '../screens/groups/invite_screen.dart';
import '../screens/groups/members_screen.dart';
import '../screens/shell_screen.dart';
import '../screens/stub_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final subscription = ref.watch(subscriptionProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isLoggedIn = authState.whenOrNull(
            data: (_) => true,
          ) ??
          false;
      final session =
          ref.read(currentUserProvider) != null;
      final isAuthenticated = isLoggedIn && session;

      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation.startsWith('/invite/') ||
          state.matchedLocation == '/auth/callback';

      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      if (isAuthenticated && isAuthRoute) {
        return '/dashboard';
      }

      if (isAuthenticated &&
          subscription == SubscriptionStatus.inactive &&
          state.matchedLocation != '/subscription') {
        return '/subscription';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'];
          return RegisterScreen(inviteToken: token);
        },
      ),
      GoRoute(
        path: '/invite/:token',
        builder: (context, state) => InviteLandingScreen(
          token: state.pathParameters['token']!,
        ),
      ),
      GoRoute(
        path: '/auth/callback',
        builder: (context, state) =>
            const StubScreen(title: 'Auth Callback'),
      ),
      GoRoute(
        path: '/subscription',
        builder: (context, state) =>
            const StubScreen(title: 'Subscription'),
      ),
      // Create group (outside shell for full-screen)
      GoRoute(
        path: '/groups/new',
        builder: (context, state) => const CreateGroupScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScreen(navigationShell: navigationShell),
        branches: [
          // Tab 0: Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          // Tab 1: Feed (group routes)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/groups/:groupId',
                builder: (context, state) => GroupFeedScreen(
                  groupId: state.pathParameters['groupId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'chat',
                    builder: (context, state) => GroupChatScreen(
                      groupId: state.pathParameters['groupId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'members',
                    builder: (context, state) => MembersScreen(
                      groupId: state.pathParameters['groupId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'invite',
                    builder: (context, state) => InviteScreen(
                      groupId: state.pathParameters['groupId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'repository',
                    builder: (context, state) => RepositoryScreen(
                      groupId: state.pathParameters['groupId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'catch/new',
                    builder: (context, state) => CatchFormScreen(
                      groupId: state.pathParameters['groupId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'catch/:id',
                    builder: (context, state) => CatchDetailScreen(
                      groupId: state.pathParameters['groupId']!,
                      catchId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) =>
                        const StubScreen(title: 'Group Settings'),
                  ),
                ],
              ),
            ],
          ),
          // Tab 2: Log Catch (quick access)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/catch/new',
                builder: (context, state) =>
                    const StubScreen(title: 'Log Catch'),
              ),
            ],
          ),
          // Tab 3: Repository
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/repository',
                builder: (context, state) =>
                    const StubScreen(title: 'Repository'),
              ),
            ],
          ),
          // Tab 4: Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) =>
                    const StubScreen(title: 'Profile'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
