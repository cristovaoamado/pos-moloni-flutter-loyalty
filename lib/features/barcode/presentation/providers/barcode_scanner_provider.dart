import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/barcode/services/barcode_scanner_service.dart';
import 'package:pos_moloni_app/features/barcode/services/variable_weight_barcode_service.dart';
import 'package:pos_moloni_app/features/products/data/datasources/product_remote_datasource.dart';
import 'package:pos_moloni_app/features/products/data/models/product_model.dart';
import 'package:pos_moloni_app/features/products/presentation/providers/product_provider.dart';

/// Resultado de uma leitura de código de barras
enum BarcodeScanResult {
  /// Um único produto encontrado - adicionado ao carrinho
  singleProduct,
  /// Múltiplos produtos encontrados - mostrados na grid
  multipleProducts,
  /// Nenhum produto encontrado
  notFound,
  /// Erro durante a pesquisa
  error,
}

/// Estado do scanner
class BarcodeScannerState {
  const BarcodeScannerState({
    this.isScanning = false,
    this.lastBarcode,
    this.lastResult,
    this.foundProducts = const [],
    this.variableWeightResult,
    this.error,
  });

  final bool isScanning;
  final String? lastBarcode;
  final BarcodeScanResult? lastResult;
  final List<ProductModel> foundProducts;
  /// Resultado do parsing de código de peso variável (se aplicável)
  final VariableWeightBarcodeResult? variableWeightResult;
  final String? error;

  BarcodeScannerState copyWith({
    bool? isScanning,
    String? lastBarcode,
    BarcodeScanResult? lastResult,
    List<ProductModel>? foundProducts,
    VariableWeightBarcodeResult? variableWeightResult,
    bool clearVariableWeight = false,
    String? error,
  }) {
    return BarcodeScannerState(
      isScanning: isScanning ?? this.isScanning,
      lastBarcode: lastBarcode ?? this.lastBarcode,
      lastResult: lastResult ?? this.lastResult,
      foundProducts: foundProducts ?? this.foundProducts,
      variableWeightResult: clearVariableWeight ? null : (variableWeightResult ?? this.variableWeightResult),
      error: error,
    );
  }
}

/// Provider do serviço de barcode scanner
final barcodeScannerServiceProvider = Provider<BarcodeScannerService>((ref) {
  final service = BarcodeScannerService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider do serviço de peso variável
final variableWeightServiceProvider = Provider<VariableWeightBarcodeService>((ref) {
  return VariableWeightBarcodeService(
    config: VariableWeightBarcodeConfig.defaultPortugal,
  );
});

/// Provider principal do scanner
final barcodeScannerProvider = StateNotifierProvider<BarcodeScannerNotifier, BarcodeScannerState>((ref) {
  final service = ref.watch(barcodeScannerServiceProvider);
  final productDataSource = ref.watch(productDataSourceProvider);
  final variableWeightService = ref.watch(variableWeightServiceProvider);
  return BarcodeScannerNotifier(
    service: service,
    productDataSource: productDataSource,
    variableWeightService: variableWeightService,
    ref: ref,
  );
});

/// Notifier do scanner
class BarcodeScannerNotifier extends StateNotifier<BarcodeScannerState> {
  BarcodeScannerNotifier({
    required this.service,
    required this.productDataSource,
    required this.variableWeightService,
    required this.ref,
  }) : super(const BarcodeScannerState());

  final BarcodeScannerService service;
  final ProductRemoteDataSource productDataSource;
  final VariableWeightBarcodeService variableWeightService;
  final Ref ref;

  /// Callback para quando um produto único é encontrado
  /// Recebe o produto e opcionalmente a quantidade (para peso variável)
  void Function(ProductModel product, {double? quantity})? onSingleProductFound;

  /// Callback para quando múltiplos produtos são encontrados
  /// Deve ser definido pelo widget pai para actualizar a grid
  void Function(List<ProductModel> products)? onMultipleProductsFound;

  /// Inicia a escuta de códigos de barras
  void startScanning() {
    if (state.isScanning) return;

    service.startListening(_onBarcodeScanned);
    state = state.copyWith(isScanning: true);
    
    AppLogger.i('🔊 Barcode scanner activado');
  }

  /// Para a escuta de códigos de barras
  void stopScanning() {
    service.stopListening();
    state = state.copyWith(isScanning: false);
    
    AppLogger.i('🔇 Barcode scanner desactivado');
  }

  /// Callback quando um código de barras é detectado
  Future<void> _onBarcodeScanned(String barcode) async {
    AppLogger.i('📦 A processar código de barras: $barcode');
    
    state = state.copyWith(
      lastBarcode: barcode,
      error: null,
      clearVariableWeight: true,
    );

    try {
      // 1. Verificar se é código de peso variável
      final variableWeightResult = variableWeightService.parse(barcode);
      
      if (variableWeightResult != null) {
        AppLogger.i('⚖️ Código de peso variável detectado:');
        AppLogger.i('   - Código produto: ${variableWeightResult.productCode}');
        AppLogger.i('   - EAN pesquisa: ${variableWeightResult.productEan}');
        AppLogger.i('   - Peso: ${variableWeightResult.weight.toStringAsFixed(3)} kg');
        
        // Guardar resultado de peso variável no estado
        state = state.copyWith(variableWeightResult: variableWeightResult);
        
        // Pesquisar produto usando os EANs possíveis
        await _searchVariableWeightProduct(variableWeightResult);
        return;
      }

      // 2. Código normal - pesquisar pelo EAN completo
      final dataSource = productDataSource as ProductRemoteDataSourceImpl;
      final products = await dataSource.searchByBarcode(barcode);

      if (products.isEmpty) {
        // Nenhum produto encontrado - tentar pesquisa por referência
        AppLogger.d('📦 Nenhum produto por EAN, a tentar por referência...');
        final byRef = await dataSource.getProductByReference(barcode);
        
        if (byRef != null) {
          _handleSingleProduct(byRef);
        } else {
          _handleNotFound(barcode);
        }
      } else if (products.length == 1) {
        // Um único produto - adicionar ao carrinho
        _handleSingleProduct(products.first);
      } else {
        // Múltiplos produtos - mostrar na grid
        _handleMultipleProducts(products);
      }
    } catch (e) {
      AppLogger.e('Erro ao processar código de barras', error: e);
      state = state.copyWith(
        lastResult: BarcodeScanResult.error,
        error: e.toString(),
      );
    }
  }

  /// Pesquisa produto de peso variável tentando múltiplos EANs
  Future<void> _searchVariableWeightProduct(VariableWeightBarcodeResult vwResult) async {
    final dataSource = productDataSource as ProductRemoteDataSourceImpl;
    
    // Gerar lista de EANs possíveis para pesquisar
    final possibleEans = variableWeightService.generatePossibleEans(vwResult.originalBarcode);
    
    AppLogger.d('🔍 A pesquisar produto com EANs: $possibleEans');
    
    // Tentar cada EAN possível
    for (final ean in possibleEans) {
      AppLogger.d('   Tentando EAN: $ean');
      
      final products = await dataSource.searchByBarcode(ean);
      
      if (products.isNotEmpty) {
        if (products.length == 1) {
          AppLogger.i('✅ Produto encontrado com EAN: $ean');
          _handleSingleProduct(products.first, quantity: vwResult.quantity);
          return;
        } else {
          // Múltiplos produtos - mostrar na grid (o utilizador escolhe)
          AppLogger.i('⚠️ ${products.length} produtos encontrados para EAN: $ean');
          _handleMultipleProducts(products);
          return;
        }
      }
    }
    
    // Tentar também por referência usando o código do produto
    AppLogger.d('   Tentando por referência: ${vwResult.productCode}');
    final byRef = await dataSource.getProductByReference(vwResult.productCode);
    
    if (byRef != null) {
      AppLogger.i('✅ Produto encontrado por referência');
      _handleSingleProduct(byRef, quantity: vwResult.quantity);
      return;
    }
    
    // Não encontrado
    _handleNotFound(vwResult.originalBarcode);
  }

  /// Trata o caso de um único produto encontrado
  void _handleSingleProduct(ProductModel product, {double? quantity}) {
    final weightInfo = quantity != null ? ' (${quantity.toStringAsFixed(3)} kg)' : '';
    AppLogger.i('✅ Produto único encontrado: ${product.name}$weightInfo');
    
    state = state.copyWith(
      lastResult: BarcodeScanResult.singleProduct,
      foundProducts: [product],
    );

    // Notificar o callback se definido (com quantidade se for peso variável)
    onSingleProductFound?.call(product, quantity: quantity);
  }

  /// Trata o caso de múltiplos produtos encontrados
  void _handleMultipleProducts(List<ProductModel> products) {
    AppLogger.i('⚠️ ${products.length} produtos encontrados - mostrar na grid');
    
    state = state.copyWith(
      lastResult: BarcodeScanResult.multipleProducts,
      foundProducts: products,
    );

    // Notificar o callback se definido
    onMultipleProductsFound?.call(products);
  }

  /// Trata o caso de nenhum produto encontrado
  void _handleNotFound(String barcode) {
    AppLogger.w('❌ Produto não encontrado para: $barcode');
    
    state = state.copyWith(
      lastResult: BarcodeScanResult.notFound,
      foundProducts: [],
      error: 'Produto não encontrado: $barcode',
    );
  }

  /// Processa um código de barras manualmente (para input direto)
  Future<void> processBarcode(String barcode) async {
    await _onBarcodeScanned(barcode);
  }

  /// Limpa o último resultado
  void clearResult() {
    state = state.copyWith(
      lastResult: null,
      foundProducts: [],
      clearVariableWeight: true,
      error: null,
    );
  }

  /// Obtém a quantidade do último código de peso variável (se existir)
  double? get lastVariableWeightQuantity => state.variableWeightResult?.quantity;
}
