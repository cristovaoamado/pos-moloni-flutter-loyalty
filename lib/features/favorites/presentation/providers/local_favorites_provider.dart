import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/company/presentation/providers/company_provider.dart';
import 'package:pos_moloni_app/features/favorites/data/datasources/favorites_local_datasource.dart';
import 'package:pos_moloni_app/features/favorites/data/models/favorite_product_model.dart';
import 'package:pos_moloni_app/features/products/data/datasources/product_remote_datasource.dart';
import 'package:pos_moloni_app/features/products/domain/entities/product.dart';
import 'package:pos_moloni_app/features/products/presentation/providers/product_provider.dart';

/// Estado dos favoritos locais
class LocalFavoritesState {
  const LocalFavoritesState({
    this.favorites = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
    this.lastSync,
  });

  final List<FavoriteProductModel> favorites;
  final bool isLoading;
  final bool isSyncing; // True quando está a sincronizar com a API
  final String? error;
  final DateTime? lastSync;

  int get count => favorites.length;
  bool get isEmpty => favorites.isEmpty;
  bool get hasError => error != null;

  /// Verifica se um produto é favorito
  bool isFavorite(int productId) {
    return favorites.any((f) => f.productId == productId);
  }

  LocalFavoritesState copyWith({
    List<FavoriteProductModel>? favorites,
    bool? isLoading,
    bool? isSyncing,
    String? error,
    DateTime? lastSync,
    bool clearError = false,
  }) {
    return LocalFavoritesState(
      favorites: favorites ?? this.favorites,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: clearError ? null : (error ?? this.error),
      lastSync: lastSync ?? this.lastSync,
    );
  }
}

/// Provider do datasource de favoritos
final favoritesDataSourceProvider = Provider<FavoritesLocalDataSource>((ref) {
  return FavoritesLocalDataSource();
});

/// Provider principal de favoritos locais
final localFavoritesProvider =
    StateNotifierProvider<LocalFavoritesNotifier, LocalFavoritesState>((ref) {
  final dataSource = ref.watch(favoritesDataSourceProvider);
  final productDataSource = ref.watch(productDataSourceProvider);
  return LocalFavoritesNotifier(dataSource, productDataSource, ref);
});

/// Provider para verificar se um produto específico é favorito
final isFavoriteProvider = Provider.family<bool, int>((ref, productId) {
  final state = ref.watch(localFavoritesProvider);
  return state.isFavorite(productId);
});

/// Notifier para gerir favoritos locais
class LocalFavoritesNotifier extends StateNotifier<LocalFavoritesState> {
  LocalFavoritesNotifier(
    this._dataSource,
    this._productDataSource,
    this._ref,
  ) : super(const LocalFavoritesState()) {
    // Carregar favoritos ao iniciar
    _initAndLoad();
  }

  final FavoritesLocalDataSource _dataSource;
  final ProductRemoteDataSource _productDataSource;
  final Ref _ref;
  
  Timer? _syncTimer;
  static const Duration _syncInterval = Duration(hours: 1);

  Future<void> _initAndLoad() async {
    await loadFavorites();
    _startPeriodicSync();
  }

  /// Inicia sincronização periódica
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) {
      AppLogger.d('⏰ Sincronização periódica de favoritos');
      syncFavorites();
    });
  }

  /// Carrega os favoritos do armazenamento local
  Future<void> loadFavorites() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final company = _ref.read(companyProvider).selectedCompany;
      final companyId = company?.id ?? 0;

      final favorites = await _dataSource.getAllForCompany(companyId);
      final lastSync = await _dataSource.getLastSync();

      state = state.copyWith(
        favorites: favorites,
        isLoading: false,
        lastSync: lastSync,
      );

      AppLogger.i('⭐ ${favorites.length} favoritos carregados');
    } catch (e) {
      AppLogger.e('❌ Erro ao carregar favoritos', error: e);
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao carregar favoritos: $e',
      );
    }
  }

  /// Adiciona um produto aos favoritos
  Future<void> addFavorite(Product product) async {
    try {
      final favorite = FavoriteProductModel.fromProduct(
        productId: product.id,
        name: product.name,
        reference: product.reference,
        ean: product.ean,
        price: product.price,
        image: product.image,
        categoryId: product.categoryId,
        taxRate: product.totalTaxRate,
      );

      await _dataSource.addFavorite(favorite);

      // Actualizar estado
      final newFavorites = [...state.favorites, favorite];
      state = state.copyWith(favorites: newFavorites);

      AppLogger.i('⭐ Adicionado aos favoritos: ${product.name}');
    } catch (e) {
      AppLogger.e('❌ Erro ao adicionar favorito', error: e);
      state = state.copyWith(error: 'Erro ao adicionar favorito');
    }
  }

  /// Remove um produto dos favoritos
  Future<void> removeFavorite(int productId) async {
    try {
      await _dataSource.removeFavorite(productId);

      // Actualizar estado
      final newFavorites = state.favorites
          .where((f) => f.productId != productId)
          .toList();
      state = state.copyWith(favorites: newFavorites);

      AppLogger.i('⭐ Removido dos favoritos: $productId');
    } catch (e) {
      AppLogger.e('❌ Erro ao remover favorito', error: e);
      state = state.copyWith(error: 'Erro ao remover favorito');
    }
  }

  /// Alterna o estado de favorito de um produto
  Future<bool> toggleFavorite(Product product) async {
    final isFav = state.isFavorite(product.id);

    if (isFav) {
      await removeFavorite(product.id);
      return false;
    } else {
      await addFavorite(product);
      return true;
    }
  }

  /// Sincroniza os favoritos com a API (actualiza preços, nomes, etc.)
  Future<void> syncFavorites() async {
    if (state.favorites.isEmpty) {
      AppLogger.d('⭐ Nenhum favorito para sincronizar');
      return;
    }

    state = state.copyWith(isSyncing: true);

    try {
      AppLogger.i('🔄 A sincronizar ${state.favorites.length} favoritos...');

      final updatedFavorites = <FavoriteProductModel>[];
      int successCount = 0;
      int errorCount = 0;

      for (final fav in state.favorites) {
        try {
          // Buscar dados actualizados do produto
          final product = await _productDataSource.getProductByReference(fav.reference);

          if (product != null) {
            final updated = fav.copyWithUpdatedData(
              name: product.name,
              price: product.price,
              image: product.image,
              taxRate: product.totalTaxRate,
            );
            updatedFavorites.add(updated);
            successCount++;
          } else {
            // Produto não encontrado - manter dados antigos
            updatedFavorites.add(fav);
            AppLogger.w('⚠️ Produto não encontrado: ${fav.reference}');
          }
        } catch (e) {
          // Erro ao buscar - manter dados antigos
          updatedFavorites.add(fav);
          errorCount++;
        }

        // Pequena pausa para não sobrecarregar a API
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Actualizar no storage
      await _dataSource.updateMultiple(updatedFavorites);
      await _dataSource.setLastSync(DateTime.now());

      state = state.copyWith(
        favorites: updatedFavorites,
        isSyncing: false,
        lastSync: DateTime.now(),
      );

      AppLogger.i('✅ Sincronização completa: $successCount actualizados, $errorCount erros');
    } catch (e) {
      AppLogger.e('❌ Erro na sincronização', error: e);
      state = state.copyWith(
        isSyncing: false,
        error: 'Erro na sincronização: $e',
      );
    }
  }

  /// Limpa todos os favoritos
  Future<void> clearAll() async {
    try {
      await _dataSource.clear();
      state = state.copyWith(favorites: [], lastSync: null);
      AppLogger.i('🗑️ Todos os favoritos removidos');
    } catch (e) {
      AppLogger.e('❌ Erro ao limpar favoritos', error: e);
    }
  }

  /// Limpa o erro
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}
