import 'package:equatable/equatable.dart';

/// Entity que representa os tokens de autenticação
/// Entidade pura de domínio - sem dependências externas
class AuthTokens extends Equatable {

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.timestamp,
  });
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final DateTime timestamp;

  /// Verifica se o token está expirado
  bool get isExpired {
    final now = DateTime.now();
    final expirationTime = timestamp.add(Duration(seconds: expiresIn));
    return now.isAfter(expirationTime);
  }

  /// Verifica se o token vai expirar em breve (5 minutos)
  bool get isExpiringSoon {
    final now = DateTime.now();
    final expirationTime = timestamp.add(Duration(seconds: expiresIn));
    final fiveMinutesBeforeExpiration = expirationTime.subtract(
      const Duration(minutes: 5),
    );
    return now.isAfter(fiveMinutesBeforeExpiration);
  }

  /// Tempo restante até expiração
  Duration get timeUntilExpiration {
    final now = DateTime.now();
    final expirationTime = timestamp.add(Duration(seconds: expiresIn));
    return expirationTime.difference(now);
  }

  @override
  List<Object?> get props => [
        accessToken,
        refreshToken,
        tokenType,
        expiresIn,
        timestamp,
      ];

  @override
  String toString() => 'AuthTokens(tokenType: $tokenType, expiresIn: $expiresIn, isExpired: $isExpired)';
}
