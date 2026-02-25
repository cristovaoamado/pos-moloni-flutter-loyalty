import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:pos_moloni_app/core/services/storage_service.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';

/// Tipo de conexão da balança
enum ScaleConnectionType {
  serial,
  network,
}

/// Protocolo da balança
enum ScaleProtocol {
  dibal,
  toledo,
  mettlerToledo,
  cas,
  epelsa,
  generic,
}

/// Estado da conexão da balança
enum ScaleConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// Configuração da balança
class ScaleConfig {
  const ScaleConfig({
    this.connectionType = ScaleConnectionType.serial,
    this.protocol = ScaleProtocol.dibal,
    this.serialPort = '',
    this.baudRate = 9600,
    this.dataBits = 8,
    this.stopBits = 1,
    this.parity = 0,
    this.networkAddress = '',
    this.networkPort = 4001,
  });

  factory ScaleConfig.fromJson(Map<String, dynamic> json) {
    return ScaleConfig(
      connectionType: ScaleConnectionType.values[json['connectionType'] ?? 0],
      protocol: ScaleProtocol.values[json['protocol'] ?? 0],
      serialPort: json['serialPort'] ?? '',
      baudRate: json['baudRate'] ?? 9600,
      dataBits: json['dataBits'] ?? 8,
      stopBits: json['stopBits'] ?? 1,
      parity: json['parity'] ?? 0,
      networkAddress: json['networkAddress'] ?? '',
      networkPort: json['networkPort'] ?? 4001,
    );
  }

  final ScaleConnectionType connectionType;
  final ScaleProtocol protocol;
  final String serialPort;
  final int baudRate;
  final int dataBits;
  final int stopBits;
  final int parity;
  final String networkAddress;
  final int networkPort;

  bool get isConfigured => serialPort.isNotEmpty || networkAddress.isNotEmpty;

  ScaleConfig copyWith({
    ScaleConnectionType? connectionType,
    ScaleProtocol? protocol,
    String? serialPort,
    int? baudRate,
    int? dataBits,
    int? stopBits,
    int? parity,
    String? networkAddress,
    int? networkPort,
  }) {
    return ScaleConfig(
      connectionType: connectionType ?? this.connectionType,
      protocol: protocol ?? this.protocol,
      serialPort: serialPort ?? this.serialPort,
      baudRate: baudRate ?? this.baudRate,
      dataBits: dataBits ?? this.dataBits,
      stopBits: stopBits ?? this.stopBits,
      parity: parity ?? this.parity,
      networkAddress: networkAddress ?? this.networkAddress,
      networkPort: networkPort ?? this.networkPort,
    );
  }

  Map<String, dynamic> toJson() => {
        'connectionType': connectionType.index,
        'protocol': protocol.index,
        'serialPort': serialPort,
        'baudRate': baudRate,
        'dataBits': dataBits,
        'stopBits': stopBits,
        'parity': parity,
        'networkAddress': networkAddress,
        'networkPort': networkPort,
      };

  @override
  String toString() =>
      'ScaleConfig(port: $serialPort, baud: $baudRate, protocol: ${protocol.name})';
}

/// Resultado da leitura de peso
class WeightReading {
  const WeightReading({
    required this.weight,
    this.unit = 'kg',
    this.isStable = true,
  });

  final double weight;
  final String unit;
  final bool isStable;
}

/// Resultado da leitura (para compatibilidade)
class WeightResult {
  const WeightResult({
    required this.success,
    this.weight,
    this.unit = 'kg',
    this.isStable = false,
    this.error,
    this.rawData,
  });

  factory WeightResult.ok(double weight, {bool stable = true, String? raw}) =>
      WeightResult(
        success: true,
        weight: weight,
        isStable: stable,
        rawData: raw,
      );

  factory WeightResult.fail(String error, {String? raw}) => WeightResult(
        success: false,
        error: error,
        rawData: raw,
      );

  final bool success;
  final double? weight;
  final String unit;
  final bool isStable;
  final String? error;
  final String? rawData;
}

const _scaleConfigKey = 'scale_config';

/// Serviço de balança (SINGLETON) com reconexão automática
///
/// USO: Sempre usar ScaleService.instance
class ScaleService {
  factory ScaleService() => instance;
  // ========== SINGLETON ==========
  ScaleService._internal();
  static final ScaleService instance = ScaleService._internal();

  // ========== ESTADO ==========
  final _storage = PlatformStorage.instance;
  SerialPort? _port;
  ScaleConfig _config = const ScaleConfig();
  bool _configLoaded = false;

  // ========== RECONEXÃO AUTOMÁTICA ==========
  Timer? _reconnectTimer;
  Timer? _portMonitorTimer;
  ScaleConnectionState _connectionState = ScaleConnectionState.disconnected;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 0; // 0 = infinito
  static const Duration _reconnectInterval = Duration(seconds: 3);
  static const Duration _portMonitorInterval = Duration(seconds: 2);

  // Stream para notificar mudanças de estado
  final _connectionStateController =
      StreamController<ScaleConnectionState>.broadcast();
  Stream<ScaleConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  ScaleConfig get config => _config;
  bool get isConfigured => _config.isConfigured;
  bool get isConnected =>
      (_port?.isOpen ?? false) && _connectionState == ScaleConnectionState.connected;
  ScaleConnectionState get connectionState => _connectionState;

  // ========== MÉTODOS ESTÁTICOS ==========

  static List<String> getAvailablePorts() {
    try {
      return SerialPort.availablePorts;
    } catch (e) {
      AppLogger.e('Erro ao listar portas: $e');
      return [];
    }
  }

  static Map<String, String> getPortInfo(String portName) {
    try {
      final port = SerialPort(portName);
      final info = {
        'name': portName,
        'description': port.description ?? '',
        'manufacturer': port.manufacturer ?? '',
        'serialNumber': port.serialNumber ?? '',
        'productId': port.productId?.toRadixString(16) ?? '',
        'vendorId': port.vendorId?.toRadixString(16) ?? '',
      };
      port.dispose();
      return info;
    } catch (e) {
      return {'name': portName, 'description': '', 'error': e.toString()};
    }
  }

  // ========== CONFIGURAÇÃO ==========

  Future<void> loadConfig() async {
    if (_configLoaded) return;

    try {
      final json = await _storage.read(key: _scaleConfigKey);
      if (json != null) {
        _config = ScaleConfig.fromJson(jsonDecode(json));
        AppLogger.i('⚖️ Config balança carregada: $_config');
      }
      _configLoaded = true;
    } catch (e) {
      AppLogger.e('Erro ao carregar config da balança: $e');
      _configLoaded = true;
    }
  }

  Future<void> saveConfig(ScaleConfig config) async {
    // Desconectar se a porta mudou
    if (_port != null && _config.serialPort != config.serialPort) {
      await disconnect();
    }

    _config = config;
    _configLoaded = true;

    try {
      await _storage.write(
        key: _scaleConfigKey,
        value: jsonEncode(config.toJson()),
      );
      AppLogger.i('✅ Config balança guardada: $config');
    } catch (e) {
      AppLogger.e('Erro ao guardar config: $e');
    }
  }

  // ========== GESTÃO DE ESTADO ==========

  void _setConnectionState(ScaleConnectionState state) {
    if (_connectionState != state) {
      _connectionState = state;
      _connectionStateController.add(state);
      AppLogger.i('⚖️ Estado da balança: ${state.name}');
    }
  }

  // ========== CONEXÃO ==========

  /// Inicializa o serviço e inicia a monitorização da porta
  Future<void> initialize() async {
    await loadConfig();
    if (_config.isConfigured) {
      _startPortMonitor();
      await connect();
    }
  }

  Future<bool> connect() async {
    if (!_configLoaded) await loadConfig();

    if (!_config.isConfigured) {
      AppLogger.e('⚖️ Balança não configurada');
      return false;
    }

    // Se já está conectado, verificar se a porta ainda está válida
    if (_port?.isOpen ?? false) {
      if (_isPortStillValid()) {
        return true;
      }
      // Porta inválida, limpar
      await _cleanupPort();
    }

    _setConnectionState(ScaleConnectionState.connecting);

    try {
      AppLogger.i('⚖️ A conectar: ${_config.serialPort}');
      AppLogger.d(
          '   Baud: ${_config.baudRate}, Protocol: ${_config.protocol.name}',);

      // Verificar se a porta existe
      final availablePorts = SerialPort.availablePorts;
      if (!availablePorts.contains(_config.serialPort)) {
        AppLogger.e('❌ Porta não encontrada: ${_config.serialPort}');
        AppLogger.d('   Portas disponíveis: $availablePorts');
        _setConnectionState(ScaleConnectionState.disconnected);
        _scheduleReconnect();
        return false;
      }

      _port = SerialPort(_config.serialPort);

      if (!_port!.openReadWrite()) {
        final error = SerialPort.lastError;
        AppLogger.e('❌ Erro ao abrir porta: $error');
        AppLogger.e('   Código: ${error?.errorCode}, Msg: ${error?.message}');
        await _cleanupPort();
        _scheduleReconnect();
        return false;
      }

      AppLogger.d('✓ Porta aberta com sucesso');

      final portConfig = SerialPortConfig();
      portConfig.baudRate = _config.baudRate;
      portConfig.bits = _config.dataBits;
      portConfig.stopBits = _config.stopBits;
      portConfig.parity = _config.parity;
      portConfig.setFlowControl(SerialPortFlowControl.none);
      _port!.config = portConfig;

      // Verificar config aplicada
      final appliedConfig = _port!.config;
      AppLogger.d(
          '✓ Config aplicada: baud=${appliedConfig.baudRate}, bits=${appliedConfig.bits}',);

      _setConnectionState(ScaleConnectionState.connected);
      _reconnectAttempts = 0;
      _cancelReconnect();
      _startPortMonitor();

      AppLogger.i('✅ Conectado: ${_config.serialPort}');
      return true;
    } catch (e, stack) {
      AppLogger.e('❌ Erro ao conectar: $e');
      AppLogger.e('   Stack: $stack');
      await _cleanupPort();
      _scheduleReconnect();
      return false;
    }
  }

  /// Verifica se a porta configurada ainda está disponível no sistema
  bool _isPortStillValid() {
    try {
      final availablePorts = SerialPort.availablePorts;
      if (!availablePorts.contains(_config.serialPort)) {
        AppLogger.w('⚖️ Porta ${_config.serialPort} já não está disponível');
        return false;
      }

      // Verificar se a porta ainda está aberta
      if (_port == null || !_port!.isOpen) {
        AppLogger.w('⚖️ Porta não está aberta');
        return false;
      }

      return true;
    } catch (e) {
      AppLogger.e('⚖️ Erro ao verificar porta: $e');
      return false;
    }
  }

  /// Limpa a porta atual
  Future<void> _cleanupPort() async {
    try {
      if (_port != null) {
        if (_port!.isOpen) {
          _port!.close();
        }
        _port!.dispose();
        _port = null;
      }
    } catch (e) {
      AppLogger.e('Erro ao limpar porta: $e');
      _port = null;
    }
    _setConnectionState(ScaleConnectionState.disconnected);
  }

  // ========== RECONEXÃO AUTOMÁTICA ==========

  /// Inicia a monitorização periódica da porta
  void _startPortMonitor() {
    _portMonitorTimer?.cancel();
    _portMonitorTimer = Timer.periodic(_portMonitorInterval, (_) {
      _checkPortHealth();
    });
  }

  /// Para a monitorização da porta
  void _stopPortMonitor() {
    _portMonitorTimer?.cancel();
    _portMonitorTimer = null;
  }

  /// Verifica a saúde da conexão
  void _checkPortHealth() {
    if (!_config.isConfigured) return;

    // Se está em processo de reconexão, não fazer nada
    if (_connectionState == ScaleConnectionState.reconnecting ||
        _connectionState == ScaleConnectionState.connecting) {
      return;
    }

    // Verificar se a porta ainda existe e está válida
    if (!_isPortStillValid()) {
      AppLogger.w('⚖️ Monitor: porta desconectada, a iniciar reconexão...');
      _handleDisconnection();
    }
  }

  /// Trata uma desconexão detectada
  void _handleDisconnection() {
    if (_connectionState == ScaleConnectionState.reconnecting) return;

    _cleanupPort();
    _scheduleReconnect();
  }

  /// Agenda uma tentativa de reconexão
  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;

    _setConnectionState(ScaleConnectionState.reconnecting);

    _reconnectTimer = Timer.periodic(_reconnectInterval, (_) async {
      _reconnectAttempts++;

      // Verificar limite de tentativas (0 = infinito)
      if (_maxReconnectAttempts > 0 &&
          _reconnectAttempts > _maxReconnectAttempts) {
        AppLogger.e(
            '⚖️ Limite de tentativas de reconexão atingido ($_maxReconnectAttempts)',);
        _cancelReconnect();
        _setConnectionState(ScaleConnectionState.disconnected);
        return;
      }

      AppLogger.i(
          '⚖️ Tentativa de reconexão #$_reconnectAttempts...',);

      // Verificar se a porta apareceu
      final availablePorts = SerialPort.availablePorts;
      if (availablePorts.contains(_config.serialPort)) {
        AppLogger.i('⚖️ Porta ${_config.serialPort} encontrada!');
        _cancelReconnect();

        // Pequeno delay para dar tempo ao sistema
        await Future.delayed(const Duration(milliseconds: 500));

        if (await connect()) {
          AppLogger.i('✅ Reconexão bem sucedida!');
        }
      } else {
        AppLogger.d(
            '⚖️ Porta ${_config.serialPort} ainda não disponível. Portas: $availablePorts',);
      }
    });
  }

  /// Cancela o timer de reconexão
  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  Future<void> disconnect() async {
    _cancelReconnect();
    _stopPortMonitor();
    await _cleanupPort();
  }

  // ========== LEITURA ==========

  /// Número máximo de tentativas de leitura
  static const int _maxReadRetries = 3;
  
  /// Delay entre tentativas (ms)
  static const int _retryDelayMs = 150;

  /// Lê o peso da balança com retries automáticos
  Future<WeightReading?> readWeight() async {
    for (int attempt = 1; attempt <= _maxReadRetries; attempt++) {
      AppLogger.d('⚖️ Tentativa de leitura $attempt/$_maxReadRetries');
      
      final result = await _readWeightOnce();
      
      if (result != null) {
        return result;
      }
      
      // Se não é a última tentativa, esperar antes de tentar novamente
      if (attempt < _maxReadRetries) {
        await Future.delayed(Duration(milliseconds: _retryDelayMs));
      }
    }
    
    AppLogger.w('⚖️ Todas as $_maxReadRetries tentativas de leitura falharam');
    return null;
  }

  /// Executa uma única tentativa de leitura
  Future<WeightReading?> _readWeightOnce() async {
    if (!_configLoaded) await loadConfig();
    if (!_config.isConfigured) {
      AppLogger.w('⚖️ readWeight: Balança não configurada');
      return null;
    }

    // Verificar conexão e tentar reconectar se necessário
    if (!isConnected) {
      AppLogger.d('⚖️ readWeight: Não conectado, a tentar conectar...');
      if (!await connect()) {
        AppLogger.e('⚖️ readWeight: Falha ao conectar');
        return null;
      }
    }

    // Verificar novamente se a porta está válida
    if (!_isPortStillValid()) {
      AppLogger.e('⚖️ readWeight: Porta inválida');
      _handleDisconnection();
      return null;
    }

    try {
      // Limpar buffer
      int cleared = 0;
      while (_port!.bytesAvailable > 0) {
        cleared += _port!.read(_port!.bytesAvailable).length;
      }
      if (cleared > 0) {
        AppLogger.d('⚖️ Buffer limpo: $cleared bytes');
      }

      // Enviar comando
      final command = _getWeightCommand();
      AppLogger.d(
          '📤 A enviar comando: ${_bytesToHex(command)} (${command.length} bytes)',);

      final written = _port!.write(Uint8List.fromList(command));
      AppLogger.d('📤 Bytes escritos: $written');

      if (written != command.length) {
        AppLogger.e('❌ Erro: escritos $written de ${command.length} bytes');
        _handleDisconnection();
        return null;
      }

      // Delay mais generoso para dar tempo à balança responder
      await Future.delayed(const Duration(milliseconds: 80));

      // Ler resposta com timeout aumentado
      AppLogger.d('📥 A aguardar resposta (700ms timeout)...');
      final response = await _readWithTimeout(const Duration(milliseconds: 700));

      if (response == null || response.isEmpty) {
        AppLogger.w('📥 Sem resposta da balança');
        return null;
      }

      AppLogger.i('📥 Recebido ${response.length} bytes: ${_bytesToHex(response)}');
      final ascii =
          String.fromCharCodes(response.where((b) => b >= 32 && b < 127));
      AppLogger.d('   ASCII: "$ascii"');

      // Se receber "?" significa que o comando não é reconhecido
      // Tentar auto-detecção
      if (response.contains(0x3F)) {
        AppLogger.w('⚠️ Comando não reconhecido ("?"), a tentar auto-detecção...');
        return await readWeightWithAutoDetect();
      }

      final result = _parseWeight(response);
      if (result != null) {
        AppLogger.i(
            '✅ Peso: ${result.weight} ${result.unit} (estável: ${result.isStable})',);
      } else {
        AppLogger.w('⚠️ Não foi possível fazer parse da resposta');
      }

      return result;
    } catch (e, stack) {
      AppLogger.e('❌ Erro ao ler peso: $e');
      AppLogger.e('   Stack: $stack');

      // Verificar se foi erro de comunicação
      if (e.toString().contains('port') ||
          e.toString().contains('serial') ||
          e.toString().contains('I/O')) {
        _handleDisconnection();
      }

      return null;
    }
  }

  Future<WeightResult> readWeightResult() async {
    final reading = await readWeight();
    if (reading != null) {
      return WeightResult.ok(reading.weight, stable: reading.isStable);
    }
    return WeightResult.fail('Não foi possível ler o peso');
  }

  // ========== PROTOCOLO ==========

  List<int> _getWeightCommand() {
    switch (_config.protocol) {
      case ScaleProtocol.dibal:
        // Dibal G325 com protocolo 16 (DIALOG 06):
        // O protocolo DIALOG requer que a caixa (POS) envie primeiro o preço
        // e a balança responde com peso quando recebe o pedido.
        // Para polling simples, muitas Dibal usam ENQ (0x05)
        // ou o formato STX + "01" + ETX para pedir peso
        return [0x05]; // ENQ - mais universal para Dibal
      case ScaleProtocol.toledo:
      case ScaleProtocol.mettlerToledo:
        return [0x53]; // 'S'
      case ScaleProtocol.cas:
        return [0x05]; // ENQ
      case ScaleProtocol.epelsa:
        return [0x11]; // DC1
      case ScaleProtocol.generic:
        return [0x05]; // ENQ
    }
  }

  /// Tenta ler peso com múltiplos protocolos/comandos (para auto-detecção)
  Future<WeightReading?> readWeightWithAutoDetect() async {
    if (!_configLoaded) await loadConfig();
    if (!_config.isConfigured) return null;
    if (!isConnected && !await connect()) return null;

    // Lista de comandos a tentar, incluindo frames estruturados
    // Formato: (bytes, descrição)
    final commands = [
      // Comandos simples
      ([0x05], 'ENQ'), // ENQ - polling genérico
      ([0x57], 'W'), // 'W' - pedido de peso ASCII
      ([0x11], 'DC1'), // DC1 - protocolo 16
      ([0x53], 'S'), // 'S' - Mettler-Toledo

      // Frames estruturados STX/ETX (DIALOG 06 style)
      // Frame 1: STX + "01" + ESC + "000000" + ETX (preço zero para pedir peso)
      (
        [0x02, 0x30, 0x31, 0x1B, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x03],
        'DIALOG-01'
      ),

      // Frame ANKER: STX + preço + ETX
      ([0x02, 0x30, 0x30, 0x30, 0x30, 0x30, 0x03], 'ANKER'),

      // Frame NCI: 'W' seguido de CR
      ([0x57, 0x0D], 'NCI-W'),

      // Frame CASIO: '@1' + preço + CR
      ([0x40, 0x31, 0x30, 0x30, 0x30, 0x30, 0x30, 0x0D], 'CASIO'),

      // Comandos adicionais
      ([0x12], 'DC2'), // DC2
      ([0x06], 'ACK'), // ACK (alguns modelos respondem com peso)
    ];

    for (final cmd in commands) {
      try {
        // Limpar buffer
        while (_port!.bytesAvailable > 0) {
          _port!.read(_port!.bytesAvailable);
        }

        AppLogger.d('⚖️ Tentando comando ${cmd.$2} (${_bytesToHex(cmd.$1)})');
        _port!.write(Uint8List.fromList(cmd.$1));

        await Future.delayed(const Duration(milliseconds: 100));
        final response =
            await _readWithTimeout(const Duration(milliseconds: 400));

        if (response != null && response.isNotEmpty) {
          AppLogger.d('   Resposta: ${_bytesToHex(response)}');

          // Verificar se é "?" (comando não reconhecido)
          if (response.contains(0x3F)) {
            AppLogger.d('   → "?" - comando não reconhecido');
            continue;
          }

          // Verificar se é NAK
          if (response.contains(0x15)) {
            AppLogger.d('   → NAK - rejeitado');
            continue;
          }

          // Tentar fazer parse
          final result = _parseWeight(response);
          if (result != null) {
            AppLogger.i('✅ Comando ${cmd.$2} funcionou! Peso: ${result.weight}');
            return result;
          } else {
            AppLogger.d('   → Não foi possível fazer parse');
          }
        } else {
          AppLogger.d('   → Sem resposta');
        }
      } catch (e) {
        AppLogger.d('   → Erro: $e');
      }
    }

    AppLogger.w('⚠️ Nenhum comando funcionou. Verifique:');
    AppLogger.w('   1. Protocolo configurado na balança (sidepr=16)');
    AppLogger.w('   2. Parâmetros série: 9600-8-N-1');
    AppLogger.w('   3. Cabo RS-232 correctamente ligado');
    return null;
  }

  Future<Uint8List?> _readWithTimeout(Duration timeout) async {
    final completer = Completer<Uint8List?>();
    final buffer = <int>[];
    Timer? timeoutTimer;
    Timer? readTimer;

    timeoutTimer = Timer(timeout, () {
      readTimer?.cancel();
      if (!completer.isCompleted) {
        completer.complete(buffer.isEmpty ? null : Uint8List.fromList(buffer));
      }
    });

    readTimer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      try {
        if (_port == null || !_port!.isOpen) {
          timeoutTimer?.cancel();
          readTimer?.cancel();
          if (!completer.isCompleted) completer.complete(null);
          return;
        }

        final available = _port!.bytesAvailable;
        if (available > 0) {
          buffer.addAll(_port!.read(available));

          // Frame completo?
          if (buffer.contains(0x0D) ||
              buffer.contains(0x0A) ||
              buffer.contains(0x03)) {
            timeoutTimer?.cancel();
            readTimer?.cancel();
            if (!completer.isCompleted) {
              completer.complete(Uint8List.fromList(buffer));
            }
          }
        }
      } catch (_) {}
    });

    return completer.future;
  }

  /// Tenta ler peso em modo passivo (para balanças com transmissão contínua)
  /// Algumas balanças enviam peso automaticamente quando há alteração
  Future<WeightReading?> readWeightPassive(
      {Duration timeout = const Duration(seconds: 2),}) async {
    if (!_configLoaded) await loadConfig();
    if (!_config.isConfigured) return null;
    if (!isConnected && !await connect()) return null;

    try {
      AppLogger.d('⚖️ Modo passivo: aguardando dados da balança...');

      // Limpar buffer primeiro
      while (_port!.bytesAvailable > 0) {
        _port!.read(_port!.bytesAvailable);
      }

      // Aguardar dados sem enviar comando
      final response = await _readWithTimeout(timeout);

      if (response != null && response.isNotEmpty) {
        AppLogger.i('📥 Dados recebidos: ${_bytesToHex(response)}');
        return _parseWeight(response);
      }

      AppLogger.d('   Nenhum dado recebido no modo passivo');
      return null;
    } catch (e) {
      AppLogger.e('Erro modo passivo: $e');
      return null;
    }
  }

  /// Método de diagnóstico - testa todos os modos de comunicação
  Future<Map<String, dynamic>> runDiagnostics() async {
    final results = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'config': _config.toString(),
      'connectionState': _connectionState.name,
    };

    // Tentar conectar
    if (!isConnected) {
      results['connect'] = await connect();
    } else {
      results['connect'] = true;
    }

    if (!isConnected) {
      results['error'] = 'Não foi possível conectar';
      return results;
    }

    // Teste 1: Modo passivo (balança pode enviar dados automaticamente)
    AppLogger.i('🔍 Teste 1: Modo passivo');
    final passiveResult =
        await readWeightPassive(timeout: const Duration(seconds: 1));
    results['passive_mode'] = passiveResult != null
        ? 'OK - Peso: ${passiveResult.weight}'
        : 'Sem resposta';

    // Teste 2: Comando principal
    AppLogger.i('🔍 Teste 2: Comando principal');
    final mainResult = await readWeight();
    results['main_command'] =
        mainResult != null ? 'OK - Peso: ${mainResult.weight}' : 'Falhou';

    // Teste 3: Info da porta
    results['port_info'] = {
      'name': _config.serialPort,
      'open': _port?.isOpen ?? false,
      'available_ports': SerialPort.availablePorts,
    };

    AppLogger.i('📊 Diagnóstico completo: $results');
    return results;
  }

  // ========== PARSING ==========

  WeightReading? _parseWeight(Uint8List data) {
    if (data.contains(0x15)) return null; // NAK

    final cleanStr = String.fromCharCodes(data)
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ')
        .trim();

    switch (_config.protocol) {
      case ScaleProtocol.dibal:
        return _parseDialWeight(cleanStr, data);
      case ScaleProtocol.toledo:
      case ScaleProtocol.mettlerToledo:
        return _parseMettlerWeight(cleanStr, data);
      case ScaleProtocol.cas:
        return _parseCasWeight(cleanStr, data);
      default:
        return _parseGenericWeight(cleanStr, data);
    }
  }

  WeightReading? _parseDialWeight(String cleanStr, Uint8List data) {
    // DIALOG 06 response format: STX + status + 5 digits weight + ETX ou similar
    // Exemplo: 0x02 0x30 0x30 W W W W W 0x03
    // Também pode ter formato: peso + unidade

    AppLogger.d('   Parse Dibal: "$cleanStr" | raw: ${_bytesToHex(data)}');

    // Verificar se há STX/ETX (protocolo DIALOG)
    if (data.contains(0x02) && data.contains(0x03)) {
      final startIdx = data.indexOf(0x02) + 1;
      final endIdx = data.indexOf(0x03);
      if (endIdx > startIdx) {
        final payload = data.sublist(startIdx, endIdx);
        final payloadStr =
            String.fromCharCodes(payload).replaceAll(RegExp(r'[^\d\.]'), '');
        AppLogger.d('   Payload DIALOG: $payloadStr');

        // Extrair peso (normalmente últimos 5-6 dígitos)
        if (payloadStr.length >= 5) {
          var numStr = payloadStr;
          // Inserir ponto decimal se não existir
          if (!numStr.contains('.')) {
            final len = numStr.length;
            numStr =
                '${numStr.substring(0, len - 3)}.${numStr.substring(len - 3)}';
          }
          final weight = double.tryParse(numStr);
          if (weight != null && weight >= 0) {
            final isStable = !data.contains(0x55) && !cleanStr.contains('U');
            return WeightReading(weight: weight, isStable: isStable);
          }
        }
      }
    }

    // Formato simples: extrair números
    final match = RegExp(r'[\d\s\.]+').firstMatch(cleanStr);
    if (match != null) {
      var numStr = match.group(0)!.replaceAll(' ', '');
      if (!numStr.contains('.') && numStr.length >= 5) {
        final len = numStr.length;
        numStr =
            '${numStr.substring(0, len - 3)}.${numStr.substring(len - 3)}';
      }
      final weight = double.tryParse(numStr);
      if (weight != null && weight >= 0) {
        return WeightReading(weight: weight, isStable: !data.contains(0x55));
      }
    }
    return null;
  }

  WeightReading? _parseMettlerWeight(String cleanStr, Uint8List data) {
    final isStable = cleanStr.contains('S S') || !cleanStr.contains('S D');
    final match = RegExp(r'[\d]+\.[\d]+').firstMatch(cleanStr);
    if (match != null) {
      final weight = double.tryParse(match.group(0)!);
      if (weight != null && weight >= 0) {
        return WeightReading(weight: weight, isStable: isStable);
      }
    }
    return null;
  }

  WeightReading? _parseCasWeight(String cleanStr, Uint8List data) {
    final isStable = cleanStr.contains('ST');
    final match = RegExp(r'[+-]?[\d]+\.[\d]+').firstMatch(cleanStr);
    if (match != null) {
      final weight = double.tryParse(match.group(0)!.replaceAll('+', ''));
      if (weight != null && weight >= 0) {
        return WeightReading(weight: weight, isStable: isStable);
      }
    }
    return null;
  }

  WeightReading? _parseGenericWeight(String cleanStr, Uint8List data) {
    final match = RegExp(r'[\d]+\.?[\d]*').firstMatch(cleanStr);
    if (match != null) {
      var numStr = match.group(0)!;
      if (!numStr.contains('.') && numStr.length >= 5) {
        final len = numStr.length;
        numStr =
            '${numStr.substring(0, len - 3)}.${numStr.substring(len - 3)}';
      }
      final weight = double.tryParse(numStr);
      if (weight != null && weight >= 0) {
        return WeightReading(weight: weight, isStable: true);
      }
    }
    return null;
  }

  String _bytesToHex(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');

  void dispose() {
    _connectionStateController.close();
    disconnect();
  }
}
