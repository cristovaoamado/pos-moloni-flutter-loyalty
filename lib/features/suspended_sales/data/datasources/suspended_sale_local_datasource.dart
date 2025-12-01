import 'package:hive/hive.dart';

import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/suspended_sales/data/models/suspended_sale_model.dart';

/// Datasource local para vendas suspensas (Hive)
abstract class SuspendedSaleLocalDataSource {
  /// Obtém todas as vendas suspensas persistentes
  Future<List<SuspendedSaleModel>> getAll();

  /// Guarda uma venda suspensa
  Future<void> save(SuspendedSaleModel sale);

  /// Remove uma venda suspensa
  Future<void> delete(String saleId);

  /// Remove todas as vendas suspensas
  Future<void> deleteAll();

  /// Verifica se existe uma venda com o ID
  Future<bool> exists(String saleId);
}

/// Implementação usando Hive
class SuspendedSaleLocalDataSourceImpl implements SuspendedSaleLocalDataSource {
  static const String _boxName = 'suspended_sales';

  Future<Box<SuspendedSaleModel>> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox<SuspendedSaleModel>(_boxName);
    }
    return Hive.box<SuspendedSaleModel>(_boxName);
  }

  @override
  Future<List<SuspendedSaleModel>> getAll() async {
    try {
      final box = await _getBox();
      final sales = box.values.toList();
      
      // Ordenar por data de criação (mais recente primeiro)
      sales.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      AppLogger.d('💾 ${sales.length} vendas suspensas carregadas do storage');
      return sales;
    } catch (e) {
      AppLogger.e('Erro ao carregar vendas suspensas', error: e);
      return [];
    }
  }

  @override
  Future<void> save(SuspendedSaleModel sale) async {
    try {
      final box = await _getBox();
      await box.put(sale.id, sale);
      AppLogger.i('💾 Venda suspensa guardada: ${sale.id}');
    } catch (e) {
      AppLogger.e('Erro ao guardar venda suspensa', error: e);
      rethrow;
    }
  }

  @override
  Future<void> delete(String saleId) async {
    try {
      final box = await _getBox();
      await box.delete(saleId);
      AppLogger.i('🗑️ Venda suspensa removida: $saleId');
    } catch (e) {
      AppLogger.e('Erro ao remover venda suspensa', error: e);
      rethrow;
    }
  }

  @override
  Future<void> deleteAll() async {
    try {
      final box = await _getBox();
      await box.clear();
      AppLogger.i('🗑️ Todas as vendas suspensas removidas');
    } catch (e) {
      AppLogger.e('Erro ao remover todas as vendas suspensas', error: e);
      rethrow;
    }
  }

  @override
  Future<bool> exists(String saleId) async {
    try {
      final box = await _getBox();
      return box.containsKey(saleId);
    } catch (e) {
      AppLogger.e('Erro ao verificar venda suspensa', error: e);
      return false;
    }
  }

  /// Regista os adaptadores Hive (chamar na inicialização da app)
  static void registerAdapters() {
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(SuspendedSaleModelAdapter());
    }
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(SuspendedSaleItemModelAdapter());
    }
    if (!Hive.isAdapterRegistered(12)) {
      Hive.registerAdapter(SuspendedSaleTaxModelAdapter());
    }
  }
}
