import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:pos_moloni_app/core/constants/api_constants.dart';
import 'package:pos_moloni_app/core/errors/exceptions.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/products/data/models/product_model.dart';

/// Interface do datasource remoto de produtos
abstract class ProductRemoteDataSource {
  /// Pesquisa produtos
  Future<List<ProductModel>> searchProducts({
    required String query,
    int limit = 50,
    int offset = 0,
  });

  /// Obtém produto por código de barras
  Future<ProductModel?> getProductByBarcode(String barcode);

  /// Obtém produto por referência
  Future<ProductModel?> getProductByReference(String reference);

  /// Obtém todos os produtos
  Future<List<ProductModel>> getAllProducts({
    int limit = 100,
    int offset = 0,
  });
}

/// Implementação usando Dio
class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {

  ProductRemoteDataSourceImpl({
    required this.dio,
    required this.storage,
  });
  final Dio dio;
  final FlutterSecureStorage storage;

  @override
  Future<List<ProductModel>> searchProducts({
    required String query,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final apiUrl = await storage.read(key: ApiConstants.keyApiUrl) ??
          ApiConstants.defaultMoloniApiUrl;
      final accessToken = await storage.read(key: ApiConstants.keyAccessToken);
      final companyId = await storage.read(key: ApiConstants.keyCompanyId);

      if (accessToken == null || companyId == null) {
        throw const AuthenticationException('Autenticação inválida');
      }

      final url =
          '$apiUrl/${ApiConstants.productsSearch}?access_token=$accessToken';

      AppLogger.moloniApi(
        'products/search',
        data: {
          'query': query,
          'limit': limit,
          'offset': offset,
        },
      );

      final response = await dio.get(
        url,
        queryParameters: {
          'query': query,
          'company_id': companyId,
          'limit': limit,
          'offset': offset,
        },
      );

      if (response.statusCode == 200 && response.data is List) {
        final products = (response.data as List)
            .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
            .toList();

        AppLogger.i('✅ ${products.length} produtos encontrados');
        return products;
      }

      throw ServerException(
        'Resposta inválida do servidor',
        response.statusCode.toString(),
      );
    } on DioException catch (e) {
      AppLogger.e('Erro ao pesquisar produtos', error: e);

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
      AppLogger.e('Erro inesperado ao pesquisar produtos', error: e);

      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ProductModel?> getProductByBarcode(String barcode) async {
    try {
      final apiUrl = await storage.read(key: ApiConstants.keyApiUrl) ??
          ApiConstants.defaultMoloniApiUrl;
      final accessToken = await storage.read(key: ApiConstants.keyAccessToken);
      final companyId = await storage.read(key: ApiConstants.keyCompanyId);

      if (accessToken == null || companyId == null) {
        throw const AuthenticationException('Autenticação inválida');
      }

      final url =
          '$apiUrl/${ApiConstants.productsGetByBarcode}?access_token=$accessToken';

      AppLogger.moloniApi('products/getByBarcode', data: {'barcode': barcode});

      final response = await dio.get(
        url,
        queryParameters: {
          'company_id': companyId,
          'ean': barcode,
        },
      );

      if (response.statusCode == 200 && response.data is Map) {
        final product =
            ProductModel.fromJson(response.data as Map<String, dynamic>);

        AppLogger.i('✅ Produto encontrado por código de barras');
        return product;
      }

      if (response.statusCode == 404) {
        AppLogger.d('Produto não encontrado');
        return null;
      }

      throw ServerException(
        'Resposta inválida do servidor',
        response.statusCode.toString(),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }

      if (e.response?.statusCode == 401) {
        throw const TokenExpiredException();
      }

      throw ServerException(
        e.response?.data?.toString() ?? 'Erro no servidor',
        e.response?.statusCode.toString(),
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ProductModel?> getProductByReference(String reference) async {
    try {
      final apiUrl = await storage.read(key: ApiConstants.keyApiUrl) ??
          ApiConstants.defaultMoloniApiUrl;
      final accessToken = await storage.read(key: ApiConstants.keyAccessToken);
      final companyId = await storage.read(key: ApiConstants.keyCompanyId);

      if (accessToken == null || companyId == null) {
        throw const AuthenticationException('Autenticação inválida');
      }

      final url =
          '$apiUrl/${ApiConstants.productsGetByReference}?access_token=$accessToken';

      AppLogger.moloniApi(
        'products/getByReference',
        data: {
          'reference': reference,
        },
      );

      final response = await dio.get(
        url,
        queryParameters: {
          'company_id': companyId,
          'reference': reference,
        },
      );

      if (response.statusCode == 200 && response.data is Map) {
        final product =
            ProductModel.fromJson(response.data as Map<String, dynamic>);

        AppLogger.i('✅ Produto encontrado por referência');
        return product;
      }

      if (response.statusCode == 404) {
        AppLogger.d('Produto não encontrado');
        return null;
      }

      throw ServerException(
        'Resposta inválida do servidor',
        response.statusCode.toString(),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }

      if (e.response?.statusCode == 401) {
        throw const TokenExpiredException();
      }

      throw ServerException(
        e.response?.data?.toString() ?? 'Erro no servidor',
        e.response?.statusCode.toString(),
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<ProductModel>> getAllProducts({
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final apiUrl = await storage.read(key: ApiConstants.keyApiUrl) ??
          ApiConstants.defaultMoloniApiUrl;
      final accessToken = await storage.read(key: ApiConstants.keyAccessToken);
      final companyId = await storage.read(key: ApiConstants.keyCompanyId);

      if (accessToken == null || companyId == null) {
        throw const AuthenticationException('Autenticação inválida');
      }

      final url =
          '$apiUrl/${ApiConstants.productsGetAll}?access_token=$accessToken';

      AppLogger.moloniApi(
        'products/getAll',
        data: {
          'limit': limit,
          'offset': offset,
        },
      );

      final response = await dio.get(
        url,
        queryParameters: {
          'company_id': companyId,
          'limit': limit,
          'offset': offset,
        },
      );

      if (response.statusCode == 200 && response.data is List) {
        final products = (response.data as List)
            .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
            .toList();

        AppLogger.i('✅ ${products.length} produtos carregados');
        return products;
      }

      throw ServerException(
        'Resposta inválida do servidor',
        response.statusCode.toString(),
      );
    } on DioException catch (e) {
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
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }
}
