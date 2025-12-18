/// Serviço para processar códigos de barras de peso variável
/// 
/// Códigos de peso variável começam tipicamente com "2" e contêm:
/// - Prefixo (1-2 dígitos): identifica como código de peso variável
/// - Código do produto (5-6 dígitos): para pesquisar no Moloni
/// - Peso ou Preço (5 dígitos): quantidade a adicionar ao carrinho
/// - Check digit (1 dígito): validação
/// 
/// Formatos suportados:
/// - Formato 13 dígitos (EAN-13): 2PPPPPWWWWWC ou 2PPPPPPWWWWC
/// - Formato 12 dígitos (UPC-A): 2PPPPPWWWWC
/// 
/// Configuração flexível permite adaptar a diferentes balanças/sistemas
library;

class VariableWeightBarcodeConfig {
  const VariableWeightBarcodeConfig({
    this.prefixes = const ['2'],
    this.productCodeLength = 5,
    this.productCodeStart = 1,
    this.weightLength = 5,
    this.weightDecimals = 3,
    this.isPrice = false,
    this.priceDecimals = 2,
  });

  /// Prefixos que identificam códigos de peso variável (ex: ['2', '02', '20', '21', '22', '23', '24', '25', '26', '27', '28', '29'])
  final List<String> prefixes;

  /// Comprimento do código do produto (tipicamente 5 ou 6 dígitos)
  final int productCodeLength;

  /// Posição inicial do código do produto (após o prefixo)
  final int productCodeStart;

  /// Comprimento do campo de peso/preço (tipicamente 5 dígitos)
  final int weightLength;

  /// Casas decimais do peso (ex: 3 = 01234 -> 1.234 kg)
  final int weightDecimals;

  /// Se true, o campo contém preço em vez de peso
  final bool isPrice;

  /// Casas decimais do preço (ex: 2 = 01234 -> 12.34 €)
  final int priceDecimals;

  /// Configuração padrão portuguesa (balanças típicas)
  /// Formato: 2PPPPPWWWWWC (13 dígitos)
  /// - 2: Prefixo
  /// - PPPPP: Código do produto (5 dígitos)
  /// - WWWWW: Peso (5 dígitos, 3 decimais = gramas)
  /// - C: Check digit
  static const VariableWeightBarcodeConfig defaultPortugal = VariableWeightBarcodeConfig(
    prefixes: ['2'],
    productCodeLength: 5,
    productCodeStart: 1,
    weightLength: 5,
    weightDecimals: 3,
  );

  /// Configuração alternativa com código de 6 dígitos
  /// Formato: 2PPPPPPWWWWC (13 dígitos)
  static const VariableWeightBarcodeConfig sixDigitProduct = VariableWeightBarcodeConfig(
    prefixes: ['2'],
    productCodeLength: 6,
    productCodeStart: 1,
    weightLength: 4,
    weightDecimals: 3,
  );

  /// Configuração para preço variável (em vez de peso)
  /// Formato: 2PPPPPVVVVVC (13 dígitos)
  /// - VVVVV: Valor em cêntimos (5 dígitos, 2 decimais)
  static const VariableWeightBarcodeConfig priceVariable = VariableWeightBarcodeConfig(
    prefixes: ['2'],
    productCodeLength: 5,
    productCodeStart: 1,
    weightLength: 5,
    weightDecimals: 2,
    isPrice: true,
    priceDecimals: 2,
  );

  VariableWeightBarcodeConfig copyWith({
    List<String>? prefixes,
    int? productCodeLength,
    int? productCodeStart,
    int? weightLength,
    int? weightDecimals,
    bool? isPrice,
    int? priceDecimals,
  }) {
    return VariableWeightBarcodeConfig(
      prefixes: prefixes ?? this.prefixes,
      productCodeLength: productCodeLength ?? this.productCodeLength,
      productCodeStart: productCodeStart ?? this.productCodeStart,
      weightLength: weightLength ?? this.weightLength,
      weightDecimals: weightDecimals ?? this.weightDecimals,
      isPrice: isPrice ?? this.isPrice,
      priceDecimals: priceDecimals ?? this.priceDecimals,
    );
  }
}

/// Resultado do parsing de um código de peso variável
class VariableWeightBarcodeResult {
  const VariableWeightBarcodeResult({
    required this.originalBarcode,
    required this.productCode,
    required this.weight,
    this.price,
    required this.isWeightBased,
  });

  /// Código de barras original completo
  final String originalBarcode;

  /// Código base do produto (usar como EAN no Moloni)
  final String productCode;

  /// Peso em kg (ex: 1.234)
  final double weight;

  /// Preço (se o código contém preço em vez de peso)
  final double? price;

  /// True se é peso, False se é preço
  final bool isWeightBased;

  /// Quantidade a usar no Moloni
  double get quantity => isWeightBased ? weight : 1.0;

  @override
  String toString() {
    return isWeightBased
        ? 'VariableWeightBarcode(product: $productCode, weight: ${weight.toStringAsFixed(3)} kg)'
        : 'VariableWeightBarcode(product: $productCode, price: ${price?.toStringAsFixed(2)} €)';
  }
}

/// Serviço para processar códigos de barras de peso variável
class VariableWeightBarcodeService {
  VariableWeightBarcodeService({
    this.config = VariableWeightBarcodeConfig.defaultPortugal,
  });

  final VariableWeightBarcodeConfig config;

  /// Verifica se um código de barras é de peso variável
  bool isVariableWeightBarcode(String barcode) {
    if (barcode.isEmpty) return false;

    for (final prefix in config.prefixes) {
      if (barcode.startsWith(prefix)) {
        final minLength =
            prefix.length + config.productCodeLength + config.weightLength;
        return barcode.length >= minLength;
      }
    }
    return false;
  }

  /// Processa um código de barras de peso variável
  VariableWeightBarcodeResult? parse(String barcode) {
    if (!isVariableWeightBarcode(barcode)) return null;

    try {
      final prefix = config.prefixes.firstWhere(barcode.startsWith);

      // Código do produto
      final productStart = prefix.length + config.productCodeStart - 1;
      final productEnd = productStart + config.productCodeLength;
      if (productEnd > barcode.length) return null;

      final productCode = barcode.substring(productStart, productEnd);

      // Peso / preço
      final valueStart = productEnd;
      final valueEnd = valueStart + config.weightLength;
      if (valueEnd > barcode.length) return null;

      final valueRaw = int.tryParse(barcode.substring(valueStart, valueEnd));
      if (valueRaw == null) return null;

      double weight;
      double? price;

      if (config.isPrice) {
        price = valueRaw / _pow10(config.priceDecimals);
        weight = 1.0;
      } else {
        weight = valueRaw / _pow10(config.weightDecimals);
        price = null;
      }

      return VariableWeightBarcodeResult(
        originalBarcode: barcode,
        productCode: productCode,
        weight: weight,
        price: price,
        isWeightBased: !config.isPrice,
      );
    } catch (_) {
      return null;
    }
  }

  double _pow10(int exp) {
    double result = 1;
    for (int i = 0; i < exp; i++) {
      result *= 10;
    }
    return result;
  }
}

/// Extensão para facilitar uso no CartProvider
extension VariableWeightBarcodeExtension on String {
  bool isVariableWeightBarcode([VariableWeightBarcodeConfig? config]) {
    final service = VariableWeightBarcodeService(
      config: config ?? VariableWeightBarcodeConfig.defaultPortugal,
    );
    return service.isVariableWeightBarcode(this);
  }

  VariableWeightBarcodeResult? parseAsVariableWeight(
      [VariableWeightBarcodeConfig? config,]) {
    final service = VariableWeightBarcodeService(
      config: config ?? VariableWeightBarcodeConfig.defaultPortugal,
    );
    return service.parse(this);
  }
}
