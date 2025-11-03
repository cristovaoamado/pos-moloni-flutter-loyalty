import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/constants/api_constants.dart';
import 'package:pos_moloni_app/core/errors/failures.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:pos_moloni_app/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:pos_moloni_app/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:pos_moloni_app/features/settings/domain/entities/app_settings.dart';
import 'package:pos_moloni_app/features/settings/domain/repositories/settings_repository.dart';
import 'package:pos_moloni_app/features/settings/domain/usecases/get_settings_usecase.dart';
import 'package:pos_moloni_app/features/settings/domain/usecases/save_settings_usecase.dart';

// ==================== PROVIDERS DE DEPENDÊNCIAS ====================

/// Provider do SettingsLocalDataSource
final settingsLocalDataSourceProvider = Provider<SettingsLocalDataSource>((ref) {
  return SettingsLocalDataSourceImpl(
    storage: ref.watch(secureStorageProvider),
  );
});

/// Provider do SettingsRepository
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl(
    localDataSource: ref.watch(settingsLocalDataSourceProvider),
  );
});

// ==================== PROVIDERS DE USE CASES ====================

/// Provider do GetSettingsUseCase
final getSettingsUseCaseProvider = Provider<GetSettingsUseCase>((ref) {
  return GetSettingsUseCase(ref.watch(settingsRepositoryProvider));
});

/// Provider do SaveSettingsUseCase
final saveSettingsUseCaseProvider = Provider<SaveSettingsUseCase>((ref) {
  return SaveSettingsUseCase(ref.watch(settingsRepositoryProvider));
});

// ==================== PROVIDER DE ESTADO ====================

/// Estado de configurações
class SettingsState {

  const SettingsState({
    this.settings,
    this.isLoading = false,
    this.error,
    this.isSaving = false,
  });
  final AppSettings? settings;
  final bool isLoading;
  final String? error;
  final bool isSaving;

  SettingsState copyWith({
    AppSettings? settings,
    bool? isLoading,
    String? error,
    bool? isSaving,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

/// Notifier para gestão do estado de configurações
class SettingsNotifier extends StateNotifier<SettingsState> {

  SettingsNotifier({
    required this.getSettingsUseCase,
    required this.saveSettingsUseCase,
  }) : super(const SettingsState()) {
    // Carregar configurações ao inicializar
    loadSettings();
  }
  final GetSettingsUseCase getSettingsUseCase;
  final SaveSettingsUseCase saveSettingsUseCase;

  /// Carregar configurações
  Future<void> loadSettings() async {
    AppLogger.i('📥 Carregando configurações...');

    state = state.copyWith(isLoading: true);

    final result = await getSettingsUseCase.call();

    result.fold(
      (failure) {
        AppLogger.e('❌ Erro ao carregar configurações: ${failure.message}');
        state = state.copyWith(
          isLoading: false,
          error: failure.getUserFriendlyMessage(),
        );
      },
      (settings) {
        AppLogger.i('✅ Configurações carregadas');
        state = state.copyWith(
          settings: settings,
          isLoading: false,
          error: null,
        );
      },
    );
  }

  /// Guardar configurações
  Future<bool> saveSettings(AppSettings settings) async {
    AppLogger.i('💾 Guardando configurações...');

    state = state.copyWith(isSaving: true, error: null);

    final result = await saveSettingsUseCase.call(settings);

    return result.fold(
      (failure) {
        AppLogger.e('❌ Erro ao guardar configurações: ${failure.message}');
        state = state.copyWith(
          isSaving: false,
          error: failure.getUserFriendlyMessage(),
        );
        return false;
      },
      (_) {
        AppLogger.i('✅ Configurações guardadas');
        state = state.copyWith(
          settings: settings,
          isSaving: false,
          error: null,
        );
        return true;
      },
    );
  }

  /// Limpar erro
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Obter configurações default
  AppSettings getDefaultSettings() {
    return const AppSettings(
      apiUrl: ApiConstants.defaultMoloniApiUrl,
      clientId: '',
      clientSecret: '',
    );
  }
}

/// Provider do SettingsNotifier
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(
    getSettingsUseCase: ref.watch(getSettingsUseCaseProvider),
    saveSettingsUseCase: ref.watch(saveSettingsUseCaseProvider),
  );
});

/// Provider conveniente para verificar se tem configurações válidas
final hasValidSettingsProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsProvider).settings;
  return settings?.isValid ?? false;
});
