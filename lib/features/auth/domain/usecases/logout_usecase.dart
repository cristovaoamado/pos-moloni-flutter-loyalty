import 'package:dartz/dartz.dart';

import 'package:pos_moloni_app/core/errors/failures.dart';
import 'package:pos_moloni_app/features/auth/domain/repositories/auth_repository.dart';

/// Use Case para logout
class LogoutUseCase {

  LogoutUseCase(this.repository);
  final AuthRepository repository;

  /// Executa o logout
  /// 
  /// Limpa todos os dados de autenticação:
  /// - Tokens de acesso
  /// - Dados de utilizador
  /// - Cache de sessão
  /// 
  /// Retorna:
  /// - [Right(void)]: Logout bem-sucedido
  /// - [Left(Failure)]: Erro no logout (raro)
  Future<Either<Failure, void>> call() async {
    return await repository.logout();
  }
}