/// Exceções customizadas da aplicação
/// Estas exceções são lançadas na camada de Data e convertidas em Failures na camada de Domain
library;

/// Exceção base para todas as exceções da aplicação
abstract class AppException implements Exception {

  const AppException(this.message, [this.code]);
  final String message;
  final String? code;

  @override
  String toString() => 'AppException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Exceções de Servidor/API
class ServerException extends AppException {
  const ServerException([super.message = 'Erro no servidor', super.code]);
}

/// Exceções de Cache/Storage Local
class CacheException extends AppException {
  const CacheException([super.message = 'Erro ao aceder ao cache', super.code]);
}

/// Exceções de Rede/Conectividade
class NetworkException extends AppException {
  const NetworkException([super.message = 'Erro de conexão', super.code]);
}

/// Exceções de Autenticação
class AuthenticationException extends AppException {
  const AuthenticationException([super.message = 'Erro de autenticação', super.code]);
}

/// Token expirado (subclasse de AuthenticationException)
class TokenExpiredException extends AuthenticationException {
  const TokenExpiredException([String message = 'Token expirado'])
      : super(message, 'TOKEN_EXPIRED');
}

/// Credenciais inválidas
class InvalidCredentialsException extends AuthenticationException {
  const InvalidCredentialsException([String message = 'Credenciais inválidas'])
      : super(message, 'INVALID_CREDENTIALS');
}

/// Exceções de Validação
class ValidationException extends AppException {

  const ValidationException(
    super.message, [
    this.errors,
    super.code,
  ]);
  final Map<String, String>? errors;

  @override
  String toString() {
    if (errors != null && errors!.isNotEmpty) {
      final errorMessages = errors!.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      return 'ValidationException: $message ($errorMessages)';
    }
    return super.toString();
  }
}

/// Exceção quando recurso não é encontrado
class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Recurso não encontrado', super.code]);
}

/// Exceção de timeout
class TimeoutException extends AppException {
  const TimeoutException([super.message = 'Tempo de conexão esgotado', super.code]);
}

/// Exceção de permissões
class PermissionException extends AppException {
  const PermissionException([super.message = 'Permissão negada', super.code]);
}

/// Exceção de formato inválido (JSON, etc.)
class FormatException extends AppException {
  const FormatException([super.message = 'Formato de dados inválido', super.code]);
}

/// Exceção quando não há configuração (API URL, tokens, etc.)
class ConfigurationException extends AppException {
  const ConfigurationException([super.message = 'Configuração ausente', super.code]);
}

/// Exceção de negócio específica da API Moloni
class MoloniApiException extends ServerException {

  const MoloniApiException(
    String message, {
    this.statusCode,
    this.response,
    String? code,
  }) : super(message, code);
  final int? statusCode;
  final dynamic response;

  @override
  String toString() {
    return 'MoloniApiException: $message'
        '${statusCode != null ? ' (Status: $statusCode)' : ''}'
        '${code != null ? ' (Code: $code)' : ''}';
  }
}
