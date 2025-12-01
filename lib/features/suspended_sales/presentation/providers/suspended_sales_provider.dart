import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/cart/domain/entities/cart_item.dart';
import 'package:pos_moloni_app/features/document_sets/domain/entities/document_set.dart';
import 'package:pos_moloni_app/features/pos/presentation/models/pos_models.dart';
import 'package:pos_moloni_app/features/suspended_sales/data/datasources/suspended_sale_local_datasource.dart';
import 'package:pos_moloni_app/features/suspended_sales/data/models/suspended_sale_model.dart';

/// Estado das vendas suspensas
class SuspendedSalesState {
  const SuspendedSalesState({
    this.sales = const [],
    this.isLoading = false,
    this.error,
  });

  final List<SuspendedSale> sales;
  final bool isLoading;
  final String? error;

  /// Vendas em memória (não persistentes)
  List<SuspendedSale> get memorySales => 
      sales.where((s) => !s.isPersistent).toList();

  /// Vendas persistentes (guardadas localmente)
  List<SuspendedSale> get persistentSales => 
      sales.where((s) => s.isPersistent).toList();

  SuspendedSalesState copyWith({
    List<SuspendedSale>? sales,
    bool? isLoading,
    String? error,
  }) {
    return SuspendedSalesState(
      sales: sales ?? this.sales,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Provider do datasource
final suspendedSaleDataSourceProvider = Provider<SuspendedSaleLocalDataSource>((ref) {
  return SuspendedSaleLocalDataSourceImpl();
});

/// Provider principal de vendas suspensas
final suspendedSalesProvider = StateNotifierProvider<SuspendedSalesNotifier, SuspendedSalesState>((ref) {
  final dataSource = ref.watch(suspendedSaleDataSourceProvider);
  return SuspendedSalesNotifier(dataSource);
});

/// Notifier para gerir vendas suspensas
class SuspendedSalesNotifier extends StateNotifier<SuspendedSalesState> {
  SuspendedSalesNotifier(this._dataSource) : super(const SuspendedSalesState()) {
    // Carregar vendas persistentes ao iniciar
    loadPersistentSales();
  }

  final SuspendedSaleLocalDataSource _dataSource;
  final _uuid = const Uuid();

  /// Carrega vendas persistentes do storage
  Future<void> loadPersistentSales({List<DocumentTypeOption>? documentOptions}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final models = await _dataSource.getAll();
      final persistentSales = models
          .map((m) => m.toEntity(availableDocumentOptions: documentOptions))
          .toList();

      // Manter vendas em memória e adicionar as persistentes
      final memorySales = state.sales.where((s) => !s.isPersistent).toList();
      
      state = state.copyWith(
        sales: [...memorySales, ...persistentSales],
        isLoading: false,
      );

      AppLogger.i('📂 ${persistentSales.length} vendas persistentes carregadas');
    } catch (e) {
      AppLogger.e('Erro ao carregar vendas persistentes', error: e);
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao carregar vendas suspensas',
      );
    }
  }

  /// Suspende a venda actual
  Future<SuspendedSale> suspendSale({
    required List<CartItem> items,
    required Customer customer,
    DocumentTypeOption? documentOption,
    String? note,
    bool persistent = false,
  }) async {
    final sale = SuspendedSale(
      id: _uuid.v4(),
      items: items,
      customer: customer,
      documentOption: documentOption,
      createdAt: DateTime.now(),
      note: note,
      isPersistent: persistent,
    );

    // Se persistente, guardar no storage
    if (persistent) {
      try {
        await _dataSource.save(SuspendedSaleModel.fromEntity(sale));
        AppLogger.i('💾 Venda suspensa guardada permanentemente');
      } catch (e) {
        AppLogger.e('Erro ao guardar venda suspensa', error: e);
      }
    }

    // Adicionar à lista
    state = state.copyWith(
      sales: [...state.sales, sale],
    );

    AppLogger.i('⏸️ Venda suspensa: ${sale.id} (persistent: $persistent)');
    return sale;
  }

  /// Restaura uma venda suspensa (remove da lista)
  Future<SuspendedSale?> restoreSale(String saleId) async {
    final sale = state.sales.firstWhere(
      (s) => s.id == saleId,
      orElse: () => throw Exception('Venda não encontrada'),
    );

    // Se era persistente, remover do storage
    if (sale.isPersistent) {
      try {
        await _dataSource.delete(saleId);
      } catch (e) {
        AppLogger.e('Erro ao remover venda do storage', error: e);
      }
    }

    // Remover da lista
    state = state.copyWith(
      sales: state.sales.where((s) => s.id != saleId).toList(),
    );

    AppLogger.i('▶️ Venda restaurada: $saleId');
    return sale;
  }

  /// Remove uma venda suspensa sem restaurar
  Future<void> deleteSale(String saleId) async {
    final sale = state.sales.firstWhere(
      (s) => s.id == saleId,
      orElse: () => throw Exception('Venda não encontrada'),
    );

    // Se era persistente, remover do storage
    if (sale.isPersistent) {
      try {
        await _dataSource.delete(saleId);
      } catch (e) {
        AppLogger.e('Erro ao remover venda do storage', error: e);
      }
    }

    // Remover da lista
    state = state.copyWith(
      sales: state.sales.where((s) => s.id != saleId).toList(),
    );

    AppLogger.i('🗑️ Venda removida: $saleId');
  }

  /// Torna uma venda persistente (ou remove persistência)
  Future<void> togglePersistence(String saleId) async {
    final saleIndex = state.sales.indexWhere((s) => s.id == saleId);
    if (saleIndex == -1) return;

    final sale = state.sales[saleIndex];
    final newPersistence = !sale.isPersistent;
    final updatedSale = sale.copyWith(isPersistent: newPersistence);

    if (newPersistence) {
      // Guardar no storage
      try {
        await _dataSource.save(SuspendedSaleModel.fromEntity(updatedSale));
        AppLogger.i('💾 Venda marcada como persistente');
      } catch (e) {
        AppLogger.e('Erro ao guardar venda', error: e);
        return;
      }
    } else {
      // Remover do storage
      try {
        await _dataSource.delete(saleId);
        AppLogger.i('📤 Venda removida do storage (apenas memória)');
      } catch (e) {
        AppLogger.e('Erro ao remover venda do storage', error: e);
        return;
      }
    }

    // Atualizar estado
    final updatedSales = [...state.sales];
    updatedSales[saleIndex] = updatedSale;
    state = state.copyWith(sales: updatedSales);
  }

  /// Limpa todas as vendas em memória (não persistentes)
  void clearMemorySales() {
    state = state.copyWith(
      sales: state.sales.where((s) => s.isPersistent).toList(),
    );
    AppLogger.i('🧹 Vendas em memória limpas');
  }

  /// Limpa todas as vendas (incluindo persistentes)
  Future<void> clearAllSales() async {
    try {
      await _dataSource.deleteAll();
    } catch (e) {
      AppLogger.e('Erro ao limpar vendas do storage', error: e);
    }

    state = state.copyWith(sales: []);
    AppLogger.i('🧹 Todas as vendas limpas');
  }
}
