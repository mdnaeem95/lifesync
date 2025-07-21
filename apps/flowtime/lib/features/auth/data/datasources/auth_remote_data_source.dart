import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../../../../core/errors/exceptions.dart';

abstract class IAuthRemoteDataSource {
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  });
  
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  });
  
  Future<UserModel> signInWithGoogle();
  
  Future<UserModel> signInWithApple();
  
  Future<void> signOut();
  
  Future<UserModel> refreshToken(String refreshToken);
}

class AuthRemoteDataSource implements IAuthRemoteDataSource {
  final Dio dio;
  
  AuthRemoteDataSource({Dio? dio}) 
    : dio = dio ?? Dio(BaseOptions(
        baseUrl: 'http://localhost:8080', // TODO: Update with actual API URL
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 3),
        headers: {
          'Content-Type': 'application/json',
        },
      ));
  
  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // For now, mock the API response
      // TODO: Replace with actual API call
      await Future.delayed(const Duration(seconds: 1));
      
      // Mock successful response
      final mockResponse = {
        'user': {
          'id': 'mock_user_id',
          'email': email,
          'name': 'Mock User',
          'createdAt': DateTime.now().toIso8601String(),
        },
        'token': {
          'accessToken': 'mock_access_token',
          'refreshToken': 'mock_refresh_token',
          'expiresIn': 3600,
        },
      };
      
      return UserModel.fromJson(mockResponse['user'] as Map<String, dynamic>);
      
      // Actual API call would look like:
      /*
      final response = await dio.post(
        '/auth/signin',
        data: {
          'email': email,
          'password': password,
        },
      );
      
      if (response.statusCode == 200) {
        return UserModel.fromJson(response.data['user']);
      } else {
        throw ServerException('Invalid credentials');
      }
      */
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
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      // Mock implementation
      await Future.delayed(const Duration(seconds: 1));
      
      final mockResponse = {
        'user': {
          'id': 'new_user_id',
          'email': email,
          'name': name ?? email.split('@')[0],
          'createdAt': DateTime.now().toIso8601String(),
        },
        'token': {
          'accessToken': 'mock_access_token',
          'refreshToken': 'mock_refresh_token',
          'expiresIn': 3600,
        },
      };
      
      return UserModel.fromJson(mockResponse['user'] as Map<String, dynamic>);
      
      // Actual API call:
      /*
      final response = await dio.post(
        '/auth/signup',
        data: {
          'email': email,
          'password': password,
          'name': name,
        },
      );
      
      if (response.statusCode == 201) {
        return UserModel.fromJson(response.data['user']);
      } else {
        throw ServerException('Failed to create account');
      }
      */
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
    // TODO: Implement Google Sign In
    throw UnimplementedError('Google Sign In not implemented yet');
  }
  
  @override
  Future<UserModel> signInWithApple() async {
    // TODO: Implement Apple Sign In
    throw UnimplementedError('Apple Sign In not implemented yet');
  }
  
  @override
  Future<void> signOut() async {
    try {
      // Mock implementation
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Actual API call:
      /*
      await dio.post('/auth/signout');
      */
    } catch (e) {
      // Sign out should succeed even if API call fails
      // We'll clear local data anyway
    }
  }
  
  @override
  Future<UserModel> refreshToken(String refreshToken) async {
    try {
      // Mock implementation
      await Future.delayed(const Duration(milliseconds: 500));
      
      final mockResponse = {
        'user': {
          'id': 'mock_user_id',
          'email': 'user@example.com',
          'name': 'Mock User',
          'createdAt': DateTime.now().toIso8601String(),
        },
        'token': {
          'accessToken': 'new_mock_access_token',
          'refreshToken': 'new_mock_refresh_token',
          'expiresIn': 3600,
        },
      };
      
      return UserModel.fromJson(mockResponse['user'] as Map<String, dynamic>);
      
      // Actual API call:
      /*
      final response = await dio.post(
        '/auth/refresh',
        data: {
          'refreshToken': refreshToken,
        },
      );
      
      if (response.statusCode == 200) {
        return UserModel.fromJson(response.data['user']);
      } else {
        throw ServerException('Invalid refresh token');
      }
      */
    } catch (e) {
      throw ServerException('Failed to refresh token: $e');
    }
  }
}