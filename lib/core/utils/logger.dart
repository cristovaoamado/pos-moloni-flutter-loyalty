import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// Logger centralizado da aplicação
/// Suporta output para consola e ficheiro
class AppLogger {
  static late Logger _logger;
  static File? _logFile;
  static IOSink? _fileSink;
  static bool _initialized = false;
  static bool _fileLoggingEnabled = true;

  /// Inicializa o logger (chamar no main.dart)
  static Future<void> init({bool enableFileLogging = true}) async {
    if (_initialized) return;

    _fileLoggingEnabled = enableFileLogging;

    // Criar logger para consola
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 5,
        lineLength: 80,
        colors: true,
        printEmojis: true,
      ),
      level: kDebugMode ? Level.debug : Level.info,
    );

    // Inicializar ficheiro de log
    if (_fileLoggingEnabled && !kIsWeb) {
      await _initFileLogging();
    }

    _initialized = true;
    i('📋 Logger inicializado');
  }

  /// Inicializa o ficheiro de log
  static Future<void> _initFileLogging() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final logsDir = Directory('${appDir.path}/logs');
      
      // Criar pasta de logs se não existir
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }

      // Nome do ficheiro com data
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _logFile = File('${logsDir.path}/pos_$dateStr.log');
      
      // Abrir sink para escrita (append mode)
      _fileSink = _logFile!.openWrite(mode: FileMode.append);
      
      // Escrever header
      _writeToFile('\n${'=' * 60}');
      _writeToFile('LOG INICIADO: ${DateTime.now().toIso8601String()}');
      _writeToFile('${'=' * 60}\n');
      
      if (kDebugMode) {
        print('📁 Ficheiro de log: ${_logFile!.path}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Erro ao inicializar ficheiro de log: $e');
      }
    }
  }

  /// Escreve no ficheiro de log
  static void _writeToFile(String message) {
    if (_fileSink != null) {
      try {
        _fileSink!.writeln(message);
      } catch (e) {
        // Ignora erros de escrita silenciosamente
      }
    }
  }

  /// Formata mensagem para ficheiro
  static String _formatForFile(String level, String message, {dynamic error, StackTrace? stackTrace}) {
    final timestamp = DateFormat('HH:mm:ss.SSS').format(DateTime.now());
    final buffer = StringBuffer();
    buffer.write('[$timestamp] [$level] $message');
    if (error != null) {
      buffer.write('\n  ERROR: $error');
    }
    if (stackTrace != null) {
      buffer.write('\n  STACK: $stackTrace');
    }
    return buffer.toString();
  }

  /// Força escrita do buffer para disco
  static Future<void> flush() async {
    await _fileSink?.flush();
  }

  /// Fecha o ficheiro de log
  static Future<void> close() async {
    _writeToFile('\n${'=' * 60}');
    _writeToFile('LOG TERMINADO: ${DateTime.now().toIso8601String()}');
    _writeToFile('${'=' * 60}\n');
    await _fileSink?.flush();
    await _fileSink?.close();
    _fileSink = null;
  }

  /// Obtém o caminho do ficheiro de log actual
  static String? get logFilePath => _logFile?.path;

  /// Obtém o directório de logs
  static Future<String?> getLogsDirectory() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      return '${appDir.path}/logs';
    } catch (e) {
      return null;
    }
  }

  /// Lista todos os ficheiros de log
  static Future<List<File>> listLogFiles() async {
    try {
      final logsDir = await getLogsDirectory();
      if (logsDir == null) return [];
      
      final dir = Directory(logsDir);
      if (!await dir.exists()) return [];
      
      return dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.log'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path)); // Mais recentes primeiro
    } catch (e) {
      return [];
    }
  }

  /// Limpa logs antigos (mais de X dias)
  static Future<int> cleanOldLogs({int keepDays = 7}) async {
    try {
      final files = await listLogFiles();
      final cutoff = DateTime.now().subtract(Duration(days: keepDays));
      int deleted = 0;
      
      for (final file in files) {
        final stat = await file.stat();
        if (stat.modified.isBefore(cutoff)) {
          await file.delete();
          deleted++;
        }
      }
      
      return deleted;
    } catch (e) {
      return 0;
    }
  }

  // ==================== MÉTODOS DE LOG ====================

  /// Log de debug (🔍)
  static void d(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      _logger.d(message, error: error, stackTrace: stackTrace);
    }
    _writeToFile(_formatForFile('DEBUG', message, error: error, stackTrace: stackTrace));
  }

  /// Log de informação (ℹ️)
  static void i(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      _logger.i(message, error: error, stackTrace: stackTrace);
    }
    _writeToFile(_formatForFile('INFO', message, error: error, stackTrace: stackTrace));
  }

  /// Log de aviso (⚠️)
  static void w(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _logger.w(message, error: error, stackTrace: stackTrace);
    _writeToFile(_formatForFile('WARN', message, error: error, stackTrace: stackTrace));
  }

  /// Log de erro (❌)
  static void e(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _logger.e(message, error: error, stackTrace: stackTrace);
    _writeToFile(_formatForFile('ERROR', message, error: error, stackTrace: stackTrace));
  }

  /// Log crítico (🔥)
  static void f(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _logger.f(message, error: error, stackTrace: stackTrace);
    _writeToFile(_formatForFile('FATAL', message, error: error, stackTrace: stackTrace));
  }

  // ==================== LOGS ESPECÍFICOS ====================

  /// Log de autenticação
  static void auth(
    String action, {
    bool success = true,
    String? error,
  }) {
    final status = success ? '✅ Sucesso' : '❌ Falha';
    final msg = '🔐 AUTH [$action] $status${error != null ? ' - $error' : ''}';
    if (success) {
      i(msg);
    } else {
      e(msg);
    }
  }

  /// Log de requisições HTTP
  static void request(String method, String url, {Map<String, dynamic>? data}) {
    final msg = '🌐 HTTP $method: $url${data != null ? '\n  Data: $data' : ''}';
    d(msg);
  }

  /// Log de respostas HTTP
  static void response(int statusCode, String url, {dynamic data}) {
    final emoji = statusCode >= 200 && statusCode < 300 ? '✅' : '❌';
    final msg = '$emoji HTTP $statusCode: $url${data != null ? '\n  Response: $data' : ''}';
    if (statusCode >= 200 && statusCode < 300) {
      d(msg);
    } else {
      e(msg);
    }
  }

  /// Log de chamadas à API Moloni
  static void moloniApi(
    String endpoint, {
    Map<String, dynamic>? data,
    dynamic response,
    dynamic error,
  }) {
    final buffer = StringBuffer('🔵 Moloni API: $endpoint');
    if (data != null) {
      buffer.write('\n  📤 Request: $data');
    }
    if (response != null) {
      buffer.write('\n  📥 Response: $response');
    }
    if (error != null) {
      e(buffer.toString(), error: error);
    } else {
      d(buffer.toString());
    }
  }

  /// Log de chamadas à API Loyalty
  static void loyaltyApi(
    String endpoint, {
    Map<String, dynamic>? data,
    dynamic response,
    dynamic error,
  }) {
    final buffer = StringBuffer('💳 Loyalty API: $endpoint');
    if (data != null) {
      buffer.write('\n  📤 Request: $data');
    }
    if (response != null) {
      buffer.write('\n  📥 Response: $response');
    }
    if (error != null) {
      e(buffer.toString(), error: error);
    } else {
      d(buffer.toString());
    }
  }

  /// Log de impressão
  static void printer(
    String action, {
    bool success = true,
    String? details,
    dynamic error,
  }) {
    final emoji = success ? '🖨️' : '❌';
    final msg = '$emoji PRINTER: $action${details != null ? ' - $details' : ''}';
    if (success) {
      i(msg);
    } else {
      e(msg, error: error);
    }
  }

  /// Log de gaveta
  static void cashDrawer(
    String action, {
    bool success = true,
    String? details,
    dynamic error,
  }) {
    final emoji = success ? '🗄️' : '❌';
    final msg = '$emoji DRAWER: $action${details != null ? ' - $details' : ''}';
    if (success) {
      i(msg);
    } else {
      e(msg, error: error);
    }
  }

  /// Log de checkout/venda
  static void checkout(
    String action, {
    double? amount,
    String? documentNumber,
    Map<String, dynamic>? details,
    dynamic error,
  }) {
    final buffer = StringBuffer('🛒 CHECKOUT: $action');
    if (amount != null) {
      buffer.write(' - €${amount.toStringAsFixed(2)}');
    }
    if (documentNumber != null) {
      buffer.write(' - Doc: $documentNumber');
    }
    if (details != null) {
      buffer.write('\n  Details: $details');
    }
    if (error != null) {
      e(buffer.toString(), error: error);
    } else {
      i(buffer.toString());
    }
  }

  /// Log de fidelização
  static void loyalty(
    String action, {
    String? cardNumber,
    int? points,
    double? discount,
    Map<String, dynamic>? details,
    dynamic error,
  }) {
    final buffer = StringBuffer('💳 LOYALTY: $action');
    if (cardNumber != null) {
      buffer.write(' - Card: $cardNumber');
    }
    if (points != null) {
      buffer.write(' - Points: $points');
    }
    if (discount != null) {
      buffer.write(' - Discount: €${discount.toStringAsFixed(2)}');
    }
    if (details != null) {
      buffer.write('\n  Details: $details');
    }
    if (error != null) {
      e(buffer.toString(), error: error);
    } else {
      i(buffer.toString());
    }
  }

  /// Log de performance
  static void performance(String operation, Duration duration) {
    final ms = duration.inMilliseconds;
    final emoji = ms < 100 ? '⚡' : ms < 500 ? '🟢' : ms < 1000 ? '🟡' : '🔴';
    d('$emoji PERF: $operation - ${ms}ms');
  }

  /// Log de rede/network
  static void network(
    String type, {
    required String method,
    required String url,
    int? statusCode,
    String? error,
  }) {
    switch (type) {
      case 'REQUEST':
        d('🌐 REQUEST [$method] $url');
        break;
      case 'RESPONSE':
        final emoji = (statusCode != null && statusCode >= 200 && statusCode < 300) ? '✅' : '❌';
        d('$emoji RESPONSE [$method] $url - Status: $statusCode');
        break;
      case 'ERROR':
        e('❌ NETWORK ERROR [$method] $url - $statusCode - $error');
        break;
      default:
        d('🌐 $type - $method $url');
    }
  }

  /// Log de operações de cache
  static void cache(
    String action,
    String key, {
    int count = 0,
    bool hit = false,
  }) {
    switch (action) {
      case 'GET':
        if (hit) {
          d('💾 CACHE [GET] $key - HIT (count: $count)');
        } else {
          d('💾 CACHE [GET] $key - MISS');
        }
        break;
      case 'SEARCH':
        d('🔍 CACHE [SEARCH] $key - Found: $count items');
        break;
      case 'SAVE':
        d('💾 CACHE [SAVE] $key (count: $count)');
        break;
      case 'DELETE':
        d('🗑️ CACHE [DELETE] $key');
        break;
      default:
        d('💾 CACHE [$action] $key - Count: $count');
    }
    _writeToFile(_formatForFile('CACHE', '[$action] $key - count: $count, hit: $hit'));
  }

  /// Log de navegação
  static void navigation(String from, String to) {
    d('🧭 NAV: $from → $to');
  }
}
