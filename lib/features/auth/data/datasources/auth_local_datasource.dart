import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:pos_moloni_app/core/constants/api_constants.dart';
import 'package:pos_moloni_app/core/errors/exceptions.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/auth/data/models/auth_tokens_model.dart';
import 'package:pos_moloni_app/features/auth/data/models/user_model.dart';

/// Interface do datasource local de autenticação
abstract class AuthLocalDataSource {
  Future<AuthTokensModel?> getStoredTokens();
  Future<void> saveTokens(AuthTokensModel tokens);
  Future<void> clearTokens();
  Future<UserModel?> getStoredUser();
  Future<void> saveUser(UserModel user);
  Future<void> clearUser();
  Future<void> clearAll();
  Future<String?> getUsername();
  Future<void> saveUsername(String username);
}

/// Implementação do datasource local usando FlutterSecureStorage
class AuthLocalDataSourceImpl implements AuthLocalDataSource {

  AuthLocalDataSourceImpl({required this.storage});
  final FlutterSecureStorage storage;

  @override
  Future<AuthTokensModel?> getStoredTokens() async {
    try {
      final accessToken = await storage.read(key: ApiConstants.keyAccessToken);
      final refreshToken = await storage.read(key: ApiConstants.keyRefreshToken);
      final tokenType = await storage.read(key: ApiConstants.keyTokenType);
      final expiresIn = await storage.read(key: ApiConstants.keyExpiresIn);
      final timestampStr = await storage.read(key: ApiConstants.keyTokenTimestamp);

      if (accessToken == null ||
          refreshToken == null ||
          expiresIn == null ||
          timestampStr == null) {
        AppLogger.d('Tokens não encontrados no storage');
        return null;
      }

      final tokens = AuthTokensModel(
        accessToken: accessToken,
        refreshToken: refreshToken,
        tokenType: tokenType ?? 'Bearer',
        expiresIn: int.parse(expiresIn),
        timestamp: DateTime.parse(timestampStr),
      );

      AppLogger.cache('GET', 'auth_tokens', hit: true);
      return tokens;
    } catch (e) {
      AppLogger.e('Erro ao ler tokens', error: e);
      throw const CacheException('Erro ao ler tokens guardados');
    }
  }

  @override
  Future<void> saveTokens(AuthTokensModel tokens) async {
    try {
      await storage.write(
        key: ApiConstants.keyAccessToken,
        value: tokens.accessToken,
      );
      await storage.write(
        key: ApiConstants.keyRefreshToken,
        value: tokens.refreshToken,
      );
      await storage.write(
        key: ApiConstants.keyTokenType,
        value: tokens.tokenType,
      );
      await storage.write(
        key: ApiConstants.keyExpiresIn,
        value: tokens.expiresIn.toString(),
      );
      await storage.write(
        key: ApiConstants.keyTokenTimestamp,
        value: tokens.timestamp.toIso8601String(),
      );

      AppLogger.cache('SAVE', 'auth_tokens');
    } catch (e) {
      AppLogger.e('Erro ao guardar tokens', error: e);
      throw const CacheException('Erro ao guardar tokens');
    }
  }

  @override
  Future<void> clearTokens() async {
    try {
      await storage.delete(key: ApiConstants.keyAccessToken);
      await storage.delete(key: ApiConstants.keyRefreshToken);
      await storage.delete(key: ApiConstants.keyTokenType);
      await storage.delete(key: ApiConstants.keyExpiresIn);
      await storage.delete(key: ApiConstants.keyTokenTimestamp);

      AppLogger.cache('DELETE', 'auth_tokens');
    } catch (e) {
      AppLogger.e('Erro ao limpar tokens', error: e);
      throw const CacheException('Erro ao limpar tokens');
    }
  }

  @override
  Future<UserModel?> getStoredUser() async {
    try {
      final userId = await storage.read(key: ApiConstants.keyUserId);
      final username = await storage.read(key: ApiConstants.keyUsername);

      if (userId == null || username == null) {
        return null;
      }

      final user = UserModel(
        id: userId,
        username: username,
      );

      AppLogger.cache('GET', 'user', hit: true);
      return user;
    } catch (e) {
      AppLogger.e('Erro ao ler utilizador', error: e);
      throw const CacheException('Erro ao ler utilizador guardado');
    }
  }

  @override
  Future<void> saveUser(UserModel user) async {
    try {
      await storage.write(key: ApiConstants.keyUserId, value: user.id);
      await storage.write(key: ApiConstants.keyUsername, value: user.username);

      AppLogger.cache('SAVE', 'user');
    } catch (e) {
      AppLogger.e('Erro ao guardar utilizador', error: e);
      throw const CacheException('Erro ao guardar utilizador');
    }
  }

  @override
  Future<void> clearUser() async {
    try {
      await storage.delete(key: ApiConstants.keyUserId);
      await storage.delete(key: ApiConstants.keyUsername);

      AppLogger.cache('DELETE', 'user');
    } catch (e) {
      AppLogger.e('Erro ao limpar utilizador', error: e);
      throw const CacheException('Erro ao limpar utilizador');
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      await clearTokens();
      await clearUser();

      AppLogger.cache('DELETE', 'all_auth_data');
    } catch (e) {
      AppLogger.e('Erro ao limpar dados de autenticação', error: e);
      throw const CacheException('Erro ao limpar dados');
    }
  }

  @override
  Future<String?> getUsername() async {
    try {
      return await storage.read(key: ApiConstants.keyUsername);
    } catch (e) {
      AppLogger.e('Erro ao ler username', error: e);
      return null;
    }
  }

  @override
  Future<void> saveUsername(String username) async {
    try {
      await storage.write(key: ApiConstants.keyUsername, value: username);
      AppLogger.cache('SAVE', 'username');
    } catch (e) {
      AppLogger.e('Erro ao guardar username', error: e);
      throw const CacheException('Erro ao guardar username');
    }
  }
}
