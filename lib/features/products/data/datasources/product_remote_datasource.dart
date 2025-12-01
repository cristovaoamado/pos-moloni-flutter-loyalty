import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:pos_moloni_app/core/constants/api_constants.dart';
import 'package:pos_moloni_app/core/errors/exceptions.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/products/data/models/product_model.dart';

/// Resultado de pesquisa com info de paginação
class ProductSearchResult {
  const ProductSearchResult({
    required this.products,
    required this.totalCount,
    required this.offset,
  });

  final List<ProductModel> products;
  final int totalCount;
  final int offset;

  bool get hasMore => offset + products.length < totalCount;
}

/// Interface do datasource remoto de produtos
abstract class ProductRemoteDataSource {
  /// Conta produtos por pesquisa
  Future<int> countBySearch(String query);

  /// Pesquisa produtos com paginação
  Future<ProductSearchResult> searchProducts({
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
  Future<int> countBySearch(String query) async {
    try {
      final apiUrl = await storage.read(key: ApiConstants.keyApiUrl) ??
          ApiConstants.defaultMoloniApiUrl;
      final accessToken = await storage.read(key: ApiConstants.keyAccessToken);
      final companyId = await storage.read(key: ApiConstants.keyCompanyId);

      if (accessToken == null) {
        throw const AuthenticationException('Token de acesso não encontrado');
      }

      if (companyId == null) {
        throw const AuthenticationException('Empresa não selecionada');
      }

      final url = '$apiUrl/products/countBySearch/?access_token=$accessToken';

      AppLogger.d('🔢 [ProductDS] countBySearch: $query');

      final response = await dio.post(
        url,
        data: {
          'company_id': companyId,
          'search': query,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data.containsKey('count')) {
          final count = data['count'] as int;
          AppLogger.d('🔢 Total: $count produtos');
          return count;
        }
      }

      return 0;
    } catch (e) {
      AppLogger.e('Erro ao contar produtos', error: e);
      return 0;
    }
  }

  @override
  Future<ProductSearchResult> searchProducts({
    required String query,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final apiUrl = await storage.read(key: ApiConstants.keyApiUrl) ??
          ApiConstants.defaultMoloniApiUrl;
      final accessToken = await storage.read(key: ApiConstants.keyAccessToken);
      final companyId = await storage.read(key: ApiConstants.keyCompanyId);

      AppLogger.d('🔍 [ProductDS] searchProducts');
      AppLogger.d('   - apiUrl: $apiUrl');
      AppLogger.d('   - accessToken: ${accessToken != null ? '***' : 'null'}');
      AppLogger.d('   - companyId: $companyId');
      AppLogger.d('   - offset: $offset, limit: $limit');

      if (accessToken == null) {
        throw const AuthenticationException('Token de acesso não encontrado');
      }

      if (companyId == null) {
        throw const AuthenticationException('Empresa não selecionada');
      }

      final url = '$apiUrl/products/getBySearch/?access_token=$accessToken';

      AppLogger.moloniApi(
        'products/getBySearch',
        data: {
          'company_id': companyId,
          'search': query,
          'qty': limit,
          'offset': offset,
        },
      );

      final response = await dio.post(
        url,
        data: {
          'company_id': companyId,
          'search': query,
          'qty': limit,
          'offset': offset,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      AppLogger.d('📦 Response status: ${response.statusCode}');
      AppLogger.d('📦 Response data type: ${response.data.runtimeType}');

      if (response.statusCode == 200 && response.data is List) {
        final products = (response.data as List)
            .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
            .toList();

        // Calcular total estimado:
        // - Se retornou menos que o limite, sabemos o total exato
        // - Se retornou exatamente o limite, há potencialmente mais
        final bool hasMore = products.length == limit;
        final int estimatedTotal = hasMore 
            ? offset + products.length + limit  // Estimativa: pelo menos mais uma página
            : offset + products.length;         // Total exato

        AppLogger.i('✅ ${products.length} produtos encontrados (estimatedTotal: $estimatedTotal, hasMore: $hasMore)');
        
        return ProductSearchResult(
          products: products,
          totalCount: estimatedTotal,
          offset: offset,
        );
      }

      if (response.data is Map && (response.data as Map).containsKey('error')) {
        throw ServerException(
          response.data['error_description'] ?? 'Erro desconhecido',
          response.statusCode.toString(),
        );
      }

      throw ServerException(
        'Resposta inválida do servidor',
        response.statusCode.toString(),
      );
    } on DioException catch (e) {
      AppLogger.e('Erro ao pesquisar produtos', error: e);
      AppLogger.d('📦 Response data: ${e.response?.data}');

      if (e.response?.statusCode == 401) {
        throw const TokenExpiredException();
      } else if (e.response?.statusCode == 403) {
        final errorDesc = e.response?.data?['error_description'] ?? 'Acesso negado';
        throw ServerException(errorDesc, '403');
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

      final url = '$apiUrl/${ApiConstants.productsGetByBarcode}/?access_token=$accessToken';

      AppLogger.moloniApi('products/getByBarcode', data: {'ean': barcode});

      final response = await dio.post(
        url,
        data: {
          'company_id': companyId,
          'ean': barcode,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200) {
        if (response.data is Map && (response.data as Map).isNotEmpty) {
          if ((response.data as Map).containsKey('error')) {
            AppLogger.d('Produto não encontrado');
            return null;
          }
          final product = ProductModel.fromJson(response.data as Map<String, dynamic>);
          AppLogger.i('✅ Produto encontrado por código de barras');
          return product;
        }
        // Lista vazia ou resposta sem dados
        return null;
      }

      return null;
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

      final url = '$apiUrl/${ApiConstants.productsGetByReference}/?access_token=$accessToken';

      AppLogger.moloniApi('products/getByReference', data: {'reference': reference});

      final response = await dio.post(
        url,
        data: {
          'company_id': companyId,
          'reference': reference,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200) {
        if (response.data is Map && (response.data as Map).isNotEmpty) {
          if ((response.data as Map).containsKey('error')) {
            AppLogger.d('Produto não encontrado');
            return null;
          }
          final product = ProductModel.fromJson(response.data as Map<String, dynamic>);
          AppLogger.i('✅ Produto encontrado por referência');
          return product;
        }
        return null;
      }

      return null;
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

      final url = '$apiUrl/${ApiConstants.productsGetAll}/?access_token=$accessToken';

      AppLogger.moloniApi(
        'products/getAll',
        data: {
          'company_id': companyId,
          'qty': limit,
          'offset': offset,
        },
      );

      final response = await dio.post(
        url,
        data: {
          'company_id': companyId,
          'qty': limit,
          'offset': offset,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
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
      AppLogger.e('Erro ao carregar produtos', error: e);

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
