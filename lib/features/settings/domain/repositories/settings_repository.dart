import 'package:dartz/dartz.dart';

import 'package:pos_moloni_app/core/errors/failures.dart';
import 'package:pos_moloni_app/features/settings/domain/entities/app_settings.dart';

/// Interface do repositório de configurações
abstract class SettingsRepository {
  /// Obtém configurações guardadas
  Future<Either<Failure, AppSettings?>> getSettings();

  /// Guarda configurações
  Future<Either<Failure, void>> saveSettings(AppSettings settings);

  /// Limpa todas as configurações
  Future<Either<Failure, void>> clearSettings();
}
