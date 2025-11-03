import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:pos_moloni_app/features/products/data/datasources/product_local_datasource.dart';
import 'package:pos_moloni_app/features/products/data/datasources/product_remote_datasource.dart';
import 'package:pos_moloni_app/features/products/data/repositories/product_repository_impl.dart';
import 'package:pos_moloni_app/features/products/domain/entities/product.dart';
import 'package:pos_moloni_app/features/products/domain/repositories/product_repository.dart';
import 'package:pos_moloni_app/features/products/domain/usecases/search_products_usecase.dart';
import 'package:pos_moloni_app/features/products/domain/usecases/product_usecases.dart' show GetProductByBarcodeUseCase, GetProductByReferenceUseCase, GetCachedProductsUseCase, ClearProductsCacheUseCase;

// ==================== PROVIDERS DE DEPENDÊNCIAS ====================

/// Provider do ProductLocalDataSource
final productLocalDataSourceProvider = Provider<ProductLocalDataSource>((ref) {
  return ProductLocalDataSourceImpl();
});

/// Provider do ProductRemoteDataSource
final productRemoteDataSourceProvider = Provider<ProductRemoteDataSource>((ref) {
  return ProductRemoteDataSourceImpl(
    dio: ref.watch(dioProvider),
    storage: ref.watch(secureStorageProvider),
  );
});

/// Provider do ProductRepository
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepositoryImpl(
    remoteDataSource: ref.watch(productRemoteDataSourceProvider),
    localDataSource: ref.watch(productLocalDataSourceProvider),
  );
});

// ==================== PROVIDERS DE USE CASES ====================

/// Provider do SearchProductsUseCase
final searchProductsUseCaseProvider = Provider<SearchProductsUseCase>((ref) {
  return SearchProductsUseCase(ref.watch(productRepositoryProvider));
});

/// Provider do GetProductByBarcodeUseCase
final getProductByBarcodeUseCaseProvider = Provider<GetProductByBarcodeUseCase>((ref) {
  return GetProductByBarcodeUseCase(ref.watch(productRepositoryProvider));
});

/// Provider do GetProductByReferenceUseCase
final getProductByReferenceUseCaseProvider =
    Provider<GetProductByReferenceUseCase>((ref) {
  return GetProductByReferenceUseCase(ref.watch(productRepositoryProvider));
});

/// Provider do GetCachedProductsUseCase
final getCachedProductsUseCaseProvider = Provider<GetCachedProductsUseCase>((ref) {
  return GetCachedProductsUseCase(ref.watch(productRepositoryProvider));
});

/// Provider do ClearProductsCacheUseCase
final clearProductsCacheUseCaseProvider = Provider<ClearProductsCacheUseCase>((ref) {
  return ClearProductsCacheUseCase(ref.watch(productRepositoryProvider));
});

// ==================== PROVIDER DE ESTADO ====================

/// Estado de produtos
class ProductState {
  const ProductState({
    this.products = const [],
    this.selectedProduct,
    this.isLoading = false,
    this.error,
    this.lastQuery = '',
  });

  final List<Product> products;
  final Product? selectedProduct;
  final bool isLoading;
  final String? error;
  final String lastQuery;

  ProductState copyWith({
    List<Product>? products,
    Product? selectedProduct,
    bool? isLoading,
    String? error,
    String? lastQuery,
  }) {
    return ProductState(
      products: products ?? this.products,
      selectedProduct: selectedProduct ?? this.selectedProduct,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastQuery: lastQuery ?? this.lastQuery,
    );
  }
}

/// Notifier para gestão do estado de produtos
class ProductNotifier extends StateNotifier<ProductState> {
  ProductNotifier({
    required this.searchProductsUseCase,
    required this.getProductByBarcodeUseCase,
    required this.getProductByReferenceUseCase,
    required this.getCachedProductsUseCase,
    required this.clearProductsCacheUseCase,
  }) : super(const ProductState()) {
    // Carregar produtos cacheados ao inicializar
    _loadCachedProducts();
  }

  final SearchProductsUseCase searchProductsUseCase;
  final GetProductByBarcodeUseCase getProductByBarcodeUseCase;
  final GetProductByReferenceUseCase getProductByReferenceUseCase;
  final GetCachedProductsUseCase getCachedProductsUseCase;
  final ClearProductsCacheUseCase clearProductsCacheUseCase;

  /// Carregar produtos cacheados
  Future<void> _loadCachedProducts() async {
    final result = await getCachedProductsUseCase();

    result.fold(
      (failure) {
        AppLogger.d('Nenhum produto em cache ou erro ao carregar');
      },
      (products) {
        if (products.isNotEmpty) {
          AppLogger.i('✅ ${products.length} produtos carregados do cache');
          state = state.copyWith(products: products);
        }
      },
    );
  }

  /// Pesquisar produtos
  Future<void> searchProducts(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(products: [], lastQuery: '');
      return;
    }

    AppLogger.i('🔍 Pesquisando: "$query"');

    state = state.copyWith(isLoading: true, error: null);

    final result = await searchProductsUseCase(
      query: query,
      limit: 50,
    );

    result.fold(
      (failure) {
        AppLogger.e('❌ Erro na pesquisa: ${failure.message}');
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (products) {
        AppLogger.i('✅ ${products.length} produtos encontrados');
        state = state.copyWith(
          products: products,
          isLoading: false,
          error: null,
          lastQuery: query,
        );
      },
    );
  }

  /// Procurar produto por código de barras
  Future<Product?> searchByBarcode(String barcode) async {
    AppLogger.i('🔍 Procurando por código de barras: $barcode');

    state = state.copyWith(isLoading: true, error: null);

    final result = await getProductByBarcodeUseCase(barcode);

    return result.fold(
      (failure) {
        AppLogger.e('❌ Erro ao procurar: ${failure.message}');
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
        return null;
      },
      (product) {
        if (product != null) {
          AppLogger.i('✅ Produto encontrado: ${product.name}');
          state = state.copyWith(
            selectedProduct: product,
            isLoading: false,
            error: null,
          );
        } else {
          AppLogger.w('⚠️ Produto não encontrado');
          state = state.copyWith(
            isLoading: false,
            error: 'Produto não encontrado',
          );
        }
        return product;
      },
    );
  }

  /// Procurar produto por referência
  Future<Product?> searchByReference(String reference) async {
    AppLogger.i('🔍 Procurando por referência: $reference');

    state = state.copyWith(isLoading: true, error: null);

    final result = await getProductByReferenceUseCase(reference);

    return result.fold(
      (failure) {
        AppLogger.e('❌ Erro ao procurar: ${failure.message}');
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
        return null;
      },
      (product) {
        if (product != null) {
          AppLogger.i('✅ Produto encontrado: ${product.name}');
          state = state.copyWith(
            selectedProduct: product,
            isLoading: false,
            error: null,
          );
        } else {
          AppLogger.w('⚠️ Produto não encontrado');
          state = state.copyWith(
            isLoading: false,
            error: 'Produto não encontrado',
          );
        }
        return product;
      },
    );
  }

  /// Selecionar produto
  void selectProduct(Product product) {
    AppLogger.i('📌 Selecionando: ${product.name}');
    state = state.copyWith(selectedProduct: product);
  }

  /// Desselecionar produto
  void deselectProduct() {
    state = state.copyWith(selectedProduct: null);
  }

  /// Limpar resultados de pesquisa
  void clearSearchResults() {
    state = state.copyWith(products: [], lastQuery: '');
  }

  /// Limpar erro
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Limpar cache
  Future<void> clearCache() async {
    AppLogger.i('🗑️ Limpando cache');

    final result = await clearProductsCacheUseCase();

    result.fold(
      (failure) {
        AppLogger.e('❌ Erro ao limpar: ${failure.message}');
      },
      (_) {
        AppLogger.i('✅ Cache limpo');
        state = state.copyWith(products: []);
      },
    );
  }
}

/// Provider do ProductNotifier
final productProvider = StateNotifierProvider<ProductNotifier, ProductState>((ref) {
  return ProductNotifier(
    searchProductsUseCase: ref.watch(searchProductsUseCaseProvider),
    getProductByBarcodeUseCase: ref.watch(getProductByBarcodeUseCaseProvider),
    getProductByReferenceUseCase: ref.watch(getProductByReferenceUseCaseProvider),
    getCachedProductsUseCase: ref.watch(getCachedProductsUseCaseProvider),
    clearProductsCacheUseCase: ref.watch(clearProductsCacheUseCaseProvider),
  );
});

/// Provider conveniente para verificar se tem produtos
final hasProductsProvider = Provider<bool>((ref) {
  return ref.watch(productProvider).products.isNotEmpty;
});

/// Provider conveniente para obter produto selecionado
final selectedProductProvider = Provider<Product?>((ref) {
  return ref.watch(productProvider).selectedProduct;
});
