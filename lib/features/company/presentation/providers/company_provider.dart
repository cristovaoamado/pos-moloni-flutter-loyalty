import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:pos_moloni_app/core/constants/api_constants.dart';
import 'package:pos_moloni_app/core/services/storage_service.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/company/domain/entities/company.dart';

/// Callback para notificar mudança de empresa
typedef OnCompanyChangedCallback = Future<void> Function(Company company);

/// Estado do provider de empresas
class CompanyState {
  const CompanyState({
    this.companies = const [],
    this.selectedCompany,
    this.isLoading = false,
    this.isLoadingDependencies = false,
    this.error,
  });

  final List<Company> companies;
  final Company? selectedCompany;
  final bool isLoading;
  final bool isLoadingDependencies; // A carregar dados dependentes da empresa
  final String? error;

  bool get hasCompanies => companies.isNotEmpty;
  bool get hasSelectedCompany => selectedCompany != null;

  CompanyState copyWith({
    List<Company>? companies,
    Company? selectedCompany,
    bool? isLoading,
    bool? isLoadingDependencies,
    String? error,
    bool clearError = false,
    bool clearSelectedCompany = false,
  }) {
    return CompanyState(
      companies: companies ?? this.companies,
      selectedCompany: clearSelectedCompany ? null : (selectedCompany ?? this.selectedCompany),
      isLoading: isLoading ?? this.isLoading,
      isLoadingDependencies: isLoadingDependencies ?? this.isLoadingDependencies,
      error: clearError ? null : error,
    );
  }
}

/// Provider de empresas
final companyProvider = StateNotifierProvider<CompanyNotifier, CompanyState>((ref) {
  return CompanyNotifier(
    ref: ref,
    dio: Dio(),
    storage: PlatformStorage.instance,
  );
});

/// Notifier para gestão de empresas
class CompanyNotifier extends StateNotifier<CompanyState> {
  CompanyNotifier({
    required this.ref,
    required this.dio,
    required this.storage,
  }) : super(const CompanyState());

  final Ref ref;
  final Dio dio;
  final FlutterSecureStorage storage;
  
  /// Callbacks para recarregar dados quando a empresa muda
  final List<OnCompanyChangedCallback> _onCompanyChangedCallbacks = [];

  /// Regista um callback para ser chamado quando a empresa mudar
  void registerOnCompanyChanged(OnCompanyChangedCallback callback) {
    _onCompanyChangedCallbacks.add(callback);
  }

  /// Remove um callback
  void unregisterOnCompanyChanged(OnCompanyChangedCallback callback) {
    _onCompanyChangedCallbacks.remove(callback);
  }

  /// Carrega todas as empresas da API
  Future<void> loadCompanies() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final apiUrl = await storage.read(key: ApiConstants.keyApiUrl) ??
          ApiConstants.defaultMoloniApiUrl;
      final accessToken = await storage.read(key: ApiConstants.keyAccessToken);

      if (accessToken == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Token de acesso não encontrado. Faça login novamente.',
        );
        return;
      }

      final url = '$apiUrl/companies/getAll/?access_token=$accessToken';

      AppLogger.moloniApi('companies/getAll');

      final response = await dio.post(url);

      if (response.statusCode == 200 && response.data is List) {
        final companies = (response.data as List).map((json) {
          final map = json as Map<String, dynamic>;
          return Company(
            id: map['company_id'] as int? ?? 0,
            name: map['name'] as String? ?? '',
            vat: _parseString(map['vat']),
            email: _parseString(map['email']),
            address: _parseString(map['address']),
            city: _parseString(map['city']),
            zipCode: _parseString(map['zip_code']),
            country: _parseString(map['country']).isNotEmpty 
                ? _parseString(map['country']) 
                : 'PT',
            phone: _parseString(map['phone']),
          );
        }).toList();

        AppLogger.i('✅ ${companies.length} empresas carregadas');

        state = state.copyWith(
          companies: companies,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Resposta inválida do servidor',
        );
      }
    } on DioException catch (e) {
      AppLogger.e('Erro ao carregar empresas', error: e);
      
      String errorMessage = 'Erro ao carregar empresas';
      if (e.response?.statusCode == 401) {
        errorMessage = 'Sessão expirada. Faça login novamente.';
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Tempo limite excedido. Verifique a ligação.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'Sem ligação à Internet.';
      }
      
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
    } catch (e) {
      AppLogger.e('Erro inesperado ao carregar empresas', error: e);
      state = state.copyWith(
        isLoading: false,
        error: 'Erro inesperado: $e',
      );
    }
  }

  /// Seleciona uma empresa e guarda todos os dados na storage
  /// Depois notifica todos os listeners para recarregar dados
  Future<bool> selectCompany(Company company) async {
    try {
      AppLogger.i('======== SELECCIONANDO EMPRESA ========');
      AppLogger.i('Empresa: ${company.name} (ID: ${company.id})');

      // Tentar carregar detalhes completos da empresa (incluindo imagem)
      Company companyWithDetails;
      try {
        companyWithDetails = await _loadCompanyDetails(company.id);
      } catch (e) {
        // Se falhar, usar os dados basicos que ja temos
        AppLogger.w('Falha ao carregar detalhes, usando dados basicos: $e');
        companyWithDetails = company;
      }

      // Guardar todos os dados da empresa na storage
      await _saveCompanyToStorage(companyWithDetails);

      state = state.copyWith(selectedCompany: companyWithDetails);
      
      // Notificar todos os listeners para recarregar dados
      await _notifyCompanyChanged(companyWithDetails);
      
      AppLogger.i('======== EMPRESA SELECCIONADA ========');
      return true;
    } catch (e) {
      AppLogger.e('Erro ao selecionar empresa', error: e);
      state = state.copyWith(error: 'Erro ao selecionar empresa: $e');
      return false;
    }
  }

  /// Carrega detalhes completos da empresa usando companies/getOne
  Future<Company> _loadCompanyDetails(int companyId) async {
    AppLogger.i('======== CARREGANDO DETALHES DA EMPRESA ========');
    
    try {
      final apiUrl = await storage.read(key: ApiConstants.keyApiUrl) ??
          ApiConstants.defaultMoloniApiUrl;
      final accessToken = await storage.read(key: ApiConstants.keyAccessToken);

      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Token nao encontrado');
      }

      final url = '$apiUrl/companies/getOne/?access_token=$accessToken';

      AppLogger.d('URL: $url');
      AppLogger.d('company_id: $companyId');

      final response = await dio.post(
        url,
        data: {'company_id': companyId},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          validateStatus: (status) => true, // Aceitar qualquer status para ver a resposta
        ),
      );

      AppLogger.i('======== RESPOSTA companies/getOne ========');
      AppLogger.i('Status: ${response.statusCode}');
      AppLogger.i('Response type: ${response.data.runtimeType}');
      
      // Se erro, mostrar detalhes
      if (response.statusCode != 200) {
        AppLogger.e('Erro HTTP: ${response.statusCode}');
        AppLogger.e('Response body: ${response.data}');
        throw Exception('HTTP ${response.statusCode}: ${response.data}');
      }
      
      // Log da resposta completa
      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        AppLogger.i('company_id: ${data['company_id']}');
        AppLogger.i('name: ${data['name']}');
        AppLogger.i('vat: ${data['vat']}');
        AppLogger.i('email: ${data['email']}');
        AppLogger.i('address: ${data['address']}');
        AppLogger.i('city: ${data['city']}');
        AppLogger.i('zip_code: ${data['zip_code']}');
        AppLogger.i('phone: ${data['phone']}');
        AppLogger.i('fax: ${data['fax']}');
        AppLogger.i('website: ${data['website']}');
        AppLogger.i('image: "${data['image']}" (type: ${data['image']?.runtimeType})');
        AppLogger.i('country: ${data['country']}');
        AppLogger.i('================================================');
        
        final company = Company.fromApiJson(data);
        
        AppLogger.i('Company criada:');
        AppLogger.i('  - ID: ${company.id}');
        AppLogger.i('  - Nome: ${company.name}');
        AppLogger.i('  - NIF: ${company.vat}');
        AppLogger.i('  - ImageUrl: ${company.imageUrl}');
        AppLogger.i('  - HasImage: ${company.hasImage}');
        
        return company;
      } else {
        AppLogger.w('Resposta nao e um Map: ${response.data}');
        throw Exception('Resposta invalida');
      }
    } catch (e) {
      AppLogger.e('Erro ao carregar detalhes da empresa: $e');
      rethrow;
    }
  }

  /// Guarda todos os dados da empresa na storage
  Future<void> _saveCompanyToStorage(Company company) async {
    AppLogger.d('A guardar empresa na storage...');
    
    await storage.write(key: ApiConstants.keyCompanyId, value: company.id.toString());
    await storage.write(key: ApiConstants.keyCompanyName, value: company.name);
    await storage.write(key: ApiConstants.keyCompanyVat, value: company.vat);
    await storage.write(key: ApiConstants.keyCompanyAddress, value: company.address);
    await storage.write(key: ApiConstants.keyCompanyZipCode, value: company.zipCode);
    await storage.write(key: ApiConstants.keyCompanyCity, value: company.city);
    
    if (company.phone != null && company.phone!.isNotEmpty) {
      await storage.write(key: ApiConstants.keyCompanyPhone, value: company.phone!);
    }
    if (company.email.isNotEmpty) {
      await storage.write(key: ApiConstants.keyCompanyEmail, value: company.email);
    }
    if (company.imageUrl != null && company.imageUrl!.isNotEmpty) {
      await storage.write(key: 'company_selected_image_url', value: company.imageUrl!);
      AppLogger.d('ImageUrl guardada: ${company.imageUrl}');
    } else {
      await storage.delete(key: 'company_selected_image_url');
      AppLogger.d('Sem imagem para guardar');
    }

    AppLogger.i('Empresa guardada na storage: ${company.name}');
  }

  /// Notifica todos os callbacks que a empresa mudou
  Future<void> _notifyCompanyChanged(Company company) async {
    if (_onCompanyChangedCallbacks.isEmpty) {
      AppLogger.d('📢 Nenhum callback registado para mudança de empresa');
      return;
    }

    AppLogger.i('📢 A notificar ${_onCompanyChangedCallbacks.length} listeners de mudança de empresa...');
    state = state.copyWith(isLoadingDependencies: true);

    try {
      for (final callback in _onCompanyChangedCallbacks) {
        await callback(company);
      }
      AppLogger.i('✅ Todos os dados dependentes recarregados');
    } catch (e) {
      AppLogger.e('❌ Erro ao recarregar dados dependentes', error: e);
    } finally {
      state = state.copyWith(isLoadingDependencies: false);
    }
  }

  /// Carrega a empresa selecionada da storage
  /// Se nao tiver imagem, recarrega da API
  Future<void> loadSelectedCompany() async {
    try {
      final companyId = await storage.read(key: ApiConstants.keyCompanyId);
      if (companyId == null) {
        AppLogger.d('Nenhuma empresa na storage');
        return;
      }

      AppLogger.i('A carregar empresa da storage (ID: $companyId)...');

      // Ler todos os valores da storage
      final name = await storage.read(key: ApiConstants.keyCompanyName) ?? '';
      final vat = await storage.read(key: ApiConstants.keyCompanyVat) ?? '';
      final email = await storage.read(key: ApiConstants.keyCompanyEmail) ?? '';
      final address = await storage.read(key: ApiConstants.keyCompanyAddress) ?? '';
      final city = await storage.read(key: ApiConstants.keyCompanyCity) ?? '';
      final zipCode = await storage.read(key: ApiConstants.keyCompanyZipCode) ?? '';
      final phone = await storage.read(key: ApiConstants.keyCompanyPhone);
      final country = await storage.read(key: 'company_selected_country') ?? 'PT';
      final imageUrl = await storage.read(key: 'company_selected_image_url');

      AppLogger.d('Storage - imageUrl: $imageUrl');

      final parsedId = int.tryParse(companyId) ?? 0;
      if (parsedId <= 0) {
        AppLogger.w('ID da empresa invalido: $companyId');
        return;
      }

      // Se nao tem imagem na storage, recarregar da API
      if (imageUrl == null || imageUrl.isEmpty) {
        AppLogger.i('Imagem nao encontrada na storage, a recarregar da API...');
        try {
          final company = await _loadCompanyDetails(parsedId);
          await _saveCompanyToStorage(company);
          state = state.copyWith(selectedCompany: company);
          AppLogger.i('Empresa recarregada da API: ${company.name} (imagem: ${company.hasImage ? 'sim' : 'nao'})');
          return;
        } catch (e) {
          AppLogger.w('Falha ao recarregar da API, usando dados da storage: $e');
        }
      }

      // Usar dados da storage
      final company = Company(
        id: parsedId,
        name: name,
        vat: vat,
        email: email,
        address: address,
        city: city,
        zipCode: zipCode,
        phone: phone,
        country: country,
        imageUrl: imageUrl,
      );

      state = state.copyWith(selectedCompany: company);
      AppLogger.i('Empresa carregada da storage: ${company.name} (imagem: ${company.hasImage ? 'sim' : 'nao'})');
    } catch (e) {
      AppLogger.e('Erro ao carregar empresa da storage', error: e);
    }
  }

  /// Verifica se há uma empresa selecionada
  Future<bool> hasSelectedCompany() async {
    final companyId = await storage.read(key: ApiConstants.keyCompanyId);
    return companyId != null && companyId.isNotEmpty;
  }

  /// Limpa a empresa selecionada
  Future<void> clearSelectedCompany() async {
    await storage.delete(key: ApiConstants.keyCompanyId);
    await storage.delete(key: ApiConstants.keyCompanyName);
    await storage.delete(key: ApiConstants.keyCompanyVat);
    await storage.delete(key: ApiConstants.keyCompanyAddress);
    await storage.delete(key: ApiConstants.keyCompanyZipCode);
    await storage.delete(key: ApiConstants.keyCompanyCity);
    await storage.delete(key: ApiConstants.keyCompanyPhone);
    await storage.delete(key: ApiConstants.keyCompanyEmail);
    await storage.delete(key: 'company_selected_image_url');
    
    state = state.copyWith(clearSelectedCompany: true);
    AppLogger.i('Empresa limpa da storage');
  }

  /// Helper para parsear strings (alguns campos podem vir como Map)
  static String _parseString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map) return value['title']?.toString() ?? value['name']?.toString() ?? '';
    return value.toString();
  }
}
