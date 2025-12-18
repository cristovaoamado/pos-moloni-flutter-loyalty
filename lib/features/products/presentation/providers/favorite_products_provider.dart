import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/company/presentation/providers/company_provider.dart';
import 'package:pos_moloni_app/features/products/data/datasources/favorite_products_cache.dart';
import 'package:pos_moloni_app/features/products/data/datasources/product_remote_datasource.dart';
import 'package:pos_moloni_app/features/products/domain/entities/product.dart';
import 'package:pos_moloni_app/features/products/presentation/providers/product_provider.dart';

/// Estado dos produtos favoritos
class FavoriteProductsState {
  const FavoriteProductsState({
    this.favorites = const [],
    this.isLoading = false,
    this.isLoadingFromApi = false,
    this.error,
    this.loadProgress,
    this.lastUpdate,
  });

  final List<Product> favorites;
  final bool isLoading;
  final bool isLoadingFromApi; // True quando está a carregar da API (não do cache)
  final String? error;
  final String? loadProgress; // Ex: "150/300 produtos"
  final DateTime? lastUpdate;

  bool get hasFavorites => favorites.isNotEmpty;
  bool get isEmpty => favorites.isEmpty && !isLoading;

  FavoriteProductsState copyWith({
    List<Product>? favorites,
    bool? isLoading,
    bool? isLoadingFromApi,
    String? error,
    String? loadProgress,
    DateTime? lastUpdate,
    bool clearError = false,
    bool clearProgress = false,
  }) {
    return FavoriteProductsState(
      favorites: favorites ?? this.favorites,
      isLoading: isLoading ?? this.isLoading,
      isLoadingFromApi: isLoadingFromApi ?? this.isLoadingFromApi,
      error: clearError ? null : (error ?? this.error),
      loadProgress: clearProgress ? null : (loadProgress ?? this.loadProgress),
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }
}

/// Provider do cache de favoritos
final favoriteProductsCacheProvider = Provider<FavoriteProductsCache>((ref) {
  return FavoriteProductsCache();
});

/// Provider principal dos produtos favoritos
final favoriteProductsProvider = StateNotifierProvider<FavoriteProductsNotifier, FavoriteProductsState>((ref) {
  final dataSource = ref.watch(productDataSourceProvider);
  final cache = ref.watch(favoriteProductsCacheProvider);
  return FavoriteProductsNotifier(dataSource, cache, ref);
});

/// Notifier para gerir produtos favoritos
class FavoriteProductsNotifier extends StateNotifier<FavoriteProductsState> {
  FavoriteProductsNotifier(
    this._dataSource,
    this._cache,
    this._ref,
  ) : super(const FavoriteProductsState());

  final ProductRemoteDataSource _dataSource;
  final FavoriteProductsCache _cache;
  final Ref _ref;

  /// Carrega os produtos favoritos (cache primeiro, API se necessário)
  Future<void> loadFavorites({bool forceRefresh = false}) async {
    // Obter ID da empresa actual
    final company = _ref.read(companyProvider).selectedCompany;
    if (company == null) {
      AppLogger.w('⚠️ Nenhuma empresa selecionada para carregar favoritos');
      return;
    }

    final companyId = company.id;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // 1. Verificar se há cache válido (e não forçou refresh)
      if (!forceRefresh) {
        final isCacheValid = await _cache.isCacheValid(companyId);
        
        if (isCacheValid) {
          final cachedFavorites = await _cache.getFavorites(companyId);
          
          if (cachedFavorites != null && cachedFavorites.isNotEmpty) {
            final lastUpdate = await _cache.getLastUpdate();
            
            // ═══════════════════════════════════════════════════════════════════
            // CORRECÇÃO: Converter explicitamente ProductModel para Product
            // ═══════════════════════════════════════════════════════════════════
            final favoriteEntities = <Product>[];
            for (final model in cachedFavorites) {
              favoriteEntities.add(model.toEntity());
            }
            
            state = state.copyWith(
              favorites: favoriteEntities,
              isLoading: false,
              lastUpdate: lastUpdate,
              clearProgress: true,
            );
            
            AppLogger.i('⭐ ${cachedFavorites.length} favoritos carregados do cache');
            return;
          }
        }
      }

      // 2. Carregar da API
      AppLogger.i('⭐ A carregar favoritos da API...');
      state = state.copyWith(isLoadingFromApi: true);

      final favorites = await _dataSource.loadFavoriteProducts(
        onProgress: (loaded, estimated) {
          final progress = estimated != null 
              ? '$loaded/$estimated produtos'
              : '$loaded produtos';
          
          state = state.copyWith(loadProgress: progress);
        },
      );

      // 3. Guardar no cache
      await _cache.saveFavorites(favorites, companyId);

      // 4. Actualizar estado
      // ═══════════════════════════════════════════════════════════════════════
      // CORRECÇÃO: Converter explicitamente ProductModel para Product
      // ═══════════════════════════════════════════════════════════════════════
      final favoriteEntities = <Product>[];
      for (final model in favorites) {
        favoriteEntities.add(model.toEntity());
      }

      state = state.copyWith(
        favorites: favoriteEntities,
        isLoading: false,
        isLoadingFromApi: false,
        lastUpdate: DateTime.now(),
        clearProgress: true,
      );

      AppLogger.i('⭐ ${favorites.length} favoritos carregados e guardados no cache');
    } catch (e) {
      AppLogger.e('❌ Erro ao carregar favoritos', error: e);
      
      // Tentar usar cache mesmo que expirado
      try {
        final cachedFavorites = await _cache.getFavorites(companyId);
        if (cachedFavorites != null && cachedFavorites.isNotEmpty) {
          // ═══════════════════════════════════════════════════════════════════
          // CORRECÇÃO: Converter explicitamente ProductModel para Product
          // ═══════════════════════════════════════════════════════════════════
          final favoriteEntities = <Product>[];
          for (final model in cachedFavorites) {
            favoriteEntities.add(model.toEntity());
          }
          
          state = state.copyWith(
            favorites: favoriteEntities,
            isLoading: false,
            isLoadingFromApi: false,
            error: 'Usando cache (erro ao actualizar)',
            clearProgress: true,
          );
          return;
        }
      } catch (_) {}
      
      state = state.copyWith(
        isLoading: false,
        isLoadingFromApi: false,
        error: 'Erro ao carregar favoritos: $e',
        clearProgress: true,
      );
    }
  }

  /// Força actualização dos favoritos (ignora cache)
  Future<void> refreshFavorites() async {
    await loadFavorites(forceRefresh: true);
  }

  /// Limpa os favoritos (usado ao mudar de empresa ou logout)
  Future<void> clearFavorites() async {
    await _cache.clearCache();
    state = const FavoriteProductsState();
    AppLogger.i('🗑️ Favoritos limpos');
  }
}
