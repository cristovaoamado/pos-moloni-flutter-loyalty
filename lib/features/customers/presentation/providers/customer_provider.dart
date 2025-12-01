import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:pos_moloni_app/features/customers/data/datasources/customer_remote_datasource.dart';
import 'package:pos_moloni_app/features/customers/data/models/customer_model.dart';
import 'package:pos_moloni_app/features/customers/domain/entities/customer.dart';

/// Estado dos clientes
class CustomerState {
  const CustomerState({
    this.searchResults = const [],
    this.selectedCustomer,
    this.isSearching = false,
    this.isCreating = false,
    this.searchError,
    this.createError,
  });

  final List<Customer> searchResults;
  final Customer? selectedCustomer;
  final bool isSearching;
  final bool isCreating;
  final String? searchError;
  final String? createError;

  CustomerState copyWith({
    List<Customer>? searchResults,
    Customer? selectedCustomer,
    bool? isSearching,
    bool? isCreating,
    String? searchError,
    String? createError,
  }) {
    return CustomerState(
      searchResults: searchResults ?? this.searchResults,
      selectedCustomer: selectedCustomer ?? this.selectedCustomer,
      isSearching: isSearching ?? this.isSearching,
      isCreating: isCreating ?? this.isCreating,
      searchError: searchError,
      createError: createError,
    );
  }
}

/// Provider do datasource
final customerDataSourceProvider = Provider<CustomerRemoteDataSource>((ref) {
  final dio = Dio();
  final secureStorage = ref.watch(secureStorageProvider);
  return CustomerRemoteDataSourceImpl(dio: dio, secureStorage: secureStorage);
});

/// Provider principal de clientes
final customerProvider = StateNotifierProvider<CustomerNotifier, CustomerState>((ref) {
  final dataSource = ref.watch(customerDataSourceProvider);
  return CustomerNotifier(dataSource);
});

/// Notifier para gerir estado dos clientes
class CustomerNotifier extends StateNotifier<CustomerState> {
  CustomerNotifier(this._dataSource) : super(const CustomerState());

  final CustomerRemoteDataSource _dataSource;

  /// Pesquisa clientes
  Future<void> search(String query) async {
    if (query.length < 3) {
      state = state.copyWith(searchResults: [], searchError: null);
      return;
    }

    state = state.copyWith(isSearching: true, searchError: null);

    try {
      AppLogger.i('🔍 A pesquisar clientes: $query');

      final results = await _dataSource.searchByQuery(query);

      AppLogger.i('✅ Encontrados ${results.length} clientes');

      state = state.copyWith(
        searchResults: results,
        isSearching: false,
      );
    } catch (e) {
      AppLogger.e('❌ Erro ao pesquisar clientes: $e');
      state = state.copyWith(
        isSearching: false,
        searchError: e.toString(),
      );
    }
  }

  /// Pesquisa cliente por NIF
  Future<Customer?> getByVat(String vat) async {
    try {
      AppLogger.i('🔍 A pesquisar cliente por NIF: $vat');

      final customer = await _dataSource.getByVat(vat);

      if (customer != null) {
        AppLogger.i('✅ Cliente encontrado: ${customer.name}');
      } else {
        AppLogger.i('ℹ️ Nenhum cliente encontrado com NIF: $vat');
      }

      return customer;
    } catch (e) {
      AppLogger.e('❌ Erro ao pesquisar cliente por NIF: $e');
      return null;
    }
  }

  /// Cria um novo cliente
  Future<Customer?> create({
    required String name,
    required String vat,
    String? email,
    String? phone,
    String? address,
    String? zipCode,
    String? city,
  }) async {
    state = state.copyWith(isCreating: true, createError: null);

    try {
      AppLogger.i('➕ A criar cliente: $name');

      // Obter próximo número
      final nextNumber = await _dataSource.getNextNumber();

      final newCustomer = CustomerModel(
        id: 0,
        name: name,
        vat: vat,
        number: nextNumber,
        email: email,
        phone: phone,
        address: address,
        zipCode: zipCode,
        city: city,
        countryId: 1, // Portugal
        languageId: 1, // Português
      );

      final createdCustomer = await _dataSource.insert(newCustomer);

      AppLogger.i('✅ Cliente criado com ID: ${createdCustomer.id}');

      state = state.copyWith(
        isCreating: false,
        selectedCustomer: createdCustomer,
      );

      return createdCustomer;
    } catch (e) {
      AppLogger.e('❌ Erro ao criar cliente: $e');
      state = state.copyWith(
        isCreating: false,
        createError: e.toString(),
      );
      return null;
    }
  }

  /// Seleciona um cliente
  void selectCustomer(Customer customer) {
    AppLogger.i('👤 Cliente selecionado: ${customer.name}');
    state = state.copyWith(selectedCustomer: customer);
  }

  /// Limpa a seleção
  void clearSelection() {
    state = state.copyWith(
      selectedCustomer: Customer.consumidorFinal,
    );
  }

  /// Limpa os resultados da pesquisa
  void clearSearch() {
    state = state.copyWith(
      searchResults: [],
      searchError: null,
    );
  }

  /// Limpa todo o estado
  void clear() {
    state = const CustomerState();
  }
}

/// Provider para o cliente selecionado
final selectedCustomerProvider = Provider<Customer?>((ref) {
  return ref.watch(customerProvider).selectedCustomer;
});

/// Provider para verificar se está a pesquisar
final isSearchingCustomersProvider = Provider<bool>((ref) {
  return ref.watch(customerProvider).isSearching;
});
