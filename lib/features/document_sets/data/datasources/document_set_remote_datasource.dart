import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:pos_moloni_app/core/constants/api_constants.dart';
import 'package:pos_moloni_app/core/errors/exceptions.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/document_sets/data/models/document_set_model.dart';

/// Interface para o datasource remoto de séries de documentos
abstract class DocumentSetRemoteDataSource {
  /// Obtém todas as séries de documentos da empresa
  Future<List<DocumentSetModel>> getAll();
}

/// Implementação do datasource remoto
class DocumentSetRemoteDataSourceImpl implements DocumentSetRemoteDataSource {
  DocumentSetRemoteDataSourceImpl({
    required this.dio,
    required this.secureStorage,
  });

  final Dio dio;
  final FlutterSecureStorage secureStorage;

  @override
  Future<List<DocumentSetModel>> getAll() async {
    try {
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

      AppLogger.d('🔍 [DocumentSetDS] getAll');
      AppLogger.d('   - companyId: $companyId');

      final url = '$apiUrl/documentSets/getAll/?access_token=$accessToken';

      final response = await dio.post(
        url,
        data: {
          'company_id': companyId,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      AppLogger.d('📦 Response status: ${response.statusCode}');
      AppLogger.d('📦 Response data type: ${response.data.runtimeType}');

      if (response.statusCode == 200) {
        final data = response.data;

        if (data is List) {
          AppLogger.i('✅ Encontradas ${data.length} séries de documentos');
          
          // Log detalhado de cada série
          for (final item in data) {
            if (item is Map) {
              AppLogger.d('📄 Série: ${item['name']} (ID: ${item['document_set_id']})');
              AppLogger.d('   active_by_default: ${item['active_by_default']} (type: ${item['active_by_default']?.runtimeType})');
              
              // Verificar outros campos que podem indicar tipos suportados
              if (item['document_type_templates'] != null) {
                AppLogger.d('   document_type_templates: ${item['document_type_templates']}');
              }
              if (item['template'] != null) {
                AppLogger.d('   template: ${item['template']}');
              }
            }
          }
          
          return data
              .map((json) => DocumentSetModel.fromJson(json as Map<String, dynamic>))
              .toList();
        } else if (data is Map && data.containsKey('error')) {
          throw ServerException(data['error_description'] ?? 'Erro na API');
        }

        return [];
      } else if (response.statusCode == 401) {
        throw const TokenExpiredException('Token expirado');
      } else if (response.statusCode == 403) {
        final error = response.data is Map ? response.data['error_description'] : 'Acesso negado';
        throw ServerException(error ?? 'Forbidden');
      } else {
        throw ServerException('Erro ${response.statusCode}');
      }
    } on DioException catch (e) {
      AppLogger.e('❌ DioException ao obter séries: ${e.message}');

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
    } catch (e) {
      AppLogger.e('⛔ Erro inesperado ao obter séries: $e');
      rethrow;
    }
  }
}
