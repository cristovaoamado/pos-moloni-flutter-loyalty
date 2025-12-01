import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:pos_moloni_app/core/constants/api_constants.dart';
import 'package:pos_moloni_app/core/errors/exceptions.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/customers/data/models/customer_model.dart';

/// Interface para o datasource remoto de clientes
abstract class CustomerRemoteDataSource {
  /// Pesquisa clientes por nome, NIF ou número
  Future<List<CustomerModel>> searchByQuery(String query);

  /// Pesquisa cliente por NIF
  Future<CustomerModel?> getByVat(String vat);

  /// Obtém próximo número de cliente disponível
  Future<String> getNextNumber();

  /// Insere um novo cliente
  Future<CustomerModel> insert(CustomerModel customer);
}

/// Implementação do datasource remoto
class CustomerRemoteDataSourceImpl implements CustomerRemoteDataSource {
  CustomerRemoteDataSourceImpl({
    required this.dio,
    required this.secureStorage,
  });

  final Dio dio;
  final FlutterSecureStorage secureStorage;

  Future<Map<String, String>> _getAuthParams() async {
    final accessToken = await secureStorage.read(key: ApiConstants.keyAccessToken);
    final companyId = await secureStorage.read(key: ApiConstants.keyCompanyId);
    final apiUrl = await secureStorage.read(key: ApiConstants.keyApiUrl) ?? 
                   ApiConstants.defaultMoloniApiUrl;

    if (accessToken == null) {
      throw const TokenExpiredException('Token não encontrado');
    }

    if (companyId == null) {
      throw const ServerException('Empresa não selecionada');
    }

    return {
      'accessToken': accessToken,
      'companyId': companyId,
      'apiUrl': apiUrl,
    };
  }

  @override
  Future<List<CustomerModel>> searchByQuery(String query) async {
    try {
      final params = await _getAuthParams();

      AppLogger.d('🔍 [CustomerDS] searchByQuery: $query');

      final url = '${params['apiUrl']}/customers/getBySearch/?access_token=${params['accessToken']}';

      final response = await dio.post(
        url,
        data: {
          'company_id': params['companyId'],
          'search': query,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      AppLogger.d('📦 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;

        if (data is List) {
          AppLogger.i('✅ Encontrados ${data.length} clientes');
          
          return data
              .map((json) => CustomerModel.fromJson(json as Map<String, dynamic>))
              .toList();
        } else if (data is Map && data.containsKey('error')) {
          throw ServerException(data['error_description'] ?? 'Erro na API');
        }

        return [];
      } else if (response.statusCode == 401) {
        throw const TokenExpiredException('Token expirado');
      } else {
        throw ServerException('Erro ${response.statusCode}');
      }
    } on DioException catch (e) {
      AppLogger.e('❌ DioException ao pesquisar clientes: ${e.message}');
      _handleDioException(e);
      rethrow;
    } catch (e) {
      AppLogger.e('⛔ Erro inesperado ao pesquisar clientes: $e');
      rethrow;
    }
  }

  @override
  Future<CustomerModel?> getByVat(String vat) async {
    try {
      final params = await _getAuthParams();

      AppLogger.d('🔍 [CustomerDS] getByVat: $vat');

      final url = '${params['apiUrl']}/customers/getByVat/?access_token=${params['accessToken']}';

      final response = await dio.post(
        url,
        data: {
          'company_id': params['companyId'],
          'vat': vat,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        if (data is List && data.isNotEmpty) {
          AppLogger.i('✅ Cliente encontrado por NIF');
          return CustomerModel.fromJson(data.first as Map<String, dynamic>);
        }

        return null;
      } else if (response.statusCode == 401) {
        throw const TokenExpiredException('Token expirado');
      } else {
        throw ServerException('Erro ${response.statusCode}');
      }
    } on DioException catch (e) {
      AppLogger.e('❌ DioException ao buscar cliente por NIF: ${e.message}');
      _handleDioException(e);
      rethrow;
    } catch (e) {
      AppLogger.e('⛔ Erro inesperado ao buscar cliente por NIF: $e');
      rethrow;
    }
  }

  @override
  Future<String> getNextNumber() async {
    try {
      final params = await _getAuthParams();

      AppLogger.d('🔍 [CustomerDS] getNextNumber');

      final url = '${params['apiUrl']}/customers/getNextNumber/?access_token=${params['accessToken']}';

      final response = await dio.post(
        url,
        data: {
          'company_id': params['companyId'],
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        if (data is Map && data.containsKey('number')) {
          AppLogger.i('✅ Próximo número de cliente: ${data['number']}');
          return data['number'].toString();
        }

        throw const ServerException('Resposta inválida ao obter próximo número');
      } else if (response.statusCode == 401) {
        throw const TokenExpiredException('Token expirado');
      } else {
        throw ServerException('Erro ${response.statusCode}');
      }
    } on DioException catch (e) {
      AppLogger.e('❌ DioException ao obter próximo número: ${e.message}');
      _handleDioException(e);
      rethrow;
    } catch (e) {
      AppLogger.e('⛔ Erro inesperado ao obter próximo número: $e');
      rethrow;
    }
  }

  @override
  Future<CustomerModel> insert(CustomerModel customer) async {
    try {
      final params = await _getAuthParams();

      AppLogger.d('🔍 [CustomerDS] insert: ${customer.name}');

      final url = '${params['apiUrl']}/customers/insert/?access_token=${params['accessToken']}';

      // Preparar dados para envio
      final data = {
        'company_id': params['companyId'],
        ...customer.toJson(),
      };

      // country_id obrigatório - default Portugal
      if (data['country_id'] == null) {
        data['country_id'] = 1; // Portugal
      }

      // language_id obrigatório - default Português
      if (data['language_id'] == null) {
        data['language_id'] = 1; // Português
      }

      // maturity_date_id obrigatório - default Pronto pagamento
      if (data['maturity_date_id'] == null) {
        data['maturity_date_id'] = 0; // Pronto pagamento
      }

      AppLogger.d('📤 Dados a enviar: $data');

      final response = await dio.post(
        url,
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      AppLogger.d('📦 Response status: ${response.statusCode}');
      AppLogger.d('📦 Response data: ${response.data}');

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData is Map) {
          if (responseData.containsKey('customer_id')) {
            AppLogger.i('✅ Cliente criado com ID: ${responseData['customer_id']}');
            
            // Retornar cliente com o ID atribuído
            return customer.copyWith(
              id: responseData['customer_id'] as int,
            );
          } else if (responseData.containsKey('error')) {
            throw ServerException(responseData['error_description'] ?? 'Erro ao criar cliente');
          }
        }

        throw const ServerException('Resposta inválida ao criar cliente');
      } else if (response.statusCode == 401) {
        throw const TokenExpiredException('Token expirado');
      } else {
        throw ServerException('Erro ${response.statusCode}');
      }
    } on DioException catch (e) {
      AppLogger.e('❌ DioException ao criar cliente: ${e.message}');
      _handleDioException(e);
      rethrow;
    } catch (e) {
      AppLogger.e('⛔ Erro inesperado ao criar cliente: $e');
      rethrow;
    }
  }

  void _handleDioException(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw const TimeoutException('Timeout na ligação');
    }

    if (e.type == DioExceptionType.connectionError) {
      throw const NetworkException('Erro de rede');
    }

    if (e.response?.statusCode == 401) {
      throw const TokenExpiredException('Token expirado');
    }

    if (e.response?.statusCode == 403) {
      final error = e.response?.data is Map 
          ? e.response?.data['error_description'] 
          : 'Acesso negado';
      throw ServerException(error ?? 'Forbidden');
    }

    throw ServerException(e.message ?? 'Erro desconhecido');
  }
}
