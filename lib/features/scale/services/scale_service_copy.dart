import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/core/services/storage_service.dart';

/// Protocolo de comunicação da balança
enum ScaleProtocol {
  /// Protocolo genérico (texto simples com peso)
  generic,

  /// Protocolo Dibal (G-310, G-325, etc.)
  dibal,

  /// Protocolo Toledo
  toledo,

  /// Protocolo Mettler-Toledo
  mettlerToledo,

  /// Protocolo CAS
  cas,

  /// Protocolo Epelsa
  epelsa,
}

/// Tipo de conexão com a balança
enum ScaleConnectionType {
  /// Conexão via porta série (RS-232/USB-Serial)
  serial,

  /// Conexão via rede TCP/IP
  tcp,

  /// Conexão via HTTP/REST API
  http,
}

/// Configuração da balança
class ScaleConfig {
  const ScaleConfig({
    this.connectionType = ScaleConnectionType.serial,
    this.protocol = ScaleProtocol.dibal,
    this.host = '192.168.1.100',
    this.port = 3000,
    this.serialPort = '',
    this.baudRate = 9600,
    this.dataBits = 8,
    this.stopBits = 1,
    this.parity = SerialPortParity.none,
    this.timeout = const Duration(seconds: 5),
    this.requestCommand,
    this.weightRegex,
    this.decimalPlaces = 3,
  });

  factory ScaleConfig.fromJson(Map<String, dynamic> json) {
    return ScaleConfig(
      connectionType: ScaleConnectionType.values.firstWhere(
        (e) => e.name == json['connectionType'],
        orElse: () => ScaleConnectionType.serial,
      ),
      protocol: ScaleProtocol.values.firstWhere(
        (e) => e.name == json['protocol'],
        orElse: () => ScaleProtocol.dibal,
      ),
      host: json['host'] ?? '192.168.1.100',
      port: json['port'] ?? 3000,
      serialPort: json['serialPort'] ?? '',
      baudRate: json['baudRate'] ?? 9600,
      dataBits: json['dataBits'] ?? 8,
      stopBits: json['stopBits'] ?? 1,
      parity: json['parity'] ?? SerialPortParity.none,
      timeout: Duration(milliseconds: json['timeout'] ?? 3000),
      requestCommand: json['requestCommand'],
      weightRegex: json['weightRegex'],
      decimalPlaces: json['decimalPlaces'] ?? 3,
    );
  }

  /// Tipo de conexão
  final ScaleConnectionType connectionType;

  /// Protocolo da balança
  final ScaleProtocol protocol;

  /// Host para conexão TCP/HTTP
  final String host;

  /// Porta para conexão TCP/HTTP
  final int port;

  /// Porta série (ex: COM3 no Windows, /dev/ttyUSB0 no Linux)
  final String serialPort;

  /// Baud rate para conexão serial
  final int baudRate;

  /// Data bits (normalmente 8)
  final int dataBits;

  /// Stop bits (normalmente 1)
  final int stopBits;

  /// Paridade
  final int parity;

  /// Timeout para leitura
  final Duration timeout;

  /// Comando para solicitar peso (opcional)
  final String? requestCommand;

  /// Regex para extrair peso da resposta (opcional)
  final String? weightRegex;

  /// Casas decimais do peso
  final int decimalPlaces;

  /// Configuração padrão para Dibal G-325 RS-232
  /// Configuração típica: 9600 baud, 8N1
  static const ScaleConfig dibalG325 = ScaleConfig(
    connectionType: ScaleConnectionType.serial,
    protocol: ScaleProtocol.dibal,
    serialPort: '', // Será detectado automaticamente ou configurado
    baudRate: 9600,
    dataBits: 8,
    stopBits: 1,
    parity: SerialPortParity.none,
    decimalPlaces: 3,
  );

  /// Configuração alternativa Dibal com paridade par
  static const ScaleConfig dibalG325Parity = ScaleConfig(
    connectionType: ScaleConnectionType.serial,
    protocol: ScaleProtocol.dibal,
    serialPort: '',
    baudRate: 9600,
    dataBits: 7,
    stopBits: 1,
    parity: SerialPortParity.even,
    decimalPlaces: 3,
  );

  ScaleConfig copyWith({
    ScaleConnectionType? connectionType,
    ScaleProtocol? protocol,
    String? host,
    int? port,
    String? serialPort,
    int? baudRate,
    int? dataBits,
    int? stopBits,
    int? parity,
    Duration? timeout,
    String? requestCommand,
    String? weightRegex,
    int? decimalPlaces,
  }) {
    return ScaleConfig(
      connectionType: connectionType ?? this.connectionType,
      protocol: protocol ?? this.protocol,
      host: host ?? this.host,
      port: port ?? this.port,
      serialPort: serialPort ?? this.serialPort,
      baudRate: baudRate ?? this.baudRate,
      dataBits: dataBits ?? this.dataBits,
      stopBits: stopBits ?? this.stopBits,
      parity: parity ?? this.parity,
      timeout: timeout ?? this.timeout,
      requestCommand: requestCommand ?? this.requestCommand,
      weightRegex: weightRegex ?? this.weightRegex,
      decimalPlaces: decimalPlaces ?? this.decimalPlaces,
    );
  }

  Map<String, dynamic> toJson() => {
        'connectionType': connectionType.name,
        'protocol': protocol.name,
        'host': host,
        'port': port,
        'serialPort': serialPort,
        'baudRate': baudRate,
        'dataBits': dataBits,
        'stopBits': stopBits,
        'parity': parity,
        'timeout': timeout.inMilliseconds,
        'requestCommand': requestCommand,
        'weightRegex': weightRegex,
        'decimalPlaces': decimalPlaces,
      };
}

/// Resultado da leitura de peso
class ScaleReading {
  const ScaleReading({
    required this.weight,
    required this.unit,
    required this.isStable,
    this.rawData,
  });

  /// Peso lido (em kg)
  final double weight;

  /// Unidade (kg, g, lb, etc.)
  final String unit;

  /// Se a leitura está estável
  final bool isStable;

  /// Dados brutos da balança (para debug)
  final String? rawData;

  @override
  String toString() =>
      'ScaleReading(${weight.toStringAsFixed(3)} $unit, stable: $isStable)';
}

/// Serviço para comunicação com balanças
class ScaleService {
  ScaleService({
    ScaleConfig? config,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? PlatformStorage.instance {
    // ↑ USA PLATFORMSTORAGE (compatível com macOS)
    _config = config ?? ScaleConfig.dibalG325;
  }

  final FlutterSecureStorage _storage;
  late ScaleConfig _config;

  SerialPort? _serialPort;
  bool _isConnected = false;

  /// Configuração actual
  ScaleConfig get config => _config;

  /// Se está conectado
  bool get isConnected => _isConnected;

  /// Lista as portas série disponíveis
  static List<String> getAvailablePorts() {
    try {
      final ports = SerialPort.availablePorts;
      AppLogger.d('⚖️ Portas série disponíveis: $ports');
      return ports;
    } catch (e) {
      AppLogger.e('⚖️ Erro ao listar portas série', error: e);
      return [];
    }
  }

  /// Obtém informação detalhada de uma porta
  static Map<String, String> getPortInfo(String portName) {
    try {
      final port = SerialPort(portName);
      final info = {
        'name': portName,
        'description': port.description ?? 'N/A',
        'manufacturer': port.manufacturer ?? 'N/A',
        'serialNumber': port.serialNumber ?? 'N/A',
        'productId': port.productId?.toString() ?? 'N/A',
        'vendorId': port.vendorId?.toString() ?? 'N/A',
      };
      port.dispose();
      return info;
    } catch (e) {
      return {'name': portName, 'error': e.toString()};
    }
  }

  /// Carrega configuração do storage
  Future<void> loadConfig() async {
    try {
      final configJson = await _storage.read(key: 'scale_config');
      if (configJson != null) {
        _config = ScaleConfig.fromJson(jsonDecode(configJson));
        AppLogger.i(
            '⚖️ Configuração da balança carregada: ${_config.serialPort}',);
      } else {
        // Tentar detectar porta automaticamente
        await _autoDetectPort();
      }
    } catch (e) {
      AppLogger.w('⚖️ Erro ao carregar configuração da balança: $e');
      // Em caso de erro, tentar detectar porta
      await _autoDetectPort();
    }
  }

  /// Tenta detectar a porta da balança automaticamente
  Future<void> _autoDetectPort() async {
    final ports = getAvailablePorts();
    AppLogger.d('⚖️ Portas disponíveis para auto-detecção: $ports');

    if (ports.isEmpty) {
      AppLogger.w('⚖️ Nenhuma porta série encontrada');
      return;
    }

    // Procurar por portas USB-Serial comuns
    for (final portName in ports) {
      final info = getPortInfo(portName);
      final description = (info['description'] ?? '').toLowerCase();
      final manufacturer = (info['manufacturer'] ?? '').toLowerCase();

      AppLogger.d('⚖️ Verificando porta: $portName');
      AppLogger.d('⚖️   Descrição: ${info['description']}');
      AppLogger.d('⚖️   Fabricante: ${info['manufacturer']}');

      // Detectar adaptadores USB-Serial comuns
      if (description.contains('usb') ||
          description.contains('serial') ||
          description.contains('ch340') ||
          description.contains('pl2303') ||
          description.contains('ftdi') ||
          description.contains('cp210') ||
          description.contains('modem') || // Para macOS usbmodem
          manufacturer.contains('prolific') ||
          manufacturer.contains('ftdi') ||
          portName.contains('usbmodem') || // macOS: /dev/cu.usbmodem...
          portName.contains('usbserial')) {
        // macOS/Linux: /dev/cu.usbserial...
        AppLogger.i('⚖️ Porta detectada automaticamente: $portName');
        _config = _config.copyWith(serialPort: portName);
        return;
      }
    }

    // Se não encontrou adaptador USB-Serial, usar a primeira porta que não seja Bluetooth
    for (final portName in ports) {
      if (!portName.toLowerCase().contains('bluetooth') &&
          !portName.toLowerCase().contains('debug') &&
          !portName.toLowerCase().contains('wlan')) {
        AppLogger.i('⚖️ A usar porta disponível: $portName');
        _config = _config.copyWith(serialPort: portName);
        return;
      }
    }

    // Última opção: usar a primeira porta
    if (ports.isNotEmpty) {
      AppLogger.i('⚖️ A usar primeira porta disponível: ${ports.first}');
      _config = _config.copyWith(serialPort: ports.first);
    }
  }

  /// Guarda configuração no storage
  Future<void> saveConfig(ScaleConfig config) async {
    _config = config;
    try {
      await _storage.write(
        key: 'scale_config',
        value: jsonEncode(config.toJson()),
      );
      AppLogger.i('⚖️ Configuração da balança guardada: ${config.serialPort}');
    } catch (e) {
      AppLogger.e('⚖️ Erro ao guardar configuração da balança', error: e);
    }
  }

  /// Abre a conexão com a porta série
  bool _openSerialPort() {
    if (_config.serialPort.isEmpty) {
      AppLogger.e('⚖️ Porta série não configurada');
      return false;
    }

    try {
      // Fechar porta anterior se existir
      _closeSerialPort();

      AppLogger.d('⚖️ A abrir porta: ${_config.serialPort}');
      _serialPort = SerialPort(_config.serialPort);

      // Verificar se a porta existe
      if (!_serialPort!.isOpen) {
        // Configurar porta ANTES de abrir
        final portConfig = SerialPortConfig();
        portConfig.baudRate = _config.baudRate;
        portConfig.bits = _config.dataBits;
        portConfig.stopBits = _config.stopBits;
        portConfig.parity = _config.parity;
        portConfig.setFlowControl(SerialPortFlowControl.none);

        // Tentar aplicar configuração
        try {
          _serialPort!.config = portConfig;
        } catch (e) {
          AppLogger.w('⚖️ Aviso ao configurar porta (pode ser normal): $e');
        }
      }

      // Abrir porta para leitura e escrita
      if (!_serialPort!.openReadWrite()) {
        final error = SerialPort.lastError;
        AppLogger.e('⚖️ Erro ao abrir porta série: $error');
        _serialPort?.dispose();
        _serialPort = null;
        return false;
      }

      // Aplicar configuração após abrir (algumas plataformas precisam disto)
      try {
        final portConfig = SerialPortConfig();
        portConfig.baudRate = _config.baudRate;
        portConfig.bits = _config.dataBits;
        portConfig.stopBits = _config.stopBits;
        portConfig.parity = _config.parity;
        portConfig.setFlowControl(SerialPortFlowControl.none);
        _serialPort!.config = portConfig;
      } catch (e) {
        AppLogger.w('⚖️ Aviso ao reconfigurar porta: $e');
      }

      _isConnected = true;
      AppLogger.i('⚖️ ✅ Porta série aberta: ${_config.serialPort}');
      AppLogger.d('⚖️   Baud rate: ${_config.baudRate}');
      AppLogger.d('⚖️   Data bits: ${_config.dataBits}');
      AppLogger.d('⚖️   Stop bits: ${_config.stopBits}');
      AppLogger.d('⚖️   Parity: ${_config.parity}');
      return true;
    } catch (e) {
      AppLogger.e('⚖️ Erro ao abrir porta série', error: e);
      _serialPort?.dispose();
      _serialPort = null;
      return false;
    }
  }

  /// Fecha a conexão com a porta série
  void _closeSerialPort() {
    try {
      if (_serialPort != null) {
        if (_serialPort!.isOpen) {
          _serialPort!.close();
        }
        _serialPort!.dispose();
        _serialPort = null;
      }
      _isConnected = false;
    } catch (e) {
      AppLogger.e('⚖️ Erro ao fechar porta série', error: e);
    }
  }

  /// Lê o peso actual da balança
  Future<ScaleReading?> readWeight() async {
    switch (_config.connectionType) {
      case ScaleConnectionType.serial:
        return _readWeightSerial();
      case ScaleConnectionType.tcp:
        return _readWeightTcp();
      case ScaleConnectionType.http:
        return _readWeightHttp();
    }
  }

  /// Lê peso via porta série (RS-232)
  Future<ScaleReading?> _readWeightSerial() async {
    if (_config.serialPort.isEmpty) {
      // Tentar detectar porta
      await _autoDetectPort();
      if (_config.serialPort.isEmpty) {
        AppLogger.e('⚖️ Nenhuma porta série configurada ou detectada');
        return null;
      }
    }

    try {
      // Abrir porta se necessário
      if (!_isConnected || _serialPort == null || !_serialPort!.isOpen) {
        if (!_openSerialPort()) {
          return null;
        }
      }

      AppLogger.d('⚖️ A ler peso da balança via RS-232...');

      // Limpar buffer de entrada
      try {
        _serialPort!.flush();
        // TESTE: Enviar MÚLTIPLOS comandos
        _serialPort!.write(Uint8List.fromList([0x05])); // ENQ
        await Future.delayed(const Duration(milliseconds: 100));
        _serialPort!.write(Uint8List.fromList([0x14])); // DC4
        await Future.delayed(const Duration(milliseconds: 100));
        _serialPort!.write(Uint8List.fromList('P'.codeUnits)); // 'P'
        AppLogger.d('⚖️ Múltiplos comandos enviados');
      } catch (e) {
        AppLogger.w('⚖️ Aviso ao limpar buffer: $e');
      }

      // Enviar comando de solicitação de peso (se necessário para o protocolo)
      if (_config.protocol == ScaleProtocol.dibal) {
        // Dibal G-325: Enviar comando para solicitar peso
        // Protocolo Dibal: ENQ (0x05) solicita peso
        // Alternativa: DC4 (0x14) ou 'P' (0x50)
        try {
          // _serialPort!.write(Uint8List.fromList([0x05])); // ENQ
          // AppLogger.d('⚖️ Comando ENQ (0x05) enviado');

          // _serialPort!.write(Uint8List.fromList([0x14]));
          // AppLogger.d('⚖️ Comando DC4 (0x14) enviado');

          // _serialPort!.write(Uint8List.fromList([0x50])); // 'P'
          // AppLogger.d('⚖️ Comando "P" (0x50) enviado');

          // _serialPort!.write(Uint8List.fromList('P'.codeUnits));
          // AppLogger.d('⚖️ Comando "P" enviado');

          _serialPort!.write(Uint8List.fromList([0x1B]));
          AppLogger.d('⚖️ Comando ESC (0x1B) enviado');
        } catch (e) {
          AppLogger.w('⚖️ Aviso ao enviar comando: $e');
        }
      } else if (_config.requestCommand != null) {
        _serialPort!
            .write(Uint8List.fromList(_config.requestCommand!.codeUnits));
      }

      // Aguardar resposta
      await Future.delayed(const Duration(milliseconds: 500));

      // Ler resposta
      final buffer = StringBuffer();
      final rawBytes = <int>[];
      final startTime = DateTime.now();

      while (DateTime.now().difference(startTime) < _config.timeout) {
        final available = _serialPort!.bytesAvailable;
        if (available > 0) {
          final data = _serialPort!.read(available);
          if (data.isNotEmpty) {
            rawBytes.addAll(data);
            buffer.write(String.fromCharCodes(data));

            // Verificar se temos uma linha completa
            final content = buffer.toString();
            if (content.contains('\r') ||
                content.contains('\n') ||
                content.length >= 15) {
              final hexStr = rawBytes
                  .map((b) => b.toRadixString(16).padLeft(2, '0'))
                  .join(' ');
              AppLogger.d('⚖️ Dados recebidos: "$content"');
              AppLogger.d('⚖️ Dados hex: $hexStr');

              final reading = _parseResponse(content);
              if (reading != null) {
                return reading;
              }
            }
          }
        }
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Timeout - tentar fazer parse do que temos
      if (buffer.isNotEmpty) {
        final hexStr =
            rawBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
        AppLogger.d('⚖️ Timeout, dados recebidos: "${buffer.toString()}"');
        AppLogger.d('⚖️ Dados hex: $hexStr');
        return _parseResponse(buffer.toString());
      }

      AppLogger.w('⚖️ Timeout ao ler balança - nenhum dado recebido');
      return null;
    } catch (e) {
      AppLogger.e('⚖️ Erro ao ler balança RS-232', error: e);
      _closeSerialPort();
      return null;
    }
  }

  /// Lê peso via TCP
  Future<ScaleReading?> _readWeightTcp() async {
    Socket? socket;

    try {
      AppLogger.d(
          '⚖️ A conectar à balança TCP: ${_config.host}:${_config.port}',);

      socket = await Socket.connect(
        _config.host,
        _config.port,
        timeout: _config.timeout,
      );

      if (_config.requestCommand != null) {
        socket.write(_config.requestCommand);
      }

      final completer = Completer<String>();
      final buffer = StringBuffer();

      final subscription = socket.listen(
        (Uint8List data) {
          final str = String.fromCharCodes(data);
          buffer.write(str);

          if (str.contains('\n') || str.contains('\r')) {
            if (!completer.isCompleted) {
              completer.complete(buffer.toString());
            }
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(buffer.toString());
          }
        },
      );

      final response = await completer.future.timeout(
        _config.timeout,
        onTimeout: () {
          subscription.cancel();
          throw TimeoutException('Timeout ao ler balança');
        },
      );

      subscription.cancel();

      AppLogger.d('⚖️ Resposta TCP: $response');

      return _parseResponse(response);
    } catch (e) {
      AppLogger.e('⚖️ Erro ao ler balança TCP', error: e);
      return null;
    } finally {
      socket?.destroy();
    }
  }

  /// Lê peso via HTTP
  Future<ScaleReading?> _readWeightHttp() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = _config.timeout;

      final request = await client
          .getUrl(Uri.parse('http://${_config.host}:${_config.port}'));
      final response = await request.close();

      final responseBody = await response.transform(utf8.decoder).join();

      AppLogger.d('⚖️ Resposta HTTP: $responseBody');

      client.close();

      return _parseResponse(responseBody);
    } catch (e) {
      AppLogger.e('⚖️ Erro ao ler balança HTTP', error: e);
      return null;
    }
  }

  /// Faz parse da resposta da balança
  ScaleReading? _parseResponse(String response) {
    if (response.isEmpty) {
      AppLogger.w('⚖️ Resposta vazia da balança');
      return null;
    }

    try {
      final cleaned = response.trim();

      // Regex personalizado primeiro
      if (_config.weightRegex != null) {
        final regex = RegExp(_config.weightRegex!);
        final match = regex.firstMatch(cleaned);
        if (match != null) {
          final weightStr = match.group(1) ?? match.group(0);
          final weight = double.tryParse(weightStr?.replaceAll(',', '.') ?? '');
          if (weight != null) {
            return ScaleReading(
              weight: weight,
              unit: 'kg',
              isStable: true,
              rawData: cleaned,
            );
          }
        }
      }

      // Parse baseado no protocolo
      switch (_config.protocol) {
        case ScaleProtocol.dibal:
          return _parseDialResponse(cleaned);
        case ScaleProtocol.toledo:
          return _parseToledoResponse(cleaned);
        case ScaleProtocol.mettlerToledo:
          return _parseMettlerToledoResponse(cleaned);
        case ScaleProtocol.cas:
          return _parseCasResponse(cleaned);
        case ScaleProtocol.epelsa:
        case ScaleProtocol.generic:
          return _parseGenericResponse(cleaned);
      }
    } catch (e) {
      AppLogger.e('⚖️ Erro ao fazer parse da resposta', error: e);
      return null;
    }
  }

  /// Parse para balanças Dibal (G-310, G-325, etc.)
  /// Formato típico Dibal: STX + dados + ETX ou formato ASCII
  /// Exemplos:
  /// - "  1.234" (peso em kg, espaços à esquerda)
  /// - "\x02001234\x03" (STX + peso em gramas + ETX)
  ScaleReading? _parseDialResponse(String response) {
    AppLogger.d('⚖️ A fazer parse Dibal: "$response"');

    // Remover caracteres de controlo (STX, ETX, etc.)
    var cleaned = response
        .replaceAll('\x02', '') // STX
        .replaceAll('\x03', '') // ETX
        .replaceAll('\x06', '') // ACK
        .replaceAll('\x15', '') // NAK
        .replaceAll('\r', '')
        .replaceAll('\n', '')
        .trim();

    AppLogger.d('⚖️ Após limpeza: "$cleaned"');

    // Verificar estabilidade (algumas Dibal enviam flag)
    final isStable = !response.contains('?') && !response.contains('M');

    // Tentar extrair peso
    // Formato 1: Peso em kg com decimais (ex: "  1.234" ou "1,234")
    var regex = RegExp(r'(\d+[.,]\d+)');
    var match = regex.firstMatch(cleaned);

    if (match != null) {
      final weightStr = match.group(1)!.replaceAll(',', '.');
      final weight = double.tryParse(weightStr);
      if (weight != null) {
        AppLogger.i('⚖️ ✅ Peso extraído (formato decimal): $weight kg');
        return ScaleReading(
          weight: weight,
          unit: 'kg',
          isStable: isStable,
          rawData: response,
        );
      }
    }

    // Formato 2: Peso em gramas sem decimal (ex: "001234" = 1.234 kg)
    regex = RegExp(r'(\d{5,6})');
    match = regex.firstMatch(cleaned);

    if (match != null) {
      final weightInt = int.tryParse(match.group(1)!);
      if (weightInt != null) {
        // Converter de gramas para kg (assumindo 3 casas decimais)
        final weight = weightInt / 1000.0;
        AppLogger.i('⚖️ ✅ Peso extraído (formato inteiro): $weight kg');
        return ScaleReading(
          weight: weight,
          unit: 'kg',
          isStable: isStable,
          rawData: response,
        );
      }
    }

    // Formato 3: Qualquer número
    return _parseGenericResponse(cleaned);
  }

  /// Parse genérico
  ScaleReading? _parseGenericResponse(String response) {
    final isStable = !response.contains('?') &&
        (response.contains('S') || !response.contains('M'));

    final regex = RegExp(r'[+-]?\d+[.,]?\d*');
    final match = regex.firstMatch(response);

    if (match != null) {
      var weightStr = match.group(0)!.replaceAll(',', '.');
      var weight = double.tryParse(weightStr);

      if (weight != null) {
        String unit = 'kg';
        if (response.toLowerCase().contains('g') &&
            !response.toLowerCase().contains('kg')) {
          weight = weight / 1000;
        } else if (response.toLowerCase().contains('lb')) {
          weight = weight * 0.453592;
        }

        if (weight > 100 && !weightStr.contains('.')) {
          weight = weight / 1000;
        }

        AppLogger.i('⚖️ ✅ Peso extraído (genérico): $weight kg');
        return ScaleReading(
          weight: weight,
          unit: unit,
          isStable: isStable,
          rawData: response,
        );
      }
    }

    AppLogger.w('⚖️ Não foi possível extrair peso: "$response"');
    return null;
  }

  /// Parse para balanças Toledo
  ScaleReading? _parseToledoResponse(String response) {
    final isStable = response.startsWith('ST');

    final regex = RegExp(r'[+-]?(\d+\.?\d*)');
    final match = regex.firstMatch(response);

    if (match != null) {
      final weight = double.tryParse(match.group(1) ?? '');
      if (weight != null) {
        return ScaleReading(
          weight: weight,
          unit: 'kg',
          isStable: isStable,
          rawData: response,
        );
      }
    }

    return _parseGenericResponse(response);
  }

  /// Parse para balanças Mettler-Toledo
  ScaleReading? _parseMettlerToledoResponse(String response) {
    final parts = response.split(RegExp(r'\s+'));
    final isStable = parts.isNotEmpty && parts[0] == 'S';

    for (final part in parts) {
      final weight = double.tryParse(part.replaceAll(',', '.'));
      if (weight != null && weight > 0) {
        return ScaleReading(
          weight: weight,
          unit: 'kg',
          isStable: isStable,
          rawData: response,
        );
      }
    }

    return _parseGenericResponse(response);
  }

  /// Parse para balanças CAS
  ScaleReading? _parseCasResponse(String response) {
    final parts = response.split(',');
    final isStable = parts.isNotEmpty && parts[0].contains('ST');

    for (final part in parts) {
      final cleaned = part.replaceAll(RegExp(r'[^0-9.,+-]'), '');
      final weight = double.tryParse(cleaned.replaceAll(',', '.'));
      if (weight != null && weight > 0) {
        return ScaleReading(
          weight: weight,
          unit: 'kg',
          isStable: isStable,
          rawData: response,
        );
      }
    }

    return _parseGenericResponse(response);
  }

  /// Testa a conexão com a balança
  Future<bool> testConnection() async {
    final reading = await readWeight();
    return reading != null;
  }

  /// Fecha conexões
  void dispose() {
    _closeSerialPort();
  }
}
