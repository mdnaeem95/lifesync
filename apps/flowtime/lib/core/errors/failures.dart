import 'package:equatable/equatable.dart';

/// Base class for all failures in the application.
/// 
/// All specific failure types should extend this class.
/// Failures represent expected error states that can be handled gracefully.
abstract class Failure extends Equatable {
  final String? message;
  final String? code;
  
  const Failure({this.message, this.code});
  
  @override
  List<Object?> get props => [message, code];
}

/// General failures
class ServerFailure extends Failure {
  const ServerFailure([String? message]) : super(message: message);
}

class CacheFailure extends Failure {
  const CacheFailure([String? message]) : super(message: message);
}

class NetworkFailure extends Failure {
  const NetworkFailure([String? message]) : super(message: message);
}

// Add if missing
class BiometricFailure extends Failure {
  const BiometricFailure([String? message]) : super(message: message);
}

class UnknownFailure extends Failure {
  const UnknownFailure([String? message]) : super(message: message ?? 'Unknown error');
}

/// Specific failures
class ValidationFailure extends Failure {
  final Map<String, List<String>>? fieldErrors;
  
  const ValidationFailure(String message, {this.fieldErrors}) 
      : super(message: message);
  
  @override
  List<Object?> get props => [message, fieldErrors];
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([String? message]) 
      : super(message: message ?? 'Unauthorized access');
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([String? message]) 
      : super(message: message ?? 'Resource not found');
}

class ConflictFailure extends Failure {
  const ConflictFailure([String? message]) 
      : super(message: message ?? 'Resource conflict');
}

class TimeoutFailure extends Failure {
  const TimeoutFailure([String? message]) 
      : super(message: message ?? 'Operation timed out');
}

class PermissionFailure extends Failure {
  const PermissionFailure([String? message]) 
      : super(message: message ?? 'Permission denied');
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure([String? message]) 
      : super(message: message ?? 'An unexpected error occurred');
}

class CancellationFailure extends Failure {
  const CancellationFailure() : super(message: 'Operation cancelled');
}

/// Business logic specific failures
class InsufficientEnergyFailure extends Failure {
  final int requiredEnergy;
  final int currentEnergy;
  
  const InsufficientEnergyFailure({
    required this.requiredEnergy,
    required this.currentEnergy,
  }) : super(message: 'Insufficient energy for this task');
  
  @override
  List<Object?> get props => [message, requiredEnergy, currentEnergy];
}

class ScheduleConflictFailure extends Failure {
  final List<String> conflictingTaskIds;
  
  const ScheduleConflictFailure({
    required this.conflictingTaskIds,
    String? message,
  }) : super(message: message ?? 'Schedule conflict detected');
  
  @override
  List<Object?> get props => [message, conflictingTaskIds];
}

class QuotaExceededFailure extends Failure {
  final String quotaType;
  final int limit;
  final int current;
  
  const QuotaExceededFailure({
    required this.quotaType,
    required this.limit,
    required this.current,
  }) : super(message: 'Quota exceeded for $quotaType');
  
  @override
  List<Object?> get props => [message, quotaType, limit, current];
}

/// Extension to provide user-friendly error messages
extension FailureMessage on Failure {
  String get userMessage {
    if (this is ServerFailure) {
      return 'Server error occurred. Please try again later.';
    } else if (this is NetworkFailure) {
      return 'No internet connection. Please check your network.';
    } else if (this is CacheFailure) {
      return 'Error loading cached data.';
    } else if (this is ValidationFailure) {
      return message ?? 'Please check your input and try again.';
    } else if (this is UnauthorizedFailure) {
      return 'Please sign in to continue.';
    } else if (this is NotFoundFailure) {
      return 'The requested content was not found.';
    } else if (this is ConflictFailure) {
      return message ?? 'A conflict occurred. Please refresh and try again.';
    } else if (this is TimeoutFailure) {
      return 'Request timed out. Please try again.';
    } else if (this is PermissionFailure) {
      return 'You don\'t have permission to perform this action.';
    } else if (this is InsufficientEnergyFailure) {
      return 'You need more energy to complete this task.';
    } else if (this is ScheduleConflictFailure) {
      return 'This time slot conflicts with another task.';
    } else if (this is QuotaExceededFailure) {
      return message ?? 'You\'ve reached your limit.';
    } else if (this is CancellationFailure) {
      return 'Operation was cancelled.';
    } else {
      return message ?? 'Something went wrong. Please try again.';
    }
  }
  
  bool get isRetryable {
    return this is ServerFailure || 
           this is NetworkFailure || 
           this is TimeoutFailure ||
           (this is UnexpectedFailure && !message!.contains('critical'));
  }
  
  bool get requiresAuthentication {
    return this is UnauthorizedFailure;
  }
}