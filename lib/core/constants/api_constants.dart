/// Constantes da API Moloni
class ApiConstants {
  ApiConstants._(); // Não instanciável

  // ==================== MOLONI API ====================

  /// URL base padrão da API Moloni
  static const String defaultMoloniApiUrl = 'https://api.moloni.pt/v1';

  // ==================== AUTHENTICATION ====================

  /// Endpoint de autenticação (grant)
  static const String grantEndpoint = 'grant';

  /// Grant type: password
  static const String grantTypePassword = 'password';

  /// Grant type: refresh_token
  static const String grantTypeRefreshToken = 'refresh_token';

  // ==================== COMPANIES ====================

  /// Endpoint para obter todas as empresas
  static const String companiesGetAll = 'companies/getAll';

  // ==================== PRODUCTS ====================

  /// Endpoint para pesquisar produtos
  static const String productsSearch = 'products/search';

  /// Endpoint para obter produto por código de barras
  static const String productsGetByBarcode = 'products/getByBarcode';

  /// Endpoint para obter produto por referência
  static const String productsGetByReference = 'products/getByReference';

  /// Endpoint para obter todos os produtos
  static const String productsGetAll = 'products/getAll';

  // ==================== INVOICES ====================

  /// Endpoint para criar fatura
  static const String invoicesInsert = 'invoices/insert';

  /// Endpoint para obter fatura
  static const String invoicesGet = 'invoices/get';

  /// Endpoint para obter todas as faturas
  static const String invoicesGetAll = 'invoices/getAll';

  /// Endpoint para cancelar fatura
  static const String invoicesCancel = 'invoices/cancel';

  // ==================== STORAGE KEYS ====================

  /// Chave para guardar access token
  static const String keyAccessToken = 'auth_access_token';

  /// Chave para guardar refresh token
  static const String keyRefreshToken = 'auth_refresh_token';

  /// Chave para guardar tipo de token
  static const String keyTokenType = 'auth_token_type';

  /// Chave para guardar tempo de expiração
  static const String keyExpiresIn = 'auth_expires_in';

  /// Chave para guardar timestamp do token
  static const String keyTokenTimestamp = 'auth_token_timestamp';

  /// Chave para guardar ID do utilizador
  static const String keyUserId = 'auth_user_id';

  /// Chave para guardar username
  static const String keyUsername = 'auth_username';

  /// Chave para guardar API URL
  static const String keyApiUrl = 'settings_api_url';

  /// Chave para guardar API URL customizada
  static const String keyCustomApiUrl = 'settings_custom_api_url';

  /// Chave para guardar Client ID
  static const String keyClientId = 'settings_client_id';

  /// Chave para guardar Client Secret
  static const String keyClientSecret = 'settings_client_secret';

  /// Chave para guardar ID da empresa selecionada
  static const String keyCompanyId = 'company_selected_id';

  /// Chave para guardar nome da empresa selecionada
  static const String keyCompanyName = 'company_selected_name';

  /// Chave para guardar margem padrão
  static const String keyDefaultMargin = 'settings_default_margin';

  /// Chave para guardar MAC da impressora
  static const String keyPrinterMac = 'settings_printer_mac';

  // ==================== HIVE BOXES ====================

  /// Nome da box de produtos
  static const String boxProducts = 'products';

  /// Nome da box de empresas
  static const String boxCompanies = 'companies';

  /// Nome da box de faturas
  static const String boxInvoices = 'invoices';

  /// Nome da box de carrinho
  static const String boxCart = 'cart';

  /// Nome da box de configurações
  static const String boxSettings = 'settings';

  // ==================== TIMEOUTS ====================

  /// Timeout para conectar (em segundos)
  static const int connectTimeout = 30;

  /// Timeout para enviar (em segundos)
  static const int sendTimeout = 30;

  /// Timeout para receber (em segundos)
  static const int receiveTimeout = 30;

  // ==================== PAGINATION ====================

  /// Limite padrão de itens por página
  static const int defaultPageLimit = 50;

  /// Offset padrão
  static const int defaultPageOffset = 0;

  // ==================== ERROR CODES ====================

  /// Código: Não autorizado
  static const int errorUnauthorized = 401;

  /// Código: Proibido
  static const int errorForbidden = 403;

  /// Código: Não encontrado
  static const int errorNotFound = 404;

  /// Código: Erro do servidor
  static const int errorServerError = 500;

  /// Código: Serviço indisponível
  static const int errorServiceUnavailable = 503;

  // ==================== API PARAMETERS ====================

  /// Parâmetro: access token
  static const String paramAccessToken = 'access_token';

  /// Parâmetro: company ID
  static const String paramCompanyId = 'company_id';

  /// Parâmetro: mensagens de erro amigáveis
  static const String paramHumanErrors = 'human_errors';

  /// Parâmetro: JSON response
  static const String paramJson = 'json';

  // ==================== CONTENT TYPES ====================

  /// Content-Type: application/json
  static const String contentTypeJson = 'application/json';

  /// Content-Type: application/x-www-form-urlencoded
  static const String contentTypeFormUrlEncoded =
      'application/x-www-form-urlencoded';

  /// Content-Type: multipart/form-data
  static const String contentTypeMultipart = 'multipart/form-data';

  // ==================== HEADERS ====================

  /// Header: Authorization
  static const String headerAuthorization = 'Authorization';

  /// Header: Content-Type
  static const String headerContentType = 'Content-Type';

  /// Header: Accept
  static const String headerAccept = 'Accept';

  /// Prefixo: Bearer token
  static const String tokenPrefix = 'Bearer ';

  // ==================== PAGINATION DEFAULTS ====================

  /// Página padrão (começa em 0)
  static const int defaultPage = 0;

  /// Itens por página padrão
  static const int defaultPerPage = 50;

  /// Máximo de itens por página
  static const int maxPerPage = 1000;

  // ==================== CACHE DURATION ====================

  /// Duração do cache em minutos (30 min)
  static const int cacheDurationMinutes = 30;

  /// Duração de produto cache em horas (2 horas)
  static const int productCacheDurationHours = 2;

  /// Duração de empresa cache em dias (1 dia)
  static const int companyCacheDurationDays = 1;
}
