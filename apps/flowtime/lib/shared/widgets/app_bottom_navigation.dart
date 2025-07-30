import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import '../../core/constants/app_colors.dart';

class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final _logger = Logger('AppBottomNavigation');

  AppBottomNavigation({
    super.key,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Important for 5 items
        backgroundColor: Colors.transparent,
        elevation: 0,
        currentIndex: currentIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        onTap: (index) => _onItemTapped(context, index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.timeline),
            label: 'Timeline',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bolt),
            label: 'Energy',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_view_week),
            label: 'Planning',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timer),
            label: 'Focus',
          ),
        ],
      ),
    );
  }

  void _onItemTapped(BuildContext context, int index) {
    _logger.fine('Navigation tapped: $index');
    
    // Don't navigate if already on the current page
    if (index == currentIndex) return;
    
    switch (index) {
      case 0:
        context.go('/timeline');
        break;
      case 1:
        context.go('/energy');
        break;
      case 2:
        context.go('/planning');
        break;
      case 3:
        context.go('/insights');
        break;
      case 4:
        context.go('/focus');
        break;
    }
  }
}

// Extension to get the current navigation index from route
extension NavigationIndex on BuildContext {
  int get currentNavigationIndex {
    final location = GoRouterState.of(this).matchedLocation;
    
    if (location.contains('/timeline')) return 0;
    if (location.contains('/energy')) return 1;
    if (location.contains('/planning')) return 2;
    if (location.contains('/insights')) return 3;
    if (location.contains('/focus')) return 4;
    
    // Default to timeline
    return 0;
  }
}