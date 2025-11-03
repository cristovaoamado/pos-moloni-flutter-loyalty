import 'package:dartz/dartz.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:pos_moloni_app/core/constants/api_constants.dart';
import 'package:pos_moloni_app/core/errors/exceptions.dart';
import 'package:pos_moloni_app/core/errors/failures.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/company/data/datasources/company_remote_datasource.dart';
import 'package:pos_moloni_app/features/company/domain/entities/company.dart';
import 'package:pos_moloni_app/features/company/domain/repositories/company_repository.dart';

/// Implementação do repositório de empresas
class CompanyRepositoryImpl implements CompanyRepository {

  CompanyRepositoryImpl({
    required this.remoteDataSource,
    required this.storage,
  });
  final CompanyRemoteDataSource remoteDataSource;
  final FlutterSecureStorage storage;

  @override
  Future<Either<Failure, List<Company>>> getCompanies() async {
    try {
      AppLogger.i('🏢 Carregando empresas...');

      final companies = await remoteDataSource.getCompanies();

      return Right(companies.map((model) => model.toEntity()).toList());
    } on TokenExpiredException {
      AppLogger.w('❌ Token expirado ao carregar empresas');
      return const Left(TokenExpiredFailure());
    } on NetworkException {
      AppLogger.w('❌ Erro de rede');
      return const Left(NetworkFailure());
    } on TimeoutException {
      AppLogger.w('❌ Timeout');
      return const Left(TimeoutFailure());
    } on ServerException catch (e) {
      AppLogger.e('❌ Erro no servidor', error: e);
      return Left(ServerFailure(e.message));
    } catch (e) {
      AppLogger.e('❌ Erro inesperado ao carregar empresas', error: e);
      return const Left(UnexpectedFailure('Erro ao carregar empresas'));
    }
  }

  @override
  Future<Either<Failure, void>> selectCompany(Company company) async {
    try {
      AppLogger.i('🏢 Selecionando empresa: ${company.name}');

      // Guardar dados da empresa selecionada
      await storage.write(
        key: ApiConstants.keyCompanyId,
        value: company.id.toString(),
      );
      await storage.write(key: ApiConstants.keyCompanyName, value: company.name);

      // Guardar outros dados opcionais
      await storage.write(key: 'company_email', value: company.email);
      await storage.write(key: 'company_address', value: company.address);
      await storage.write(key: 'company_city', value: company.city);
      await storage.write(key: 'company_zip_code', value: company.zipCode);
      await storage.write(key: 'company_vat', value: company.vat);

      AppLogger.i('✅ Empresa selecionada com sucesso');
      return const Right(null);
    } catch (e) {
      AppLogger.e('❌ Erro ao selecionar empresa', error: e);
      return const Left(CacheFailure('Erro ao guardar empresa selecionada'));
    }
  }

  @override
  Future<Either<Failure, Company?>> getSelectedCompany() async {
    try {
      final companyId = await storage.read(key: ApiConstants.keyCompanyId);
      final companyName = await storage.read(key: ApiConstants.keyCompanyName);

      if (companyId == null || companyName == null) {
        return const Right(null);
      }

      // Reconstruir objeto Company com dados básicos
      final company = Company(
        id: int.parse(companyId),
        name: companyName,
        vat: await storage.read(key: 'company_vat') ?? '',
        email: await storage.read(key: 'company_email') ?? '',
        address: await storage.read(key: 'company_address') ?? '',
        city: await storage.read(key: 'company_city') ?? '',
        zipCode: await storage.read(key: 'company_zip_code') ?? '',
      );

      return Right(company);
    } catch (e) {
      AppLogger.e('❌ Erro ao obter empresa selecionada', error: e);
      return const Left(CacheFailure('Erro ao obter empresa selecionada'));
    }
  }

  @override
  Future<Either<Failure, void>> clearSelectedCompany() async {
    try {
      await storage.delete(key: ApiConstants.keyCompanyId);
      await storage.delete(key: ApiConstants.keyCompanyName);
      await storage.delete(key: 'company_email');
      await storage.delete(key: 'company_address');
      await storage.delete(key: 'company_city');
      await storage.delete(key: 'company_zip_code');
      await storage.delete(key: 'company_vat');

      AppLogger.i('✅ Empresa desmarcada');
      return const Right(null);
    } catch (e) {
      AppLogger.e('❌ Erro ao limpar empresa', error: e);
      return const Left(CacheFailure('Erro ao limpar empresa'));
    }
  }
}
