// lib/core/usecases/usecase.dart

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../errors/failures.dart';

/// Abstract class for all use cases in the application.
/// 
/// Type [T] represents the return type of the use case.
/// Type [Params] represents the parameters required by the use case.
/// 
/// All use cases should extend this class and implement the [call] method.
abstract class UseCase<T, Params> {
  /// Executes the use case with the given parameters.
  /// 
  /// Returns [Either] a [Failure] or the expected result of type [T].
  Future<Either<Failure, T>> call(Params params);
}

/// Class to be used for use cases that don't require any parameters.
/// 
/// Example:
/// ```dart
/// class GetCurrentUser implements UseCase<User, NoParams> {
///   @override
///   Future<Either<Failure, User>> call(NoParams params) async {
///     // Implementation
///   }
/// }
/// ```
class NoParams extends Equatable {
  const NoParams();
  
  @override
  List<Object?> get props => [];
}

/// Abstract class for use cases that return a [Stream].
/// 
/// Type [T] represents the type of data emitted by the stream.
/// Type [Params] represents the parameters required by the use case.
abstract class StreamUseCase<T, Params> {
  /// Executes the use case with the given parameters.
  /// 
  /// Returns a [Stream] that emits [Either] a [Failure] or the expected result of type [T].
  Stream<Either<Failure, T>> call(Params params);
}

/// Abstract class for synchronous use cases.
/// 
/// Type [T] represents the return type of the use case.
/// Type [Params] represents the parameters required by the use case.
abstract class SyncUseCase<T, Params> {
  /// Executes the use case synchronously with the given parameters.
  /// 
  /// Returns [Either] a [Failure] or the expected result of type [T].
  Either<Failure, T> call(Params params);
}

/// Abstract class for use cases that don't return a value (void operations).
/// 
/// Type [Params] represents the parameters required by the use case.
abstract class VoidUseCase<Params> {
  /// Executes the use case with the given parameters.
  /// 
  /// Returns [Either] a [Failure] or [Unit] (from dartz package) on success.
  Future<Either<Failure, Unit>> call(Params params);
}

/// Class to be used for pagination parameters.
/// 
/// Can be extended for specific pagination needs.
class PaginationParams extends Equatable {
  final int page;
  final int pageSize;
  final Map<String, dynamic>? filters;
  final String? sortBy;
  final bool ascending;

  const PaginationParams({
    required this.page,
    this.pageSize = 20,
    this.filters,
    this.sortBy,
    this.ascending = true,
  });

  @override
  List<Object?> get props => [page, pageSize, filters, sortBy, ascending];
}

/// Mixin to add cancellation support to use cases.
/// 
/// Example:
/// ```dart
/// class SearchUsers with CancellableUseCase implements UseCase<List<User>, SearchParams> {
///   @override
///   Future<Either<Failure, List<User>>> call(SearchParams params) async {
///     // Check for cancellation periodically during long operations
///     if (isCancelled) {
///       return Left(CancellationFailure());
///     }
///     // Implementation
///   }
/// }
/// ```
mixin CancellableUseCase {
  bool _isCancelled = false;
  
  bool get isCancelled => _isCancelled;
  
  void cancel() {
    _isCancelled = true;
  }
  
  void reset() {
    _isCancelled = false;
  }
}

/// Abstract class for use cases that support caching.
/// 
/// Type [T] represents the return type of the use case.
/// Type [Params] represents the parameters required by the use case.
abstract class CacheableUseCase<T, Params> extends UseCase<T, Params> {
  /// Gets the cache key for the given parameters.
  String getCacheKey(Params params);
  
  /// Determines if the cache should be used for the given parameters.
  bool shouldUseCache(Params params) => true;
  
  /// Gets the cache duration for the given parameters.
  Duration getCacheDuration(Params params) => const Duration(hours: 1);
}