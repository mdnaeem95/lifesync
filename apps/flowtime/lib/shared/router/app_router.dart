import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/signin_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/timeline/presentation/screens/timeline_screen.dart';
import '../../features/account/presentation/screens/account_screen.dart';

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
        path: '/account',
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: '/energy',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Energy Dashboard')),
          body: const Center(child: Text('Energy Dashboard - Coming Soon')),
        ),
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
      // Add a root redirect
      GoRoute(
        path: '/',
        redirect: (context, state) => '/auth/signin',
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
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
              state.error?.toString() ?? 'Unknown error occurred',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/auth/signin'),
              child: const Text('Go to Sign In'),
            ),
          ],
        ),
      ),
    ),
  );
});

// Helper class to convert AsyncValue changes to Listenable
class GoRouterRefreshStream extends ChangeNotifier {
  final Ref ref;
  
  GoRouterRefreshStream(this.ref) {
    // Listen to auth state changes
    ref.listen(authNotifierProvider, (previous, next) {
      // Notify listeners whenever auth state changes
      notifyListeners();
    });
  }
}