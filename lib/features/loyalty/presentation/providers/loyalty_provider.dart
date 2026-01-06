import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/loyalty_remote_datasource.dart';
import '../../data/models/sale_models.dart';
import '../../domain/entities/loyalty_customer.dart';

// ==================== Constantes ====================

const String _keyLoyaltyApiUrl = 'loyalty_api_url';
const String _keyLoyaltyEnabled = 'loyalty_enabled';
const String _keyLoyaltyCardPrefix = 'loyalty_card_prefix';
const String _keyPosIdentifier = 'pos_identifier';

const String _defaultApiUrl = 'http://localhost:5000/api';
const String _defaultCardPrefix = '269';

// ==================== Estado ====================

/// Estado do módulo Loyalty
class LoyaltyState {
  final bool isEnabled;
  final bool isLoading;
  final String? error;
  final LoyaltyCustomer? currentCustomer;
  final int? pendingSaleId;
  final RegisterSaleResult? lastSaleResult;
  final String apiUrl;
  final String cardPrefix;
  final bool isConnected;

  const LoyaltyState({
    this.isEnabled = false,
    this.isLoading = false,
    this.error,
    this.currentCustomer,
    this.pendingSaleId,
    this.lastSaleResult,
    this.apiUrl = _defaultApiUrl,
    this.cardPrefix = _defaultCardPrefix,
    this.isConnected = false,
  });

  LoyaltyState copyWith({
    bool? isEnabled,
    bool? isLoading,
    String? error,
    LoyaltyCustomer? currentCustomer,
    bool clearCustomer = false,
    int? pendingSaleId,
    bool clearPendingSale = false,
    RegisterSaleResult? lastSaleResult,
    bool clearLastSaleResult = false,
    String? apiUrl,
    String? cardPrefix,
    bool? isConnected,
  }) {
    return LoyaltyState(
      isEnabled: isEnabled ?? this.isEnabled,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentCustomer: clearCustomer ? null : (currentCustomer ?? this.currentCustomer),
      pendingSaleId: clearPendingSale ? null : (pendingSaleId ?? this.pendingSaleId),
      lastSaleResult: clearLastSaleResult ? null : (lastSaleResult ?? this.lastSaleResult),
      apiUrl: apiUrl ?? this.apiUrl,
      cardPrefix: cardPrefix ?? this.cardPrefix,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  /// Verifica se um código de barras é de cartão fidelização
  bool isLoyaltyCard(String barcode) {
    return barcode.startsWith(cardPrefix);
  }

  /// Calcula pontos que serão ganhos na compra
  int calculatePointsToEarn(double amount) {
    if (currentCustomer?.card == null) return 0;
    final multiplier = currentCustomer!.card!.tier.multiplier;
    return (amount * multiplier).floor();
  }

  /// Calcula desconto máximo possível (em euros)
  double calculateMaxDiscount(double cartTotal) {
    if (currentCustomer?.card == null) return 0;
    final pointsValue = currentCustomer!.card!.pointsValueInEuros;
    return pointsValue > cartTotal ? cartTotal : pointsValue;
  }
}

// ==================== Notifier ====================

/// Provider principal do módulo Loyalty
final loyaltyProvider = StateNotifierProvider<LoyaltyNotifier, LoyaltyState>((ref) {
  final dataSource = ref.watch(loyaltyRemoteDataSourceProvider);
  return LoyaltyNotifier(dataSource);
});

/// Notifier para gestão do estado Loyalty
class LoyaltyNotifier extends StateNotifier<LoyaltyState> {
  final LoyaltyRemoteDataSource _dataSource;

  LoyaltyNotifier(this._dataSource) : super(const LoyaltyState()) {
    _loadSettings();
  }

  // ==================== Inicialização ====================

  /// Carrega configurações das SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiUrl = prefs.getString(_keyLoyaltyApiUrl) ?? _defaultApiUrl;
      final isEnabled = prefs.getBool(_keyLoyaltyEnabled) ?? false;
      final cardPrefix = prefs.getString(_keyLoyaltyCardPrefix) ?? _defaultCardPrefix;

      _dataSource.setBaseUrl(apiUrl);

      state = state.copyWith(
        apiUrl: apiUrl,
        isEnabled: isEnabled,
        cardPrefix: cardPrefix,
      );

      // Testar conexão se estiver activo
      if (isEnabled) {
        await testConnection();
      }
    } catch (e) {
      state = state.copyWith(error: 'Erro ao carregar configurações');
    }
  }

  // ==================== Configurações ====================

  /// Activa ou desactiva o módulo Loyalty
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoyaltyEnabled, enabled);
    state = state.copyWith(isEnabled: enabled);

    if (enabled) {
      await testConnection();
    }
  }

  /// Define o URL da API
  Future<void> setApiUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLoyaltyApiUrl, url);
    _dataSource.setBaseUrl(url);
    state = state.copyWith(apiUrl: url);
  }

  /// Define o prefixo dos cartões
  Future<void> setCardPrefix(String prefix) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLoyaltyCardPrefix, prefix);
    state = state.copyWith(cardPrefix: prefix);
  }

  /// Testa conexão com a API
  Future<bool> testConnection() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final connected = await _dataSource.testConnection();
      state = state.copyWith(isLoading: false, isConnected: connected);
      return connected;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isConnected: false,
        error: 'Não foi possível conectar à API',
      );
      return false;
    }
  }

  // ==================== Gestão de Cliente ====================

  /// Identifica cliente pelo código de barras do cartão
  Future<bool> identifyCustomerByBarcode(String barcode) async {
    if (!state.isEnabled) return false;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final cardInfo = await _dataSource.getCardByBarcode(barcode);
      
      if (cardInfo == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Cartão não encontrado',
        );
        return false;
      }

      if (!cardInfo.isActive) {
        state = state.copyWith(
          isLoading: false,
          error: 'Cartão inactivo ou bloqueado',
        );
        return false;
      }

      final customer = cardInfo.toEntity();
      state = state.copyWith(
        isLoading: false,
        currentCustomer: customer,
      );
      return true;
    } on LoyaltyApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao identificar cliente',
      );
      return false;
    }
  }

  /// Remove cliente actual
  void clearCustomer() {
    state = state.copyWith(
      clearCustomer: true,
      clearPendingSale: true,
      clearLastSaleResult: true,
    );
  }

  // ==================== Vendas ====================

  /// Passo 1: Registar venda (botão "Confirmar")
  Future<RegisterSaleResult?> registerSale({
    required double amount,
    String? paymentMethod,
    int pointsToRedeem = 0,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final prefs = await SharedPreferences.getInstance();
      final posIdentifier = prefs.getString(_keyPosIdentifier);

      final request = RegisterSaleRequest(
        amount: amount,
        cardBarcode: state.currentCustomer?.card?.barcode,
        paymentMethod: paymentMethod,
        posIdentifier: posIdentifier,
        pointsToRedeem: pointsToRedeem,
      );

      final result = await _dataSource.registerSale(request);

      state = state.copyWith(
        isLoading: false,
        pendingSaleId: result.saleId,
        lastSaleResult: result,
      );

      return result;
    } on LoyaltyApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao registar venda',
      );
      return null;
    }
  }

  /// Passo 2: Finalizar venda (botão "Finalizar")
  Future<bool> completeSale({
    String? documentReference,
    int? documentId,
  }) async {
    if (state.pendingSaleId == null) {
      state = state.copyWith(error: 'Nenhuma venda pendente');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final request = CompleteSaleRequest(
        saleId: state.pendingSaleId!,
        documentReference: documentReference,
        documentId: documentId,
      );

      await _dataSource.completeSale(request);

      state = state.copyWith(
        isLoading: false,
        clearPendingSale: true,
        clearCustomer: true,
        clearLastSaleResult: true,
      );

      return true;
    } on LoyaltyApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao finalizar venda',
      );
      return false;
    }
  }

  /// Cancelar venda pendente
  Future<bool> cancelPendingSale({String? reason}) async {
    if (state.pendingSaleId == null) return true;

    try {
      final request = CancelSaleRequest(
        saleId: state.pendingSaleId!,
        reason: reason,
      );

      await _dataSource.cancelSale(request);

      state = state.copyWith(
        clearPendingSale: true,
        clearLastSaleResult: true,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Limpa erro
  void clearError() {
    state = state.copyWith(error: null);
  }
}
