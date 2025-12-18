import 'package:hive_flutter/hive_flutter.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/favorites/data/models/favorite_product_model.dart';

class FavoritesStorage {
  static const String _boxName = 'favorites';
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (!Hive.isAdapterRegistered(20)) {
        Hive.registerAdapter(FavoriteProductModelAdapter());
        AppLogger.d('⭐ FavoriteProductModelAdapter registado');
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