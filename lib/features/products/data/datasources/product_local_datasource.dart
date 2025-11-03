import 'package:hive_flutter/hive_flutter.dart';

import 'package:pos_moloni_app/core/constants/api_constants.dart';
import 'package:pos_moloni_app/core/errors/exceptions.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/products/data/models/product_model.dart';

/// Interface do datasource local de produtos
abstract class ProductLocalDataSource {
  /// Obtém produtos cacheados
  Future<List<ProductModel>> getCachedProducts();

  /// Guarda produtos em cache
  Future<void> cacheProducts(List<ProductModel> products);

  /// Obtém produto por referência do cache
  Future<ProductModel?> getCachedProductByReference(String reference);

  /// Obtém produto por EAN do cache
  Future<ProductModel?> getCachedProductByEan(String ean);

  /// Limpa cache de produtos
  Future<void> clearCache();

  /// Pesquisa em cache local
  Future<List<ProductModel>> searchInCache(String query);
}

/// Implementação do datasource local usando Hive
class ProductLocalDataSourceImpl implements ProductLocalDataSource {

  ProductLocalDataSourceImpl();

  /// Abre box de produtos (lazy)
  Future<Box<dynamic>> _openProductsBox() async {
    try {
      if (Hive.isBoxOpen(ApiConstants.boxProducts)) {
        return Hive.box(ApiConstants.boxProducts);
      }
      return await Hive.openBox(ApiConstants.boxProducts);
    } catch (e) {
      AppLogger.e('Erro ao abrir box de produtos', error: e);
      throw const CacheException('Erro ao acessar cache de produtos');
    }
  }

  @override
  Future<List<ProductModel>> getCachedProducts() async {
    try {
      final box = await _openProductsBox();

      if (box.isEmpty) {
        AppLogger.d('Cache de produtos vazio');
        return [];
      }

      final products = box.values
          .whereType<Map<dynamic, dynamic>>()
          .map((json) => ProductModel.fromJson(
            Map<String, dynamic>.from(json),
          ),)
          .toList();

      AppLogger.cache('GET', 'products', count: products.length);
      return products;
    } catch (e) {
      AppLogger.e('Erro ao obter produtos do cache', error: e);
      throw const CacheException('Erro ao ler cache de produtos');
    }
  }

  @override
  Future<void> cacheProducts(List<ProductModel> products) async {
    try {
      final box = await _openProductsBox();

      // Limpar produtos antigos
      await box.clear();

      // Guardar cada produto com sua referência como chave
      for (final product in products) {
        await box.put(
          product.reference,
          product.toJson(),
        );
      }

      AppLogger.cache('SAVE', 'products', count: products.length);
    } catch (e) {
      AppLogger.e('Erro ao guardar produtos em cache', error: e);
      throw const CacheException('Erro ao guardar cache de produtos');
    }
  }

  @override
  Future<ProductModel?> getCachedProductByReference(String reference) async {
    try {
      final box = await _openProductsBox();
      final json = box.get(reference);

      if (json == null) {
        AppLogger.cache('GET', 'product_by_ref', count: 0);
        return null;
      }

      final product = ProductModel.fromJson(
        Map<String, dynamic>.from(json as Map<dynamic, dynamic>),
      );

      AppLogger.cache('GET', 'product_by_ref', count: 1);
      return product;
    } catch (e) {
      AppLogger.e('Erro ao obter produto por referência', error: e);
      return null;
    }
  }

  @override
  Future<ProductModel?> getCachedProductByEan(String ean) async {
    try {
      final box = await _openProductsBox();

      // Procurar por EAN em todos os produtos
      final products = box.values
          .whereType<Map<dynamic, dynamic>>()
          .map((json) => ProductModel.fromJson(
            Map<String, dynamic>.from(json),
          ),)
          .toList();

      ProductModel? product;
      for (final p in products) {
        if (p.ean == ean) {
          product = p;
          break;
        }
      }

      if (product == null) {
        AppLogger.cache('GET', 'product_by_ean', count: 0);
        return null;
      }

      AppLogger.cache('GET', 'product_by_ean', count: 1);
      return product;
    } catch (e) {
      AppLogger.e('Erro ao obter produto por EAN', error: e);
      return null;
    }
  }

  @override
  Future<void> clearCache() async {
    try {
      final box = await _openProductsBox();
      await box.clear();

      AppLogger.cache('DELETE', 'all_products');
    } catch (e) {
      AppLogger.e('Erro ao limpar cache de produtos', error: e);
      throw const CacheException('Erro ao limpar cache');
    }
  }

  @override
  Future<List<ProductModel>> searchInCache(String query) async {
    try {
      final box = await _openProductsBox();
      final queryLower = query.toLowerCase();

      final products = box.values
          .whereType<Map<dynamic, dynamic>>()
          .map((json) => ProductModel.fromJson(
            Map<String, dynamic>.from(json),
          ),)
          .where((product) =>
              product.name.toLowerCase().contains(queryLower) ||
              product.reference.toLowerCase().contains(queryLower) ||
              (product.ean?.toLowerCase().contains(queryLower) ?? false),)
          .toList();

      AppLogger.cache('SEARCH', 'products', count: products.length);
      return products;
    } catch (e) {
      AppLogger.e('Erro ao pesquisar em cache', error: e);
      throw const CacheException('Erro ao pesquisar cache');
    }
  }
}
