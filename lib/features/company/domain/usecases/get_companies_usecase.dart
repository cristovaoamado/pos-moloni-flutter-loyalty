import 'package:dartz/dartz.dart';

import 'package:pos_moloni_app/core/errors/failures.dart';
import 'package:pos_moloni_app/features/company/domain/entities/company.dart';
import 'package:pos_moloni_app/features/company/domain/repositories/company_repository.dart';

/// Use Case para obter lista de empresas
class GetCompaniesUseCase {

  GetCompaniesUseCase(this.repository);
  final CompanyRepository repository;

  Future<Either<Failure, List<Company>>> call() async {
    return await repository.getCompanies();
  }
}
