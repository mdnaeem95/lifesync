import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../../../../core/errors/exceptions.dart';

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
  Future<UserModel> signInWithGoogle();
  Future<UserModel> signInWithApple();
  Future<void> signOut();
  Future<AuthResponse> refreshToken(String refreshToken);
}

class AuthRemoteDataSource implements IAuthRemoteDataSource {
  final Dio dio;
  static const String baseUrl = 'http://localhost:8000'; // API Gateway URL
  
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
    try {
      final response = await dio.post(
        '/auth/signin',
        data: {
          'email': email,
          'password': password,
        },
      );
      
      if (response.statusCode == 200) {
        return AuthResponse.fromJson(response.data);
      } else {
        throw ServerException('Invalid credentials');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw ServerException('Invalid email or password');
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw ServerException('Connection timeout');
      } else {
        throw ServerException('Server error: ${e.message}');
      }
    } catch (e) {
      throw ServerException('Unexpected error: $e');
    }
  }
  
  @override
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
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
        return AuthResponse.fromJson(response.data);
      } else {
        throw ServerException('Failed to create account');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw ServerException('Email already exists');
      } else {
        throw ServerException('Server error: ${e.message}');
      }
    } catch (e) {
      throw ServerException('Unexpected error: $e');
    }
  }
  
  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      // TODO: Implement actual Google Sign-In flow
      // For now, return mock data
      await Future.delayed(const Duration(seconds: 2));
      return UserModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        email: 'google.user@example.com',
        name: 'Google User',
        photoUrl: 'https://example.com/photo.jpg',
        createdAt: DateTime.now(),
      );
    } catch (e) {
      throw ServerException('Google sign in failed: $e');
    }
  }
  
  @override
  Future<UserModel> signInWithApple() async {
    try {
      // TODO: Implement actual Apple Sign-In flow
      // For now, return mock data
      await Future.delayed(const Duration(seconds: 2));
      return UserModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        email: 'apple.user@example.com',
        name: 'Apple User',
        createdAt: DateTime.now(),
      );
    } catch (e) {
      throw ServerException('Apple sign in failed: $e');
    }
  }
  
  @override
  Future<void> signOut() async {
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