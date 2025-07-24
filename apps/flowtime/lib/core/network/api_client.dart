import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../storage/secure_storage.dart';
import '../../shared/router/app_router.dart';
import 'api_endpoints.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(storage, ref);
});

class ApiClient {
  late final Dio _dio;
  final SecureStorage _storage;
  final Ref _ref;
  bool _isRefreshing = false;
  final List<Function> _failedQueue = [];

  ApiClient(this._storage, this._ref) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add auth token to requests
          final token = await _storage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // Handle 401 Unauthorized errors
          if (error.response?.statusCode == 401) {
            // Don't try to refresh if this is already a refresh request
            if (error.requestOptions.path.contains('/auth/refresh')) {
              await _handleAuthFailure();
              handler.reject(error);
              return;
            }

            if (!_isRefreshing) {
              _isRefreshing = true;
              
              try {
                final refreshToken = await _storage.getRefreshToken();
                if (refreshToken != null) {
                  final response = await _dio.post(
                    ApiEndpoints.refreshToken,
                    data: {'refresh_token': refreshToken},
                    options: Options(
                      headers: {
                        'Content-Type': 'application/json',
                      },
                    ),
                  );
                  
                  if (response.statusCode == 200) {
                    final newAccessToken = response.data['access_token'];
                    final newRefreshToken = response.data['refresh_token'] ?? refreshToken;
                    
                    await _storage.saveAccessToken(newAccessToken);
                    await _storage.saveRefreshToken(newRefreshToken);
                    
                    // Retry failed requests
                    _failedQueue.forEach((callback) => callback());
                    _failedQueue.clear();
                    
                    // Retry original request
                    error.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
                    final clonedRequest = await _dio.request(
                      error.requestOptions.path,
                      options: Options(
                        method: error.requestOptions.method,
                        headers: error.requestOptions.headers,
                      ),
                      data: error.requestOptions.data,
                      queryParameters: error.requestOptions.queryParameters,
                    );
                    
                    _isRefreshing = false;
                    return handler.resolve(clonedRequest);
                  }
                }
              } catch (e) {
                // Refresh failed
                _failedQueue.clear();
                _isRefreshing = false;
                await _handleAuthFailure();
                handler.reject(error);
                return;
              }
              
              _isRefreshing = false;
              await _handleAuthFailure();
              handler.reject(error);
              return;
            } else {
              // Add to queue if already refreshing
              final completer = Future(() async {
                final token = await _storage.getAccessToken();
                if (token != null) {
                  error.requestOptions.headers['Authorization'] = 'Bearer $token';
                  final clonedRequest = await _dio.request(
                    error.requestOptions.path,
                    options: Options(
                      method: error.requestOptions.method,
                      headers: error.requestOptions.headers,
                    ),
                    data: error.requestOptions.data,
                    queryParameters: error.requestOptions.queryParameters,
                  );
                  return handler.resolve(clonedRequest);
                }
                handler.reject(error);
              });
              
              _failedQueue.add(() => completer);
              return;
            }
          }
          
          handler.next(error);
        },
      ),
    );
  }

  Future<void> _handleAuthFailure() async {
    // Clear all auth data
    await _storage.clearTokens();
    
    // Sign out the user through the auth provider
    await _ref.read(authNotifierProvider.notifier).signOut();
    
    // Navigate to sign in screen
    final context = _ref.read(routerProvider).routerDelegate.navigatorKey.currentContext;
    if (context != null && context.mounted) {
      context.go('/auth/signin');
    }
  }

  // HTTP methods
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) {
    return _dio.patch(path, data: data);
  }

  Future<Response> delete(String path) {
    return _dio.delete(path);
  }
}