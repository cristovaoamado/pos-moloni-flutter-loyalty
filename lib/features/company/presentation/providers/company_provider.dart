import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_moloni_app/core/errors/failures.dart';

import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:pos_moloni_app/features/company/data/datasources/company_remote_datasource.dart';
import 'package:pos_moloni_app/features/company/data/repositories/company_repository_impl.dart';
import 'package:pos_moloni_app/features/company/domain/entities/company.dart';
import 'package:pos_moloni_app/features/company/domain/repositories/company_repository.dart';
import 'package:pos_moloni_app/features/company/domain/usecases/get_companies_usecase.dart';
import 'package:pos_moloni_app/features/company/domain/usecases/select_company_usecase.dart';

// ==================== PROVIDERS DE DEPENDÊNCIAS ====================

/// Provider do CompanyRemoteDataSource
final companyRemoteDataSourceProvider = Provider<CompanyRemoteDataSource>((ref) {
  return CompanyRemoteDataSourceImpl(
    dio: ref.watch(dioProvider),
    storage: ref.watch(secureStorageProvider),
  );
});

/// Provider do CompanyRepository
final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return CompanyRepositoryImpl(
    remoteDataSource: ref.watch(companyRemoteDataSourceProvider),
    storage: ref.watch(secureStorageProvider),
  );
});

// ==================== PROVIDERS DE USE CASES ====================

/// Provider do GetCompaniesUseCase
final getCompaniesUseCaseProvider = Provider<GetCompaniesUseCase>((ref) {
  return GetCompaniesUseCase(ref.watch(companyRepositoryProvider));
});

/// Provider do SelectCompanyUseCase
final selectCompanyUseCaseProvider = Provider<SelectCompanyUseCase>((ref) {
  return SelectCompanyUseCase(ref.watch(companyRepositoryProvider));
});

// ==================== PROVIDER DE ESTADO ====================

/// Estado de empresas
class CompanyState {

  const CompanyState({
    this.companies = const [],
    this.selectedCompany,
    this.isLoading = false,
    this.error,
  });
  final List<Company> companies;
  final Company? selectedCompany;
  final bool isLoading;
  final String? error;

  CompanyState copyWith({
    List<Company>? companies,
    Company? selectedCompany,
    bool? isLoading,
    String? error,
  }) {
    return CompanyState(
      companies: companies ?? this.companies,
      selectedCompany: selectedCompany ?? this.selectedCompany,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier para gestão do estado de empresas
class CompanyNotifier extends StateNotifier<CompanyState> {

  CompanyNotifier({
    required this.getCompaniesUseCase,
    required this.selectCompanyUseCase,
    required this.companyRepository,
  }) : super(const CompanyState()) {
    // Carregar empresa selecionada ao inicializar
    _loadSelectedCompany();
  }
  final GetCompaniesUseCase getCompaniesUseCase;
  final SelectCompanyUseCase selectCompanyUseCase;
  final CompanyRepository companyRepository;

  /// Carregar empresa selecionada (se houver)
  Future<void> _loadSelectedCompany() async {
    final result = await companyRepository.getSelectedCompany();

    result.fold(
      (failure) {
        AppLogger.d('Nenhuma empresa selecionada');
      },
      (company) {
        if (company != null) {
          AppLogger.i('✅ Empresa já selecionada: ${company.name}');
          state = state.copyWith(selectedCompany: company);
        }
      },
    );
  }

  /// Carregar lista de empresas
  Future<void> loadCompanies() async {
    AppLogger.i('📥 Carregando empresas...');

    state = state.copyWith(isLoading: true, error: null);

    final result = await getCompaniesUseCase.call();

    result.fold(
      (failure) {
        AppLogger.e('❌ Erro ao carregar empresas: ${failure.message}');
        state = state.copyWith(
          isLoading: false,
          error: failure.getUserFriendlyMessage(),
        );
      },
      (companies) {
        AppLogger.i('✅ ${companies.length} empresas carregadas');
        state = state.copyWith(
          companies: companies,
          isLoading: false,
          error: null,
        );
      },
    );
  }

  /// Selecionar empresa
  Future<bool> selectCompany(Company company) async {
    AppLogger.i('🏢 Selecionando empresa: ${company.name}');

    state = state.copyWith(isLoading: true, error: null);

    final result = await selectCompanyUseCase.call(company);

    return result.fold(
      (failure) {
        AppLogger.e('❌ Erro ao selecionar empresa: ${failure.message}');
        state = state.copyWith(
          isLoading: false,
          error: failure.getUserFriendlyMessage(),
        );
        return false;
      },
      (_) {
        AppLogger.i('✅ Empresa selecionada com sucesso');
        state = state.copyWith(
          selectedCompany: company,
          isLoading: false,
          error: null,
        );
        return true;
      },
    );
  }

  /// Limpar erro
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider do CompanyNotifier
final companyProvider = StateNotifierProvider<CompanyNotifier, CompanyState>((ref) {
  return CompanyNotifier(
    getCompaniesUseCase: ref.watch(getCompaniesUseCaseProvider),
    selectCompanyUseCase: ref.watch(selectCompanyUseCaseProvider),
    companyRepository: ref.watch(companyRepositoryProvider),
  );
});

/// Provider conveniente para verificar se tem empresa selecionada
final hasSelectedCompanyProvider = Provider<bool>((ref) {
  return ref.watch(companyProvider).selectedCompany != null;
});
