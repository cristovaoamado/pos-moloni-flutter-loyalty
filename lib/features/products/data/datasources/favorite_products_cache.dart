import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/products/data/models/product_model.dart';

/// Cache local para produtos favoritos usando Hive
/// Guarda os favoritos para não precisar carregar todos os produtos sempre
class FavoriteProductsCache {
  static const String _boxName = 'favorite_products_cache';
  static const String _productsKey = 'products';
  static const String _lastUpdateKey = 'last_update';
  static const String _companyIdKey = 'company_id';
  
  /// Validade do cache em horas
  static const int cacheValidityHours = 24;

  Box? _box;

  /// Inicializa o cache
  Future<void> initialize() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox(_boxName);
      AppLogger.d('📦 FavoriteProductsCache inicializado');
    }
  }

  /// Guarda os produtos favoritos no cache
  Future<void> saveFavorites(List<ProductModel> favorites, int companyId) async {
    await initialize();
    
    try {
      // Converter para JSON
      final jsonList = favorites.map((p) => p.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      
      await _box!.put(_productsKey, jsonString);
      await _box!.put(_lastUpdateKey, DateTime.now().toIso8601String());
      await _box!.put(_companyIdKey, companyId);
      
      AppLogger.i('💾 ${favorites.length} favoritos guardados no cache para empresa $companyId');
    } catch (e) {
      AppLogger.e('❌ Erro ao guardar favoritos no cache', error: e);
    }
  }

  /// Obtém os produtos favoritos do cache
  Future<List<ProductModel>?> getFavorites(int companyId) async {
    await initialize();
    
    try {
      // Verificar se o cache é para a mesma empresa
      final cachedCompanyId = _box!.get(_companyIdKey) as int?;
      if (cachedCompanyId != companyId) {
        AppLogger.d('📦 Cache é de outra empresa ($cachedCompanyId vs $companyId)');
        return null;
      }
      
      final jsonString = _box!.get(_productsKey) as String?;
      if (jsonString == null) {
        AppLogger.d('📦 Cache vazio');
        return null;
      }
      
      final jsonList = jsonDecode(jsonString) as List;
      final products = jsonList
          .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
          .toList();
      
      AppLogger.i('📦 ${products.length} favoritos carregados do cache');
      return products;
    } catch (e) {
      AppLogger.e('❌ Erro ao ler favoritos do cache', error: e);
      return null;
    }
  }

  /// Verifica se o cache é válido (não expirou)
  Future<bool> isCacheValid(int companyId) async {
    await initialize();
    
    try {
      // Verificar empresa
      final cachedCompanyId = _box!.get(_companyIdKey) as int?;
      if (cachedCompanyId != companyId) {
        return false;
      }
      
      // Verificar data
      final lastUpdateStr = _box!.get(_lastUpdateKey) as String?;
      if (lastUpdateStr == null) {
        return false;
      }
      
      final lastUpdate = DateTime.parse(lastUpdateStr);
      final now = DateTime.now();
      final difference = now.difference(lastUpdate);
      
      final isValid = difference.inHours < cacheValidityHours;
      
      AppLogger.d('📦 Cache válido: $isValid (idade: ${difference.inHours}h)');
      return isValid;
    } catch (e) {
      AppLogger.e('❌ Erro ao verificar validade do cache', error: e);
      return false;
    }
  }

  /// Obtém a data da última actualização
  Future<DateTime?> getLastUpdate() async {
    await initialize();
    
    try {
      final lastUpdateStr = _box!.get(_lastUpdateKey) as String?;
      if (lastUpdateStr == null) return null;
      return DateTime.parse(lastUpdateStr);
    } catch (e) {
      return null;
    }
  }

  /// Limpa o cache
  Future<void> clearCache() async {
    await initialize();
    
    try {
      await _box!.clear();
      AppLogger.i('🗑️ Cache de favoritos limpo');
    } catch (e) {
      AppLogger.e('❌ Erro ao limpar cache', error: e);
    }
  }

  /// Fecha o cache
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }
  }
}
