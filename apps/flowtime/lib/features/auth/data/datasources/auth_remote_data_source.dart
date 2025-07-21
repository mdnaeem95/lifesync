import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../models/auth_token_model.dart';
import '../../../../core/errors/exceptions.dart';

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
  Future<UserModel> signInWithEmail({
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
        // Save tokens
        final tokens = AuthTokenModel(
          accessToken: response.data['access_token'],
          refreshToken: response.data['refresh_token'],
          expiresAt: DateTime.now().add(Duration(seconds: response.data['expires_in'])),
        );
        
        // Return user
        return UserModel.fromJson(response.data['user']);
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
  Future<UserModel> signUpWithEmail({
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
        // Save tokens
        final tokens = AuthTokenModel(
          accessToken: response.data['access_token'],
          refreshToken: response.data['refresh_token'],
          expiresAt: DateTime.now().add(Duration(seconds: response.data['expires_in'])),
        );
        
        return UserModel.fromJson(response.data['user']);
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
}