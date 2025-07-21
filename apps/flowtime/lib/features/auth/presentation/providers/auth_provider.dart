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

final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    baseUrl: 'http://localhost:8000', // TODO: Update with actual API URL
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
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
    try {
      // First try to get the current user
      final result = await authRepository.getCurrentUser();
      result.fold(
        (failure) => state = const AsyncValue.data(null),
        (user) => state = AsyncValue.data(user),
      );
      
      // Listen to auth state changes
      _authStateSubscription = authRepository.authStateChanges.listen((user) {
        state = AsyncValue.data(user);
      }, onError: (error) {
        state = AsyncValue.error(error, StackTrace.current);
      });
    } catch (e) {
      state = const AsyncValue.data(null);
    }
  }
  
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    final result = await signInUseCase(
      SignInParams(email: email, password: password),
    );
    result.fold(
      (failure) => state = AsyncValue.error(failure.message ?? 'Sign in failed', StackTrace.current),
      (user) => state = AsyncValue.data(user),
    );
  }
  
  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    final result = await authRepository.signInWithGoogle();
    result.fold(
      (failure) => state = AsyncValue.error(failure.message ?? 'Google sign in failed', StackTrace.current),
      (user) => state = AsyncValue.data(user),
    );
  }
  
  Future<void> signInWithApple() async {
    state = const AsyncValue.loading();
    final result = await authRepository.signInWithApple();
    result.fold(
      (failure) => state = AsyncValue.error(failure.message ?? 'Apple sign in failed', StackTrace.current),
      (user) => state = AsyncValue.data(user),
    );
  }
  
  Future<void> signInWithBiometric() async {
    state = const AsyncValue.loading();
    final result = await authRepository.signInWithBiometric();
    result.fold(
      (failure) => state = AsyncValue.error(failure.message ?? 'Biometric sign in failed', StackTrace.current),
      (r) async {
        if (r == true) {
          final userResult = await authRepository.getCurrentUser();
          userResult.fold(
            (failure) => state = AsyncValue.error(failure.message ?? 'Failed to get user', StackTrace.current),
            (user) => state = AsyncValue.data(user),
          );
        } else {
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
    state = const AsyncValue.loading();
    final result = await signUpUseCase(
      SignUpParams(email: email, password: password, name: name),
    );
    result.fold(
      (failure) => state = AsyncValue.error(failure.message ?? 'Sign up failed', StackTrace.current),
      (user) => state = AsyncValue.data(user),
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