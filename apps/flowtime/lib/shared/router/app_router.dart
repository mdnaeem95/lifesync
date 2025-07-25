import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/signin_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/timeline/presentation/screens/timeline_screen.dart';
import '../../features/energy/presentation/screens/energy_dashboard_screen.dart';
import '../../features/account/presentation/screens/account_screen.dart';

// Expose the router instance globally for navigation
final routerProvider = Provider<GoRouter>((ref) {
  return ref.watch(appRouterProvider);
});

final appRouterProvider = Provider<GoRouter>((ref) { 
  return GoRouter(
    initialLocation: '/auth/signin',
    refreshListenable: GoRouterRefreshStream(ref),
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      
      // Handle loading state
      if (authState.isLoading) {
        return null; // Don't redirect while loading
      }
      
      // Handle error state
      if (authState.hasError) {
        // Stay on current page if there's an error
        return null;
      }
      
      // Check authentication status
      final isAuthenticated = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      
      // If not authenticated and not on auth route, go to signin
      if (!isAuthenticated && !isAuthRoute) {
        return '/auth/signin';
      }
      
      // If authenticated and on auth route, go to timeline
      if (isAuthenticated && isAuthRoute) {
        return '/timeline';
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth/signin',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/auth/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/auth/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/timeline',
        builder: (context, state) => const TimelineScreen(),
      ),
      GoRoute(
        path: '/energy',
        builder: (context, state) => const EnergyDashboardScreen(),
      ),
      GoRoute(
        path: '/focus',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Focus Mode')),
          body: const Center(child: Text('Focus Mode - Coming Soon')),
        ),
      ),
      GoRoute(
        path: '/insights',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Insights')),
          body: const Center(child: Text('Insights - Coming Soon')),
        ),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountScreen(),
      ),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Ref ref) {
    // Listen to auth state changes
    ref.listen(authNotifierProvider, (_, __) {
      notifyListeners();
    });
  }
}