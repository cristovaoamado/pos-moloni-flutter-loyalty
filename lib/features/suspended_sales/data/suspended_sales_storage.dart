import 'package:hive_flutter/hive_flutter.dart';

import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/suspended_sales/data/models/suspended_sale_model.dart';

/// Serviço de inicialização do storage de vendas suspensas
class SuspendedSalesStorage {
  static const String _boxName = 'suspended_sales';
  static bool _initialized = false;

  /// Inicializa o Hive e regista os adaptadores
  /// Chamar no main.dart antes de runApp()
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Registar adaptadores (verificar se já não estão registados)
      if (!Hive.isAdapterRegistered(10)) {
        Hive.registerAdapter(SuspendedSaleModelAdapter());
        AppLogger.d('📦 SuspendedSaleModelAdapter registado');
      }
      if (!Hive.isAdapterRegistered(11)) {
        Hive.registerAdapter(SuspendedSaleItemModelAdapter());
        AppLogger.d('📦 SuspendedSaleItemModelAdapter registado');
      }
      if (!Hive.isAdapterRegistered(12)) {
        Hive.registerAdapter(SuspendedSaleTaxModelAdapter());
        AppLogger.d('📦 SuspendedSaleTaxModelAdapter registado');
      }

      // Abrir a box para garantir que está disponível
      await Hive.openBox<SuspendedSaleModel>(_boxName);
      
      _initialized = true;
      AppLogger.i('✅ Storage de vendas suspensas inicializado');
    } catch (e) {
      AppLogger.e('❌ Erro ao inicializar storage de vendas suspensas', error: e);
      rethrow;
    }
  }

  /// Fecha a box (chamar ao fazer logout se necessário)
  static Future<void> close() async {
    try {
      if (Hive.isBoxOpen(_boxName)) {
        await Hive.box<SuspendedSaleModel>(_boxName).close();
        AppLogger.d('📦 Box de vendas suspensas fechada');
      }
    } catch (e) {
      AppLogger.e('Erro ao fechar box', error: e);
    }
  }
}
