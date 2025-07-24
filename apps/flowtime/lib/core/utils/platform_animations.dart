import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Utility class to handle platform-specific animation decisions
class PlatformAnimations {
  /// Check if continuous animations should be enabled
  static bool get shouldEnableContinuousAnimations {
    // Disable continuous animations on web to prevent window.dart errors
    return !kIsWeb;
  }

  /// Apply continuous animation only if platform supports it
  static Widget conditionalContinuousAnimation({
    required Widget child,
    required Widget Function(Widget) animationBuilder,
  }) {
    if (shouldEnableContinuousAnimations) {
      return animationBuilder(child);
    }
    return child;
  }

  /// Apply shimmer effect only on supported platforms
  static Widget conditionalShimmer(Widget child) {
    if (shouldEnableContinuousAnimations) {
      return child.animate(onPlay: (controller) => controller.repeat())
          .shimmer(duration: 3000.ms, color: Colors.white.withValues(alpha: 0.1));
    }
    return child;
  }

  /// Apply pulse animation only on supported platforms
  static Widget conditionalPulse(Widget child) {
    if (shouldEnableContinuousAnimations) {
      return child.animate(onPlay: (controller) => controller.repeat())
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.05, 1.05),
            duration: 2000.ms,
          );
    }
    return child;
  }
}