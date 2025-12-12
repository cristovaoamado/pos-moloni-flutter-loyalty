/// Tipo de conexão da impressora
enum PrinterConnectionType {
  usb,
  network,
  bluetooth,
}

/// Configuração da impressora térmica
class PrinterConfig {
  const PrinterConfig({
    this.name = '',
    this.connectionType = PrinterConnectionType.usb,
    this.address = '',
    this.port = 9100,
    this.paperWidth = 80,
    this.isEnabled = false,
    this.autoPrint = true,
    this.printCopy = false,
  });

  factory PrinterConfig.fromJson(Map<String, dynamic> json) {
    return PrinterConfig(
      name: json['name'] as String? ?? '',
      connectionType: PrinterConnectionType.values[json['connectionType'] as int? ?? 0],
      address: json['address'] as String? ?? '',
      port: json['port'] as int? ?? 9100,
      paperWidth: json['paperWidth'] as int? ?? 80,
      isEnabled: json['isEnabled'] as bool? ?? false,
      autoPrint: json['autoPrint'] as bool? ?? true,
      printCopy: json['printCopy'] as bool? ?? false,
    );
  }

  /// Nome da impressora (para USB) ou identificador
  final String name;

  /// Tipo de conexão
  final PrinterConnectionType connectionType;

  /// Endereço IP (para rede) ou MAC address (para Bluetooth)
  final String address;

  /// Porta (para conexão de rede, padrão 9100)
  final int port;

  /// Largura do papel em mm (58 ou 80)
  final int paperWidth;

  /// Se a impressora está activa
  final bool isEnabled;

  /// Imprimir automaticamente após venda
  final bool autoPrint;

  /// Imprimir cópia do talão
  final bool printCopy;

  /// Número de caracteres por linha baseado na largura do papel
  int get charsPerLine => paperWidth == 58 ? 32 : 48;

  /// Se está configurada
  bool get isConfigured => name.isNotEmpty || address.isNotEmpty;

  PrinterConfig copyWith({
    String? name,
    PrinterConnectionType? connectionType,
    String? address,
    int? port,
    int? paperWidth,
    bool? isEnabled,
    bool? autoPrint,
    bool? printCopy,
  }) {
    return PrinterConfig(
      name: name ?? this.name,
      connectionType: connectionType ?? this.connectionType,
      address: address ?? this.address,
      port: port ?? this.port,
      paperWidth: paperWidth ?? this.paperWidth,
      isEnabled: isEnabled ?? this.isEnabled,
      autoPrint: autoPrint ?? this.autoPrint,
      printCopy: printCopy ?? this.printCopy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'connectionType': connectionType.index,
      'address': address,
      'port': port,
      'paperWidth': paperWidth,
      'isEnabled': isEnabled,
      'autoPrint': autoPrint,
      'printCopy': printCopy,
    };
  }

  @override
  String toString() {
    return 'PrinterConfig(name: $name, type: $connectionType, address: $address, port: $port, enabled: $isEnabled)';
  }
}
