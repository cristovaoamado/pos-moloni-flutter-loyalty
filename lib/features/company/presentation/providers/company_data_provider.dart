import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/checkout/presentation/providers/checkout_provider.dart';
import 'package:pos_moloni_app/features/company/domain/entities/company.dart';
import 'package:pos_moloni_app/features/company/presentation/providers/company_provider.dart';
import 'package:pos_moloni_app/features/document_sets/presentation/providers/document_set_provider.dart';

/// Estado do carregamento de dados da empresa
class CompanyDataState {
  const CompanyDataState({
    this.isLoading = false,
    this.isLoaded = false,
    this.error,
    this.loadedCompanyId,
  });

  final bool isLoading;
  final bool isLoaded;
  final String? error;
  final int? loadedCompanyId; // ID da empresa para a qual os dados foram carregados

  CompanyDataState copyWith({
    bool? isLoading,
    bool? isLoaded,
    String? error,
    int? loadedCompanyId,
    bool clearError = false,
  }) {
    return CompanyDataState(
      isLoading: isLoading ?? this.isLoading,
      isLoaded: isLoaded ?? this.isLoaded,
      error: clearError ? null : (error ?? this.error),
      loadedCompanyId: loadedCompanyId ?? this.loadedCompanyId,
    );
  }
}

/// Provider que gere o carregamento centralizado de dados da empresa
final companyDataProvider = StateNotifierProvider<CompanyDataNotifier, CompanyDataState>((ref) {
  return CompanyDataNotifier(ref);
});

/// Notifier para carregar todos os dados necessários quando uma empresa é selecionada
class CompanyDataNotifier extends StateNotifier<CompanyDataState> {
  CompanyDataNotifier(this._ref) : super(const CompanyDataState());

  final Ref _ref;

  /// Carrega todos os dados necessários para a empresa selecionada
  Future<void> loadCompanyData(Company company) async {
    // Se já carregou para esta empresa, não recarregar
    if (state.loadedCompanyId == company.id && state.isLoaded) {
      AppLogger.d('📦 Dados já carregados para empresa ${company.id}');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    AppLogger.i('📦 A carregar dados para empresa: ${company.name} (ID: ${company.id})');

    try {
      // 1. Carregar séries de documentos
      AppLogger.d('📄 A carregar séries de documentos...');
      await _ref.read(documentSetProvider.notifier).loadDocumentSets();

      // 2. Carregar métodos de pagamento
      AppLogger.d('💳 A carregar métodos de pagamento...');
      await _ref.read(checkoutProvider.notifier).loadPaymentMethods();

      // 3. TODO: Carregar outros dados específicos da empresa
      // - Produtos (se quiser cache)
      // - Clientes frequentes
      // - Configurações da empresa

      state = state.copyWith(
        isLoading: false,
        isLoaded: true,
        loadedCompanyId: company.id,
      );

      AppLogger.i('✅ Dados da empresa carregados com sucesso');
    } catch (e) {
      AppLogger.e('❌ Erro ao carregar dados da empresa', error: e);
      state = state.copyWith(
        isLoading: false,
        isLoaded: false,
        error: 'Erro ao carregar dados: $e',
      );
    }
  }

  /// Força recarregamento de todos os dados
  Future<void> reloadCompanyData() async {
    final company = _ref.read(companyProvider).selectedCompany;
    if (company == null) {
      AppLogger.w('⚠️ Nenhuma empresa selecionada para recarregar dados');
      return;
    }

    // Limpar estado para forçar recarregamento
    state = const CompanyDataState();
    await loadCompanyData(company);
  }

  /// Limpa os dados quando muda de empresa ou faz logout
  void clearData() {
    // Limpar providers individuais
    _ref.read(documentSetProvider.notifier).clear();
    _ref.read(checkoutProvider.notifier).reset();

    state = const CompanyDataState();
    AppLogger.i('🗑️ Dados da empresa limpos');
  }
}

/// Provider que pode ser usado para verificar se os dados estao prontos
/// NOTA: O carregamento e feito explicitamente em _AuthenticatedFlow
/// Este provider e mantido apenas para compatibilidade
final companyDataLoaderProvider = Provider<bool>((ref) {
  final dataState = ref.watch(companyDataProvider);
  return dataState.isLoaded;
});
