import 'package:pos_moloni_app/features/auth/domain/entities/auth_tokens.dart';

/// Model que estende AuthTokens e adiciona serialização JSON
class AuthTokensModel extends AuthTokens {
  const AuthTokensModel({
    required super.accessToken,
    required super.refreshToken,
    required super.tokenType,
    required super.expiresIn,
    required super.timestamp,
  });

  /// Converte Entity para Model
  factory AuthTokensModel.fromEntity(AuthTokens entity) {
    return AuthTokensModel(
      accessToken: entity.accessToken,
      refreshToken: entity.refreshToken,
      tokenType: entity.tokenType,
      expiresIn: entity.expiresIn,
      timestamp: entity.timestamp,
    );
  }

  /// Cria model a partir de JSON local (storage)
  factory AuthTokensModel.fromStorageJson(Map<String, dynamic> json) {
    return AuthTokensModel(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String? ?? 'Bearer',
      expiresIn: json['expires_in'] as int? ?? 3600,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  /// Cria model a partir de JSON (API response do Moloni)
  /// API Response format:
  /// {
  ///   "access_token": "...",
  ///   "refresh_token": "...",
  ///   "token_type": "bearer",
  ///   "expires_in": 3600,
  ///   "scope": null
  /// }
  factory AuthTokensModel.fromJson(Map<String, dynamic> json) {
    return AuthTokensModel(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'Bearer',
      expiresIn: json['expires_in'] as int? ?? 3600,
      timestamp: DateTime.now(), // Timestamp de quando recebemos
    );
  }

  /// Converte model para JSON (para guardar localmente)
  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
      'expires_in': expiresIn,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Converte Model para Entity
  AuthTokens toEntity() {
    return AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: tokenType,
      expiresIn: expiresIn,
      timestamp: timestamp,
    );
  }
}
