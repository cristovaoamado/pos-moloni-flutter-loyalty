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

/// Callback para progresso do carregamento de produtos
typedef ProductLoadProgressCallback = void Function(int loaded, int? estimated);

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

  /// Obtém produtos de uma categoria específica
  Future<List<ProductModel>> getProductsByCategory({
    required int categoryId,
    int limit = 50,
    int offset = 0,
  });

  /// Carrega TODOS os produtos recursivamente (para extrair favoritos)
  /// [onProgress] é chamado com (produtos carregados, estimativa total)
  Future<List<ProductModel>> loadAllProductsRecursively({
    ProductLoadProgressCallback? onProgress,
  });

  /// Carrega apenas os produtos favoritos (filtra localmente após carregar todos)
  Future<List<ProductModel>> loadFavoriteProducts({
    ProductLoadProgressCallback? onProgress,
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
          // A API pode retornar String ou int
          final countValue = data['count'];
          final count = countValue is int ? countValue : int.tryParse(countValue.toString()) ?? 0;
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
        final products = _parseProductList(response.data as List);

        // Calcular total estimado
        final bool hasMore = products.length == limit;
        final int estimatedTotal = hasMore 
            ? offset + products.length + limit
            : offset + products.length;

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

  /// Parse seguro de uma lista de produtos
  /// Ignora produtos com erros de parsing em vez de falhar todo o batch
  List<ProductModel> _parseProductList(List<dynamic> jsonList) {
    final products = <ProductModel>[];
    
    for (int i = 0; i < jsonList.length; i++) {
      try {
        final json = jsonList[i];
        if (json is Map<String, dynamic>) {
          products.add(ProductModel.fromJson(json));
        } else {
          AppLogger.w('⚠️ Produto $i não é um Map: ${json.runtimeType}');
        }
      } catch (e) {
        // Log do erro mas continua com os outros produtos
        AppLogger.w('⚠️ Erro ao fazer parsing do produto $i: $e');
      }
    }
    
    return products;
  }

  @override
  Future<ProductModel?> getProductByBarcode(String barcode) async {
    final products = await searchByBarcode(barcode);
    return products.isNotEmpty ? products.first : null;
  }

  /// Pesquisa produtos por código de barras (EAN)
  Future<List<ProductModel>> searchByBarcode(String barcode) async {
    try {
      final apiUrl = await storage.read(key: ApiConstants.keyApiUrl) ??
          ApiConstants.defaultMoloniApiUrl;
      final accessToken = await storage.read(key: ApiConstants.keyAccessToken);
      final companyId = await storage.read(key: ApiConstants.keyCompanyId);

      if (accessToken == null || companyId == null) {
        throw const AuthenticationException('Autenticação inválida');
      }

      final url = '$apiUrl/products/getByEAN/?access_token=$accessToken';

      AppLogger.moloniApi('products/getByEAN', data: {
        'company_id': companyId,
        'ean': barcode,
      },);

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

      AppLogger.d('📦 getByEAN Response status: ${response.statusCode}');
      AppLogger.d('📦 getByEAN Response type: ${response.data.runtimeType}');

      if (response.statusCode == 200) {
        if (response.data is List) {
          final products = _parseProductList(response.data as List);
          AppLogger.i('✅ ${products.length} produto(s) encontrado(s) por EAN: $barcode');
          return products;
        } else if (response.data is Map && !(response.data as Map).containsKey('error')) {
          try {
            final product = ProductModel.fromJson(response.data as Map<String, dynamic>);
            AppLogger.i('✅ 1 produto encontrado por EAN: $barcode');
            return [product];
          } catch (e) {
            AppLogger.w('⚠️ Erro ao fazer parsing do produto por EAN: $e');
          }
        }
        
        AppLogger.d('📦 Nenhum produto encontrado para EAN: $barcode');
        return [];
      }

      return [];
    } on DioException catch (e) {
      AppLogger.e('Erro ao pesquisar por EAN', error: e);
      
      if (e.response?.statusCode == 404) {
        return [];
      }

      if (e.response?.statusCode == 401) {
        throw const TokenExpiredException();
      }

      return [];
    } catch (e) {
      AppLogger.e('Erro inesperado ao pesquisar por EAN', error: e);
      if (e is AppException) rethrow;
      return [];
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
          try {
            final product = ProductModel.fromJson(response.data as Map<String, dynamic>);
            AppLogger.i('✅ Produto encontrado por referência');
            return product;
          } catch (e) {
            AppLogger.w('⚠️ Erro ao fazer parsing do produto: $e');
            return null;
          }
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
        final products = _parseProductList(response.data as List);
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

  @override
  Future<List<ProductModel>> getProductsByCategory({
    required int categoryId,
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

      final url = '$apiUrl/products/getAll/?access_token=$accessToken';

      AppLogger.moloniApi(
        'products/getAll (category)',
        data: {
          'company_id': companyId,
          'category_id': categoryId,
          'qty': limit,
          'offset': offset,
        },
      );

      final response = await dio.post(
        url,
        data: {
          'company_id': companyId,
          'category_id': categoryId,
          'qty': limit,
          'offset': offset,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      if (response.statusCode == 200 && response.data is List) {
        final products = _parseProductList(response.data as List);
        AppLogger.d('✅ ${products.length} produtos da categoria $categoryId');
        return products;
      }

      return [];
    } on DioException catch (e) {
      AppLogger.e('Erro ao carregar produtos da categoria', error: e);

      if (e.response?.statusCode == 401) {
        throw const TokenExpiredException();
      }

      return [];
    } catch (e) {
      AppLogger.e('Erro inesperado ao carregar produtos da categoria', error: e);
      return [];
    }
  }

  @override
  Future<List<ProductModel>> loadAllProductsRecursively({
    ProductLoadProgressCallback? onProgress,
  }) async {
    final allProducts = <ProductModel>[];
    int offset = 0;
    const int batchSize = 50;
    int? estimatedTotal;

    AppLogger.i('🔄 Iniciando carregamento recursivo de todos os produtos...');

    try {
      final apiUrl = await storage.read(key: ApiConstants.keyApiUrl) ??
          ApiConstants.defaultMoloniApiUrl;
      final accessToken = await storage.read(key: ApiConstants.keyAccessToken);
      final companyId = await storage.read(key: ApiConstants.keyCompanyId);

      if (accessToken == null || companyId == null) {
        throw const AuthenticationException('Autenticação inválida');
      }

      // Tentar obter contagem total
      try {
        final countUrl = '$apiUrl/products/countBySearch/?access_token=$accessToken';
        final countResponse = await dio.post(
          countUrl,
          data: {
            'company_id': companyId,
            'search': '',
          },
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
        
        if (countResponse.statusCode == 200 && countResponse.data is Map) {
          final countValue = countResponse.data['count'];
          estimatedTotal = countValue is int 
              ? countValue 
              : int.tryParse(countValue.toString());
          AppLogger.d('📊 Total estimado de produtos: $estimatedTotal');
        }
      } catch (e) {
        AppLogger.w('⚠️ Não foi possível obter contagem total: $e');
      }

      // ═══════════════════════════════════════════════════════════════════════
      // USAR products/getAll SEM category_id (funciona no Moloni)
      // ═══════════════════════════════════════════════════════════════════════
      while (true) {
        final url = '$apiUrl/products/getAll/?access_token=$accessToken';

        AppLogger.d('📡 A carregar lote: offset=$offset, qty=$batchSize');

        final response = await dio.post(
          url,
          data: {
            'company_id': companyId,
            'qty': batchSize,
            'offset': offset,
            // NÃO enviar category_id - isto retorna TODOS os produtos
          },
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );

        AppLogger.d('📦 Response status: ${response.statusCode}');
        AppLogger.d('📦 Response type: ${response.data.runtimeType}');

        // Log do primeiro elemento para debug
        if (response.data is List && (response.data as List).isNotEmpty) {
          final firstItem = (response.data as List).first;
          AppLogger.d('📦 Primeiro item tipo: ${firstItem.runtimeType}');
          if (firstItem is Map) {
            AppLogger.d('📦 Primeiro produto: ${firstItem['name']} (ID: ${firstItem['product_id']})');
          }
        }

        if (response.statusCode == 200 && response.data is List) {
          final batch = _parseProductList(response.data as List);

          allProducts.addAll(batch);

          // Notificar progresso
          onProgress?.call(allProducts.length, estimatedTotal);

          AppLogger.d('📦 Lote carregado: ${batch.length} produtos (total: ${allProducts.length})');

          // Se veio menos que o batch size, chegámos ao fim
          if (batch.length < batchSize) {
            AppLogger.i('✅ Carregamento completo: ${allProducts.length} produtos totais');
            break;
          }

          offset += batchSize;

          // Pequena pausa para não sobrecarregar a API
          await Future.delayed(const Duration(milliseconds: 100));
        } else {
          // Log da resposta para debug
          AppLogger.w('⚠️ Resposta inesperada: ${response.data}');
          break;
        }
      }

      // Log de alguns produtos para verificar o campo pos_favorite
      if (allProducts.isNotEmpty) {
        AppLogger.d('📊 Amostra de produtos carregados:');
        for (final p in allProducts.take(5)) {
          AppLogger.d('   - ${p.name}: posFavorite=${p.posFavorite}');
        }
      }

      return allProducts;
    } on DioException catch (e) {
      AppLogger.e('❌ Erro ao carregar produtos recursivamente', error: e);

      if (e.response?.statusCode == 401) {
        throw const TokenExpiredException();
      }

      // Retornar o que já foi carregado
      return allProducts;
    } catch (e) {
      AppLogger.e('❌ Erro inesperado ao carregar produtos', error: e);
      if (e is AppException) rethrow;
      
      // Retornar o que já foi carregado
      return allProducts;
    }
  }

  @override
  Future<List<ProductModel>> loadFavoriteProducts({
    ProductLoadProgressCallback? onProgress,
  }) async {
    AppLogger.i('⭐ A carregar produtos favoritos...');

    // Carregar todos os produtos
    final allProducts = await loadAllProductsRecursively(onProgress: onProgress);

    // Filtrar apenas os favoritos
    final favorites = allProducts.where((p) => p.posFavorite).toList();

    AppLogger.i('⭐ ${favorites.length} produtos favoritos encontrados de ${allProducts.length} totais');

    // Log dos favoritos encontrados
    if (favorites.isNotEmpty) {
      AppLogger.d('⭐ Favoritos encontrados:');
      for (final fav in favorites.take(10)) {
        AppLogger.d('   - ${fav.name} (ID: ${fav.id})');
      }
      if (favorites.length > 10) {
        AppLogger.d('   ... e mais ${favorites.length - 10}');
      }
    } else {
      AppLogger.w('⚠️ Nenhum produto tem pos_favorite=true');
    }

    return favorites;
  }
}
