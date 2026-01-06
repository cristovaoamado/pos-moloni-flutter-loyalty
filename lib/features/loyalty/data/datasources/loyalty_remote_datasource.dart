import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/loyalty_customer_model.dart';
import '../models/sale_models.dart';

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

  // ==================== Cartões ====================

  /// Busca informação do cartão por código de barras
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

  // ==================== Vendas ====================

  /// Passo 1: Registar venda (botão "Confirmar")
  /// Endpoint: POST /api/sales/register
  Future<RegisterSaleResult> registerSale(RegisterSaleRequest request) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/sales/register',
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
  /// Endpoint: POST /api/sales/complete
  Future<SaleResponse> completeSale(CompleteSaleRequest request) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/sales/complete',
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          return SaleResponse.fromJson(data['data'] as Map<String, dynamic>);
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
  /// Endpoint: POST /api/sales/cancel
  Future<bool> cancelSale(CancelSaleRequest request) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/sales/cancel',
        data: request.toJson(),
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
        '$_baseUrl/sales/today/stats',
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
