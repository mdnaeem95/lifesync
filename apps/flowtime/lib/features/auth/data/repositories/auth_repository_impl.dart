import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:local_auth/local_auth.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/user.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/exceptions.dart';
import '../datasources/auth_remote_data_source.dart';
import '../datasources/auth_local_data_source.dart';
import '../models/auth_token_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final IAuthRemoteDataSource remoteDataSource;
  final IAuthLocalDataSource localDataSource;
  final LocalAuthentication localAuth;
  
  final _authStateController = StreamController<User?>.broadcast();
  User? _currentUser;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    LocalAuthentication? localAuth,
  }) : localAuth = localAuth ?? LocalAuthentication() {
    _initializeAuth();
  }
  
  Future<void> _initializeAuth() async {
    try {
      // Check for cached user and valid tokens
      final cachedUser = await localDataSource.getCachedUser();
      final tokens = await localDataSource.getTokens();
      
      if (cachedUser != null && tokens != null) {
        if (!tokens.isExpired) {
          _currentUser = cachedUser.toEntity();
          _authStateController.add(_currentUser);
        } else {
          // Try to refresh token
          try {
            final newUser = await remoteDataSource.refreshToken(tokens.refreshToken);
            await localDataSource.cacheUser(newUser);
            _currentUser = newUser.toEntity();
            _authStateController.add(_currentUser);
          } catch (e) {
            // Refresh failed, clear everything
            await _clearAuthData();
          }
        }
      } else {
        // no cahced user, start with null
        _authStateController.add(null);
      }
    } catch (e) {
      // Initialization failed, start with no user
      _authStateController.add(null);
    }
  }
  
  @override
  Future<Either<Failure, User>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userModel = await remoteDataSource.signInWithEmail(
        email: email,
        password: password,
      );
      
      // Cache user and tokens
      await localDataSource.cacheUser(userModel);
      // In a real app, we'd get tokens from the response
      await localDataSource.saveTokens(
        AuthTokenModel(
          accessToken: 'mock_access_token',
          refreshToken: 'mock_refresh_token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      
      _currentUser = userModel.toEntity();
      _authStateController.add(_currentUser);
      
      return Right(_currentUser!);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final userModel = await remoteDataSource.signUpWithEmail(
        email: email,
        password: password,
        name: name,
      );
      
      // Cache user and tokens
      await localDataSource.cacheUser(userModel);
      await localDataSource.saveTokens(
        AuthTokenModel(
          accessToken: 'mock_access_token',
          refreshToken: 'mock_refresh_token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      
      _currentUser = userModel.toEntity();
      _authStateController.add(_currentUser);
      
      return Right(_currentUser!);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> signInWithGoogle() async {
    try {
      final userModel = await remoteDataSource.signInWithGoogle();
      
      await localDataSource.cacheUser(userModel);
      _currentUser = userModel.toEntity();
      _authStateController.add(_currentUser);
      
      return Right(_currentUser!);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> signInWithApple() async {
    try {
      final userModel = await remoteDataSource.signInWithApple();
      
      await localDataSource.cacheUser(userModel);
      _currentUser = userModel.toEntity();
      _authStateController.add(_currentUser);
      
      return Right(_currentUser!);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> signInWithBiometric() async {
    try {
      // Check if biometric is available
      final isAvailable = await localAuth.canCheckBiometrics;
      if (!isAvailable) {
        return Left(BiometricFailure('Biometric authentication not available'));
      }
      
      // Check if biometric is enabled for this app
      final isEnabled = await localDataSource.isBiometricEnabled();
      if (!isEnabled) {
        return Left(BiometricFailure('Biometric authentication not enabled'));
      }
      
      // Authenticate
      final authenticated = await localAuth.authenticate(
        localizedReason: 'Authenticate to access FlowTime',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      
      if (authenticated) {
        // Get cached user
        final cachedUser = await localDataSource.getCachedUser();
        if (cachedUser != null) {
          _currentUser = cachedUser.toEntity();
          _authStateController.add(_currentUser);
          return const Right(true);
        } else {
          return Left(CacheFailure('No cached user found'));
        }
      } else {
        return const Right(false);
      }
    } catch (e) {
      return Left(BiometricFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await remoteDataSource.signOut();
      await _clearAuthData();
      return const Right(null);
    } catch (e) {
      // Even if remote sign out fails, clear local data
      await _clearAuthData();
      return const Right(null);
    }
  }

  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    try {
      if (_currentUser != null) {
        return Right(_currentUser!);
      }
      
      final cachedUser = await localDataSource.getCachedUser();
      if (cachedUser != null) {
        _currentUser = cachedUser.toEntity();
        return Right(_currentUser!);
      }
      
      return Left(CacheFailure('No user found'));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Stream<User?> get authStateChanges => _authStateController.stream;
  
  Future<void> _clearAuthData() async {
    await localDataSource.clearCache();
    await localDataSource.clearTokens();
    _currentUser = null;
    _authStateController.add(null);
  }
  
  void dispose() {
    _authStateController.close();
  }
}

// Additional Failure classes
class ServerFailure extends Failure {
  ServerFailure(super.message);
}

class CacheFailure extends Failure {
  CacheFailure(super.message);
}

class BiometricFailure extends Failure {
  BiometricFailure(super.message);
}

class UnknownFailure extends Failure {
  UnknownFailure(super.message);
}