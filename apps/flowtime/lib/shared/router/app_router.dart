import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/signin_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/timeline/presentation/screens/timeline_screen.dart';
import '../../features/timeline/presentation/screens/focus_mode_screen.dart';
import '../../features/energy/presentation/screens/energy_dashboard_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/account/presentation/screens/account_screen.dart';
import '../../features/weekly_planning/presentation/screens/weekly_planning_screen.dart';
import '../../features/timeline/domain/entities/task.dart';

// Expose the router instance globally for navigation
final routerProvider = Provider<GoRouter>((ref) {
  return ref.watch(appRouterProvider);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final logger = Logger('AppRouter');
  
  return GoRouter(
    initialLocation: '/auth/signin',
    refreshListenable: GoRouterRefreshStream(ref),
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      
      logger.fine('Router redirect check - Path: ${state.matchedLocation}, Auth: ${authState.valueOrNull != null}');
      
      // Handle loading state
      if (authState.isLoading) {
        logger.fine('Auth is loading, not redirecting');
        return null; // Don't redirect while loading
      }
      
      // Handle error state
      if (authState.hasError) {
        logger.warning('Auth has error: ${authState.error}');
        // Stay on current page if there's an error
        return null;
      }
      
      // Check authentication status
      final isAuthenticated = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      
      // If not authenticated and not on auth route, go to signin
      if (!isAuthenticated && !isAuthRoute) {
        logger.info('Not authenticated, redirecting to signin');
        return '/auth/signin';
      }
      
      // If authenticated and on auth route, go to timeline
      if (isAuthenticated && isAuthRoute) {
        logger.info('Authenticated, redirecting to timeline');
        return '/timeline';
      }
      
      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/auth/signin',
        builder: (context, state) {
          Logger('Router').fine('Building SignInScreen');
          return const SignInScreen();
        },
      ),
      GoRoute(
        path: '/auth/signup',
        builder: (context, state) {
          Logger('Router').fine('Building SignUpScreen');
          return const SignUpScreen();
        },
      ),
      GoRoute(
        path: '/auth/onboarding',
        builder: (context, state) {
          Logger('Router').fine('Building OnboardingScreen');
          return const OnboardingScreen();
        },
      ),
      
      // Main app routes
      GoRoute(
        path: '/timeline',
        builder: (context, state) {
          Logger('Router').fine('Building TimelineScreen');
          return const TimelineScreen();
        },
      ),
      GoRoute(
        path: '/energy',
        builder: (context, state) {
          Logger('Router').fine('Building EnergyDashboardScreen');
          return const EnergyDashboardScreen();
        },
      ),
      GoRoute(
        path: '/focus',
        builder: (context, state) {
          Logger('Router').fine('Building FocusModeScreen');
          final task = state.extra as Task?;
          return FocusModeScreen(task: task);
        },
      ),
      GoRoute(
        path: '/insights',
        builder: (context, state) {
          Logger('Router').fine('Building AnalyticsScreen');
          return const AnalyticsScreen();
        },
      ),
      GoRoute(
        path: '/planning',
        builder: (context, state) {
          Logger('Router').fine('Building WeeklyPlanningScreen');
          return const WeeklyPlanningScreen();
        },
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) {
          Logger('Router').fine('Building AccountScreen');
          return const AccountScreen();
        },
      ),
    ],
    
    // Error builder
    errorBuilder: (context, state) {
      Logger('Router').severe('Router error: ${state.error}');
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Navigation Error',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                state.error?.toString() ?? 'Unknown error',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/timeline'),
                child: const Text('Go to Timeline'),
              ),
            ],
          ),
        ),
      );
    },
  );
});

// Helper class for auth state changes
class GoRouterRefreshStream extends ChangeNotifier {
  final Ref _ref;
  late final void Function() _authListener;
  final _logger = Logger('GoRouterRefreshStream');

  GoRouterRefreshStream(this._ref) {
    _logger.info('Initializing router refresh stream');
    
    _authListener = () {
      _logger.fine('Auth state changed, notifying router');
      notifyListeners();
    };
    
    // Listen to auth state changes
    _ref.listen(authNotifierProvider, (_, __) => _authListener());
  }

  @override
  void dispose() {
    _logger.info('Disposing router refresh stream');
    super.dispose();
  }
}