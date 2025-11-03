import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:pos_moloni_app/core/constants/api_constants.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';

/// Cliente HTTP configurado para a API Moloni
class ApiClient {
  ApiClient({required FlutterSecureStorage storage}) : _storage = storage {
    _dio = _initDio();
  }
  Dio get dio => _dio;

  late final Dio _dio;
  final FlutterSecureStorage _storage;

  /// Inicializar Dio com configurações padrão
  Dio _initDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: ApiConstants.connectTimeout),
        sendTimeout: const Duration(seconds: ApiConstants.sendTimeout),
        receiveTimeout: const Duration(seconds: ApiConstants.receiveTimeout),
        headers: {
          ApiConstants.headerContentType: ApiConstants.contentTypeJson,
          ApiConstants.headerAccept: ApiConstants.contentTypeJson,
        },
      ),
    );

    // Adicionar interceptores
    dio.interceptors.add(_TokenInterceptor(_storage));
    dio.interceptors.add(_LoggingInterceptor());

    return dio;
  }

  /// GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
}

/// Interceptador para adicionar tokens
class _TokenInterceptor extends Interceptor {
  _TokenInterceptor(this._storage);
  final FlutterSecureStorage _storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      // Obter token armazenado
      final accessToken = await _storage.read(key: ApiConstants.keyAccessToken);

      if (accessToken != null && accessToken.isNotEmpty) {
        // Adicionar token ao header
        options.headers[ApiConstants.headerAuthorization] =
            '${ApiConstants.tokenPrefix}$accessToken';
      }

      return handler.next(options);
    } catch (e) {
      AppLogger.e('Erro ao adicionar token', error: e);
      return handler.next(options);
    }
  }
}

/// Interceptador para logging
class _LoggingInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    AppLogger.network(
      'REQUEST',
      method: options.method,
      url: options.uri.toString(),
    );
    return handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    AppLogger.network(
      'RESPONSE',
      method: response.requestOptions.method,
      url: response.requestOptions.uri.toString(),
      statusCode: response.statusCode,
    );
    return handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    AppLogger.network(
      'ERROR',
      method: err.requestOptions.method,
      url: err.requestOptions.uri.toString(),
      statusCode: err.response?.statusCode,
      error: err.message,
    );
    return handler.next(err);
  }
}
