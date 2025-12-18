import 'package:hive_flutter/hive_flutter.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/favorites/data/models/favorite_product_model.dart';

/// Datasource local para gerir produtos favoritos
class FavoritesLocalDataSource {
  static const String _boxName = 'local_favorites';
  static const String _metaBoxName = 'local_favorites_meta';
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _companyIdKey = 'company_id';

  Box<FavoriteProductModel>? _box;
  Box<dynamic>? _metaBox;

  /// Lock para evitar múltiplas inicializações em paralelo
  Future<void>? _initFuture;

  /// Inicialização segura (executa apenas uma vez)
  Future<void> _initialize() {
    _initFuture ??= _doInitialize();
    return _initFuture!;
  }

  Future<void> _doInitialize() async {
    if (_box?.isOpen == true && _metaBox?.isOpen == true) return;

    _box = await Hive.openBox<FavoriteProductModel>(_boxName);
    _metaBox = await Hive.openBox(_metaBoxName);

    AppLogger.d('⭐ FavoritesLocalDataSource inicializado');
  }

  /// Obtém todos os favoritos
  Future<List<FavoriteProductModel>> getAll() async {
    await _initialize();
    return _box!.values.toList(growable: false);
  }

  /// Obtém todos os favoritos para uma empresa específica
  Future<List<FavoriteProductModel>> getAllForCompany(int companyId) async {
    await _initialize();

    final storedCompanyId = _metaBox!.get(_companyIdKey) as int?;

    if (storedCompanyId != null && storedCompanyId != companyId) {
      AppLogger.w(
        '⚠️ Empresa mudou ($storedCompanyId → $companyId), a limpar favoritos',
      );
      await clear();
      await _metaBox!.put(_companyIdKey, companyId);
      return [];
    }

    if (storedCompanyId == null) {
      await _metaBox!.put(_companyIdKey, companyId);
    }

    return getAll();
  }

  /// Verifica se um produto é favorito
  Future<bool> isFavorite(int productId) async {
    await _initialize();
    return _box!.containsKey(productId);
  }

  /// Adiciona um produto aos favoritos
  Future<void> addFavorite(FavoriteProductModel favorite) async {
    await _initialize();
    await _box!.put(favorite.productId, favorite);
    AppLogger.i('⭐ Produto adicionado aos favoritos: ${favorite.name}');
  }

  /// Remove um produto dos favoritos
  Future<void> removeFavorite(int productId) async {
    await _initialize();
    final favorite = _box!.get(productId);
    if (favorite != null) {
      await _box!.delete(productId);
      AppLogger.i('⭐ Produto removido dos favoritos: ${favorite.name}');
    }
  }

  /// Alterna o estado de favorito
  Future<bool> toggleFavorite(FavoriteProductModel favorite) async {
    await _initialize();

    if (_box!.containsKey(favorite.productId)) {
      await removeFavorite(favorite.productId);
      return false;
    } else {
      await addFavorite(favorite);
      return true;
    }
  }

  /// Actualiza um favorito
  Future<void> updateFavorite(FavoriteProductModel favorite) async {
    await _initialize();
    if (_box!.containsKey(favorite.productId)) {
      await _box!.put(favorite.productId, favorite);
      AppLogger.d('⭐ Favorito actualizado: ${favorite.name}');
    }
  }

  /// Actualiza múltiplos favoritos (versão optimizada)
  Future<void> updateMultiple(List<FavoriteProductModel> favorites) async {
    await _initialize();

    final updates = <int, FavoriteProductModel>{
      for (final fav in favorites)
        if (_box!.containsKey(fav.productId)) fav.productId: fav,
    };

    if (updates.isNotEmpty) {
      await _box!.putAll(updates);
      AppLogger.i('⭐ ${updates.length} favoritos actualizados');
    }
  }

  /// Obtém um favorito por ID
  Future<FavoriteProductModel?> getFavorite(int productId) async {
    await _initialize();
    return _box!.get(productId);
  }

  /// Última sincronização
  Future<DateTime?> getLastSync() async {
    await _initialize();
    final timestamp = _metaBox!.get(_lastSyncKey) as String?;
    return timestamp != null ? DateTime.tryParse(timestamp) : null;
  }

  /// Define a data da última sincronização
  Future<void> setLastSync(DateTime dateTime) async {
    await _initialize();
    await _metaBox!.put(_lastSyncKey, dateTime.toIso8601String());
  }

  /// Limpa todos os favoritos
  Future<void> clear() async {
    await _initialize();
    await _box!.clear();
    AppLogger.i('🗑️ Todos os favoritos foram removidos');
  }

  /// Total de favoritos
  Future<int> get count async {
    await _initialize();
    return _box!.length;
  }

  /// Fecha as boxes
  Future<void> close() async {
    await _box?.close();
    await _metaBox?.close();
  }
}