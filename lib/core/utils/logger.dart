import 'package:logger/logger.dart';

/// Logger centralizado para toda a aplicação
class AppLogger {
  static final _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 5,
      lineLength: 100,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  // ==================== LEVEL INFO ====================

  /// Log informativo (ℹ️)
  static void i(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  // ==================== LEVEL DEBUG ====================

  /// Log de debug (🐛)
  static void d(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  // ==================== LEVEL WARNING ====================

  /// Log de aviso (⚠️)
  static void w(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  // ==================== LEVEL ERROR ====================

  /// Log de erro (❌)
  static void e(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  // ==================== LEVEL FATAL ====================

  /// Log crítico (🔥)
  static void f(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  // ==================== AUTHENTICATION ====================

  /// Log de autenticação
  static void auth(
    String action, {
    bool success = true,
    String? error,
  }) {
    final status = success ? '✅ Sucesso' : '❌ Falha';
    final msg = '🔐 AUTH [$action] $status';
    if (error != null) {
      e('$msg - Error: $error');
    } else if (success) {
      i(msg);
    } else {
      w(msg);
    }
  }

  // ==================== NETWORK ====================

  /// Log de requisições HTTP
  static void network(
    String type, {
    required String method,
    required String url,
    int? statusCode,
    String? error,
  }) {
    switch (type) {
      case 'REQUEST':
        i('🌐 REQUEST [$method] $url');
        break;
      case 'RESPONSE':
        i('✅ RESPONSE [$method] $url - Status: $statusCode');
        break;
      case 'ERROR':
        e('❌ NETWORK ERROR [$method] $url - $statusCode - $error');
        break;
      default:
        d('🌐 $type - $method $url');
    }
  }

  // ==================== API MOLONI ====================

  /// Log de chamadas à API Moloni
  static void moloniApi(
    String endpoint, {
    Map<String, dynamic>? data,
  }) {
    if (data != null && data.isNotEmpty) {
      i('📡 MOLONI API [$endpoint]\nData: $data');
    } else {
      i('📡 MOLONI API [$endpoint]');
    }
  }

  // ==================== CACHE ====================

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
          i('💾 CACHE [GET] $key - HIT (count: $count)');
        } else {
          d('💾 CACHE [GET] $key - MISS');
        }
        break;
      case 'SEARCH':
        i('🔍 CACHE [SEARCH] $key - Found: $count items');
        break;
      case 'SAVE':
        i('💾 CACHE [SAVE] $key (count: $count)');
        break;
      case 'DELETE':
        i('🗑️  CACHE [DELETE] $key');
        break;
      default:
        d('💾 CACHE [$action] $key - Count: $count');
    }
  }

  // ==================== BUSINESS LOGIC ====================

  /// Log de adicionar item ao carrinho
  static void addToCart(
    String productName,
    int quantity, {
    double price = 0,
  }) {
    i('🛒 CART [ADD] $productName x$quantity ${price > 0 ? '($price€)' : ''}');
  }

  /// Log de remover item do carrinho
  static void removeFromCart(String productName) {
    i('🛒 CART [REMOVE] $productName');
  }

  /// Log de checkout/pagamento
  static void checkout(
    double total, {
    String method = 'unknown',
  }) {
    i('💳 CHECKOUT - Total: $total€ - Method: $method');
  }

  /// Log de criação de fatura
  static void invoiceCreated(
    int invoiceId, {
    double total = 0,
  }) {
    i('📄 INVOICE [CREATED] ID: $invoiceId - Total: $total€');
  }

  /// Log de cancelamento de fatura
  static void invoiceCancelled(int invoiceId) {
    w('📄 INVOICE [CANCELLED] ID: $invoiceId');
  }

  // ==================== DATABASE ====================

  /// Log de operações em base de dados
  static void database(
    String operation, {
    required String table,
    int? count,
    String? error,
  }) {
    if (error != null) {
      e('🗄️  DATABASE [$operation] $table - Error: $error');
    } else {
      final countStr = count != null ? ' (count: $count)' : '';
      i('🗄️  DATABASE [$operation] $table$countStr');
    }
  }

  // ==================== UI ====================

  /// Log de navegação entre telas
  static void navigation(String fromScreen, String toScreen) {
    i('🔀 NAVIGATION $fromScreen → $toScreen');
  }

  /// Log de estado da UI
  static void uiState(String screen, String state) {
    d('🎨 UI [$screen] State: $state');
  }

  /// Log de validação de formulário
  static void formValidation(String form, {required bool isValid}) {
    if (isValid) {
      i('✅ FORM [$form] - Valid');
    } else {
      w('⚠️  FORM [$form] - Invalid');
    }
  }

  // ==================== PERFORMANCE ====================

  /// Log de performance/timing
  static void performance(
    String operation,
    Duration duration,
  ) {
    final ms = duration.inMilliseconds;
    final emoji = ms < 100
        ? '⚡'
        : ms < 500
            ? '✅'
            : ms < 1000
                ? '⚠️'
                : '🐢';
    i('$emoji PERFORMANCE [$operation] ${ms}ms');
  }

  /// Log de início de operação (para timing)
  static void startOperation(String operation) {
    d('▶️  START [$operation]');
  }

  /// Log de fim de operação
  static void endOperation(String operation) {
    d('⏹️  END [$operation]');
  }

  // ==================== FEATURE SPECIFIC ====================

  /// Log de varredura de código de barras
  static void barcodeScanned(String barcode, {String? productName}) {
    final product = productName != null ? ' - $productName' : '';
    i('📦 BARCODE [SCANNED] $barcode$product');
  }

  /// Log de impressão de recibo
  static void receiptPrinted(int invoiceId, {bool success = true}) {
    if (success) {
      i('🖨️  RECEIPT [PRINTED] Invoice: $invoiceId');
    } else {
      e('🖨️  RECEIPT [FAILED] Invoice: $invoiceId');
    }
  }

  /// Log de sincronização com servidor
  static void sync(String feature, {bool success = true}) {
    if (success) {
      i('🔄 SYNC [$feature] - Success');
    } else {
      w('🔄 SYNC [$feature] - Failed');
    }
  }

  /// Log de verificação de conexão
  static void connectivity(bool isConnected) {
    if (isConnected) {
      i('📡 CONNECTIVITY - Online');
    } else {
      w('📡 CONNECTIVITY - Offline');
    }
  }

  // ==================== CONFIGURATION ====================

  /// Log de configuração da aplicação
  static void config(String key, String value) {
    d('⚙️  CONFIG [$key] = $value');
  }

  /// Log de inicialização
  static void init(String module) {
    i('🚀 INIT [$module]');
  }

  /// Log de finalização
  static void shutdown(String module) {
    i('🛑 SHUTDOWN [$module]');
  }

  // ==================== UTILITY ====================

  /// Log genérico com emoji custom
  static void custom(
    String emoji,
    String category,
    String message,
  ) {
    i('$emoji [$category] $message');
  }

  /// Log de separador (para organizar logs)
  static void separator() {
    d('═' * 50);
  }

  /// Log de secção
  static void section(String title) {
    separator();
    i('📌 $title');
    separator();
  }
}
