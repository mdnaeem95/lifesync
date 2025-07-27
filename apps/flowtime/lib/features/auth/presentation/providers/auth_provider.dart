import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_up_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/datasources/auth_local_data_source.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:async';
import 'package:logging/logging.dart';
import '../../../../core/utils/logger_config.dart';

final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    baseUrl: 'http://localhost:8000', // Fixed: API Gateway URL
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
    },
    validateStatus: (status) {
      return status! < 500; // Don't throw for client errors
    },
  ));
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override in main()');
});

final authRemoteDataSourceProvider = Provider<IAuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(dio: ref.watch(dioProvider));
});

final authLocalDataSourceProvider = Provider<IAuthLocalDataSource>((ref) {
  return AuthLocalDataSource(
    sharedPreferences: ref.watch(sharedPreferencesProvider),
    secureStorage: const FlutterSecureStorage(),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    localDataSource: ref.watch(authLocalDataSourceProvider),
    localAuth: LocalAuthentication()
  );
});

final signInUseCaseProvider = Provider<SignInUseCase>((ref) {
  return SignInUseCase(ref.watch(authRepositoryProvider));
});

final signUpUseCaseProvider = Provider<SignUpUseCase>((ref) {
  return SignUpUseCase(ref.watch(authRepositoryProvider));
});

final signOutUseCaseProvider = Provider<SignOutUseCase>((ref) {
  return SignOutUseCase(ref.watch(authRepositoryProvider));
});

final authNotifierProvider = 
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(
    signInUseCase: ref.watch(signInUseCaseProvider),
    signUpUseCase: ref.watch(signUpUseCaseProvider),
    signOutUseCase: ref.watch(signOutUseCaseProvider),
    authRepository: ref.watch(authRepositoryProvider),
  );
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final SignInUseCase signInUseCase;
  final SignUpUseCase signUpUseCase;
  final SignOutUseCase signOutUseCase;
  final AuthRepository authRepository;
  final Logger _logger = LoggerConfig.getLogger('AuthNotifier');
  StreamSubscription<User?>? _authStateSubscription;
  
  AuthNotifier({
    required this.signInUseCase,
    required this.signUpUseCase,
    required this.signOutUseCase,
    required this.authRepository,
  }) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() async {
    _logger.info('Initializing auth notifier');
    try {
      // First try to get the current user
      _logger.debug('Checking for current user');
      final result = await authRepository.getCurrentUser();
      result.fold(
        (failure) {
          _logger.debug('No current user found: ${failure.message}');
          state = const AsyncValue.data(null);
        },
        (user) {
          _logger.info('Current user found: ${user.email.replaceAll(RegExp(r'@.*'), '@***')}');
          state = AsyncValue.data(user);
        }
      );
      
      // Listen to auth state changes
      _logger.debug('Setting up auth state listener');
      _authStateSubscription = authRepository.authStateChanges.listen(
        (user) {
        _logger.debug('Auth state changed: ${user != null ? 'User logged in' : 'User logged out'}');
        state = AsyncValue.data(user);
      }, onError: (error, stackTrace) {
         _logger.error('Auth state stream error', error, stackTrace);
        state = AsyncValue.error(error, StackTrace.current);
      });
    } catch (e, stackTrace) {
      _logger.error('Error during auth initialization', e, stackTrace);
      state = const AsyncValue.data(null);
    }
  }
  
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _logger.info('Attempting email sign in');
    state = const AsyncValue.loading();

    final result = await signInUseCase(
      SignInParams(email: email, password: password),
    );
    result.fold(
      (failure) {
        _logger.warning('Email sign in failed: ${failure.message}');
        state = AsyncValue.error(failure.message ?? 'Sign in failed', StackTrace.current);
      },
      (user) {
        _logger.info('Email sign in successful');
        state = AsyncValue.data(user);
      }
    );
  }
  
  Future<void> signInWithGoogle() async {
    _logger.info('Attempting Google sign in');
    state = const AsyncValue.loading();

    final result = await authRepository.signInWithGoogle();
    result.fold(
      (failure) {
        _logger.warning('Google sign in failed: ${failure.message}');
        state = AsyncValue.error(failure.message ?? 'Google sign in failed', StackTrace.current);
      },
      (user) {
        _logger.info('Google sign in successful');
        state = AsyncValue.data(user);
      }
    );
  }
  
  Future<void> signInWithApple() async {
    _logger.info('Attempting Apple sign in');
    state = const AsyncValue.loading();

    final result = await authRepository.signInWithApple();
    result.fold(
      (failure) {
        _logger.warning('Apple sign in failed: ${failure.message}');
        state = AsyncValue.error(failure.message ?? 'Apple sign in failed', StackTrace.current);
      },
      (user) {
        _logger.info('Apple sign in successful');
        state = AsyncValue.data(user);
      }
    );
  }
  
  Future<void> signInWithBiometric() async {
    _logger.info('Attempting biometric sign in');
    state = const AsyncValue.loading();
    
    final result = await authRepository.signInWithBiometric();
    
    result.fold(
      (failure) {
        _logger.warning('Biometric sign in failed: ${failure.message}');
        state = AsyncValue.error(
          failure.message ?? 'Biometric sign in failed',
          StackTrace.current,
        );
      },
      (authenticated) async {
        if (authenticated == true) {
          _logger.debug('Biometric authentication successful, fetching user');
          final userResult = await authRepository.getCurrentUser();
          
          userResult.fold(
            (failure) {
              _logger.error('Failed to get user after biometric auth: ${failure.message}');
              state = AsyncValue.error(
                failure.message ?? 'Failed to get user',
                StackTrace.current,
              );
            },
            (user) {
              _logger.info('Biometric sign in completed successfully');
              state = AsyncValue.data(user);
            },
          );
        } else {
          _logger.warning('Biometric authentication cancelled or failed');
          state = const AsyncValue.data(null);
        }
      },
    );
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    _logger.info('Attempting email sign up');
    state = const AsyncValue.loading();
    
    final result = await signUpUseCase(
      SignUpParams(email: email, password: password, name: name),
    );
    
    result.fold(
      (failure) {
        _logger.warning('Email sign up failed: ${failure.message}');
        state = AsyncValue.error(
          failure.message ?? 'Sign up failed',
          StackTrace.current,
        );
      },
      (user) {
        _logger.info('Email sign up successful');
        state = AsyncValue.data(user);
      },
    );
  }
  
  Future<void> signOut() async {
    await signOutUseCase();
    state = const AsyncValue.data(null);
  }
  
  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}