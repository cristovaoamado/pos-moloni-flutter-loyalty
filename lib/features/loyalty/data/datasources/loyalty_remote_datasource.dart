import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/loyalty_customer_model.dart';
import '../models/sale_models.dart';
import '../models/coupon_models.dart';

/// Provider para o datasource
final loyaltyRemoteDataSourceProvider = Provider<LoyaltyRemoteDataSource>((ref) {
  return LoyaltyRemoteDataSource();
});

/// Datasource para comunicação com a API Loyalty
class LoyaltyRemoteDataSource {
  late final Dio _dio;
  String _baseUrl = 'http://localhost:5000/api';

  LoyaltyRemoteDataSource() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
  }

  /// Configura o URL base da API
  void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  String get baseUrl => _baseUrl;

  // ==================== POS ====================

  /// Busca informação do cartão com cupões disponíveis
  /// Endpoint: GET /api/pos/card/{identifier}
  Future<PosCardInfoResult?> getPosCardInfo(String identifier) async {
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
      throw LoyaltyApiException('Erro ao buscar cartão: ${e.message}');
    }
  }

  /// Busca informação do cartão por código de barras (endpoint alternativo)
  /// Endpoint: GET /api/cards/barcode/{barcode}
  Future<CardInfoResponse?> getCardByBarcode(String barcode) async {
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
      throw LoyaltyApiException('Erro ao buscar cartão: ${e.message}');
    }
  }

  /// Pesquisa clientes por termo
  /// Endpoint: GET /api/customers/search?term={term}
  Future<List<LoyaltyCustomerModel>> searchCustomers(String term) async {
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
      final message = _extractErrorMessage(e);
      throw LoyaltyApiException(message);
    }
  }

  // ==================== Vendas ====================

  /// Passo 1: Registar venda (botão "Confirmar")
  /// Endpoint: POST /api/pos/confirm
  Future<RegisterSaleResult> registerSale(RegisterSaleRequest request) async {
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
      final message = _extractErrorMessage(e);
      throw LoyaltyApiException(message);
    }
  }

  /// Passo 2: Finalizar venda (botão "Finalizar")
  /// Endpoint: POST /api/pos/sync
  Future<SaleResponse> completeSale(CompleteSaleRequest request) async {
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
      final message = _extractErrorMessage(e);
      throw LoyaltyApiException(message);
    }
  }

  /// Cancelar venda pendente
  /// Endpoint: POST /api/pos/cancel
  Future<bool> cancelSale(CancelSaleRequest request) async {
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
      final message = _extractErrorMessage(e);
      throw LoyaltyApiException(message);
    }
  }

  // ==================== Utilitários ====================

  /// Testa a conexão com a API
  Future<bool> testConnection() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/dashboard/stats',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
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
