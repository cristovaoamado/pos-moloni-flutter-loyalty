import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pos_moloni_app/core/errors/failures.dart';

import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/core/services/storage_service.dart';
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

/// Provider do FlutterSecureStorage (usando PlatformStorage para compatibilidade desktop)
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  // Usa o PlatformStorage que funciona em todas as plataformas
  return PlatformStorage.instance;
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
    required this.storage,
  }) : super(const AuthState());
  
  final LoginUseCase loginUseCase;
  final LogoutUseCase logoutUseCase;
  final RefreshTokenUseCase refreshTokenUseCase;
  final AuthRepository authRepository;
  final FlutterSecureStorage storage;

  /// Chaves para guardar credenciais
  static const _keyUsername = 'moloni_username';
  static const _keyPassword = 'moloni_password';

  /// Inicializa e tenta auto-login
  Future<void> initialize() async {
    AppLogger.i('Inicializando autenticacao...');
    // Usar Future.microtask para garantir que o provider esta pronto
    await Future.microtask(() {});
    await _checkAutoLogin();
  }

  /// Verifica se existe sessão válida (auto-login)
  Future<void> _checkAutoLogin() async {
    AppLogger.i('Verificando auto-login...');

    // Verificar se o notifier ainda esta montado antes de actualizar estado
    if (!mounted) return;
    
    state = state.copyWith(isLoading: true);

    // Primeiro, verificar se há token válido
    final hasValidTokenResult = await authRepository.hasValidToken();

    final hasValidToken = hasValidTokenResult.fold(
      (failure) {
        AppLogger.w('❌ Erro ao verificar token: ${failure.message}');
        return false;
      },
      (valid) => valid,
    );

    if (hasValidToken) {
      // Token válido - obter utilizador
      final userResult = await authRepository.getCurrentUser();
      
      userResult.fold(
        (failure) {
          AppLogger.w('Erro ao obter utilizador: ${failure.message}');
          if (mounted) {
            state = state.copyWith(isLoading: false, isAuthenticated: false);
          }
        },
        (user) {
          AppLogger.i('Auto-login bem-sucedido (token valido)');
          if (mounted) {
            state = state.copyWith(
              user: user,
              isLoading: false,
              isAuthenticated: true,
            );
          }
        },
      );
      return;
    }

    // Token inválido ou expirado - tentar com credenciais guardadas
    AppLogger.d('Token invalido, tentando credenciais guardadas...');
    
    final username = await storage.read(key: _keyUsername);
    final password = await storage.read(key: _keyPassword);

    if (username != null && username.isNotEmpty && 
        password != null && password.isNotEmpty) {
      AppLogger.d('Credenciais encontradas, tentando login...');
      
      final success = await _doLogin(username: username, password: password, saveCredentials: false);
      
      if (success) {
        AppLogger.i('Auto-login bem-sucedido (credenciais guardadas)');
        return;
      }
    }

    // Sem credenciais ou login falhou
    AppLogger.d('Auto-login falhou - requer login manual');
    if (mounted) {
      state = state.copyWith(isLoading: false, isAuthenticated: false);
    }
  }

  /// Fazer login
  Future<bool> login({
    required String username,
    required String password,
    bool saveCredentials = true,
  }) async {
    AppLogger.i('🔐 Tentando login...');
    state = state.copyWith(isLoading: true, error: null);
    
    return _doLogin(
      username: username, 
      password: password, 
      saveCredentials: saveCredentials,
    );
  }

  /// Executa o login (interno)
  Future<bool> _doLogin({
    required String username,
    required String password,
    required bool saveCredentials,
  }) async {
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

        // Guardar credenciais se solicitado
        if (saveCredentials) {
          await storage.write(key: _keyUsername, value: username);
          await storage.write(key: _keyPassword, value: password);
          AppLogger.d('💾 Credenciais guardadas');
        }

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
  Future<void> logout({bool clearCredentials = false}) async {
    AppLogger.i('🚪 Fazendo logout...');

    state = state.copyWith(isLoading: true);

    // Limpar credenciais se solicitado
    if (clearCredentials) {
      await storage.delete(key: _keyUsername);
      await storage.delete(key: _keyPassword);
      AppLogger.d('🗑️ Credenciais removidas');
    }

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

  /// Verifica se há credenciais guardadas
  Future<bool> hasStoredCredentials() async {
    final username = await storage.read(key: _keyUsername);
    final password = await storage.read(key: _keyPassword);
    return username != null && username.isNotEmpty && 
           password != null && password.isNotEmpty;
  }
}

/// Provider do AuthNotifier
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    loginUseCase: ref.watch(loginUseCaseProvider),
    logoutUseCase: ref.watch(logoutUseCaseProvider),
    refreshTokenUseCase: ref.watch(refreshTokenUseCaseProvider),
    authRepository: ref.watch(authRepositoryProvider),
    storage: ref.watch(secureStorageProvider),
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
