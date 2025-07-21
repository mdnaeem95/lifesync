import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../../../../core/errors/exceptions.dart';

abstract class IAuthRemoteDataSource {
  Future<UserModel> signInWithEmail({required String email, required String password});
  Future<UserModel> signUpWithEmail({required String email, required String password, String? name});
  Future<UserModel> signInWithGoogle();
  Future<UserModel> signInWithApple();
  Future<void> signOut();
  Future<UserModel> refreshToken(String refreshToken);
}

class AuthRemoteDataSource implements IAuthRemoteDataSource {
  final Dio dio;
  
  // Use different URLs for web vs mobile
  static String get baseUrl {
    if (kIsWeb) {
      // For web, use the actual IP or hostname
      return 'http://localhost:8000';
    } else {
      // For mobile emulators
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'http://10.0.2.2:8000'; // Android emulator
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        return 'http://localhost:8000'; // iOS simulator
      } else {
        return 'http://localhost:8000'; // Desktop
      }
    }
  }
  
  AuthRemoteDataSource({Dio? dio}) 
    : dio = dio ?? Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (kIsWeb) 'Access-Control-Allow-Origin': '*',
        },
        validateStatus: (status) => status! < 500,
      ))..interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
        requestHeader: true,
        responseHeader: true
      ));
  
  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      print('Attempting to sign in at: $baseUrl/auth/signin');
      
      final response = await dio.post(
        '/auth/signin',
        data: {
          'email': email,
          'password': password,
        },
      );
      
      print('Response status: ${response.statusCode}');
      print('Response data: ${response.data}');
      
      if (response.statusCode == 200) {
        return UserModel.fromJson(response.data['user']);
      } else {
        throw ServerException('Invalid credentials');
      }
    } on DioException catch (e) {
      print('DioException: ${e.type}');
      print('Error message: ${e.message}');
      print('Error response: ${e.response?.data}');
      
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout) {
        throw ServerException('Connection timeout - please check if the backend is running');
      } else if (e.type == DioExceptionType.connectionError) {
        throw ServerException('Cannot connect to server - please check if the backend is running on port 8000');
      } else if (e.response?.statusCode == 401) {
        throw ServerException('Invalid email or password');
      } else {
        throw ServerException('Server error: ${e.message}');
      }
    } catch (e) {
      print('Unexpected error: $e');
      throw ServerException('Unexpected error: $e');
    }
  }
  
  @override
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      print('Attempting to sign up at: $baseUrl/auth/signup');
      
      final response = await dio.post(
        '/auth/signup',
        data: {
          'email': email,
          'password': password,
          'name': name ?? email.split('@')[0],
        },
      );
      
      print('Response status: ${response.statusCode}');
      print('Response data: ${response.data}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return UserModel.fromJson(response.data['user']);
      } else {
        throw ServerException('Failed to create account');
      }
    } on DioException catch (e) {
      print('DioException: ${e.type}');
      print('Error message: ${e.message}');
      print('Error response: ${e.response?.data}');
      
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout) {
        throw ServerException('Connection timeout - please check if the backend is running');
      } else if (e.type == DioExceptionType.connectionError) {
        throw ServerException('Cannot connect to server - please check if the backend is running on port 8000');
      } else if (e.response?.statusCode == 409) {
        throw ServerException('Email already exists');
      } else {
        throw ServerException('Server error: ${e.message}');
      }
    } catch (e) {
      print('Unexpected error: $e');
      throw ServerException('Unexpected error: $e');
    }
  }
  
  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      // TODO: Implement actual Google Sign-In flow
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
      print('Sign out error: $e');
    }
  }
  
  @override
  Future<UserModel> refreshToken(String refreshToken) async {
    try {
      final response = await dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      
      if (response.statusCode == 200) {
        return UserModel.fromJson(response.data['user']);
      } else {
        throw ServerException('Token refresh failed');
      }
    } catch (e) {
      throw ServerException('Token refresh failed: $e');
    }
  }
}