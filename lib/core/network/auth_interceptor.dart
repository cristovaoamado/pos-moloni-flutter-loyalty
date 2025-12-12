import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:pos_moloni_app/core/constants/api_constants.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';

/// Resultado da tentativa de recuperação de autenticação
enum AuthRecoveryResult {
  /// Token renovado com sucesso via refresh_token
  refreshed,
  
  /// Re-login feito com sucesso usando credenciais guardadas
  reloggedIn,
  
  /// Falha total - precisa de login manual
  failed,
}

/// Callback para quando precisa de re-login
typedef OnReloginRequired = Future<bool> Function(String username, String password);

/// Callback para quando falha tudo e precisa de login manual
typedef OnLoginRequired = void Function();

/// Callback para obter refresh token actual
typedef GetRefreshToken = Future<String?> Function();

/// Callback para guardar novos tokens
typedef SaveTokens = Future<void> Function(Map<String, dynamic> tokenData);

/// Interceptor Dio que automaticamente renova tokens expirados
/// 
/// Fluxo de recuperação:
/// 1. Detecta erro 401 (Unauthorized)
/// 2. Tenta refresh_token
/// 3. Se falhar, tenta re-login com credenciais guardadas
/// 4. Se falhar, encaminha para login manual
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.storage,
    required this.onRefreshToken,
    required this.onSaveTokens,
    required this.onRelogin,
    required this.onLoginRequired,
    this.maxRetries = 1,
  });

  final FlutterSecureStorage storage;
  final Future<Map<String, dynamic>?> Function(String refreshToken) onRefreshToken;
  final SaveTokens onSaveTokens;
  final OnReloginRequired onRelogin;
  final OnLoginRequired onLoginRequired;
  final int maxRetries;

  /// Flag para evitar loops de refresh
  bool _isRefreshing = false;
  
  /// Completer para requests que esperam pelo refresh
  Completer<bool>? _refreshCompleter;
  
  /// Contador de tentativas
  // int _retryCount = 0;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Só tratar erros 401 (Unauthorized) ou erros de token expirado
    if (!_isTokenError(err)) {
      return handler.next(err);
    }

    AppLogger.w('🔐 Token expirado detectado - iniciando recuperação...');

    // Se já está a fazer refresh, esperar
    if (_isRefreshing) {
      AppLogger.d('🔄 Já está a fazer refresh, aguardando...');
      final success = await _refreshCompleter?.future ?? false;
      if (success) {
        // Retry o request original
        return _retryRequest(err.requestOptions, handler);
      } else {
        return handler.next(err);
      }
    }

    // Iniciar processo de recuperação
    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();

    try {
      final result = await _attemptRecovery();
      
      _refreshCompleter?.complete(result != AuthRecoveryResult.failed);
      
      if (result == AuthRecoveryResult.failed) {
        AppLogger.e('❌ Recuperação de autenticação falhou - requer login manual');
        onLoginRequired();
        return handler.next(err);
      }

      AppLogger.i('✅ Autenticação recuperada: ${result.name}');
      
      // Retry o request original com o novo token
      return _retryRequest(err.requestOptions, handler);
      
    } catch (e) {
      AppLogger.e('❌ Erro durante recuperação de autenticação', error: e);
      _refreshCompleter?.complete(false);
      onLoginRequired();
      return handler.next(err);
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
      // _retryCount = 0;
    }
  }

  /// Verifica se é um erro de token
  bool _isTokenError(DioException err) {
    // Erro 401 Unauthorized
    if (err.response?.statusCode == 401) return true;
    
    // Verificar mensagem de erro
    final responseData = err.response?.data;
    if (responseData is Map) {
      final error = responseData['error']?.toString().toLowerCase() ?? '';
      final errorDescription = responseData['error_description']?.toString().toLowerCase() ?? '';
      
      if (error.contains('invalid_token') ||
          error.contains('expired') ||
          errorDescription.contains('token') ||
          errorDescription.contains('expired')) {
        return true;
      }
    }
    
    return false;
  }

  /// Tenta recuperar a autenticação
  Future<AuthRecoveryResult> _attemptRecovery() async {
    // 1. Tentar refresh_token
    AppLogger.d('🔄 Tentativa 1: Refresh token...');
    final refreshResult = await _tryRefreshToken();
    if (refreshResult) {
      return AuthRecoveryResult.refreshed;
    }

    // 2. Tentar re-login com credenciais guardadas
    AppLogger.d('🔄 Tentativa 2: Re-login com credenciais guardadas...');
    final reloginResult = await _tryRelogin();
    if (reloginResult) {
      return AuthRecoveryResult.reloggedIn;
    }

    // 3. Falha total
    return AuthRecoveryResult.failed;
  }

  /// Tenta renovar usando refresh_token
  Future<bool> _tryRefreshToken() async {
    try {
      final refreshToken = await storage.read(key: ApiConstants.keyRefreshToken);
      
      if (refreshToken == null || refreshToken.isEmpty) {
        AppLogger.d('❌ Nenhum refresh_token disponível');
        return false;
      }

      AppLogger.d('🔄 A chamar API de refresh_token...');
      final newTokens = await onRefreshToken(refreshToken);
      
      if (newTokens == null) {
        AppLogger.d('❌ Refresh token falhou - resposta nula');
        return false;
      }

      // Guardar novos tokens
      await onSaveTokens(newTokens);
      AppLogger.i('✅ Tokens renovados com sucesso via refresh_token');
      
      return true;
    } catch (e) {
      AppLogger.w('❌ Refresh token falhou: $e');
      return false;
    }
  }

  /// Tenta re-login com credenciais guardadas
  Future<bool> _tryRelogin() async {
    try {
      // Credenciais guardadas pelo utilizador no Settings/Login
      final username = await storage.read(key: 'moloni_username');
      final password = await storage.read(key: 'moloni_password');

      if (username == null || username.isEmpty ||
          password == null || password.isEmpty) {
        AppLogger.d('❌ Nenhumas credenciais guardadas para re-login');
        return false;
      }

      AppLogger.d('🔄 A fazer re-login com credenciais guardadas...');
      final success = await onRelogin(username, password);
      
      if (success) {
        AppLogger.i('✅ Re-login automático bem-sucedido');
      } else {
        AppLogger.w('❌ Re-login falhou - credenciais podem estar incorrectas');
      }
      
      return success;
    } catch (e) {
      AppLogger.w('❌ Re-login falhou: $e');
      return false;
    }
  }

  /// Retry o request original com o novo token
  Future<void> _retryRequest(
    RequestOptions requestOptions,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      // Obter novo access token
      final newAccessToken = await storage.read(key: ApiConstants.keyAccessToken);
      
      if (newAccessToken == null) {
        throw Exception('Novo token não disponível após refresh');
      }

      // Actualizar o token no request
      // O Moloni usa o token como query parameter, não header
      final uri = Uri.parse(requestOptions.path);
      final newParams = Map<String, dynamic>.from(uri.queryParameters);
      newParams['access_token'] = newAccessToken;
      
      final newUri = uri.replace(queryParameters: newParams.map((k, v) => MapEntry(k, v.toString())));
      
      AppLogger.d('🔄 A repetir request com novo token...');
      
      // Criar novo Dio para evitar interceptor loop
      final dio = Dio(BaseOptions(
        connectTimeout: requestOptions.connectTimeout,
        receiveTimeout: requestOptions.receiveTimeout,
      ),);
      
      final response = await dio.request(
        newUri.toString(),
        data: requestOptions.data,
        options: Options(
          method: requestOptions.method,
          headers: requestOptions.headers,
        ),
      );

      return handler.resolve(response);
    } catch (e) {
      AppLogger.e('❌ Retry do request falhou', error: e);
      return handler.reject(
        DioException(
          requestOptions: requestOptions,
          error: e,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }
}

/// Extensão para facilitar a configuração do interceptor
extension DioAuthExtension on Dio {
  void addAuthInterceptor({
    required FlutterSecureStorage storage,
    required Future<Map<String, dynamic>?> Function(String refreshToken) onRefreshToken,
    required SaveTokens onSaveTokens,
    required OnReloginRequired onRelogin,
    required OnLoginRequired onLoginRequired,
  }) {
    interceptors.add(
      AuthInterceptor(
        storage: storage,
        onRefreshToken: onRefreshToken,
        onSaveTokens: onSaveTokens,
        onRelogin: onRelogin,
        onLoginRequired: onLoginRequired,
      ),
    );
  }
}
