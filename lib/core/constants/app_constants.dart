/// Constantes gerais da aplicação
class AppConstants {
  // Info da App
  static const String appName = 'POS Moloni';
  static const String appVersion = '1.0.0';
  
  // Orientação
  static const bool forceHorizontal = true;
  
  // Debounce para pesquisas
  static const Duration searchDebounce = Duration(milliseconds: 500);
  
  // Mínimo de caracteres para pesquisa
  static const int minSearchLength = 3;
  
  // Configurações de UI
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  
  static const double defaultBorderRadius = 8.0;
  static const double cardBorderRadius = 12.0;
  
  // Animações
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration fastAnimationDuration = Duration(milliseconds: 150);
  static const Duration slowAnimationDuration = Duration(milliseconds: 500);
  
  // Tamanhos de imagem
  static const double productImageSize = 60.0;
  static const double productImageSizeLarge = 120.0;
  
  // Carrinho
  static const double minQuantity = 0.001;
  static const double maxQuantity = 9999.99;
  static const double defaultQuantity = 1.0;
  
  static const double minDiscount = 0.0;
  static const double maxDiscount = 100.0;
  
  // Vendas
  static const int defaultInvoiceExpirationDays = 30;
  static const int defaultPaymentMethodId = 1; // Numerário
  
  // Formatos
  static const String dateFormat = 'dd/MM/yyyy';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';
  static const String timeFormat = 'HH:mm';
  static const String currencySymbol = '€';
  static const String currencyFormat = '#,##0.00';
  
  // Impressora
  static const int printerPaperWidth = 48; // caracteres por linha
  static const String printerLineSeparator = '--------------------------------';
  static const String printerDoubleLine = '================================';
  
  // Validação
  static const int minPasswordLength = 6;
  static const int maxProductNameLength = 100;
  static const int maxDescriptionLength = 500;
  
  // Regex patterns
  static const String emailPattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
  static const String phonePattern = r'^\+?[\d\s()-]{9,}$';
  static const String vatPattern = r'^\d{9}$'; // NIF português
  static const String eanPattern = r'^\d{8}$|^\d{13}$'; // EAN-8 ou EAN-13
  
  // Mensagens padrão
  static const String errorGeneric = 'Ocorreu um erro. Tente novamente.';
  static const String errorNetwork = 'Sem conexão à internet.';
  static const String errorTimeout = 'Tempo de conexão esgotado.';
  static const String errorUnauthorized = 'Sessão expirada. Faça login novamente.';
  
  static const String successSaved = 'Guardado com sucesso!';
  static const String successDeleted = 'Eliminado com sucesso!';
  static const String successUpdated = 'Atualizado com sucesso!';
  
  // Placeholders
  static const String placeholderSearch = 'Pesquisar...';
  static const String placeholderNoData = 'Sem dados disponíveis';
  static const String placeholderNoResults = 'Nenhum resultado encontrado';
  static const String placeholderLoading = 'A carregar...';
  
  // Permissões
  static const String permissionCamera = 'Câmera';
  static const String permissionBluetooth = 'Bluetooth';
  static const String permissionLocation = 'Localização';
  
  // Features flags (para ativar/desativar funcionalidades)
  static const bool enableBarcodeScan = true;
  static const bool enablePrinter = true;
  static const bool enableOfflineMode = true;
  static const bool enableCustomApi = true;
  
  // Limites
  static const int maxCachedProducts = 500;
  static const int maxCachedInvoices = 100;
  static const int maxCartItems = 100;
}