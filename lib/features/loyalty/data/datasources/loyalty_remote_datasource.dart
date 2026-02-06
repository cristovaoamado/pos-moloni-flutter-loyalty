import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/loyalty_customer_model.dart';
import '../models/sale_models.dart';
import '../models/coupon_models.dart';

/// Provider para o datasource
final loyaltyRemoteDataSourceProvider = Provider<LoyaltyRemoteDataSource>((ref) {
  return LoyaltyRemoteDataSource();
});

/// Resultado do teste de conexão
class ConnectionTestResult {
  final bool success;
  final String? error;
  
  const ConnectionTestResult({required this.success, this.error});
}

/// Datasource para comunicação com a API Loyalty
class LoyaltyRemoteDataSource {
  late final Dio _dio;
  String _baseUrl = 'http://localhost:5000/api';
  String _apiKey = '';

  LoyaltyRemoteDataSource() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    // Interceptor para adicionar API Key a todos os requests
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_apiKey.isNotEmpty) {
          options.headers['X-API-Key'] = _apiKey;
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        // Log de erros para debug
        if (error.response?.statusCode == 401) {
          // API Key inválida ou expirada
          return handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              error: 'API Key inválida ou expirada',
            ),
          );
        }
        return handler.next(error);
      },
    ));
  }

  /// Configura o URL base da API
  void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// Configura a API Key para autenticação
  void setApiKey(String apiKey) {
    _apiKey = apiKey;
  }

  String get baseUrl => _baseUrl;
  String get apiKey => _apiKey;
  bool get hasApiKey => _apiKey.isNotEmpty;

  // ==================== POS ====================

  /// Busca informação do cartão com cupões disponíveis
  /// Endpoint: GET /api/pos/card/{identifier}
  Future<PosCardInfoResult?> getPosCardInfo(String identifier) async {
    _ensureApiKey();
    
    try {
      final response = await _dio.get('$_baseUrl/pos/card/$identifier');
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          return PosCardInfoResult.fromJson(data['data'] as Map<String, dynamic>);
        }
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      if (e.response?.statusCode == 401) {
        throw LoyaltyApiException('API Key inválida ou expirada');
      }
      throw LoyaltyApiException('Erro ao buscar cartão: ${e.message}');
    }
  }

  /// Busca informação do cartão por código de barras (endpoint alternativo)
  /// Endpoint: GET /api/cards/barcode/{barcode}
  Future<CardInfoResponse?> getCardByBarcode(String barcode) async {
    _ensureApiKey();
    
    try {
      final response = await _dio.get('$_baseUrl/cards/barcode/$barcode');
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          return CardInfoResponse.fromJson(data['data'] as Map<String, dynamic>);
        }
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      if (e.response?.statusCode == 401) {
        throw LoyaltyApiException('API Key inválida ou expirada');
      }
      throw LoyaltyApiException('Erro ao buscar cartão: ${e.message}');
    }
  }

  /// Pesquisa clientes por termo
  /// Endpoint: GET /api/customers/search?term={term}
  Future<List<LoyaltyCustomerModel>> searchCustomers(String term) async {
    _ensureApiKey();
    
    try {
      final response = await _dio.get(
        '$_baseUrl/customers/search',
        queryParameters: {'term': term},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          final list = data['data'] as List;
          return list
              .map((e) => LoyaltyCustomerModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw LoyaltyApiException('API Key inválida ou expirada');
      }
      throw LoyaltyApiException('Erro ao pesquisar clientes: ${e.message}');
    }
  }

  // ==================== Cupões ====================

  /// Calcula desconto do cupão para os itens do carrinho
  /// Endpoint: POST /api/pos/coupon-discount/{cardIdentifier}
  Future<ApplyCouponResult?> calculateCouponDiscount({
    required String cardIdentifier,
    required String couponCode,
    required List<CheckoutItem> items,
  }) async {
    _ensureApiKey();
    
    try {
      final response = await _dio.post(
        '$_baseUrl/pos/coupon-discount/$cardIdentifier',
        data: {
          'couponCode': couponCode,
          'items': items.map((i) => i.toJson()).toList(),
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          return ApplyCouponResult.fromJson(data['data'] as Map<String, dynamic>);
        }
        // Se não tem wrapper, tenta parsear direto
        return ApplyCouponResult.fromJson(data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw LoyaltyApiException('API Key inválida ou expirada');
      }
      final message = _extractErrorMessage(e);
      throw LoyaltyApiException(message);
    }
  }

  // ==================== Vendas ====================

  /// Passo 1: Registar venda (botão "Confirmar")
  /// Endpoint: POST /api/pos/confirm
  Future<RegisterSaleResult> registerSale(RegisterSaleRequest request) async {
    _ensureApiKey();
    
    try {
      final response = await _dio.post(
        '$_baseUrl/pos/confirm',
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          return RegisterSaleResult.fromJson(data['data'] as Map<String, dynamic>);
        }
        throw LoyaltyApiException(data['message'] ?? 'Erro ao registar venda');
      }
      throw LoyaltyApiException('Erro ao registar venda');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw LoyaltyApiException('API Key inválida ou expirada');
      }
      final message = _extractErrorMessage(e);
      throw LoyaltyApiException(message);
    }
  }

  /// Passo 2: Finalizar venda (botão "Finalizar")
  /// Endpoint: POST /api/pos/sync
  Future<SaleResponse> completeSale(CompleteSaleRequest request) async {
    _ensureApiKey();
    
    try {
      final response = await _dio.post(
        '$_baseUrl/pos/sync',
        data: {
          'transactionId': request.saleId,
          'documentReference': request.documentReference,
          'documentId': request.documentId,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          // A resposta de sync não retorna a venda completa, criamos uma resposta simplificada
          return SaleResponse(
            id: request.saleId,
            saleDate: DateTime.now(),
            amount: 0,
            pointsEarned: 0,
            pointsRedeemed: 0,
            discountApplied: 0,
            status: 'Completed',
            createdAt: DateTime.now(),
          );
        }
        throw LoyaltyApiException(data['message'] ?? 'Erro ao finalizar venda');
      }
      throw LoyaltyApiException('Erro ao finalizar venda');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw LoyaltyApiException('API Key inválida ou expirada');
      }
      final message = _extractErrorMessage(e);
      throw LoyaltyApiException(message);
    }
  }

  /// Cancelar venda pendente
  /// Endpoint: POST /api/pos/cancel
  Future<bool> cancelSale(CancelSaleRequest request) async {
    _ensureApiKey();
    
    try {
      final response = await _dio.post(
        '$_baseUrl/pos/cancel',
        data: {
          'transactionId': request.saleId,
          'reason': request.reason,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return data['success'] == true;
      }
      return false;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw LoyaltyApiException('API Key inválida ou expirada');
      }
      final message = _extractErrorMessage(e);
      throw LoyaltyApiException(message);
    }
  }

  // ==================== Utilitários ====================

  /// Testa a conexão com a API (valida também a API Key)
  Future<ConnectionTestResult> testConnection() async {
    if (_apiKey.isEmpty) {
      return const ConnectionTestResult(
        success: false,
        error: 'API Key não configurada',
      );
    }

    try {
      // Usar endpoint de validação da API Key
      final response = await _dio.post(
        '$_baseUrl/auth/api-keys/validate',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          headers: {'X-API-Key': _apiKey},
        ),
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['valid'] == true) {
          return const ConnectionTestResult(success: true);
        }
        return ConnectionTestResult(
          success: false,
          error: data['message'] ?? 'API Key inválida',
        );
      }
      return const ConnectionTestResult(
        success: false,
        error: 'Erro ao validar API Key',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return const ConnectionTestResult(
          success: false,
          error: 'API Key inválida ou expirada',
        );
      }
      if (e.response?.statusCode == 400) {
        return ConnectionTestResult(
          success: false,
          error: e.response?.data?['message'] ?? 'API Key não fornecida',
        );
      }
      return ConnectionTestResult(
        success: false,
        error: 'Não foi possível conectar ao servidor: ${e.message}',
      );
    } catch (e) {
      return ConnectionTestResult(
        success: false,
        error: 'Erro de conexão: $e',
      );
    }
  }

  /// Verifica se a API Key está configurada
  void _ensureApiKey() {
    if (_apiKey.isEmpty) {
      throw LoyaltyApiException('API Key não configurada');
    }
  }

  /// Extrai mensagem de erro da resposta
  String _extractErrorMessage(DioException e) {
    if (e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map<String, dynamic>) {
        return data['message'] as String? ?? 'Erro desconhecido';
      }
    }
    return e.message ?? 'Erro de conexão';
  }
}

/// Exceção específica da API Loyalty
class LoyaltyApiException implements Exception {
  final String message;
  const LoyaltyApiException(this.message);

  @override
  String toString() => message;
}

/// Resultado completo do endpoint /api/pos/card/{identifier}
class PosCardInfoResult {
  final String? cardNumber;
  final String? barcode;
  final String? customerName;
  final String? customerNif;
  final int pointsBalance;
  final double pointsValue;
  final int tier;
  final String tierName;
  final bool canEarnPoints;
  final bool canRedeemPoints;
  final List<AvailableCoupon> availableCoupons;

  const PosCardInfoResult({
    this.cardNumber,
    this.barcode,
    this.customerName,
    this.customerNif,
    required this.pointsBalance,
    required this.pointsValue,
    required this.tier,
    required this.tierName,
    required this.canEarnPoints,
    required this.canRedeemPoints,
    required this.availableCoupons,
  });

  factory PosCardInfoResult.fromJson(Map<String, dynamic> json) {
    return PosCardInfoResult(
      cardNumber: json['cardNumber'] as String?,
      barcode: json['barcode'] as String?,
      customerName: json['customerName'] as String?,
      customerNif: json['customerNif'] as String?,
      pointsBalance: json['pointsBalance'] as int? ?? 0,
      pointsValue: (json['pointsValue'] as num?)?.toDouble() ?? 0,
      tier: json['tier'] as int? ?? 1,
      tierName: json['tierName'] as String? ?? 'Bronze',
      canEarnPoints: json['canEarnPoints'] as bool? ?? true,
      canRedeemPoints: json['canRedeemPoints'] as bool? ?? true,
      availableCoupons: (json['availableCoupons'] as List<dynamic>?)
              ?.map((e) => AvailableCoupon.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
