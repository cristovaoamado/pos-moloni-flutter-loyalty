import 'package:dartz/dartz.dart';

import 'package:pos_moloni_app/core/errors/failures.dart';
import 'package:pos_moloni_app/features/company/domain/entities/company.dart';

/// Interface do repositório de empresas
abstract class CompanyRepository {
  /// Obtém lista de empresas do utilizador autenticado
  Future<Either<Failure, List<Company>>> getCompanies();

  /// Seleciona uma empresa (guarda ID localmente)
  Future<Either<Failure, void>> selectCompany(Company company);

  /// Obtém empresa selecionada atualmente
  Future<Either<Failure, Company?>> getSelectedCompany();

  /// Limpa seleção de empresa
  Future<Either<Failure, void>> clearSelectedCompany();
}
