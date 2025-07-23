import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/auth_token_model.dart';
import '../../../../core/errors/exceptions.dart';

abstract class IAuthLocalDataSource {
  Future<void> cacheUser(UserModel user);
  Future<UserModel?> getCachedUser();
  Future<void> clearCache();
  
  Future<void> saveTokens(AuthTokenModel tokens);
  Future<AuthTokenModel?> getTokens();
  Future<void> clearTokens();
  
  Future<void> saveBiometricEnabled(bool enabled);
  Future<bool> isBiometricEnabled();
}

class AuthLocalDataSource implements IAuthLocalDataSource {
  final SharedPreferences sharedPreferences;
  final FlutterSecureStorage secureStorage;
  
  static const String cachedUserKey = 'CACHED_USER';
  static const String accessTokenKey = 'ACCESS_TOKEN';
  static const String refreshTokenKey = 'REFRESH_TOKEN';
  static const String tokenExpiryKey = 'TOKEN_EXPIRY';
  static const String biometricEnabledKey = 'BIOMETRIC_ENABLED';
  
  AuthLocalDataSource({
    required this.sharedPreferences,
    FlutterSecureStorage? secureStorage,
  }) : secureStorage = secureStorage ?? const FlutterSecureStorage();
  
  @override
  Future<void> cacheUser(UserModel user) async {
    try {
      final userJson = json.encode(user.toJson());
      await sharedPreferences.setString(cachedUserKey, userJson);
    } catch (e) {
      throw CacheException('Failed to cache user: $e');
    }
  }
  
  @override
  Future<UserModel?> getCachedUser() async {
    try {
      final userJson = sharedPreferences.getString(cachedUserKey);
      if (userJson != null) {
        final userMap = json.decode(userJson) as Map<String, dynamic>;
        return UserModel.fromJson(userMap);
      }
      return null;
    } catch (e) {
      throw CacheException('Failed to get cached user: $e');
    }
  }
  
  @override
  Future<void> clearCache() async {
    try {
      await sharedPreferences.remove(cachedUserKey);
    } catch (e) {
      throw CacheException('Failed to clear cache: $e');
    }
  }
  
  @override
  Future<void> saveTokens(AuthTokenModel tokens) async {
    try {
      // Store tokens securely
      await secureStorage.write(
        key: accessTokenKey,
        value: tokens.accessToken,
      );
      await secureStorage.write(
        key: refreshTokenKey,
        value: tokens.refreshToken,
      );
      
      // Store expiry time in shared preferences
      await sharedPreferences.setInt(
        tokenExpiryKey,
        tokens.expiresAt.millisecondsSinceEpoch,
      );
    } catch (e) {
      throw CacheException('Failed to save tokens: $e');
    }
  }
  
  @override
  Future<AuthTokenModel?> getTokens() async {
    try {
      final accessToken = await secureStorage.read(key: accessTokenKey);
      final refreshToken = await secureStorage.read(key: refreshTokenKey);
      final expiryMillis = sharedPreferences.getInt(tokenExpiryKey);
      
      if (accessToken != null && refreshToken != null && expiryMillis != null) {
        return AuthTokenModel(
          accessToken: accessToken,
          refreshToken: refreshToken,
          expiresAt: DateTime.fromMillisecondsSinceEpoch(expiryMillis),
        );
      }
      return null;
    } catch (e) {
      throw CacheException('Failed to get tokens: $e');
    }
  }
  
  @override
  Future<void> clearTokens() async {
    try {
      await secureStorage.delete(key: accessTokenKey);
      await secureStorage.delete(key: refreshTokenKey);
      await sharedPreferences.remove(tokenExpiryKey);
    } catch (e) {
      throw CacheException('Failed to clear tokens: $e');
    }
  }
  
  @override
  Future<void> saveBiometricEnabled(bool enabled) async {
    try {
      await sharedPreferences.setBool(biometricEnabledKey, enabled);
    } catch (e) {
      throw CacheException('Failed to save biometric preference: $e');
    }
  }
  
  @override
  Future<bool> isBiometricEnabled() async {
    try {
      return sharedPreferences.getBool(biometricEnabledKey) ?? false;
    } catch (e) {
      throw CacheException('Failed to get biometric preference: $e');
    }
  }
}