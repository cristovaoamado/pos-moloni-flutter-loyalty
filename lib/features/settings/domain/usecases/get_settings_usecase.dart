import 'package:dartz/dartz.dart';

import 'package:pos_moloni_app/core/errors/failures.dart';
import 'package:pos_moloni_app/features/settings/domain/entities/app_settings.dart';
import 'package:pos_moloni_app/features/settings/domain/repositories/settings_repository.dart';

/// Use Case para obter configurações
class GetSettingsUseCase {

  GetSettingsUseCase(this.repository);
  final SettingsRepository repository;

  Future<Either<Failure, AppSettings?>> call() async {
    return await repository.getSettings();
  }
}
