import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:pos_moloni_app/core/constants/api_constants.dart';
import 'package:pos_moloni_app/core/errors/exceptions.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/company/data/models/company_model.dart';

/// Interface do datasource remoto de empresas
abstract class CompanyRemoteDataSource {
  Future<List<CompanyModel>> getCompanies();
}

/// Implementação usando Dio
class CompanyRemoteDataSourceImpl implements CompanyRemoteDataSource {

  CompanyRemoteDataSourceImpl({
    required this.dio,
    required this.storage,
  });
  final Dio dio;
  final FlutterSecureStorage storage;

  @override
  Future<List<CompanyModel>> getCompanies() async {
    try {
      final apiUrl = await storage.read(key: ApiConstants.keyApiUrl) ??
          ApiConstants.defaultMoloniApiUrl;
      final accessToken = await storage.read(key: ApiConstants.keyAccessToken);

      if (accessToken == null) {
        throw const AuthenticationException('Token de acesso não encontrado');
      }

      final url = '$apiUrl/${ApiConstants.companiesGetAll}?access_token=$accessToken';

      AppLogger.moloniApi('companies/getAll');

      final response = await dio.get(url);

      if (response.statusCode == 200 && response.data is List) {
        final companies = (response.data as List)
            .map((json) => CompanyModel.fromJson(json as Map<String, dynamic>))
            .toList();

        AppLogger.i('✅ ${companies.length} empresas carregadas');
        return companies;
      }

      throw ServerException(
        'Resposta inválida do servidor',
        response.statusCode.toString(),
      );
    } on DioException catch (e) {
      AppLogger.e('Erro ao carregar empresas', error: e);

      if (e.response?.statusCode == 401) {
        throw const TokenExpiredException();
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const TimeoutException();
      } else if (e.type == DioExceptionType.connectionError) {
        throw const NetworkException();
      }

      throw ServerException(
        e.response?.data?.toString() ?? 'Erro no servidor',
        e.response?.statusCode.toString(),
      );
    } catch (e) {
      AppLogger.e('Erro inesperado ao carregar empresas', error: e);

      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }
}
