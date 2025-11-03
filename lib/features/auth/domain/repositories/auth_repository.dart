import 'package:dartz/dartz.dart';

import 'package:pos_moloni_app/core/errors/failures.dart';
import 'package:pos_moloni_app/features/auth/domain/entities/auth_tokens.dart';
import 'package:pos_moloni_app/features/auth/domain/entities/user.dart';

/// Interface do repositório de autenticação
/// Define o contrato que a camada de Data deve implementar
abstract class AuthRepository {
  /// Faz login com username e password
  /// Retorna Either<Failure, AuthTokens>
  Future<Either<Failure, AuthTokens>> login({
    required String username,
    required String password,
  });

  /// Faz logout (limpa tokens locais)
  Future<Either<Failure, void>> logout();

  /// Refresh do access token usando refresh token
  Future<Either<Failure, AuthTokens>> refreshToken();

  /// Verifica se existe token válido guardado (auto-login)
  Future<Either<Failure, bool>> hasValidToken();

  /// Obtém tokens guardados localmente
  Future<Either<Failure, AuthTokens?>> getStoredTokens();

  /// Guarda tokens localmente
  Future<Either<Failure, void>> saveTokens(AuthTokens tokens);

  /// Obtém utilizador atual (se houver)
  Future<Either<Failure, User?>> getCurrentUser();

  /// Limpa todos os dados de autenticação
  Future<Either<Failure, void>> clearAuthData();
}
