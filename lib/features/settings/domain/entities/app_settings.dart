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
  });
  final String apiUrl;
  final String clientId;
  final String clientSecret;
  final String? username;
  final String? customApiUrl;
  final double? defaultMargin;
  final String? printerMac;

  /// Verifica se as configurações essenciais estão preenchidas
  bool get isValid {
    return apiUrl.isNotEmpty &&
        clientId.isNotEmpty &&
        clientSecret.isNotEmpty;
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
      ];

  @override
  String toString() => 'AppSettings(apiUrl: $apiUrl, clientId: $clientId, hasSecret: ${clientSecret.isNotEmpty})';
}
