import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_moloni_app/features/settings/presentation/providers/settings_provider.dart';
import '../../data/datasources/loyalty_remote_datasource.dart';
import '../../data/models/sale_models.dart';
import '../../data/models/coupon_models.dart';
import '../../domain/entities/loyalty_customer.dart';

// ==================== Constantes ====================

const String _keyLoyaltyEnabled = 'loyalty_enabled';
const String _keyLoyaltyCardPrefix = 'loyalty_card_prefix';
const String _keyLoyaltyApiKey = 'loyalty_api_key';
const String _keyPosIdentifier = 'pos_identifier';

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
  final String apiKey;
  final String cardPrefix;
  final bool isConnected;
  
  // Cupões
  final List<AvailableCoupon> availableCoupons;
  final AvailableCoupon? selectedCoupon;
  final ApplyCouponResult? couponCalculation;

  const LoyaltyState({
    this.isEnabled = false,
    this.isLoading = false,
    this.error,
    this.currentCustomer,
    this.pendingSaleId,
    this.lastSaleResult,
    this.apiUrl = '',
    this.apiKey = '',
    this.cardPrefix = _defaultCardPrefix,
    this.isConnected = false,
    this.availableCoupons = const [],
    this.selectedCoupon,
    this.couponCalculation,
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
    String? apiKey,
    String? cardPrefix,
    bool? isConnected,
    List<AvailableCoupon>? availableCoupons,
    AvailableCoupon? selectedCoupon,
    bool clearSelectedCoupon = false,
    ApplyCouponResult? couponCalculation,
    bool clearCouponCalculation = false,
  }) {
    return LoyaltyState(
      isEnabled: isEnabled ?? this.isEnabled,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentCustomer: clearCustomer ? null : (currentCustomer ?? this.currentCustomer),
      pendingSaleId: clearPendingSale ? null : (pendingSaleId ?? this.pendingSaleId),
      lastSaleResult: clearLastSaleResult ? null : (lastSaleResult ?? this.lastSaleResult),
      apiUrl: apiUrl ?? this.apiUrl,
      apiKey: apiKey ?? this.apiKey,
      cardPrefix: cardPrefix ?? this.cardPrefix,
      isConnected: isConnected ?? this.isConnected,
      availableCoupons: clearCustomer ? const [] : (availableCoupons ?? this.availableCoupons),
      selectedCoupon: clearSelectedCoupon || clearCustomer ? null : (selectedCoupon ?? this.selectedCoupon),
      couponCalculation: clearCouponCalculation || clearCustomer ? null : (couponCalculation ?? this.couponCalculation),
    );
  }

  /// Verifica se um código de barras é de cartão fidelização
  bool isLoyaltyCard(String barcode) {
    return barcode.startsWith(cardPrefix);
  }

  /// Verifica se a API Key está configurada
  bool get hasApiKey => apiKey.isNotEmpty;

  /// Verifica se está totalmente configurado
  bool get isFullyConfigured => apiUrl.isNotEmpty && apiKey.isNotEmpty;

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

  /// Verifica se há cupões disponíveis
  bool get hasCoupons => availableCoupons.isNotEmpty;

  /// Verifica se há cupão seleccionado
  bool get hasCouponSelected => selectedCoupon != null;

  /// Desconto do cupão calculado
  double get couponDiscount => couponCalculation?.totalDiscount ?? 0;

  /// Pontos bónus do cupão calculado
  int get couponBonusPoints => couponCalculation?.totalBonusPoints ?? 0;

  /// Verifica se cupão seleccionado é de pontos bónus
  bool get isBonusPointsCoupon => selectedCoupon?.isBonusPointsCoupon ?? false;

  /// Filtra cupões que têm produtos elegíveis no carrinho
  List<AvailableCoupon> getApplicableCoupons(List<String> cartProductReferences) {
    return availableCoupons.where((coupon) {
      return coupon.hasApplicableProducts(cartProductReferences);
    }).toList();
  }
}

// ==================== Notifier ====================

/// Provider principal do módulo Loyalty
final loyaltyProvider = StateNotifierProvider<LoyaltyNotifier, LoyaltyState>((ref) {
  final dataSource = ref.watch(loyaltyRemoteDataSourceProvider);
  final settingsState = ref.watch(settingsProvider);
  return LoyaltyNotifier(dataSource, ref, settingsState);
});

/// Notifier para gestão do estado Loyalty
class LoyaltyNotifier extends StateNotifier<LoyaltyState> {
  final LoyaltyRemoteDataSource _dataSource;
  final Ref _ref;
  final SettingsState _settingsState;

  LoyaltyNotifier(this._dataSource, this._ref, this._settingsState) : super(const LoyaltyState()) {
    _loadSettings();
  }

  // ==================== Inicialização ====================

  /// Carrega configurações das SharedPreferences e Settings
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Usar URL do Settings se disponível, senão usar SharedPreferences (legado)
      String apiUrl = '';
      String apiKey = '';
      final settings = _settingsState.settings;
      
      if (settings?.loyaltyApiUrl != null && settings!.loyaltyApiUrl!.isNotEmpty) {
        apiUrl = settings.loyaltyApiUrl!;
      } else {
        // Fallback para SharedPreferences (compatibilidade)
        apiUrl = prefs.getString('loyalty_api_url') ?? '';
      }

      // API Key - Settings ou SharedPreferences
      if (settings?.loyaltyApiKey != null && settings!.loyaltyApiKey!.isNotEmpty) {
        apiKey = settings.loyaltyApiKey!;
      } else {
        apiKey = prefs.getString(_keyLoyaltyApiKey) ?? '';
      }
      
      // Enabled e CardPrefix do Settings ou SharedPreferences
      bool isEnabled = settings?.loyaltyEnabled ?? prefs.getBool(_keyLoyaltyEnabled) ?? false;
      String cardPrefix = settings?.loyaltyCardPrefix ?? prefs.getString(_keyLoyaltyCardPrefix) ?? _defaultCardPrefix;

      // Configurar datasource
      if (apiUrl.isNotEmpty) {
        _dataSource.setBaseUrl(apiUrl);
      }
      if (apiKey.isNotEmpty) {
        _dataSource.setApiKey(apiKey);
      }

      state = state.copyWith(
        apiUrl: apiUrl,
        apiKey: apiKey,
        isEnabled: isEnabled,
        cardPrefix: cardPrefix,
      );

      // Testar conexão se estiver activo e tiver URL + API Key
      if (isEnabled && apiUrl.isNotEmpty && apiKey.isNotEmpty) {
        await testConnection();
      }
    } catch (e) {
      state = state.copyWith(error: 'Erro ao carregar configurações');
    }
  }

  // ==================== Configurações ====================

  /// Actualiza o URL da API a partir das Settings
  void updateFromSettings() {
    final settings = _ref.read(settingsProvider).settings;
    if (settings?.loyaltyApiUrl != null && settings!.loyaltyApiUrl!.isNotEmpty) {
      _dataSource.setBaseUrl(settings.loyaltyApiUrl!);
      
      if (settings.loyaltyApiKey != null && settings.loyaltyApiKey!.isNotEmpty) {
        _dataSource.setApiKey(settings.loyaltyApiKey!);
      }
      
      state = state.copyWith(
        apiUrl: settings.loyaltyApiUrl!,
        apiKey: settings.loyaltyApiKey ?? state.apiKey,
        isEnabled: settings.loyaltyEnabled ?? state.isEnabled,
        cardPrefix: settings.loyaltyCardPrefix ?? state.cardPrefix,
      );
    }
  }

  /// Activa ou desactiva o módulo Loyalty
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoyaltyEnabled, enabled);
    state = state.copyWith(isEnabled: enabled);

    if (enabled && state.apiUrl.isNotEmpty && state.apiKey.isNotEmpty) {
      await testConnection();
    }
  }

  /// Define o URL da API (usado pelo widget de settings)
  Future<void> setApiUrl(String url) async {
    _dataSource.setBaseUrl(url);
    state = state.copyWith(apiUrl: url);
  }

  /// Define a API Key (usado pelo widget de settings)
  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLoyaltyApiKey, key);
    _dataSource.setApiKey(key);
    state = state.copyWith(apiKey: key);
  }

  /// Define o prefixo dos cartões
  Future<void> setCardPrefix(String prefix) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLoyaltyCardPrefix, prefix);
    state = state.copyWith(cardPrefix: prefix);
  }

  /// Testa conexão com a API
  Future<bool> testConnection() async {
    if (state.apiUrl.isEmpty) {
      state = state.copyWith(
        isConnected: false,
        error: 'URL da API não configurado',
      );
      return false;
    }

    if (state.apiKey.isEmpty) {
      state = state.copyWith(
        isConnected: false,
        error: 'API Key não configurada',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final result = await _dataSource.testConnection();
      
      if (result.success) {
        state = state.copyWith(isLoading: false, isConnected: true);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          isConnected: false,
          error: result.error ?? 'Falha na autenticação',
        );
        return false;
      }
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

  /// Identifica cliente pelo código de barras do cartão (com cupões)
  Future<bool> identifyCustomerByBarcode(String barcode) async {
    if (!state.isEnabled) return false;
    if (!state.isFullyConfigured) {
      state = state.copyWith(error: 'API não configurada');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Tentar endpoint POS primeiro (que inclui cupões)
      final posInfo = await _dataSource.getPosCardInfo(barcode);
      
      if (posInfo != null) {
        final customer = LoyaltyCustomer(
          id: 0,
          name: posInfo.customerName ?? '',
          nif: posInfo.customerNif,
          card: LoyaltyCard(
            id: 0,
            cardNumber: posInfo.cardNumber ?? '',
            barcode: posInfo.barcode ?? barcode,
            pointsBalance: posInfo.pointsBalance,
            totalPointsEarned: 0,
            totalPointsRedeemed: 0,
            tier: LoyaltyTier.fromInt(posInfo.tier),
            status: CardStatus.active,
          ),
        );

        state = state.copyWith(
          isLoading: false,
          currentCustomer: customer,
          availableCoupons: posInfo.availableCoupons,
        );
        return true;
      }

      // Fallback para endpoint antigo
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
        availableCoupons: const [], // Sem cupões no endpoint antigo
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
      clearSelectedCoupon: true,
      clearCouponCalculation: true,
    );
  }

  // ==================== Cupões ====================

  /// Selecciona um cupão e calcula o desconto
  Future<void> selectCoupon(AvailableCoupon? coupon, List<CheckoutItem> items) async {
    if (coupon == null) {
      state = state.copyWith(
        clearSelectedCoupon: true,
        clearCouponCalculation: true,
      );
      return;
    }

    // Precisamos do cardIdentifier para chamar a API
    final cardIdentifier = state.currentCustomer?.card?.barcode ?? 
                           state.currentCustomer?.card?.cardNumber;
    
    if (cardIdentifier == null) {
      state = state.copyWith(
        error: 'Cartão não identificado',
        clearSelectedCoupon: true,
      );
      return;
    }

    state = state.copyWith(
      selectedCoupon: coupon,
      isLoading: true,
      error: null,
    );

    try {
      final result = await _dataSource.calculateCouponDiscount(
        cardIdentifier: cardIdentifier,
        couponCode: coupon.code,
        items: items,
      );

      state = state.copyWith(
        isLoading: false,
        couponCalculation: result,
      );
    } on LoyaltyApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
        clearSelectedCoupon: true,
        clearCouponCalculation: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao calcular desconto',
        clearSelectedCoupon: true,
        clearCouponCalculation: true,
      );
    }
  }

  /// Limpa cupão seleccionado
  void clearCoupon() {
    state = state.copyWith(
      clearSelectedCoupon: true,
      clearCouponCalculation: true,
    );
  }

  // ==================== Vendas ====================

  /// Passo 1: Registar venda (botão "Confirmar")
  Future<RegisterSaleResult?> registerSale({
    required double amount,
    String? paymentMethod,
    int pointsToRedeem = 0,
    List<CheckoutItem>? items,
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
        couponId: state.selectedCoupon?.id,
        items: state.selectedCoupon != null ? items : null,
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
        clearSelectedCoupon: true,
        clearCouponCalculation: true,
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
        clearSelectedCoupon: true,
        clearCouponCalculation: true,
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
