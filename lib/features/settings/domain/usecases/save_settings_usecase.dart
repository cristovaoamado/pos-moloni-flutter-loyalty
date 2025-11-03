import 'package:dartz/dartz.dart';

import 'package:pos_moloni_app/core/errors/failures.dart';
import 'package:pos_moloni_app/features/settings/domain/entities/app_settings.dart';
import 'package:pos_moloni_app/features/settings/domain/repositories/settings_repository.dart';

/// Use Case para guardar configurações
class SaveSettingsUseCase {

  SaveSettingsUseCase(this.repository);
  final SettingsRepository repository;

  Future<Either<Failure, void>> call(AppSettings settings) async {
    // Validação de negócio
    if (!settings.isValid) {
      return const Left(
        ValidationFailure('Configurações inválidas: faltam dados obrigatórios'),
      );
    }

    return await repository.saveSettings(settings);
  }
}