import 'package:dartz/dartz.dart';

import 'package:pos_moloni_app/core/errors/exceptions.dart';
import 'package:pos_moloni_app/core/errors/failures.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:pos_moloni_app/features/settings/data/models/app_settings_model.dart';
import 'package:pos_moloni_app/features/settings/domain/entities/app_settings.dart';
import 'package:pos_moloni_app/features/settings/domain/repositories/settings_repository.dart';

/// Implementação do repositório de configurações
class SettingsRepositoryImpl implements SettingsRepository {

  SettingsRepositoryImpl({required this.localDataSource});
  final SettingsLocalDataSource localDataSource;

  @override
  Future<Either<Failure, AppSettings?>> getSettings() async {
    try {
      final settings = await localDataSource.getSettings();
      
      if (settings == null) {
        return const Right(null);
      }

      return Right(settings.toEntity());
    } on CacheException catch (e) {
      AppLogger.e('❌ Erro ao obter configurações', error: e);
      return Left(CacheFailure(e.message));
    } catch (e) {
      AppLogger.e('❌ Erro inesperado ao obter configurações', error: e);
      return const Left(UnexpectedFailure('Erro ao obter configurações'));
    }
  }

  @override
  Future<Either<Failure, void>> saveSettings(AppSettings settings) async {
    try {
      final model = AppSettingsModel.fromEntity(settings);
      await localDataSource.saveSettings(model);
      
      AppLogger.i('✅ Configurações guardadas');
      return const Right(null);
    } on CacheException catch (e) {
      AppLogger.e('❌ Erro ao guardar configurações', error: e);
      return Left(CacheFailure(e.message));
    } catch (e) {
      AppLogger.e('❌ Erro inesperado ao guardar configurações', error: e);
      return const Left(UnexpectedFailure('Erro ao guardar configurações'));
    }
  }

  @override
  Future<Either<Failure, void>> clearSettings() async {
    try {
      await localDataSource.clearSettings();
      
      AppLogger.i('✅ Configurações limpas');
      return const Right(null);
    } on CacheException catch (e) {
      AppLogger.e('❌ Erro ao limpar configurações', error: e);
      return Left(CacheFailure(e.message));
    } catch (e) {
      AppLogger.e('❌ Erro inesperado ao limpar configurações', error: e);
      return const Left(UnexpectedFailure('Erro ao limpar configurações'));
    }
  }
}