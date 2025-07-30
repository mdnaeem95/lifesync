import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:local_auth/local_auth.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/auth_token_model.dart';
import 'package:logging/logging.dart';
import '../../../../core/utils/logger_config.dart';

class AuthRepositoryImpl implements AuthRepository {
  final IAuthRemoteDataSource remoteDataSource;
  final IAuthLocalDataSource localDataSource;
  final LocalAuthentication localAuth;
  final Logger _logger = LoggerConfig.getLogger('AuthRepository');
  
  final StreamController<User?> _authStateController = StreamController<User?>.broadcast();
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
            final authResponse = await remoteDataSource.refreshToken(tokens.refreshToken);
            await localDataSource.cacheUser(authResponse.user);
            await localDataSource.saveTokens(
              AuthTokenModel(
                accessToken: authResponse.accessToken,
                refreshToken: authResponse.refreshToken,
                expiresAt: DateTime.now().add(Duration(seconds: authResponse.expiresIn)),
              ),
            );
            _currentUser = authResponse.user.toEntity();
            _authStateController.add(_currentUser);
          } catch (e) {
            // Refresh failed, clear everything
            await _clearAuthData();
          }
        }
      } else {
        // No cached user, start with null
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
    _logger.info('Processing sign in request');
    try {
      final authResponse = await remoteDataSource.signInWithEmail(
        email: email,
        password: password,
      );
      
      // Cache user and tokens
      await localDataSource.cacheUser(authResponse.user);
      await localDataSource.saveTokens(
        AuthTokenModel(
          accessToken: authResponse.accessToken,
          refreshToken: authResponse.refreshToken,
          expiresAt: DateTime.now().add(Duration(seconds: authResponse.expiresIn)),
        ),
      );
      
      _currentUser = authResponse.user.toEntity();
      _logger.debug('Sign in response received, updating auth state');
      _authStateController.add(_currentUser);
      
      return Right(_currentUser!);
    } on ServerException catch (e) {
      _logger.warning('Server exception during sign in: ${e.message}');
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      _logger.warning('Server exception during sign in: ${e.message}');
      return Left(CacheFailure(e.message));
    } catch (e, stackTrace) {
      _logger.error('Unexpected error during sign in', e, stackTrace);
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    _logger.info('Processing sign up request');
    try {
      final authResponse = await remoteDataSource.signUpWithEmail(
        email: email,
        password: password,
        name: name,
      );
      
      // Cache user and tokens
      await localDataSource.cacheUser(authResponse.user);
      await localDataSource.saveTokens(
        AuthTokenModel(
          accessToken: authResponse.accessToken,
          refreshToken: authResponse.refreshToken,
          expiresAt: DateTime.now().add(Duration(seconds: authResponse.expiresIn)),
        ),
      );
      
      _currentUser = authResponse.user.toEntity();
      _logger.debug('Sign up response received, updating auth state');
      _authStateController.add(_currentUser);
      
      return Right(_currentUser!);
    } on ServerException catch (e) {
      _logger.warning('Server exception during sign up: ${e.message}');
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e, stackTrace) {
      _logger.error('Unexpected error during sign up', e, stackTrace);
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> signInWithGoogle() async {
    _logger.info('Processing Google sign in request');
    try {
      final authResponse = await remoteDataSource.signInWithGoogle();

      // Cache the user AND tokens - IMPORTANT!
      await localDataSource.cacheUser(authResponse.user);
      await localDataSource.saveTokens(
        AuthTokenModel(
          accessToken: authResponse.accessToken,
          refreshToken: authResponse.refreshToken,
          expiresAt: DateTime.now().add(Duration(seconds: authResponse.expiresIn)),
        ),
      );

      _currentUser = authResponse.user.toEntity();
      _logger.debug('Google sign in response received, updating auth state');
      _authStateController.add(_currentUser);

      return Right(_currentUser!);
    } on ServerException catch (e) {
      _logger.warning('Server exception during Google sign in: ${e.message}');
      return Left(ServerFailure(e.message));
    } catch (e, stackTrace) {
      _logger.error('Unexpected error during Google sign in', e, stackTrace);
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> signInWithApple() async {
    
    try {
      final authResponse = await remoteDataSource.signInWithApple();

      // Cache the user AND tokens - IMPORTANT!
      await localDataSource.cacheUser(authResponse.user);
      await localDataSource.saveTokens(
        AuthTokenModel(
          accessToken: authResponse.accessToken,
          refreshToken: authResponse.refreshToken,
          expiresAt: DateTime.now().add(Duration(seconds: authResponse.expiresIn)),
        ),
      );

      _currentUser = authResponse.user.toEntity();
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
      final isAvailable = await localAuth.canCheckBiometrics;
      if (!isAvailable) {
        return Left(BiometricFailure('Biometric authentication not available'));
      }
      
      final isEnabled = await localDataSource.isBiometricEnabled();
      if (!isEnabled) {
        return Left(BiometricFailure('Biometric authentication not enabled'));
      }
      
      final didAuthenticate = await localAuth.authenticate(
        localizedReason: 'Please authenticate to sign in',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      
      return Right(didAuthenticate);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(BiometricFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    _logger.info('Processing sign out request');
    try {
      // Note: signout endpoint returns 404, but we continue with local signout
      await remoteDataSource.signOut();
  
      _logger.debug('Sign out successful, clearing auth state');
      _authStateController.add(null);
      await _clearAuthData();
      
      return const Right(null);
    } on CacheException catch (e) {
      _logger.warning('Cache exception during sign out: ${e.message}');
      return Left(CacheFailure(e.message));
    } catch (e, stackTrace) {
      _logger.error('Unexpected error during sign out', e, stackTrace);
      return Left(CacheFailure('Failed to sign out'));
    }
  }

  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    _logger.debug('Getting current user');
    try {
      if (_currentUser != null) {
        _logger.debug('Current user found');
        _authStateController.add(_currentUser);
        return Right(_currentUser!);
      } else {
        _logger.debug('No current user found');
        _authStateController.add(null);
        return Left(ServerFailure('No user found')); 
      }
    } catch (e, stackTrace) {
      _logger.error('Error getting current user', e, stackTrace);
      _authStateController.add(null);
      return Left(ServerFailure('Failed to get current user'));
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