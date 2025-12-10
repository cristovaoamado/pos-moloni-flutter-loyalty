import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/constants/app_constants.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:pos_moloni_app/features/barcode/presentation/providers/barcode_scanner_provider.dart';
import 'package:pos_moloni_app/features/cart/domain/entities/cart_item.dart';
import 'package:pos_moloni_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:pos_moloni_app/features/checkout/presentation/widgets/checkout_dialog.dart';
import 'package:pos_moloni_app/features/company/presentation/providers/company_data_provider.dart';
import 'package:pos_moloni_app/features/company/presentation/providers/company_provider.dart';
import 'package:pos_moloni_app/features/document_sets/presentation/providers/document_set_provider.dart';
import 'package:pos_moloni_app/features/printer/presentation/providers/printer_provider.dart';
import 'package:pos_moloni_app/features/products/domain/entities/product.dart';
import 'package:pos_moloni_app/features/products/presentation/providers/product_provider.dart';
import 'package:pos_moloni_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:pos_moloni_app/features/suspended_sales/presentation/providers/suspended_sales_provider.dart';
import 'package:pos_moloni_app/features/suspended_sales/presentation/widgets/suspended_sales_dialog.dart';

import 'package:pos_moloni_app/features/pos/presentation/models/pos_models.dart';
import 'package:pos_moloni_app/features/pos/presentation/widgets/product_search_panel.dart';
import 'package:pos_moloni_app/features/pos/presentation/widgets/receipt_panel.dart';
import 'package:pos_moloni_app/features/pos/presentation/widgets/item_options_dialog.dart';
import 'package:pos_moloni_app/features/pos/presentation/widgets/customer_search_dialog.dart';

/// Tela Principal do POS
class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  Customer _selectedCustomer = Customer.consumidorFinal;
  
  /// FocusNode para capturar eventos do barcode scanner
  final FocusNode _scannerFocusNode = FocusNode();
  
  /// Buffer para acumular caracteres do scanner
  final StringBuffer _barcodeBuffer = StringBuffer();
  
  /// Timestamp da última tecla
  DateTime? _lastKeyTime;
  
  /// Tempo máximo entre teclas do scanner (ms)
  static const int _maxKeyInterval = 100;
  
  /// Estado do foco do scanner (para UI reactiva)
  bool _scannerHasFocus = false;

  @override
  void initState() {
    super.initState();
    // Carregar vendas suspensas ao iniciar
    // NOTA: Séries de documentos e métodos de pagamento são carregados
    // pelo company_data_provider quando a empresa é selecionada
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSuspendedSales();
      _initBarcodeScanner();
    });
    
    // Escutar mudanças de foco
    _scannerFocusNode.addListener(_onFocusChange);
  }
  
  @override
  void dispose() {
    _scannerFocusNode.removeListener(_onFocusChange);
    _scannerFocusNode.dispose();
    super.dispose();
  }
  
  /// Callback quando o foco muda
  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _scannerHasFocus = _scannerFocusNode.hasFocus;
      });
      
      if (_scannerFocusNode.hasFocus) {
        AppLogger.d('🔊 Scanner: Foco recuperado');
      } else {
        AppLogger.d('🔇 Scanner: Foco perdido');
      }
    }
  }
  
  /// Força o foco no scanner
  void _requestScannerFocus() {
    _scannerFocusNode.requestFocus();
    AppLogger.i('🔊 Scanner: Foco forçado pelo utilizador');
  }
  
  /// Inicializa o barcode scanner
  void _initBarcodeScanner() {
    // Configurar callbacks do scanner
    final scanner = ref.read(barcodeScannerProvider.notifier);
    
    scanner.onSingleProductFound = (product, {double? quantity}) {
      // Produto único - adicionar ao carrinho com quantidade (peso variável) ou 1
      final qty = quantity ?? 1.0;
      final weightInfo = quantity != null ? ' (${quantity.toStringAsFixed(3)} kg)' : '';
      AppLogger.i('🛒 Barcode: Adicionando ${product.name}$weightInfo ao carrinho');
      
      // Adicionar ao carrinho com a quantidade especificada
      ref.read(cartProvider.notifier).addProduct(product.toEntity(), quantity: qty);
      
      // Mostrar produto em destaque (não na grid)
      ref.read(productProvider.notifier).setScannedProduct(product);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    quantity != null 
                      ? '${product.name} - ${quantity.toStringAsFixed(3)} kg'
                      : '${product.name} adicionado',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Recuperar foco após adicionar produto
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _requestScannerFocus();
        });
      }
    };
    
    scanner.onMultipleProductsFound = (products) {
      // Múltiplos produtos - mostrar na grid de pesquisa (NÃO adicionar ao carrinho)
      AppLogger.i('🔍 Barcode: ${products.length} produtos encontrados - mostrar na grid');
      
      // Actualizar a pesquisa com os produtos encontrados
      ref.read(productProvider.notifier).setBarcodeResults(products);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info, color: Colors.white),
                const SizedBox(width: 8),
                Text('${products.length} produtos encontrados - selecione um'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Recuperar foco após mostrar resultados
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _requestScannerFocus();
        });
      }
    };
    
    // Iniciar escuta e pedir foco
    scanner.startScanning();
    _requestScannerFocus();
    AppLogger.i('🔊 Barcode scanner inicializado no POS');
  }

  void _loadSuspendedSales() {
    final docOptions = ref.read(documentSetProvider).documentTypeOptions;
    ref.read(suspendedSalesProvider.notifier).loadPersistentSales(
      documentOptions: docOptions,
    );
  }

  // ==================== AÇÕES DE PRODUTO ====================

  void _onProductTap(Product product) {
    ref.read(cartProvider.notifier).addProduct(product);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} adicionado'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
      ),
    );

    // Se não for unidade, abrir diálogo de quantidade
    final unit = product.measureUnit?.toLowerCase() ?? 'un';
    if (unit != 'un' && unit != 'unidade') {
      final item = ref.read(cartProvider.notifier).getItem(product.id);
      if (item != null) {
        _showItemOptionsDialog(item, initialTab: 0);
      }
    } else {
      // Recuperar foco do scanner após adicionar produto
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _requestScannerFocus();
      });
    }
  }

  // ==================== AÇÕES DO CARRINHO ====================

  void _showItemOptionsDialog(CartItem item, {int initialTab = 0}) {
    showDialog(
      context: context,
      builder: (context) => ItemOptionsDialog(
        item: item,
        initialTab: initialTab,
        onQuantityChanged: (qty) {
          ref.read(cartProvider.notifier).updateQuantity(item.id, qty);
        },
        onDiscountChanged: (discount) {
          ref.read(cartProvider.notifier).applyDiscount(item.id, discount);
        },
        onPriceChanged: (price) {
          ref.read(cartProvider.notifier).updatePrice(item.id, price);
        },
        onRemove: () {
          ref.read(cartProvider.notifier).removeItem(item.id);
        },
      ),
    ).then((_) {
      // Recuperar foco do scanner quando o diálogo fecha
      if (mounted) _requestScannerFocus();
    });
  }

  // ==================== TIPO DE DOCUMENTO ====================

  void _showDocumentTypeSelector() {
    final docSetState = ref.read(documentSetProvider);
    
    if (docSetState.isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A carregar tipos de documento...')),
      );
      return;
    }

    if (docSetState.documentTypeOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum tipo de documento disponível')),
      );
      return;
    }

    final groupedOptions = ref.read(documentSetProvider.notifier).groupedOptions;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Tipo de Documento',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  for (final entry in groupedOptions.entries) ...[
                    if (entry.value.isNotEmpty) ...[
                      // Header do tipo de documento
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              child: Text(
                                entry.key.code,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              entry.key.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      // Opções (séries) para este tipo
                      ...entry.value.map((option) {
                        final isSelected = docSetState.selectedOption?.uniqueId == option.uniqueId;
                        return ListTile(
                          leading: const SizedBox(width: 28), // Indentação
                          title: Text(option.documentSet.name),
                          trailing: isSelected
                              ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                              : null,
                          selected: isSelected,
                          onTap: () {
                            ref.read(documentSetProvider.notifier).selectOption(option);
                            Navigator.pop(context);
                          },
                        );
                      }),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      if (mounted) _requestScannerFocus();
    });
  }

  // ==================== CLIENTES ====================

  void _showCustomerSearch() {
    showDialog(
      context: context,
      builder: (context) => CustomerSearchDialog(
        onCustomerSelected: (customer) {
          setState(() => _selectedCustomer = customer);
        },
      ),
    ).then((_) {
      if (mounted) _requestScannerFocus();
    });
  }

  // ==================== VENDAS SUSPENSAS ====================

  void _showSuspendedSales() {
    showDialog(
      context: context,
      builder: (context) => SuspendedSalesDialog(
        onRestore: _restoreSuspendedSale,
      ),
    ).then((_) {
      if (mounted) _requestScannerFocus();
    });
  }

  Future<void> _suspendCurrentSale() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    // Mostrar diálogo com opções
    final result = await showDialog<SuspendSaleResult>(
      context: context,
      builder: (context) => SuspendSaleDialog(
        itemCount: cart.itemCount,
        total: cart.total,
      ),
    );

    if (result == null) return;

    final selectedOption = ref.read(documentSetProvider).selectedOption;

    // Suspender a venda
    await ref.read(suspendedSalesProvider.notifier).suspendSale(
      items: cart.items,
      customer: _selectedCustomer,
      documentOption: selectedOption,
      note: result.note,
    );

    // Limpar carrinho
    ref.read(cartProvider.notifier).clearCart();
    setState(() => _selectedCustomer = Customer.consumidorFinal);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Venda suspensa'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _restoreSuspendedSale(SuspendedSale sale) async {
    final cart = ref.read(cartProvider);

    // Se carrinho não está vazio, pedir confirmação
    if (!cart.isEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restaurar Venda'),
          content: const Text(
            'O carrinho atual será substituído pela venda suspensa.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Substituir'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    // Restaurar a venda (remove do provider)
    final restoredSale = await ref.read(suspendedSalesProvider.notifier)
        .restoreSale(sale.id);

    if (restoredSale != null) {
      // Limpar carrinho atual
      ref.read(cartProvider.notifier).clearCart();

      // Adicionar items da venda suspensa
      for (final item in restoredSale.items) {
        ref.read(cartProvider.notifier).addProduct(item.product, quantity: item.quantity);
        if (item.discount > 0) {
          ref.read(cartProvider.notifier).applyDiscount(item.id, item.discount);
        }
        if (item.customPrice != null) {
          ref.read(cartProvider.notifier).updatePrice(item.id, item.customPrice!);
        }
      }

      // Restaurar cliente e tipo de documento
      setState(() => _selectedCustomer = restoredSale.customer);
      
      if (restoredSale.documentOption != null) {
        ref.read(documentSetProvider.notifier).selectOption(restoredSale.documentOption!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Venda restaurada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // ==================== FINALIZAR / CANCELAR ====================

    Future<void> _finalizeSale() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    final selectedOption = ref.read(documentSetProvider).selectedOption;

    // Verificar se tem tipo de documento selecionado
    if (selectedOption == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um tipo de documento'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Abrir diálogo de checkout - PASSAR DESCONTOS
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CheckoutDialog(
        documentTypeOption: selectedOption,
        customer: _selectedCustomer,
        items: cart.items,
        total: cart.total,
        globalDiscount: cart.globalDiscount,           // NOVO
        globalDiscountValue: cart.globalDiscountValue, // NOVO
      ),
    );

    // Se checkout foi bem sucedido, limpar carrinho
    if (result == true) {
      ref.read(cartProvider.notifier).clearCart();
      setState(() => _selectedCustomer = Customer.consumidorFinal);
    }
    
    // Recuperar foco do scanner
    if (mounted) _requestScannerFocus();
  }

  void _cancelSale() {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Venda'),
        content: const Text('Deseja cancelar a venda atual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Não'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clearCart();
              setState(() => _selectedCustomer = Customer.consumidorFinal);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sim, Cancelar'),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) _requestScannerFocus();
    });
  }

  /// Abre a gaveta do dinheiro
  Future<void> _openCashDrawer() async {
    final result = await ref.read(printerProvider.notifier).openCashDrawer();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.error,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(result.success ? 'Gaveta aberta' : (result.error ?? 'Erro ao abrir gaveta')),
            ],
          ),
          backgroundColor: result.success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    final selectedCompany = ref.watch(companyProvider).selectedCompany;
    final docSetState = ref.watch(documentSetProvider);
    final suspendedState = ref.watch(suspendedSalesProvider);
    final companyDataState = ref.watch(companyDataProvider);
    final scannerState = ref.watch(barcodeScannerProvider);

    // Se está a carregar dados da empresa, mostrar loading no AppBar
    final isLoadingData = companyDataState.isLoading;
    
    // Escutar erros do scanner
    ref.listen<BarcodeScannerState>(barcodeScannerProvider, (prev, next) {
      if (next.lastResult == BarcodeScanResult.notFound && next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(next.error!)),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Recuperar foco após erro
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _requestScannerFocus();
        });
      }
    });

    // Envolver com KeyboardListener para capturar eventos do scanner
    return KeyboardListener(
      focusNode: _scannerFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        // Re-focar quando toca fora de campos de texto
        behavior: HitTestBehavior.translucent,
        onTap: () {
          final currentFocus = FocusScope.of(context).focusedChild;
          if (currentFocus == null || currentFocus == _scannerFocusNode) {
            _scannerFocusNode.requestFocus();
          }
        },
        child: Scaffold(
          appBar: _buildAppBar(
            selectedCompany?.name ?? AppConstants.appName,
            isLoading: isLoadingData,
            isScannerActive: _scannerHasFocus, // Usar estado real do foco
          ),
          body: Row(
            children: [
              // Painel de Pesquisa (esquerda - ~65%)
              Expanded(
                flex: 7,
                child: ProductSearchPanel(
                  onProductTap: _onProductTap,
                  onSearchFocusLost: _requestScannerFocus,
                ),
              ),
              const VerticalDivider(width: 1),
              // Talão de Venda (direita - ~35%)
              Expanded(
                flex: 4,
                child: ReceiptPanel(
                  selectedDocumentOption: docSetState.selectedOption,
                  selectedCustomer: _selectedCustomer,
                  suspendedSalesCount: suspendedState.sales.length,
                  isLoadingDocTypes: docSetState.isLoading,
                  onDocumentTypeTap: _showDocumentTypeSelector,
                  onCustomerSearchTap: _showCustomerSearch,
                  onSuspendedSalesTap: _showSuspendedSales,
                  onItemTap: _showItemOptionsDialog,
                  onCancelTap: _cancelSale,
                  onSuspendTap: _suspendCurrentSale,
                  onFinalizeTap: _finalizeSale,
                  onOpenDrawerTap: _openCashDrawer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // ==================== BARCODE SCANNER ====================
  
  /// Processa eventos de teclado do barcode scanner
  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    
    final now = DateTime.now();
    
    // Se passou muito tempo desde a última tecla, limpar buffer
    if (_lastKeyTime != null) {
      final elapsed = now.difference(_lastKeyTime!).inMilliseconds;
      if (elapsed > _maxKeyInterval) {
        _barcodeBuffer.clear();
      }
    }
    
    _lastKeyTime = now;
    
    // Verificar se é Enter (fim do código de barras)
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _processBarcode();
      return;
    }
    
    // Adicionar caractere ao buffer
    final char = _getCharFromKey(event);
    if (char != null) {
      _barcodeBuffer.write(char);
    }
  }
  
  /// Processa o buffer como código de barras
  void _processBarcode() {
    final barcode = _barcodeBuffer.toString().trim();
    _barcodeBuffer.clear();
    
    if (barcode.length >= 3) {
      AppLogger.i('📦 Barcode detectado: $barcode');
      ref.read(barcodeScannerProvider.notifier).processBarcode(barcode);
    }
  }
  
  /// Extrai o caractere de um KeyEvent
  String? _getCharFromKey(KeyDownEvent event) {
    final char = event.character;
    if (char != null && char.isNotEmpty && _isValidBarcodeChar(char)) {
      return char;
    }
    
    final keyLabel = event.logicalKey.keyLabel;
    if (keyLabel.length == 1 && _isValidBarcodeChar(keyLabel)) {
      return keyLabel;
    }
    
    return null;
  }
  
  /// Verifica se o caractere é válido para código de barras
  bool _isValidBarcodeChar(String char) {
    if (char.length != 1) return false;
    final code = char.codeUnitAt(0);
    
    // Aceitar dígitos, letras, hífen e ponto
    return (code >= 48 && code <= 57) ||  // 0-9
           (code >= 65 && code <= 90) ||  // A-Z
           (code >= 97 && code <= 122) || // a-z
           code == 45 ||                   // -
           code == 46;                     // .
  }

  PreferredSizeWidget _buildAppBar(String title, {bool isLoading = false, bool isScannerActive = false}) {
    final user = ref.watch(currentUserProvider);

    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title),
          if (isLoading) ...[
            const SizedBox(width: 12),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      actions: [
        // Indicador do scanner (clicável para recuperar foco)
        Tooltip(
          message: isScannerActive 
              ? 'Scanner activo - clique para verificar'
              : 'Scanner inactivo - clique para activar',
          child: InkWell(
            onTap: _requestScannerFocus,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isScannerActive 
                    ? Colors.green.withOpacity(0.3)
                    : Colors.red.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isScannerActive ? Colors.green : Colors.red, 
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isScannerActive 
                        ? Icons.qr_code_scanner 
                        : Icons.qr_code_scanner,
                    size: 16, 
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isScannerActive ? 'Scanner' : 'Scanner OFF',
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                  if (!isScannerActive) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.touch_app, size: 12, color: Colors.white70),
                  ],
                ],
              ),
            ),
          ),
        ),
        // Botão recarregar dados
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: isLoading ? null : () {
            ref.read(companyDataProvider.notifier).reloadCompanyData();
          },
          tooltip: 'Recarregar dados',
        ),
        if (user != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person, size: 16),
                    const SizedBox(width: 6),
                    Text(user.displayName, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          tooltip: 'Configurações',
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: _confirmLogout,
          tooltip: 'Sair',
        ),
      ],
    );
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja realmente sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      // Limpar dados da empresa antes de logout
      ref.read(companyDataProvider.notifier).clearData();
      ref.read(authProvider.notifier).logout();
    }
  }
}
