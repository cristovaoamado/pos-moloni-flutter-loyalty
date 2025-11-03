import 'package:dartz/dartz.dart';

import 'package:pos_moloni_app/core/errors/failures.dart';
import 'package:pos_moloni_app/features/auth/domain/entities/auth_tokens.dart';
import 'package:pos_moloni_app/features/auth/domain/repositories/auth_repository.dart';

/// Use Case para login
/// Encapsula a lógica de negócio de autenticação
class LoginUseCase {

  LoginUseCase(this.repository);
  final AuthRepository repository;

  /// Executa o login
  /// 
  /// Parâmetros:
  /// - [username]: Nome de utilizador
  /// - [password]: Password
  /// 
  /// Retorna:
  /// - [Right(AuthTokens)]: Login bem-sucedido
  /// - [Left(Failure)]: Erro no login
  Future<Either<Failure, AuthTokens>> call({
    required String username,
    required String password,
  }) async {
    // Validações de negócio
    if (username.trim().isEmpty) {
      return const Left(
        ValidationFailure('Username não pode estar vazio'),
      );
    }

    if (password.isEmpty) {
      return const Left(
        ValidationFailure('Password não pode estar vazia'),
      );
    }

    // Executar login
    return await repository.login(
      username: username.trim(),
      password: password,
    );
  }
}
