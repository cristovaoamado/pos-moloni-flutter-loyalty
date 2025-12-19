import 'dart:async';

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
    this.requiresLogin = false,
    this.isRecovering = false,
  });

  final User? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
  
  /// Flag que indica que precisa de login manual (todas as tentativas falharam)
  final bool requiresLogin;
  
  /// Flag que indica que está a tentar recuperar sessão
  final bool isRecovering;

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
    bool? requiresLogin,
    bool? isRecovering,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      requiresLogin: requiresLogin ?? this.requiresLogin,
      isRecovering: isRecovering ?? this.isRecovering,
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

  /// Timer para renovação periódica de tokens
  Timer? _tokenRefreshTimer;
  
  /// Intervalo de renovação de tokens (45 minutos)
  /// Os tokens Moloni expiram em 1 hora, renovamos antes
  static const _tokenRefreshInterval = Duration(minutes: 45);

  /// Inicializa e tenta auto-login
  Future<void> initialize() async {
    AppLogger.i('🔐 Inicializando autenticação...');
    await Future.microtask(() {});
    await _checkAutoLogin();
  }

  /// Verifica se existe sessão válida (auto-login)
  Future<void> _checkAutoLogin() async {
    AppLogger.i('🔍 Verificando auto-login...');

    if (!mounted) return;
    
    state = state.copyWith(isLoading: true, requiresLogin: false);

    // 1. Verificar se há token válido
    final hasValidTokenResult = await authRepository.hasValidToken();

    final hasValidToken = hasValidTokenResult.fold(
      (failure) {
        AppLogger.w('❌ Erro ao verificar token: ${failure.message}');
        return false;
      },
      (valid) => valid,
    );

    if (hasValidToken) {
      final userResult = await authRepository.getCurrentUser();
      
      userResult.fold(
        (failure) {
          AppLogger.w('Erro ao obter utilizador: ${failure.message}');
          if (mounted) {
            state = state.copyWith(isLoading: false, isAuthenticated: false);
          }
        },
        (user) {
          AppLogger.i('✅ Auto-login bem-sucedido (token válido)');
          if (mounted) {
            state = state.copyWith(
              user: user,
              isLoading: false,
              isAuthenticated: true,
              requiresLogin: false,
            );
            _startTokenRefreshTimer();
          }
        },
      );
      return;
    }

    // 2. Token inválido/expirado - tentar refresh
    AppLogger.d('🔄 Token inválido, tentando refresh...');
    final refreshSuccess = await _tryRefreshToken();
    
    if (refreshSuccess) {
      AppLogger.i('✅ Auto-login bem-sucedido (refresh token)');
      _startTokenRefreshTimer();
      return;
    }

    // 3. Refresh falhou - tentar com credenciais guardadas
    AppLogger.d('🔄 Refresh falhou, tentando credenciais guardadas...');
    
    final username = await storage.read(key: _keyUsername);
    final password = await storage.read(key: _keyPassword);

    if (username != null && username.isNotEmpty && 
        password != null && password.isNotEmpty) {
      AppLogger.d('🔑 Credenciais encontradas, tentando login...');
      
      final success = await _doLogin(
        username: username, 
        password: password, 
        saveCredentials: false,
      );
      
      if (success) {
        AppLogger.i('✅ Auto-login bem-sucedido (credenciais guardadas)');
        _startTokenRefreshTimer();
        return;
      }
    }

    // 4. Todas as tentativas falharam - requer login manual
    AppLogger.w('⚠️ Auto-login falhou - requer login manual');
    if (mounted) {
      state = state.copyWith(
        isLoading: false, 
        isAuthenticated: false,
        requiresLogin: true,
      );
    }
  }

  /// Inicia o timer de renovação periódica de tokens
  void _startTokenRefreshTimer() {
    _stopTokenRefreshTimer();
    
    AppLogger.i('⏰ Iniciando timer de renovação de tokens (${_tokenRefreshInterval.inMinutes} min)');
    
    _tokenRefreshTimer = Timer.periodic(_tokenRefreshInterval, (_) async {
      if (state.isAuthenticated && mounted) {
        AppLogger.d('⏰ Timer: Renovando token preventivamente...');
        await _tryRefreshTokenOrRelogin();
      }
    });
  }

  /// Para o timer de renovação
  void _stopTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
  }

  /// Tenta renovar token, se falhar tenta re-login
  Future<bool> _tryRefreshTokenOrRelogin() async {
    // 1. Tentar refresh token
    final refreshSuccess = await _tryRefreshToken();
    if (refreshSuccess) {
      AppLogger.i('✅ Token renovado preventivamente');
      return true;
    }

    // 2. Refresh falhou - tentar re-login com credenciais guardadas
    AppLogger.d('🔄 Refresh falhou, tentando re-login...');
    
    final username = await storage.read(key: _keyUsername);
    final password = await storage.read(key: _keyPassword);

    if (username != null && username.isNotEmpty && 
        password != null && password.isNotEmpty) {
      
      final result = await loginUseCase(
        username: username,
        password: password,
      );
      
      return result.fold(
        (failure) {
          AppLogger.w('❌ Re-login preventivo falhou: ${failure.message}');
          return false;
        },
        (tokens) {
          AppLogger.i('✅ Re-login preventivo bem-sucedido');
          return true;
        },
      );
    }

    return false;
  }

  /// Tenta renovar o token usando refresh_token
  Future<bool> _tryRefreshToken() async {
    try {
      final result = await refreshTokenUseCase();

      return result.fold(
        (failure) {
          AppLogger.w('❌ Refresh token falhou: ${failure.message}');
          return false;
        },
        (tokens) async {
          AppLogger.i('✅ Token renovado via refresh');
          
          final userResult = await authRepository.getCurrentUser();
          
          userResult.fold(
            (failure) {
              if (mounted) {
                state = state.copyWith(
                  isLoading: false,
                  isRecovering: false,
                  isAuthenticated: true,
                );
              }
            },
            (user) {
              if (mounted) {
                state = state.copyWith(
                  user: user,
                  isLoading: false,
                  isRecovering: false,
                  isAuthenticated: true,
                  requiresLogin: false,
                );
              }
            },
          );
          
          return true;
        },
      );
    } catch (e) {
      AppLogger.e('❌ Erro ao fazer refresh token', error: e);
      return false;
    }
  }

  /// Fazer login
  Future<bool> login({
    required String username,
    required String password,
    bool saveCredentials = true,
  }) async {
    AppLogger.i('🔐 Tentando login...');
    state = state.copyWith(isLoading: true, error: null, requiresLogin: false);
    
    final success = await _doLogin(
      username: username, 
      password: password, 
      saveCredentials: saveCredentials,
    );
    
    if (success) {
      _startTokenRefreshTimer();
    }
    
    return success;
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

        if (saveCredentials) {
          await storage.write(key: _keyUsername, value: username);
          await storage.write(key: _keyPassword, value: password);
          AppLogger.d('💾 Credenciais guardadas');
        }

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
              requiresLogin: false,
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

    _stopTokenRefreshTimer();
    
    state = state.copyWith(isLoading: true);

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
        state = const AuthState(
          isLoading: false, 
          isAuthenticated: false,
          requiresLogin: true,
        );
      },
    );
  }

  /// Tenta recuperar sessão expirada
  /// Chamado quando detecta erro de token expirado nas chamadas API
  /// Retorna true se conseguiu recuperar, false se precisa de login manual
  Future<bool> tryRecoverSession() async {
    AppLogger.i('🔄 Tentando recuperar sessão...');
    
    if (state.isRecovering) {
      AppLogger.d('Já está a recuperar sessão, ignorando...');
      return false;
    }

    if (!mounted) return false;
    
    state = state.copyWith(isRecovering: true, error: null);

    // 1. Tentar refresh token
    AppLogger.d('🔄 Tentativa 1: Refresh token...');
    final refreshSuccess = await _tryRefreshToken();
    if (refreshSuccess) {
      if (mounted) {
        state = state.copyWith(isRecovering: false);
        _startTokenRefreshTimer();
      }
      return true;
    }

    // 2. Tentar re-login com credenciais guardadas
    AppLogger.d('🔄 Tentativa 2: Re-login com credenciais guardadas...');
    final username = await storage.read(key: _keyUsername);
    final password = await storage.read(key: _keyPassword);

    if (username != null && username.isNotEmpty &&
        password != null && password.isNotEmpty) {
      
      final loginResult = await loginUseCase(
        username: username,
        password: password,
      );
      
      final loginSuccess = loginResult.fold(
        (failure) {
          AppLogger.w('❌ Re-login falhou: ${failure.message}');
          return false;
        },
        (tokens) {
          AppLogger.i('✅ Re-login bem-sucedido');
          return true;
        },
      );
      
      if (loginSuccess) {
        final userResult = await authRepository.getCurrentUser();
        userResult.fold(
          (failure) {},
          (user) {
            if (mounted) {
              state = state.copyWith(
                user: user,
                isRecovering: false,
                isAuthenticated: true,
                requiresLogin: false,
              );
              _startTokenRefreshTimer();
            }
          },
        );
        return true;
      }
    }

    // 3. Falha total
    AppLogger.w('⚠️ Recuperação de sessão falhou - requer login manual');
    if (mounted) {
      state = state.copyWith(
        isRecovering: false,
        requiresLogin: true,
        isAuthenticated: false,
        error: 'Não foi possível recuperar a sessão. Por favor, faça login.',
      );
    }
    return false;
  }

  /// Refresh token (público)
  Future<bool> refreshToken() async {
    AppLogger.i('🔄 Refreshing token...');

    final result = await refreshTokenUseCase();

    return result.fold(
      (failure) {
        AppLogger.e('❌ Erro ao fazer refresh: ${failure.message}');
        
        if (failure.message.contains('expirou') ||
            failure.message.contains('expired')) {
          state = const AuthState(isAuthenticated: false, requiresLogin: true);
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

  @override
  void dispose() {
    _stopTokenRefreshTimer();
    super.dispose();
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

/// Provider que indica se precisa de login manual
final requiresLoginProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).requiresLogin;
});

/// Provider que indica se está a recuperar sessão
final isRecoveringSessionProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isRecovering;
});
