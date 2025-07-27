import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../../../../core/errors/exceptions.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:logging/logging.dart';
import '../../../../core/utils/logger_config.dart';

// Response model for auth endpoints
class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final UserModel user;

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

abstract class IAuthRemoteDataSource {
  Future<AuthResponse> signInWithEmail({required String email, required String password});
  Future<AuthResponse> signUpWithEmail({required String email, required String password, String? name});
  Future<AuthResponse> signInWithGoogle();
  Future<AuthResponse> signInWithApple();
  Future<void> signOut();
  Future<AuthResponse> refreshToken(String refreshToken);
}

class AuthRemoteDataSource implements IAuthRemoteDataSource {
  final Dio dio;
  static const String baseUrl = 'http://localhost:8000'; // API Gateway URL
  final Logger _logger = LoggerConfig.getLogger('AuthRemoteDataSource');
  
  AuthRemoteDataSource({Dio? dio}) 
    : dio = dio ?? Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 3),
        headers: {
          'Content-Type': 'application/json',
        },
      ));
  
  @override
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _logger.info('Attempting sign in for user: ${email.replaceAll(RegExp(r'@.*'), '@***')}');
    try {
      final response = await dio.post(
        '/auth/signin',
        data: {
          'email': email,
          'password': password,
        },
      );
      
      if (response.statusCode == 200) {
        _logger.info('Sign in successful for user: ${email.replaceAll(RegExp(r'@.*'), '@***')}');
        return AuthResponse.fromJson(response.data);
      } else {
        _logger.warning('Sign in failed with status code: ${response.statusCode}');
        throw ServerException('Invalid credentials');
      }
    } on DioException catch (e) {
      _logger.error('DioException during sign in', e, e.stackTrace);
      if (e.response?.statusCode == 401) {
        throw ServerException('Invalid email or password');
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw ServerException('Connection timeout');
      } else {
        throw ServerException('Server error: ${e.message}');
      }
    } catch (e, stackTrace) {
      _logger.error('Unexpected error during sign in', e, stackTrace);
      throw ServerException('Unexpected error: $e');
    }
  }
  
  @override
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    _logger.info('Attempting sign up for user: ${email.replaceAll(RegExp(r'@.*'), '@***')}');
    try {
      final response = await dio.post(
        '/auth/signup',
        data: {
          'email': email,
          'password': password,
          'name': name ?? email.split('@')[0],
        },
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        _logger.info('Sign up successful for user: ${email.replaceAll(RegExp(r'@.*'), '@***')}');
        return AuthResponse.fromJson(response.data);
      } else {
        _logger.warning('Sign up failed with status code: ${response.statusCode}');
        throw ServerException('Failed to create account');
      }
    } on DioException catch (e) {
      _logger.error('DioException during sign up', e, e.stackTrace);
      if (e.response?.statusCode == 409) {
        throw ServerException('Email already exists');
      } else {
        throw ServerException('Server error: ${e.message}');
      }
    } catch (e, stackTrace) {
      _logger.error('Unexpected error during sign up', e, stackTrace);
      throw ServerException('Unexpected error: $e');
    }
  }
  
  @override
  Future<AuthResponse> signInWithGoogle() async {
    _logger.info('Attempting Google sign in');
    try {
      final googleSignIn = GoogleSignIn.instance;
      _logger.debug('Starting Google sign in flow');

      // Optional: initialize (only needed if you need custom client IDs)
      // await googleSignIn.initialize();

      // Step 1: Start Google Sign-In flow
      final account = await googleSignIn.authenticate();

      // Step 2: Get ID token
      _logger.debug('Getting Google auth tokens');
      final auth = account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        _logger.error('Google sign in failed: No ID token returned');
        throw ServerException('Google sign-in failed: No ID token returned');
      }

      // Step 3: Send ID token to backend
      _logger.debug('Sending Google ID token to backend');
      final response = await dio.post(
        '/auth/google',
        data: {'id_token': idToken},
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _logger.info('Google sign in successful');
        return AuthResponse.fromJson(response.data);
      } else {
        _logger.warning('Google sign in failed with status code: ${response.statusCode}');
        throw ServerException('Google sign-in failed: Backend error');
      }
    } on DioException catch (e) {
      _logger.error('DioException during Google sign in', e, e.stackTrace);
      throw ServerException('Google sign-in network error: ${e.message}');
    } catch (e, stackTrace) {
      _logger.error('Unexpected error during Google sign in', e, stackTrace);
      throw ServerException('Google sign-in failed: $e');
    }
  }

  @override
  Future<AuthResponse> signInWithApple() async {
    _logger.info('Attempting Apple sign in');
    try {
      _logger.debug('Requesting Apple ID credential');
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Send credential.identityToken to your backend for verification/login
      final idToken = credential.identityToken;

      if (idToken == null) {
        _logger.error('Apple sign in failed: No identity token returned');
        throw ServerException('Apple sign in failed: No identity token returned');
      }

      _logger.debug('Sending Apple ID token to backend');
      final response = await dio.post(
        '/auth/apple', // or your backend endpoint
        data: {'id_token': idToken},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _logger.info('Apple sign in successful');
        return AuthResponse.fromJson(response.data);
      } else {
        _logger.warning('Apple sign in failed with status code: ${response.statusCode}');
        throw ServerException('Apple sign in failed: Backend error');
      }
    } catch (e, stackTrace) {
      _logger.error('Unexpected error during Apple sign in', e, stackTrace);
      throw ServerException('Apple sign in failed: $e');
    }
  }
    
  @override
  Future<void> signOut() async {
    _logger.info('Attempting sign out');
    try {
      await dio.post('/auth/signout');
    } catch (e) {
      // Even if remote fails, we should clear local data
      throw ServerException('Sign out failed: $e');
    }
  }
  
  @override
  Future<AuthResponse> refreshToken(String refreshToken) async {
    try {
      final response = await dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      
      if (response.statusCode == 200) {
        return AuthResponse.fromJson(response.data);
      } else {
        throw ServerException('Token refresh failed');
      }
    } catch (e) {
      throw ServerException('Token refresh failed: $e');
    }
  }
}