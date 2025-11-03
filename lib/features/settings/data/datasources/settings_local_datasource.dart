import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:pos_moloni_app/core/constants/api_constants.dart';
import 'package:pos_moloni_app/core/errors/exceptions.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/settings/data/models/app_settings_model.dart';

/// Interface do datasource local de configurações
abstract class SettingsLocalDataSource {
  /// Obtém configurações guardadas
  Future<AppSettingsModel?> getSettings();

  /// Guarda configurações
  Future<void> saveSettings(AppSettingsModel settings);

  /// Limpa todas as configurações
  Future<void> clearSettings();
}

/// Implementação usando FlutterSecureStorage
class SettingsLocalDataSourceImpl implements SettingsLocalDataSource {

  SettingsLocalDataSourceImpl({required this.storage});
  final FlutterSecureStorage storage;

  @override
  Future<AppSettingsModel?> getSettings() async {
    try {
      final apiUrl =
          await storage.read(key: ApiConstants.keyApiUrl) ??
          ApiConstants.defaultMoloniApiUrl;
      final clientId = await storage.read(key: ApiConstants.keyClientId);
      final clientSecret =
          await storage.read(key: ApiConstants.keyClientSecret);
      final customApiUrl =
          await storage.read(key: ApiConstants.keyCustomApiUrl);
      final defaultMarginStr =
          await storage.read(key: ApiConstants.keyDefaultMargin);
      final printerMac = await storage.read(key: ApiConstants.keyPrinterMac);

      // Se não tem as credenciais básicas, retornar null
      if (clientId == null || clientSecret == null) {
        AppLogger.d('Nenhuma configuração completa encontrada');
        return null;
      }

      final defaultMargin =
          defaultMarginStr != null ? double.tryParse(defaultMarginStr) : null;

      final settings = AppSettingsModel(
        apiUrl: apiUrl,
        clientId: clientId,
        clientSecret: clientSecret,
        customApiUrl: customApiUrl,
        defaultMargin: defaultMargin,
        printerMac: printerMac,
      );

      AppLogger.cache('GET', 'settings', count: 1);
      return settings;
    } catch (e) {
      AppLogger.e('Erro ao ler configurações', error: e);
      throw const CacheException('Erro ao ler configurações guardadas');
    }
  }

  @override
  Future<void> saveSettings(AppSettingsModel settings) async {
    try {
      await storage.write(
        key: ApiConstants.keyApiUrl,
        value: settings.apiUrl,
      );
      await storage.write(
        key: ApiConstants.keyClientId,
        value: settings.clientId,
      );
      await storage.write(
        key: ApiConstants.keyClientSecret,
        value: settings.clientSecret,
      );

      // Campos opcionais
      if (settings.customApiUrl != null && settings.customApiUrl!.isNotEmpty) {
        await storage.write(
          key: ApiConstants.keyCustomApiUrl,
          value: settings.customApiUrl!,
        );
      }

      if (settings.defaultMargin != null && settings.defaultMargin! > 0) {
        await storage.write(
          key: ApiConstants.keyDefaultMargin,
          value: settings.defaultMargin!.toString(),
        );
      }

      if (settings.printerMac != null && settings.printerMac!.isNotEmpty) {
        await storage.write(
          key: ApiConstants.keyPrinterMac,
          value: settings.printerMac!,
        );
      }

      AppLogger.cache('SAVE', 'settings');
    } catch (e) {
      AppLogger.e('Erro ao guardar configurações', error: e);
      throw const CacheException('Erro ao guardar configurações');
    }
  }

  @override
  Future<void> clearSettings() async {
    try {
      await storage.delete(key: ApiConstants.keyApiUrl);
      await storage.delete(key: ApiConstants.keyClientId);
      await storage.delete(key: ApiConstants.keyClientSecret);
      await storage.delete(key: ApiConstants.keyCustomApiUrl);
      await storage.delete(key: ApiConstants.keyDefaultMargin);
      await storage.delete(key: ApiConstants.keyPrinterMac);

      AppLogger.cache('DELETE', 'all_settings');
    } catch (e) {
      AppLogger.e('Erro ao limpar configurações', error: e);
      throw const CacheException('Erro ao limpar configurações');
    }
  }
}
