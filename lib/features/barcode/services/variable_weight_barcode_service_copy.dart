// /// Serviço para processar códigos de barras de peso variável
// /// 
// /// Códigos de peso variável começam tipicamente com "2" e contêm:
// /// - Prefixo (1-2 dígitos): identifica como código de peso variável
// /// - Código do produto (5-6 dígitos): para pesquisar no Moloni
// /// - Peso ou Preço (5 dígitos): quantidade a adicionar ao carrinho
// /// - Check digit (1 dígito): validação
// /// 
// /// Formatos suportados:
// /// - Formato 13 dígitos (EAN-13): 2PPPPPWWWWWC ou 2PPPPPPWWWWC
// /// - Formato 12 dígitos (UPC-A): 2PPPPPWWWWC
// /// 
// /// Configuração flexível permite adaptar a diferentes balanças/sistemas
// library;

// class VariableWeightBarcodeConfig {
//   const VariableWeightBarcodeConfig({
//     this.prefixes = const ['2'],
//     this.productCodeLength = 5,
//     this.productCodeStart = 1,
//     this.weightLength = 5,
//     this.weightDecimals = 3,
//     this.isPrice = false,
//     this.priceDecimals = 2,
//   });

//   /// Prefixos que identificam códigos de peso variável (ex: ['2', '02', '20', '21', '22', '23', '24', '25', '26', '27', '28', '29'])
//   final List<String> prefixes;

//   /// Comprimento do código do produto (tipicamente 5 ou 6 dígitos)
//   final int productCodeLength;

//   /// Posição inicial do código do produto (após o prefixo)
//   final int productCodeStart;

//   /// Comprimento do campo de peso/preço (tipicamente 5 dígitos)
//   final int weightLength;

//   /// Casas decimais do peso (ex: 3 = 01234 -> 1.234 kg)
//   final int weightDecimals;

//   /// Se true, o campo contém preço em vez de peso
//   final bool isPrice;

//   /// Casas decimais do preço (ex: 2 = 01234 -> 12.34 €)
//   final int priceDecimals;

//   /// Configuração padrão portuguesa (balanças típicas)
//   /// Formato: 2PPPPPWWWWWC (13 dígitos)
//   /// - 2: Prefixo
//   /// - PPPPP: Código do produto (5 dígitos)
//   /// - WWWWW: Peso (5 dígitos, 3 decimais = gramas)
//   /// - C: Check digit
//   static const VariableWeightBarcodeConfig defaultPortugal = VariableWeightBarcodeConfig(
//     prefixes: ['2'],
//     productCodeLength: 5,
//     productCodeStart: 1,
//     weightLength: 5,
//     weightDecimals: 3,
//   );

//   /// Configuração alternativa com código de 6 dígitos
//   /// Formato: 2PPPPPPWWWWC (13 dígitos)
//   static const VariableWeightBarcodeConfig sixDigitProduct = VariableWeightBarcodeConfig(
//     prefixes: ['2'],
//     productCodeLength: 6,
//     productCodeStart: 1,
//     weightLength: 4,
//     weightDecimals: 3,
//   );

//   /// Configuração para preço variável (em vez de peso)
//   /// Formato: 2PPPPPVVVVVC (13 dígitos)
//   /// - VVVVV: Valor em cêntimos (5 dígitos, 2 decimais)
//   static const VariableWeightBarcodeConfig priceVariable = VariableWeightBarcodeConfig(
//     prefixes: ['2'],
//     productCodeLength: 5,
//     productCodeStart: 1,
//     weightLength: 5,
//     weightDecimals: 2,
//     isPrice: true,
//     priceDecimals: 2,
//   );

//   VariableWeightBarcodeConfig copyWith({
//     List<String>? prefixes,
//     int? productCodeLength,
//     int? productCodeStart,
//     int? weightLength,
//     int? weightDecimals,
//     bool? isPrice,
//     int? priceDecimals,
//   }) {
//     return VariableWeightBarcodeConfig(
//       prefixes: prefixes ?? this.prefixes,
//       productCodeLength: productCodeLength ?? this.productCodeLength,
//       productCodeStart: productCodeStart ?? this.productCodeStart,
//       weightLength: weightLength ?? this.weightLength,
//       weightDecimals: weightDecimals ?? this.weightDecimals,
//       isPrice: isPrice ?? this.isPrice,
//       priceDecimals: priceDecimals ?? this.priceDecimals,
//     );
//   }
// }

// /// Resultado do parsing de um código de peso variável
// class VariableWeightBarcodeResult {
//   const VariableWeightBarcodeResult({
//     required this.originalBarcode,
//     required this.productCode,
//     required this.productEan,
//     required this.weight,
//     this.price,
//     required this.isWeightBased,
//   });

//   /// Código de barras original completo
//   final String originalBarcode;

//   /// Código do produto extraído (5-6 dígitos)
//   final String productCode;

//   /// EAN para pesquisar no Moloni (código do produto com zeros ou prefixo)
//   final String productEan;

//   /// Peso em kg (ex: 1.234)
//   final double weight;

//   /// Preço (se o código contém preço em vez de peso)
//   final double? price;

//   /// True se é peso, False se é preço
//   final bool isWeightBased;

//   /// Quantidade a usar (peso ou 1 se for preço)
//   double get quantity => isWeightBased ? weight : 1.0;

//   @override
//   String toString() {
//     if (isWeightBased) {
//       return 'VariableWeightBarcode(product: $productCode, ean: $productEan, weight: ${weight.toStringAsFixed(3)} kg)';
//     } else {
//       return 'VariableWeightBarcode(product: $productCode, ean: $productEan, price: ${price?.toStringAsFixed(2)} €)';
//     }
//   }
// }

// /// Serviço para processar códigos de barras de peso variável
// class VariableWeightBarcodeService {
//   VariableWeightBarcodeService({
//     this.config = VariableWeightBarcodeConfig.defaultPortugal,
//   });

//   final VariableWeightBarcodeConfig config;

//   /// Verifica se um código de barras é de peso variável
//   bool isVariableWeightBarcode(String barcode) {
//     if (barcode.isEmpty) return false;
    
//     // Verificar se começa com algum dos prefixos configurados
//     for (final prefix in config.prefixes) {
//       if (barcode.startsWith(prefix)) {
//         // Verificar comprimento mínimo esperado
//         final minLength = prefix.length + config.productCodeLength + config.weightLength;
//         if (barcode.length >= minLength) {
//           return true;
//         }
//       }
//     }
//     return false;
//   }

//   /// Processa um código de barras de peso variável
//   /// Retorna null se não for um código válido de peso variável
//   VariableWeightBarcodeResult? parse(String barcode) {
//     if (!isVariableWeightBarcode(barcode)) {
//       return null;
//     }

//     try {
//       // Encontrar o prefixo usado
//       String usedPrefix = '';
//       for (final prefix in config.prefixes) {
//         if (barcode.startsWith(prefix)) {
//           usedPrefix = prefix;
//           break;
//         }
//       }

//       // Extrair código do produto
//       final productStart = usedPrefix.length + config.productCodeStart - 1;
//       final productEnd = productStart + config.productCodeLength;
      
//       if (productEnd > barcode.length) {
//         return null;
//       }
      
//       final productCode = barcode.substring(productStart, productEnd);

//       // Extrair peso/preço
//       final weightStart = productEnd;
//       final weightEnd = weightStart + config.weightLength;
      
//       if (weightEnd > barcode.length) {
//         return null;
//       }
      
//       final weightStr = barcode.substring(weightStart, weightEnd);
//       final weightInt = int.tryParse(weightStr);
      
//       if (weightInt == null) {
//         return null;
//       }

//       // Calcular peso/preço com casas decimais
//       double weight;
//       double? price;
      
//       if (config.isPrice) {
//         // É preço
//         price = weightInt / _pow10(config.priceDecimals);
//         weight = 1.0; // Quantidade fixa de 1
//       } else {
//         // É peso
//         weight = weightInt / _pow10(config.weightDecimals);
//         price = null;
//       }

//       // Gerar EAN para pesquisa no Moloni
//       // Opções comuns:
//       // 1. Usar só o código do produto com zeros: "00000PPPPP"
//       // 2. Usar prefixo + código + zeros: "2PPPPP00000C"
//       // 3. Usar o código como está
//       final productEan = _generateSearchEan(usedPrefix, productCode, barcode.length);

//       return VariableWeightBarcodeResult(
//         originalBarcode: barcode,
//         productCode: productCode,
//         productEan: productEan,
//         weight: weight,
//         price: price,
//         isWeightBased: !config.isPrice,
//       );
//     } catch (e) {
//       return null;
//     }
//   }

//   /// Gera o EAN para pesquisar o produto no Moloni
//   /// 
//   /// Estratégia: Criar um EAN "base" substituindo o peso por zeros
//   /// Assim o Moloni pode ter o produto cadastrado com peso zero
//   /// Ex: 2123450150089 -> 2123450000000 (com check digit recalculado)
//   String _generateSearchEan(String prefix, String productCode, int originalLength) {
//     // Criar EAN base: prefixo + código do produto + zeros
//     final zerosNeeded = originalLength - prefix.length - productCode.length - 1; // -1 para check digit
//     final baseEan = '$prefix$productCode${'0' * zerosNeeded}';
    
//     // Calcular check digit EAN-13
//     if (baseEan.length == 12) {
//       final checkDigit = _calculateEan13CheckDigit(baseEan);
//       return '$baseEan$checkDigit';
//     }
    
//     // Se não for EAN-13, retornar como está
//     return baseEan;
//   }

//   /// Calcula o check digit para EAN-13
//   int _calculateEan13CheckDigit(String ean12) {
//     if (ean12.length != 12) return 0;
    
//     int sum = 0;
//     for (int i = 0; i < 12; i++) {
//       final digit = int.parse(ean12[i]);
//       sum += digit * (i.isEven ? 1 : 3);
//     }
    
//     final checkDigit = (10 - (sum % 10)) % 10;
//     return checkDigit;
//   }

//   /// Potência de 10
//   double _pow10(int exp) {
//     double result = 1;
//     for (int i = 0; i < exp; i++) {
//       result *= 10;
//     }
//     return result;
//   }

//   /// Lista de EANs possíveis para pesquisar o produto
//   /// Útil quando não sabemos exactamente como o produto está cadastrado
//   List<String> generatePossibleEans(String barcode) {
//     final result = parse(barcode);
//     if (result == null) return [barcode];

//     final eans = <String>{};
    
//     // 1. EAN base (com peso zerado)
//     eans.add(result.productEan);
    
//     // 2. Só o código do produto (sem prefixo nem peso)
//     eans.add(result.productCode);
    
//     // 3. Código do produto com zeros à esquerda (para completar EAN-13)
//     final paddedCode = result.productCode.padLeft(12, '0');
//     final checkDigit = _calculateEan13CheckDigit(paddedCode);
//     eans.add('$paddedCode$checkDigit');
    
//     // 4. Código original (caso o produto esteja cadastrado com um peso específico)
//     eans.add(barcode);

//     return eans.toList();
//   }
// }

// /// Extensão para facilitar uso no CartProvider
// extension VariableWeightBarcodeExtension on String {
//   /// Verifica se este código de barras é de peso variável
//   bool isVariableWeightBarcode([VariableWeightBarcodeConfig? config]) {
//     final service = VariableWeightBarcodeService(
//       config: config ?? VariableWeightBarcodeConfig.defaultPortugal,
//     );
//     return service.isVariableWeightBarcode(this);
//   }

//   /// Processa este código de barras como peso variável
//   VariableWeightBarcodeResult? parseAsVariableWeight([VariableWeightBarcodeConfig? config]) {
//     final service = VariableWeightBarcodeService(
//       config: config ?? VariableWeightBarcodeConfig.defaultPortugal,
//     );
//     return service.parse(this);
//   }
// }
