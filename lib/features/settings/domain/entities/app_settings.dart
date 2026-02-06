import 'package:equatable/equatable.dart';

/// Entity que representa as configurações da aplicação
class AppSettings extends Equatable {

  const AppSettings({
    required this.apiUrl,
    required this.clientId,
    required this.clientSecret,
    this.username,
    this.customApiUrl,
    this.defaultMargin,
    this.printerMac,
    this.loyaltyApiUrl,
    this.loyaltyApiKey,
    this.loyaltyEnabled,
    this.loyaltyCardPrefix,
  });
  final String apiUrl;
  final String clientId;
  final String clientSecret;
  final String? username;
  final String? customApiUrl;
  final double? defaultMargin;
  final String? printerMac;
  
  // Loyalty Card Settings
  final String? loyaltyApiUrl;
  final String? loyaltyApiKey;
  final bool? loyaltyEnabled;
  final String? loyaltyCardPrefix;

  /// Verifica se as configurações essenciais estão preenchidas
  bool get isValid {
    return apiUrl.isNotEmpty &&
        clientId.isNotEmpty &&
        clientSecret.isNotEmpty;
  }

  /// Verifica se as configurações de fidelização estão preenchidas
  bool get isLoyaltyConfigured {
    return loyaltyApiUrl != null && 
           loyaltyApiUrl!.isNotEmpty &&
           loyaltyApiKey != null &&
           loyaltyApiKey!.isNotEmpty;
  }

  @override
  List<Object?> get props => [
        apiUrl,
        clientId,
        clientSecret,
        username,
        customApiUrl,
        defaultMargin,
        printerMac,
        loyaltyApiUrl,
        loyaltyApiKey,
        loyaltyEnabled,
        loyaltyCardPrefix,
      ];

  @override
  String toString() => 'AppSettings(apiUrl: $apiUrl, clientId: $clientId, hasSecret: ${clientSecret.isNotEmpty}, loyaltyApiUrl: $loyaltyApiUrl, hasApiKey: ${loyaltyApiKey?.isNotEmpty ?? false})';
}
