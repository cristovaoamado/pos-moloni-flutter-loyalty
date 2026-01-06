import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:pos_moloni_app/features/auth/presentation/screens/login_screen.dart';
import 'package:pos_moloni_app/features/barcode/presentation/providers/barcode_scanner_provider.dart';
import 'package:pos_moloni_app/features/cart/domain/entities/cart_item.dart';
import 'package:pos_moloni_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:pos_moloni_app/features/checkout/presentation/widgets/checkout_dialog.dart';
import 'package:pos_moloni_app/features/company/presentation/providers/company_data_provider.dart';
import 'package:pos_moloni_app/features/document_sets/presentation/providers/document_set_provider.dart';
import 'package:pos_moloni_app/features/printer/presentation/providers/printer_provider.dart';
import 'package:pos_moloni_app/features/products/domain/entities/product.dart';
import 'package:pos_moloni_app/features/products/presentation/providers/product_provider.dart';
import 'package:pos_moloni_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:pos_moloni_app/features/suspended_sales/presentation/providers/suspended_sales_provider.dart';
import 'package:pos_moloni_app/features/suspended_sales/presentation/widgets/suspended_sales_dialog.dart';
import 'package:pos_moloni_app/features/scale/services/scale_service.dart';

import 'package:pos_moloni_app/features/pos/presentation/models/pos_models.dart';
import 'package:pos_moloni_app/features/pos/presentation/widgets/product_search_panel.dart';
import 'package:pos_moloni_app/features/pos/presentation/widgets/receipt_panel.dart';
import 'package:pos_moloni_app/features/pos/presentation/widgets/item_options_dialog.dart';
import 'package:pos_moloni_app/features/pos/presentation/widgets/customer_search_dialog.dart';
import 'package:pos_moloni_app/features/favorites/presentation/screens/favorites_screen.dart';

// LOYALTY
import 'package:pos_moloni_app/features/loyalty/loyalty.dart';

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

  /// Estado da balança
  bool _scaleConnected = false;
  bool _scaleConnecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDocumentSets();
      _loadSuspendedSales();
      _initBarcodeScanner();
      _checkScaleConnection();
    });

    _scannerFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _scannerFocusNode.removeListener(_onFocusChange);
    _scannerFocusNode.dispose();
    super.dispose();
  }

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

  void _requestScannerFocus() {
    _scannerFocusNode.requestFocus();
    AppLogger.i('🔊 Scanner: Foco forçado pelo utilizador');
  }

  // ==================== BALANÇA ====================

  Future<void> _checkScaleConnection() async {
    final scaleService = ScaleService.instance;
    await scaleService.loadConfig();
    
    if (scaleService.config.serialPort.isEmpty) {
      setState(() => _scaleConnected = false);
      return;
    }

    // Tentar uma leitura para verificar conexão
    try {
      final reading = await scaleService.readWeight();
      setState(() => _scaleConnected = reading != null);
    } catch (e) {
      setState(() => _scaleConnected = false);
    }
  }

  Future<void> _connectScale() async {
    if (_scaleConnecting) return;

    setState(() => _scaleConnecting = true);

    try {
      final scaleService = ScaleService.instance;
      await scaleService.loadConfig();

      if (scaleService.config.serialPort.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Balança não configurada. Vá a Configurações → Balança'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() {
          _scaleConnected = false;
          _scaleConnecting = false;
        });
        return;
      }

      // Tentar ler peso para verificar conexão
      final reading = await scaleService.readWeight();

      if (reading != null) {
        setState(() => _scaleConnected = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Balança conectada: ${reading.weight.toStringAsFixed(3)} ${reading.unit}'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() => _scaleConnected = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Sem resposta da balança. Verifique a ligação e configuração.'),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Configurar',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _scaleConnected = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao conectar balança: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _scaleConnecting = false);
    }
  }

  void _initBarcodeScanner() {
    final scanner = ref.read(barcodeScannerProvider.notifier);

    scanner.onSingleProductFound = (product, {double? quantity}) {
      final qty = quantity ?? 1.0;
      final weightInfo =
          quantity != null ? ' (${quantity.toStringAsFixed(3)} kg)' : '';
      AppLogger.i(
          '🛒 Barcode: Adicionando ${product.name}$weightInfo ao carrinho',);

      ref
          .read(cartProvider.notifier)
          .addProduct(product.toEntity(), quantity: qty);
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

        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _requestScannerFocus();
        });
      }
    };

    scanner.onMultipleProductsFound = (products) {
      AppLogger.i(
          '🔍 Barcode: ${products.length} produtos encontrados - mostrar na grid',);

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

        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _requestScannerFocus();
        });
      }
    };

    scanner.startScanning();
    _requestScannerFocus();
    AppLogger.i('🔊 Barcode scanner inicializado no POS');
  }

  void _loadDocumentSets() {
    final docSetState = ref.read(documentSetProvider);
    if (docSetState.documentTypeOptions.isEmpty && !docSetState.isLoading) {
      ref.read(documentSetProvider.notifier).loadDocumentSets();
    }
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

    final unit = product.measureUnit?.toLowerCase() ?? 'un';
    if (unit != 'un' && unit != 'unidade') {
      final item = ref.read(cartProvider.notifier).getItem(product.id);
      if (item != null) {
        _showItemOptionsDialog(item, initialTab: 0);
      }
    } else {
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

    final groupedOptions =
        ref.read(documentSetProvider.notifier).groupedOptions;

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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8,),
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              child: Text(
                                entry.key.code,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              entry.key.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      ...entry.value.map((option) {
                        final isSelected =
                            docSetState.selectedOption?.uniqueId ==
                                option.uniqueId;
                        return ListTile(
                          leading: const SizedBox(width: 28),
                          title: Text(option.documentSet.name),
                          trailing: isSelected
                              ? Icon(Icons.check,
                                  color: Theme.of(context).colorScheme.primary,)
                              : null,
                          selected: isSelected,
                          onTap: () {
                            ref
                                .read(documentSetProvider.notifier)
                                .selectOption(option);
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

    final result = await showDialog<SuspendSaleResult>(
      context: context,
      builder: (context) => SuspendSaleDialog(
        itemCount: cart.itemCount,
        total: cart.total,
      ),
    );

    if (result == null) return;

    final selectedOption = ref.read(documentSetProvider).selectedOption;

    await ref.read(suspendedSalesProvider.notifier).suspendSale(
          items: cart.items,
          customer: _selectedCustomer,
          documentOption: selectedOption,
          note: result.note,
        );

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

    if (cart.isNotEmpty) {
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

    final restoredSale =
        await ref.read(suspendedSalesProvider.notifier).restoreSale(sale.id);

    if (restoredSale != null) {
      ref.read(cartProvider.notifier).clearCart();

      for (final item in restoredSale.items) {
        ref
            .read(cartProvider.notifier)
            .addProduct(item.product, quantity: item.quantity);
        if (item.discount > 0) {
          ref.read(cartProvider.notifier).applyDiscount(item.id, item.discount);
        }
        if (item.customPrice != null) {
          ref
              .read(cartProvider.notifier)
              .updatePrice(item.id, item.customPrice!);
        }
      }

      setState(() => _selectedCustomer = restoredSale.customer);

      if (restoredSale.documentOption != null) {
        ref
            .read(documentSetProvider.notifier)
            .selectOption(restoredSale.documentOption!);
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

    if (selectedOption == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um tipo de documento'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CheckoutDialog(
        documentTypeOption: selectedOption,
        customer: _selectedCustomer,
        items: cart.items,
        total: cart.total,
        globalDiscount: cart.globalDiscount,
        globalDiscountValue: cart.globalDiscountValue,
      ),
    );

    if (result == true) {
      ref.read(cartProvider.notifier).clearCart();
      setState(() => _selectedCustomer = Customer.consumidorFinal);
    }

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
              Text(result.success
                  ? 'Gaveta aberta'
                  : (result.error ?? 'Erro ao abrir gaveta'),),
            ],
          ),
          backgroundColor: result.success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

    // ==================== FAVORITOS ====================

  void _openFavoritesScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FavoritesScreen()),
    ).then((_) {
      if (mounted) _requestScannerFocus();
    });
  }


  // ==================== NAVEGAÇÃO PARA LOGIN ====================

  void _navigateToLogin() {
    ref.read(companyDataProvider.notifier).clearData();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _showSessionExpiredDialog() async {
    final authState = ref.read(authProvider);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.lock_clock, size: 48, color: Colors.orange),
        title: const Text('Sessão Expirada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              authState.error ??
                  'A sua sessão expirou. Por favor, faça login novamente.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Os dados do carrinho serão mantidos.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _navigateToLogin();
            },
            icon: const Icon(Icons.login),
            label: const Text('Fazer Login'),
          ),
        ],
      ),
    );
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    final docSetState = ref.watch(documentSetProvider);
    final suspendedState = ref.watch(suspendedSalesProvider);
    final companyDataState = ref.watch(companyDataProvider);
    final authState = ref.watch(authProvider);

    final isLoadingData = companyDataState.isLoading || authState.isRecovering;

    // ==================== LISTENER DE AUTENTICAÇÃO ====================
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.requiresLogin &&
          !next.isRecovering &&
          prev?.requiresLogin != true) {
        AppLogger.w('🔐 POS: Sessão expirada - encaminhando para login');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showSessionExpiredDialog();
        });
      }

      if (next.isRecovering && prev?.isRecovering != true) {
        AppLogger.i('🔄 POS: A recuperar sessão...');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('A renovar sessão...'),
                ],
              ),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }

      if (prev?.isRecovering == true &&
          !next.isRecovering &&
          next.isAuthenticated) {
        AppLogger.i('✅ POS: Sessão recuperada com sucesso');
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Sessão renovada'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });

    ref.listen<CompanyDataState>(companyDataProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        final errorLower = next.error!.toLowerCase();
        if (errorLower.contains('token') ||
            errorLower.contains('unauthorized') ||
            errorLower.contains('401') ||
            errorLower.contains('expirou') ||
            errorLower.contains('expired')) {
          AppLogger.w(
              '🔐 POS: Erro de autenticação detectado - tentando recuperar',);
          ref.read(authProvider.notifier).tryRecoverSession();
        }
      }
    });

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

        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _requestScannerFocus();
        });
      }
    });

    return KeyboardListener(
      focusNode: _scannerFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          final currentFocus = FocusScope.of(context).focusedChild;
          if (currentFocus == null || currentFocus == _scannerFocusNode) {
            _scannerFocusNode.requestFocus();
          }
        },
        child: Scaffold(
          appBar: _buildAppBar(
            isLoading: isLoadingData,
            isScannerActive: _scannerHasFocus,
          ),
          body: Row(
            children: [
              Expanded(
                flex: 7,
                child: ProductSearchPanel(
                  onProductTap: _onProductTap,
                  onSearchFocusLost: _requestScannerFocus,
                ),
              ),
              const VerticalDivider(width: 1),
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

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final now = DateTime.now();

    if (_lastKeyTime != null) {
      final elapsed = now.difference(_lastKeyTime!).inMilliseconds;
      if (elapsed > _maxKeyInterval) {
        _barcodeBuffer.clear();
      }
    }

    _lastKeyTime = now;

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _processBarcode();
      return;
    }

    final char = _getCharFromKey(event);
    if (char != null) {
      _barcodeBuffer.write(char);
    }
  }

  void _processBarcode() {
    final barcode = _barcodeBuffer.toString().trim();
    _barcodeBuffer.clear();

    if (barcode.length >= 3) {
      AppLogger.i('📦 Barcode detectado: $barcode');
      
      // LOYALTY: Verificar se é cartão de fidelização (prefixo 269)
      final loyaltyState = ref.read(loyaltyProvider);
      if (loyaltyState.isEnabled && loyaltyState.isLoyaltyCard(barcode)) {
        AppLogger.i('💳 Cartão fidelização detectado: $barcode');
        ref.read(loyaltyProvider.notifier).identifyCustomerByBarcode(barcode);
        return; // Não procurar como produto
      }
      
      ref.read(barcodeScannerProvider.notifier).processBarcode(barcode);
    }
  }

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

  bool _isValidBarcodeChar(String char) {
    if (char.length != 1) return false;
    final code = char.codeUnitAt(0);

    return (code >= 48 && code <= 57) || // 0-9
        (code >= 65 && code <= 90) || // A-Z
        (code >= 97 && code <= 122) || // a-z
        code == 45 || // -
        code == 46; // .
  }

  PreferredSizeWidget _buildAppBar(
      {bool isLoading = false, bool isScannerActive = false,}) {
    final user = ref.watch(currentUserProvider);

    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // LOGO
          Image.asset(
            'assets/img/logo.png',
            height: 40,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Text('Loja da Madalena');
            },
          ),
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
          const SizedBox(width: 16),
          // ═══════════════════════════════════════════════════════════════════
          // CHIP CARTÃO DE CLIENTE (junto ao logo)
          // ═══════════════════════════════════════════════════════════════════
          LoyaltyChipWidget(
            onTap: () => showLoyaltySearchDialog(context),
            onClear: () => ref.read(loyaltyProvider.notifier).clearCustomer(),
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      actions: [
        // ═══════════════════════════════════════════════════════════════════
        // CHIP DO SCANNER
        // ═══════════════════════════════════════════════════════════════════
        Tooltip(
          message: isScannerActive
              ? 'Scanner activo'
              : 'Scanner inactivo - clique para activar',
          child: InkWell(
            onTap: _requestScannerFocus,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
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
                  const Icon(
                    Icons.qr_code_scanner,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isScannerActive ? 'Scanner' : 'OFF',
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ═══════════════════════════════════════════════════════════════════
        // CHIP DA BALANÇA
        // ═══════════════════════════════════════════════════════════════════
        Tooltip(
          message: _scaleConnected
              ? 'Balança conectada'
              : 'Balança desconectada - clique para conectar',
          child: InkWell(
            onTap: _scaleConnected ? null : _connectScale,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _scaleConnected
                    ? Colors.teal.withOpacity(0.3)
                    : Colors.orange.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _scaleConnected ? Colors.teal : Colors.orange,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_scaleConnecting)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    Icon(
                      _scaleConnected ? Icons.scale : Icons.scale_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                  const SizedBox(width: 4),
                  Text(
                    _scaleConnected ? 'Balança' : 'OFF',
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),

        // BOTÃO FAVORITOS
        IconButton(
          icon: const Icon(Icons.star),
          onPressed: _openFavoritesScreen,
          tooltip: 'Gerir Favoritos',
        ),

        // Botão definições
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          tooltip: 'Configurações',
        ),

        // Botão recarregar dados
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: isLoading
              ? null
              : () {
                  ref.read(companyDataProvider.notifier).reloadCompanyData();
                },
          tooltip: 'Recarregar dados',
        ),

        // ═══════════════════════════════════════════════════════════════════
        // CHIP DO UTILIZADOR (apenas icon, estilo igual ao scanner ON)
        // ═══════════════════════════════════════════════════════════════════
        if (user != null)
          Tooltip(
            message: user.displayName,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.green,
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.person,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),

        // Botão logout
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
      ref.read(companyDataProvider.notifier).clearData();
      ref.read(authProvider.notifier).logout();
    }
  }
}
