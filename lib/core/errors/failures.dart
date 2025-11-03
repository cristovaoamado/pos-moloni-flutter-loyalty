import 'package:equatable/equatable.dart';

/// Failures representam erros na camada de Domain
/// São o resultado de Exceptions convertidas pela camada de Data
/// 
/// Usar Equatable permite comparar Failures facilmente em testes

abstract class Failure extends Equatable {

  const Failure(this.message, [this.code]);
  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];

  @override
  String toString() => 'Failure: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Falha de servidor/API
class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Erro no servidor', super.code]);
}

/// Falha de cache/storage local
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Erro ao aceder dados locais', super.code]);
}

/// Falha de conectividade
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Sem conexão à internet', super.code]);
}

/// Falha de autenticação
class AuthenticationFailure extends Failure {
  const AuthenticationFailure([super.message = 'Erro de autenticação', super.code]);
}

/// Token expirado
class TokenExpiredFailure extends AuthenticationFailure {
  const TokenExpiredFailure([String message = 'Sessão expirada'])
      : super(message, 'TOKEN_EXPIRED');
}

/// Credenciais inválidas
class InvalidCredentialsFailure extends AuthenticationFailure {
  const InvalidCredentialsFailure([String message = 'Utilizador ou password incorretos'])
      : super(message, 'INVALID_CREDENTIALS');
}

/// Falha de validação
class ValidationFailure extends Failure {

  const ValidationFailure(
    super.message, [
    this.fieldErrors,
    super.code,
  ]);
  final Map<String, String>? fieldErrors;

  @override
  List<Object?> get props => [message, code, fieldErrors];

  String getFieldError(String field) => fieldErrors?[field] ?? '';

  bool hasFieldError(String field) => fieldErrors?.containsKey(field) ?? false;
}

/// Falha quando recurso não é encontrado
class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Recurso não encontrado', super.code]);
}

/// Falha de timeout
class TimeoutFailure extends Failure {
  const TimeoutFailure([super.message = 'Tempo de conexão esgotado', super.code]);
}

/// Falha de permissões
class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'Permissão negada', super.code]);
}

/// Falha de configuração
class ConfigurationFailure extends Failure {
  const ConfigurationFailure([super.message = 'Configuração ausente ou inválida', super.code]);
}

/// Falha genérica (unexpected)
class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'Erro inesperado', super.code]);
}

/// Extensão para converter mensagens de Failure em mensagens user-friendly
extension FailureMessage on Failure {
  String getUserFriendlyMessage() {
    if (this is NetworkFailure) {
      return 'Verifique sua conexão com a internet e tente novamente.';
    } else if (this is TokenExpiredFailure) {
      return 'Sua sessão expirou. Por favor, faça login novamente.';
    } else if (this is InvalidCredentialsFailure) {
      return 'Utilizador ou password incorretos.';
    } else if (this is ServerFailure) {
      return 'Erro no servidor. Tente novamente mais tarde.';
    } else if (this is TimeoutFailure) {
      return 'Tempo de conexão esgotado. Tente novamente.';
    } else if (this is ValidationFailure) {
      return message;
    } else if (this is NotFoundFailure) {
      return 'O recurso solicitado não foi encontrado.';
    } else if (this is PermissionFailure) {
      return 'Você não tem permissão para realizar esta ação.';
    } else if (this is ConfigurationFailure) {
      return 'A aplicação não está configurada corretamente. Verifique as configurações.';
    }
    return 'Ocorreu um erro. Tente novamente.';
  }
}