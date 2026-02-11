import 'package:hive_flutter/hive_flutter.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/favorites/data/models/favorite_product_model.dart';
import 'package:pos_moloni_app/features/favorites/data/models/favorite_tax_model.dart';

class FavoritesStorage {
  static const String _boxName = 'favorites';
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // IMPORTANTE: Registar FavoriteTaxModelAdapter ANTES do FavoriteProductModelAdapter
      // porque FavoriteProductModel contém List<FavoriteTaxModel>
      if (!Hive.isAdapterRegistered(21)) {
        Hive.registerAdapter(FavoriteTaxModelAdapter());
        AppLogger.d('⭐ FavoriteTaxModelAdapter registado (typeId: 21)');
      }

      if (!Hive.isAdapterRegistered(20)) {
        Hive.registerAdapter(FavoriteProductModelAdapter());
        AppLogger.d('⭐ FavoriteProductModelAdapter registado (typeId: 20)');
      }

      await Hive.openBox<FavoriteProductModel>(_boxName);

      _initialized = true;
      AppLogger.i('✅ Storage de favoritos inicializado');
    } catch (e, st) {
      AppLogger.e(
        '❌ Erro ao inicializar storage de favoritos',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
