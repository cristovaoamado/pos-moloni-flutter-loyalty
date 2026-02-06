import 'package:pos_moloni_app/features/settings/domain/entities/app_settings.dart';

/// Model que estende AppSettings e adiciona serialização
class AppSettingsModel extends AppSettings {
  const AppSettingsModel({
    required super.apiUrl,
    required super.clientId,
    required super.clientSecret,
    super.customApiUrl,
    super.defaultMargin,
    super.printerMac,
    super.username,
    super.loyaltyApiUrl,
    super.loyaltyApiKey,
    super.loyaltyEnabled,
    super.loyaltyCardPrefix,
  });

  /// Converte Entity para Model
  factory AppSettingsModel.fromEntity(AppSettings entity) {
    return AppSettingsModel(
      apiUrl: entity.apiUrl,
      clientId: entity.clientId,
      clientSecret: entity.clientSecret,
      customApiUrl: entity.customApiUrl,
      defaultMargin: entity.defaultMargin,
      printerMac: entity.printerMac,
      username: entity.username,
      loyaltyApiUrl: entity.loyaltyApiUrl,
      loyaltyApiKey: entity.loyaltyApiKey,
      loyaltyEnabled: entity.loyaltyEnabled,
      loyaltyCardPrefix: entity.loyaltyCardPrefix,
    );
  }

  /// Cria model a partir de JSON
  factory AppSettingsModel.fromJson(Map<String, dynamic> json) {
    return AppSettingsModel(
      apiUrl: json['apiUrl'] as String? ?? '',
      clientId: json['clientId'] as String? ?? '',
      clientSecret: json['clientSecret'] as String? ?? '',
      customApiUrl: json['customApiUrl'] as String?,
      defaultMargin: (json['defaultMargin'] as num?)?.toDouble(),
      printerMac: json['printerMac'] as String?,
      username: json['username'] as String?,
      loyaltyApiUrl: json['loyaltyApiUrl'] as String?,
      loyaltyApiKey: json['loyaltyApiKey'] as String?,
      loyaltyEnabled: json['loyaltyEnabled'] as bool?,
      loyaltyCardPrefix: json['loyaltyCardPrefix'] as String?,
    );
  }

  /// Converte model para JSON
  Map<String, dynamic> toJson() {
    return {
      'apiUrl': apiUrl,
      'clientId': clientId,
      'clientSecret': clientSecret,
      'customApiUrl': customApiUrl,
      'defaultMargin': defaultMargin,
      'printerMac': printerMac,
      'username': username,
      'loyaltyApiUrl': loyaltyApiUrl,
      'loyaltyApiKey': loyaltyApiKey,
      'loyaltyEnabled': loyaltyEnabled,
      'loyaltyCardPrefix': loyaltyCardPrefix,
    };
  }

  /// Converte Model para Entity
  AppSettings toEntity() {
    return AppSettings(
      apiUrl: apiUrl,
      clientId: clientId,
      clientSecret: clientSecret,
      customApiUrl: customApiUrl,
      defaultMargin: defaultMargin,
      printerMac: printerMac,
      username: username,
      loyaltyApiUrl: loyaltyApiUrl,
      loyaltyApiKey: loyaltyApiKey,
      loyaltyEnabled: loyaltyEnabled,
      loyaltyCardPrefix: loyaltyCardPrefix,
    );
  }

  /// Cria cópia com alterações
  AppSettingsModel copyWith({
    String? apiUrl,
    String? clientId,
    String? clientSecret,
    String? customApiUrl,
    double? defaultMargin,
    String? printerMac,
    String? username,
    String? loyaltyApiUrl,
    String? loyaltyApiKey,
    bool? loyaltyEnabled,
    String? loyaltyCardPrefix,
  }) {
    return AppSettingsModel(
      apiUrl: apiUrl ?? this.apiUrl,
      clientId: clientId ?? this.clientId,
      clientSecret: clientSecret ?? this.clientSecret,
      customApiUrl: customApiUrl ?? this.customApiUrl,
      defaultMargin: defaultMargin ?? this.defaultMargin,
      printerMac: printerMac ?? this.printerMac,
      username: username ?? this.username,
      loyaltyApiUrl: loyaltyApiUrl ?? this.loyaltyApiUrl,
      loyaltyApiKey: loyaltyApiKey ?? this.loyaltyApiKey,
      loyaltyEnabled: loyaltyEnabled ?? this.loyaltyEnabled,
      loyaltyCardPrefix: loyaltyCardPrefix ?? this.loyaltyCardPrefix,
    );
  }
}
