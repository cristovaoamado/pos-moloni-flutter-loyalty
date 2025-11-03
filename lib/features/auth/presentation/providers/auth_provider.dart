import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pos_moloni_app/core/errors/failures.dart';

import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:pos_moloni_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:pos_moloni_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:pos_moloni_app/features/auth/domain/entities/user.dart';
import 'package:pos_moloni_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:pos_moloni_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:pos_moloni_app/features/auth/domain/usecases/logout_usecase.dart';
import 'package:pos_moloni_app/features/auth/domain/usecases/refresh_token_usecase.dart';

// ==================== PROVIDERS DE DEPENDÊNCIAS ====================

/// Provider do Dio (HTTP client)
final dioProvider = Provider<Dio>((ref) {
  return Dio();
});

/// Provider do FlutterSecureStorage
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

/// Provider do AuthLocalDataSource
final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  return AuthLocalDataSourceImpl(
    storage: ref.watch(secureStorageProvider),
  );
});

/// Provider do AuthRemoteDataSource
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(
    dio: ref.watch(dioProvider),
    storage: ref.watch(secureStorageProvider),
  );
});

/// Provider do AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    localDataSource: ref.watch(authLocalDataSourceProvider),
  );
});

// ==================== PROVIDERS DE USE CASES ====================

/// Provider do LoginUseCase
final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(ref.watch(authRepositoryProvider));
});

/// Provider do LogoutUseCase
final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  return LogoutUseCase(ref.watch(authRepositoryProvider));
});

/// Provider do RefreshTokenUseCase
final refreshTokenUseCaseProvider = Provider<RefreshTokenUseCase>((ref) {
  return RefreshTokenUseCase(ref.watch(authRepositoryProvider));
});

// ==================== PROVIDER DE ESTADO DE AUTENTICAÇÃO ====================

/// Estado de autenticação
class AuthState {

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });
  final User? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

/// Notifier para gestão do estado de autenticação
class AuthNotifier extends StateNotifier<AuthState> {

  AuthNotifier({
    required this.loginUseCase,
    required this.logoutUseCase,
    required this.refreshTokenUseCase,
    required this.authRepository,
  }) : super(const AuthState()) {
    // Verificar auto-login ao inicializar
    _checkAutoLogin();
  }
  final LoginUseCase loginUseCase;
  final LogoutUseCase logoutUseCase;
  final RefreshTokenUseCase refreshTokenUseCase;
  final AuthRepository authRepository;

  /// Verifica se existe sessão válida (auto-login)
  Future<void> _checkAutoLogin() async {
    AppLogger.i('🔍 Verificando auto-login...');

    state = state.copyWith(isLoading: true);

    final hasValidTokenResult = await authRepository.hasValidToken();

    hasValidTokenResult.fold(
      (failure) {
        AppLogger.w('❌ Erro ao verificar token: ${failure.message}');
        state = state.copyWith(isLoading: false, isAuthenticated: false);
      },
      (hasValidToken) async {
        if (hasValidToken) {
          // Obter utilizador guardado
          final userResult = await authRepository.getCurrentUser();

          userResult.fold(
            (failure) {
              AppLogger.w('❌ Erro ao obter utilizador: ${failure.message}');
              state = state.copyWith(isLoading: false, isAuthenticated: false);
            },
            (user) {
              AppLogger.i('✅ Auto-login bem-sucedido');
              state = state.copyWith(
                user: user,
                isLoading: false,
                isAuthenticated: true,
              );
            },
          );
        } else {
          AppLogger.d('❌ Nenhum token válido encontrado');
          state = state.copyWith(isLoading: false, isAuthenticated: false);
        }
      },
    );
  }

  /// Fazer login
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    AppLogger.i('🔐 Tentando login...');

    state = state.copyWith(isLoading: true, error: null);

    final result = await loginUseCase(
      username: username,
      password: password,
    );

    return result.fold(
      (failure) {
        AppLogger.e('❌ Login falhou: ${failure.message}');
        state = state.copyWith(
          isLoading: false,
          error: failure.getUserFriendlyMessage(),
          isAuthenticated: false,
        );
        return false;
      },
      (tokens) async {
        AppLogger.i('✅ Login bem-sucedido');

        // Obter utilizador
        final userResult = await authRepository.getCurrentUser();

        userResult.fold(
          (failure) {
            state = state.copyWith(
              isLoading: false,
              error: 'Erro ao obter dados do utilizador',
              isAuthenticated: false,
            );
          },
          (user) {
            state = state.copyWith(
              user: user,
              isLoading: false,
              error: null,
              isAuthenticated: true,
            );
          },
        );

        return true;
      },
    );
  }

  /// Fazer logout
  Future<void> logout() async {
    AppLogger.i('🚪 Fazendo logout...');

    state = state.copyWith(isLoading: true);

    final result = await logoutUseCase();

    result.fold(
      (failure) {
        AppLogger.e('❌ Erro ao fazer logout: ${failure.message}');
        state = state.copyWith(isLoading: false);
      },
      (_) {
        AppLogger.i('✅ Logout bem-sucedido');
        state = const AuthState(isLoading: false, isAuthenticated: false);
      },
    );
  }

  /// Refresh token
  Future<bool> refreshToken() async {
    AppLogger.i('🔄 Refreshing token...');

    final result = await refreshTokenUseCase();

    return result.fold(
      (failure) {
        AppLogger.e('❌ Erro ao fazer refresh: ${failure.message}');
        
        // Se token expirou, fazer logout
        if (failure.message.contains('expirou') ||
            failure.message.contains('expired')) {
          state = const AuthState(isAuthenticated: false);
        }
        
        return false;
      },
      (tokens) {
        AppLogger.i('✅ Token atualizado');
        return true;
      },
    );
  }

  /// Limpar erro
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider do AuthNotifier
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    loginUseCase: ref.watch(loginUseCaseProvider),
    logoutUseCase: ref.watch(logoutUseCaseProvider),
    refreshTokenUseCase: ref.watch(refreshTokenUseCaseProvider),
    authRepository: ref.watch(authRepositoryProvider),
  );
});

/// Provider conveniente para verificar se está autenticado
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

/// Provider conveniente para obter utilizador atual
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});
