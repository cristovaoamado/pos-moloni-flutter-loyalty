import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:pos_moloni_app/core/constants/api_constants.dart';
import 'package:pos_moloni_app/core/errors/exceptions.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/auth/data/models/auth_tokens_model.dart';

/// Interface do datasource remoto de autenticação
abstract class AuthRemoteDataSource {
  Future<AuthTokensModel> login({
    required String username,
    required String password,
  });

  Future<AuthTokensModel> refreshToken(String refreshToken);
}

/// Implementação do datasource remoto usando Dio
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {

  AuthRemoteDataSourceImpl({
    required this.dio,
    required this.storage,
  });
  final Dio dio;
  final FlutterSecureStorage storage;

  @override
  Future<AuthTokensModel> login({
    required String username,
    required String password,
  }) async {
    try {
      // Obter credenciais da API
      final apiUrl = await storage.read(key: ApiConstants.keyApiUrl) ??
          ApiConstants.defaultMoloniApiUrl;
      final clientId = await storage.read(key: ApiConstants.keyClientId);
      final clientSecret = await storage.read(key: ApiConstants.keyClientSecret);

      if (clientId == null || clientSecret == null) {
        throw const ConfigurationException(
          'Client ID ou Client Secret não configurados',
        );
      }

      // Construir query parameters
      final params = {
        'grant_type': ApiConstants.grantTypePassword,
        'client_id': clientId,
        'client_secret': clientSecret,
        'username': username,
        'password': password,
      };

      final queryString = _buildQueryString(params);
      final url = '$apiUrl/${ApiConstants.grantEndpoint}?$queryString';

      AppLogger.moloniApi('grant (login)', data: {
        'username': username,
        'grant_type': 'password',
      },);

      // Fazer request
      final response = await dio.get(url);

      AppLogger.i('📡 Response Status: ${response.statusCode}');
      AppLogger.i('📡 Response Data Type: ${response.data.runtimeType}');
      AppLogger.i('📡 Response Data: ${response.data}');

      // ✅ Verificar se status é 200 e data existe
      if (response.statusCode == 200) {
        // Tentar converter independentemente do tipo
        final data = response.data;

        if (data == null) {
          throw const ServerException(
            'Resposta vazia do servidor',
            '200',
          );
        }

        // Se for String, fazer parse JSON
        if (data is String) {
          try {
            final Map<String, dynamic> jsonData =
                (response.data as String).isEmpty
                    ? {}
                    : response.data as Map<String, dynamic>;
            final tokens = AuthTokensModel.fromJson(jsonData);
            AppLogger.auth('Login', success: true);
            return tokens;
          } catch (e) {
            AppLogger.e('Erro ao fazer parse da resposta', error: e);
            rethrow;
          }
        }

        // Se for Map, usar direto
        if (data is Map) {
          final jsonData = Map<String, dynamic>.from(data);
          final tokens = AuthTokensModel.fromJson(jsonData);
          AppLogger.auth('Login', success: true);
          return tokens;
        }

        // Se for outra coisa, erro
        throw ServerException(
          'Tipo de resposta não esperado: ${data.runtimeType}',
          '200',
        );
      }

      throw ServerException(
        'Resposta inválida do servidor',
        response.statusCode.toString(),
      );
    } on DioException catch (e) {
      AppLogger.auth('Login', success: false);

      AppLogger.i('📡 DioException Status: ${e.response?.statusCode}');
      AppLogger.i('📡 DioException Type: ${e.type}');
      AppLogger.i('📡 DioException Message: ${e.message}');
      AppLogger.i('📡 DioException Response: ${e.response?.data}');

      if (e.response?.statusCode == 401) {
        throw const InvalidCredentialsException();
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const TimeoutException();
      } else if (e.type == DioExceptionType.connectionError) {
        throw const NetworkException();
      }

      throw ServerException(
        e.response?.data?.toString() ?? e.message ?? 'Erro no servidor',
        e.response?.statusCode.toString() ?? 'unknown',
      );
    } catch (e) {
      AppLogger.e('Erro no login', error: e);

      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<AuthTokensModel> refreshToken(String refreshToken) async {
    try {
      // Obter credenciais da API
      final apiUrl = await storage.read(key: ApiConstants.keyApiUrl) ??
          ApiConstants.defaultMoloniApiUrl;
      final clientId = await storage.read(key: ApiConstants.keyClientId);
      final clientSecret = await storage.read(key: ApiConstants.keyClientSecret);

      if (clientId == null || clientSecret == null) {
        throw const ConfigurationException(
          'Client ID ou Client Secret não configurados',
        );
      }

      // Construir query parameters
      final params = {
        'grant_type': ApiConstants.grantTypeRefreshToken,
        'client_id': clientId,
        'client_secret': clientSecret,
        'refresh_token': refreshToken,
      };

      final queryString = _buildQueryString(params);
      final url = '$apiUrl/${ApiConstants.grantEndpoint}?$queryString';

      AppLogger.moloniApi('grant (refresh_token)');

      // Fazer request
      final response = await dio.get(url);

      AppLogger.i('📡 Refresh Response Status: ${response.statusCode}');
      AppLogger.i('📡 Refresh Response Data: ${response.data}');

      // ✅ Verificar se status é 200
      if (response.statusCode == 200) {
        final data = response.data;

        if (data == null) {
          throw const ServerException(
            'Resposta vazia do servidor',
            '200',
          );
        }

        // Se for String, fazer parse JSON
        if (data is String) {
          try {
            final Map<String, dynamic> jsonData =
                data.isEmpty ? {} : data as Map<String, dynamic>;
            final tokens = AuthTokensModel.fromJson(jsonData);
            AppLogger.auth('Token refresh', success: true);
            return tokens;
          } catch (e) {
            AppLogger.e('Erro ao fazer parse da resposta', error: e);
            rethrow;
          }
        }

        // Se for Map, usar direto
        if (data is Map) {
          final jsonData = Map<String, dynamic>.from(data);
          final tokens = AuthTokensModel.fromJson(jsonData);
          AppLogger.auth('Token refresh', success: true);
          return tokens;
        }

        throw ServerException(
          'Tipo de resposta não esperado: ${data.runtimeType}',
          '200',
        );
      }

      throw ServerException(
        'Resposta inválida do servidor',
        response.statusCode.toString(),
      );
    } on DioException catch (e) {
      AppLogger.auth('Token refresh', success: false);

      if (e.response?.statusCode == 401) {
        throw const TokenExpiredException();
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const TimeoutException();
      } else if (e.type == DioExceptionType.connectionError) {
        throw const NetworkException();
      }

      throw ServerException(
        e.response?.data?.toString() ?? 'Erro no servidor',
        e.response?.statusCode.toString(),
      );
    } catch (e) {
      AppLogger.e('Erro no refresh token', error: e);

      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  /// Helper para construir query string
  String _buildQueryString(Map<String, String> params) {
    return params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}
