import 'package:dartz/dartz.dart';

import 'package:pos_moloni_app/core/errors/failures.dart';
import 'package:pos_moloni_app/features/company/domain/entities/company.dart';
import 'package:pos_moloni_app/features/company/domain/repositories/company_repository.dart';

/// Use Case para selecionar uma empresa
class SelectCompanyUseCase {

  SelectCompanyUseCase(this.repository);
  final CompanyRepository repository;

  Future<Either<Failure, void>> call(Company company) async {
    return await repository.selectCompany(company);
  }
}