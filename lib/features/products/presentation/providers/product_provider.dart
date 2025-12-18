import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:pos_moloni_app/features/products/data/datasources/product_remote_datasource.dart';
import 'package:pos_moloni_app/features/products/data/models/product_model.dart';
import 'package:pos_moloni_app/features/products/domain/entities/product.dart';

/// Estado dos produtos com suporte a paginação
class ProductState {
  const ProductState({
    this.products = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.currentQuery = '',
    this.currentOffset = 0,
    this.totalCount = 0,
    this.scannedProduct,
  });

  final List<Product> products;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String currentQuery;
  final int currentOffset;
  final int totalCount;
  
  /// Produto único lido pelo scanner (para mostrar em destaque)
  final Product? scannedProduct;

  bool get hasMore => currentOffset < totalCount;
  
  /// Página atual (1-based)
  int get currentPage => (currentOffset / 50).floor() + 1;
  
  /// Total de páginas
  int get totalPages => (totalCount / 50).ceil();
  
  /// Se tem um produto scaneado para mostrar em destaque
  bool get hasScannedProduct => scannedProduct != null;

  ProductState copyWith({
    List<Product>? products,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    String? currentQuery,
    int? currentOffset,
    int? totalCount,
    Product? scannedProduct,
    bool clearScannedProduct = false,
  }) {
    return ProductState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      currentQuery: currentQuery ?? this.currentQuery,
      currentOffset: currentOffset ?? this.currentOffset,
      totalCount: totalCount ?? this.totalCount,
      scannedProduct: clearScannedProduct ? null : (scannedProduct ?? this.scannedProduct),
    );
  }
}

/// Provider do datasource
final productDataSourceProvider = Provider<ProductRemoteDataSource>((ref) {
  final dio = Dio();
  final secureStorage = ref.watch(secureStorageProvider);
  return ProductRemoteDataSourceImpl(dio: dio, storage: secureStorage);
});

/// Provider principal de produtos
final productProvider = StateNotifierProvider<ProductNotifier, ProductState>((ref) {
  final dataSource = ref.watch(productDataSourceProvider);
  return ProductNotifier(dataSource);
});

/// Notifier para gerir estado dos produtos
class ProductNotifier extends StateNotifier<ProductState> {
  ProductNotifier(this._dataSource) : super(const ProductState());

  final ProductRemoteDataSource _dataSource;
  static const int _pageSize = 50;

  /// Pesquisa produtos (nova pesquisa, reset da paginação)
  Future<void> searchProducts(String query) async {
    if (query.length < 3) {
      clearSearchResults();
      return;
    }

    // Se é a mesma query e já temos resultados, não pesquisar novamente
    if (query == state.currentQuery && state.products.isNotEmpty) {
      return;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      currentQuery: query,
      currentOffset: 0,
      totalCount: 0,
      clearScannedProduct: true, // Limpar produto scaneado ao pesquisar
    );

    try {
      AppLogger.i('🔍 A pesquisar produtos: $query');

      final result = await _dataSource.searchProducts(
        query: query,
        limit: _pageSize,
        offset: 0,
      );

      // Se recebemos menos que o limite na primeira página, esse é o total real
      final actualTotal = result.products.length < _pageSize 
          ? result.products.length 
          : result.totalCount;

      AppLogger.i('✅ ${result.products.length} de $actualTotal produtos');

      // ═══════════════════════════════════════════════════════════════════════
      // CORRECÇÃO: Converter ProductModel para Product (entity)
      // ═══════════════════════════════════════════════════════════════════════
      final productEntities = result.products.map((m) => m.toEntity()).toList();

      state = state.copyWith(
        products: productEntities,
        isLoading: false,
        currentOffset: result.products.length,
        totalCount: actualTotal,
      );
    } catch (e) {
      AppLogger.e('❌ Erro ao pesquisar produtos: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        products: [],
        totalCount: 0,
      );
    }
  }

  /// Pesquisa produto por código de barras
  /// Retorna Product (entity) ou null
  Future<Product?> searchByBarcode(String barcode) async {
    try {
      AppLogger.i('🔍 A pesquisar por código de barras: $barcode');

      final productModel = await _dataSource.getProductByBarcode(barcode);

      if (productModel != null) {
        AppLogger.i('✅ Produto encontrado: ${productModel.name}');
        // ═══════════════════════════════════════════════════════════════════
        // CORRECÇÃO: Converter ProductModel para Product (entity)
        // ═══════════════════════════════════════════════════════════════════
        return productModel.toEntity();
      }

      AppLogger.d('⚠️ Produto não encontrado');
      return null;
    } catch (e) {
      AppLogger.e('❌ Erro ao pesquisar por código de barras: $e');
      return null;
    }
  }

  /// Carrega mais produtos (paginação)
  Future<void> loadMoreProducts() async {
    // Não carregar se já está a carregar ou não há mais
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }

    if (state.currentQuery.isEmpty) {
      return;
    }

    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      AppLogger.i('📄 A carregar mais produtos (offset: ${state.currentOffset})');

      final result = await _dataSource.searchProducts(
        query: state.currentQuery,
        limit: _pageSize,
        offset: state.currentOffset,
      );

      AppLogger.i('✅ +${result.products.length} produtos carregados');

      final newOffset = state.currentOffset + result.products.length;
      
      // Se recebemos menos que o limite, não há mais produtos
      // Atualizar o totalCount para refletir o total real
      final actualTotal = result.products.length < _pageSize 
          ? newOffset 
          : state.totalCount;

      // ═══════════════════════════════════════════════════════════════════════
      // CORRECÇÃO: Converter ProductModel para Product (entity)
      // ═══════════════════════════════════════════════════════════════════════
      final newProducts = result.products.map((m) => m.toEntity()).toList();

      state = state.copyWith(
        products: [...state.products, ...newProducts],
        isLoadingMore: false,
        currentOffset: newOffset,
        totalCount: actualTotal,
      );
    } catch (e) {
      AppLogger.e('❌ Erro ao carregar mais produtos: $e');
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  /// Limpa os resultados da pesquisa
  void clearSearchResults() {
    state = const ProductState();
  }
  
  /// Limpa apenas o produto scaneado (mantém os resultados da pesquisa)
  void clearScannedProduct() {
    state = state.copyWith(clearScannedProduct: true);
  }

  /// Define um produto único scaneado (para mostrar em destaque)
  /// Aceita ProductModel e converte internamente para Product
  void setScannedProduct(ProductModel product) {
    AppLogger.i('📦 Produto scaneado: ${product.name}');
    
    state = state.copyWith(
      scannedProduct: product.toEntity(),
      // Limpar resultados de pesquisa anteriores
      products: [],
      currentQuery: '',
      currentOffset: 0,
      totalCount: 0,
    );
  }

  /// Define resultados de pesquisa por barcode (múltiplos produtos)
  /// Usado quando o scanner encontra múltiplos produtos
  /// Aceita List<ProductModel> e converte internamente para List<Product>
  void setBarcodeResults(List<ProductModel> products) {
    AppLogger.i('📦 A definir ${products.length} produtos do barcode na grid');
    
    // Converter ProductModel para Product
    final productList = products.map((p) => p.toEntity()).toList();
    
    state = state.copyWith(
      products: productList,
      isLoading: false,
      isLoadingMore: false,
      error: null,
      currentQuery: '[barcode]', // Indicador especial
      currentOffset: productList.length,
      totalCount: productList.length,
      clearScannedProduct: true, // Limpar produto scaneado anterior
    );
  }
}
