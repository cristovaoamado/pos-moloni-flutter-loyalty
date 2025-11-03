import 'package:dartz/dartz.dart';

import 'package:pos_moloni_app/core/errors/failures.dart';
import 'package:pos_moloni_app/features/auth/domain/entities/auth_tokens.dart';
import 'package:pos_moloni_app/features/auth/domain/repositories/auth_repository.dart';

/// Use Case para refresh de token
class RefreshTokenUseCase {

  RefreshTokenUseCase(this.repository);
  final AuthRepository repository;

  /// Executa o refresh do access token
  /// 
  /// Usa o refresh token guardado para obter novo access token.
  /// Útil quando:
  /// - Access token expirou
  /// - Access token vai expirar em breve
  /// - Revalidar sessão
  /// 
  /// Retorna:
  /// - [Right(AuthTokens)]: Novos tokens obtidos
  /// - [Left(Failure)]: Erro no refresh (sessão expirada, etc.)
  Future<Either<Failure, AuthTokens>> call() async {
    // Verificar se existe refresh token
    final storedTokensResult = await repository.getStoredTokens();
    
    return storedTokensResult.fold(
      (failure) => Left(failure),
      (tokens) async {
        if (tokens == null) {
          return const Left(
            AuthenticationFailure('Nenhum token guardado'),
          );
        }

        // Executar refresh
        return await repository.refreshToken();
      },
    );
  }
}