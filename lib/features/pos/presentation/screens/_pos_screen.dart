// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import 'package:pos_moloni_app/core/utils/logger.dart';
// import 'package:pos_moloni_app/features/auth/presentation/providers/auth_provider.dart';
// import 'package:pos_moloni_app/features/auth/presentation/screens/login_screen.dart';
// import 'package:pos_moloni_app/features/barcode/presentation/providers/barcode_scanner_provider.dart';
// import 'package:pos_moloni_app/features/cart/domain/entities/cart_item.dart';
// import 'package:pos_moloni_app/features/cart/presentation/providers/cart_provider.dart';
// import 'package:pos_moloni_app/features/checkout/presentation/widgets/checkout_dialog.dart';
// import 'package:pos_moloni_app/features/company/presentation/providers/company_data_provider.dart';
// import 'package:pos_moloni_app/features/document_sets/presentation/providers/document_set_provider.dart';
// import 'package:pos_moloni_app/features/favorites/presentation/screens/favorites_screen.dart';
// import 'package:pos_moloni_app/features/printer/presentation/providers/printer_provider.dart';
// import 'package:pos_moloni_app/features/products/domain/entities/product.dart';
// import 'package:pos_moloni_app/features/products/presentation/providers/product_provider.dart';
// import 'package:pos_moloni_app/features/settings/presentation/screens/settings_screen.dart';
// import 'package:pos_moloni_app/features/suspended_sales/presentation/providers/suspended_sales_provider.dart';
// import 'package:pos_moloni_app/features/suspended_sales/presentation/widgets/suspended_sales_dialog.dart';

// import 'package:pos_moloni_app/features/pos/presentation/models/pos_models.dart';
// import 'package:pos_moloni_app/features/pos/presentation/widgets/product_search_panel.dart';
// import 'package:pos_moloni_app/features/pos/presentation/widgets/receipt_panel.dart';
// import 'package:pos_moloni_app/features/pos/presentation/widgets/item_options_dialog.dart';
// import 'package:pos_moloni_app/features/pos/presentation/widgets/customer_search_dialog.dart';

// /// Tela Principal do POS
// class PosScreen extends ConsumerStatefulWidget {
//   const PosScreen({super.key});

//   @override
//   ConsumerState<PosScreen> createState() => _PosScreenState();
// }

// class _PosScreenState extends ConsumerState<PosScreen> {
//   Customer _selectedCustomer = Customer.consumidorFinal;

//   /// FocusNode para capturar eventos do barcode scanner
//   final FocusNode _scannerFocusNode = FocusNode();

//   /// Buffer para acumular caracteres do scanner
//   final StringBuffer _barcodeBuffer = StringBuffer();

//   /// Timestamp da última tecla
//   DateTime? _lastKeyTime;

//   /// Tempo máximo entre teclas do scanner (ms)
//   static const int _maxKeyInterval = 100;

//   /// Estado do foco do scanner (para UI reactiva)
//   bool _scannerHasFocus = false;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _loadSuspendedSales();
//       _initBarcodeScanner();
//     });

//     _scannerFocusNode.addListener(_onFocusChange);
//   }

//   @override
//   void dispose() {
//     _scannerFocusNode.removeListener(_onFocusChange);
//     _scannerFocusNode.dispose();
//     super.dispose();
//   }

//   void _onFocusChange() {
//     if (mounted) {
//       setState(() {
//         _scannerHasFocus = _scannerFocusNode.hasFocus;
//       });

//       if (_scannerFocusNode.hasFocus) {
//         AppLogger.d('🔊 Scanner: Foco recuperado');
//       } else {
//         AppLogger.d('🔇 Scanner: Foco perdido');
//       }
//     }
//   }

//   void _requestScannerFocus() {
//     _scannerFocusNode.requestFocus();
//     AppLogger.i('🔊 Scanner: Foco forçado pelo utilizador');
//   }

//   void _initBarcodeScanner() {
//     final scanner = ref.read(barcodeScannerProvider.notifier);

//     scanner.onSingleProductFound = (product, {double? quantity}) {
//       final qty = quantity ?? 1.0;
//       final weightInfo =
//           quantity != null ? ' (${quantity.toStringAsFixed(3)} kg)' : '';
//       AppLogger.i(
//           '🛒 Barcode: Adicionando ${product.name}$weightInfo ao carrinho',);

//       ref
//           .read(cartProvider.notifier)
//           .addProduct(product.toEntity(), quantity: qty);
//       ref.read(productProvider.notifier).setScannedProduct(product);

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Row(
//               children: [
//                 const Icon(Icons.check_circle, color: Colors.white),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     quantity != null
//                         ? '${product.name} - ${quantity.toStringAsFixed(3)} kg'
//                         : '${product.name} adicionado',
//                   ),
//                 ),
//               ],
//             ),
//             backgroundColor: Colors.green,
//             duration: const Duration(seconds: 1),
//             behavior: SnackBarBehavior.floating,
//           ),
//         );

//         Future.delayed(const Duration(milliseconds: 100), () {
//           if (mounted) _requestScannerFocus();
//         });
//       }
//     };

//     scanner.onMultipleProductsFound = (products) {
//       AppLogger.i(
//           '🔍 Barcode: ${products.length} produtos encontrados - mostrar na grid',);

//       ref.read(productProvider.notifier).setBarcodeResults(products);

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Row(
//               children: [
//                 const Icon(Icons.info, color: Colors.white),
//                 const SizedBox(width: 8),
//                 Text('${products.length} produtos encontrados - selecione um'),
//               ],
//             ),
//             backgroundColor: Colors.orange,
//             duration: const Duration(seconds: 2),
//             behavior: SnackBarBehavior.floating,
//           ),
//         );

//         Future.delayed(const Duration(milliseconds: 100), () {
//           if (mounted) _requestScannerFocus();
//         });
//       }
//     };

//     scanner.startScanning();
//     _requestScannerFocus();
//     AppLogger.i('🔊 Barcode scanner inicializado no POS');
//   }

//   void _loadSuspendedSales() {
//     final docOptions = ref.read(documentSetProvider).documentTypeOptions;
//     ref.read(suspendedSalesProvider.notifier).loadPersistentSales(
//           documentOptions: docOptions,
//         );
//   }

//   // ==================== AÇÕES DE PRODUTO ====================

//   void _onProductTap(Product product) {
//     ref.read(cartProvider.notifier).addProduct(product);

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('${product.name} adicionado'),
//         duration: const Duration(seconds: 1),
//         behavior: SnackBarBehavior.floating,
//         margin: const EdgeInsets.all(8),
//       ),
//     );

//     final unit = product.measureUnit?.toLowerCase() ?? 'un';
//     if (unit != 'un' && unit != 'unidade') {
//       final item = ref.read(cartProvider.notifier).getItem(product.id);
//       if (item != null) {
//         _showItemOptionsDialog(item, initialTab: 0);
//       }
//     } else {
//       Future.delayed(const Duration(milliseconds: 100), () {
//         if (mounted) _requestScannerFocus();
//       });
//     }
//   }

//   // ==================== AÇÕES DO CARRINHO ====================

//   void _showItemOptionsDialog(CartItem item, {int initialTab = 0}) {
//     showDialog(
//       context: context,
//       builder: (context) => ItemOptionsDialog(
//         item: item,
//         initialTab: initialTab,
//         onQuantityChanged: (qty) {
//           ref.read(cartProvider.notifier).updateQuantity(item.id, qty);
//         },
//         onDiscountChanged: (discount) {
//           ref.read(cartProvider.notifier).applyDiscount(item.id, discount);
//         },
//         onPriceChanged: (price) {
//           ref.read(cartProvider.notifier).updatePrice(item.id, price);
//         },
//         onRemove: () {
//           ref.read(cartProvider.notifier).removeItem(item.id);
//         },
//       ),
//     ).then((_) {
//       if (mounted) _requestScannerFocus();
//     });
//   }

//   // ==================== TIPO DE DOCUMENTO ====================

//   void _showDocumentTypeSelector() {
//     final docSetState = ref.read(documentSetProvider);

//     if (docSetState.isLoading) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('A carregar tipos de documento...')),
//       );
//       return;
//     }

//     if (docSetState.documentTypeOptions.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Nenhum tipo de documento disponível')),
//       );
//       return;
//     }

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Tipo de Documento'),
//         content: SizedBox(
//           width: 300,
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: docSetState.documentTypeOptions.map((option) {
//               final isSelected =
//                   docSetState.selectedDocumentType == option.type;
//               return ListTile(
//                 leading: Icon(
//                   isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
//                   color: isSelected ? Theme.of(context).colorScheme.primary : null,
//                 ),
//                 title: Text(option.label),
//                 subtitle: Text(option.description),
//                 selected: isSelected,
//                 onTap: () {
//                   ref.read(documentSetProvider.notifier).selectDocumentType(option.type);
//                   Navigator.pop(context);
//                 },
//               );
//             }).toList(),
//           ),
//         ),
//       ),
//     ).then((_) {
//       if (mounted) _requestScannerFocus();
//     });
//   }

//   // ==================== CLIENTE ====================

//   void _showCustomerSearch() {
//     showDialog(
//       context: context,
//       builder: (context) => CustomerSearchDialog(
//         onCustomerSelected: (customer) {
//           setState(() {
//             _selectedCustomer = customer;
//           });
//         },
//       ),
//     ).then((_) {
//       if (mounted) _requestScannerFocus();
//     });
//   }

//   // ==================== VENDAS SUSPENSAS ====================

//   void _showSuspendedSales() {
//     showDialog(
//       context: context,
//       builder: (context) => SuspendedSalesDialog(
//         onSaleRestored: (sale) {
//           ref.read(cartProvider.notifier).restoreFromSuspended(sale);
//           setState(() {
//             _selectedCustomer = sale.customer;
//           });
//           if (sale.documentType != null) {
//             ref.read(documentSetProvider.notifier).selectDocumentType(sale.documentType!);
//           }
//         },
//       ),
//     ).then((_) {
//       if (mounted) _requestScannerFocus();
//     });
//   }

//   void _suspendCurrentSale() async {
//     final cart = ref.read(cartProvider);
//     if (cart.items.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Carrinho vazio')),
//       );
//       return;
//     }

//     final docType = ref.read(documentSetProvider).selectedDocumentType;

//     final nameController = TextEditingController();
//     final name = await showDialog<String>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Suspender Venda'),
//         content: TextField(
//           controller: nameController,
//           decoration: const InputDecoration(
//             labelText: 'Nome (opcional)',
//             hintText: 'Ex: Mesa 5, João...',
//           ),
//           autofocus: true,
//           onSubmitted: (value) => Navigator.pop(context, value),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancelar'),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.pop(context, nameController.text),
//             child: const Text('Suspender'),
//           ),
//         ],
//       ),
//     );

//     if (name == null) return;

//     await ref.read(suspendedSalesProvider.notifier).suspendSale(
//           cart: cart,
//           customer: _selectedCustomer,
//           documentType: docType,
//           name: name.isEmpty ? null : name,
//         );

//     ref.read(cartProvider.notifier).clearCart();
//     setState(() {
//       _selectedCustomer = Customer.consumidorFinal;
//     });

//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Venda suspensa'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       _requestScannerFocus();
//     }
//   }

//   // ==================== CANCELAR VENDA ====================

//   void _cancelSale() async {
//     final cart = ref.read(cartProvider);
//     if (cart.items.isEmpty) return;

//     final confirm = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Cancelar Venda'),
//         content: const Text('Tem a certeza que deseja cancelar a venda actual?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: const Text('Não'),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.pop(context, true),
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//             child: const Text('Sim, Cancelar'),
//           ),
//         ],
//       ),
//     );

//     if (confirm == true) {
//       ref.read(cartProvider.notifier).clearCart();
//       setState(() {
//         _selectedCustomer = Customer.consumidorFinal;
//       });
//       if (mounted) _requestScannerFocus();
//     }
//   }

//   // ==================== FINALIZAR VENDA ====================

//   void _finalizeSale() {
//     final cart = ref.read(cartProvider);
//     if (cart.items.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Carrinho vazio')),
//       );
//       return;
//     }

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => CheckoutDialog(
//         customer: _selectedCustomer,
//         onSaleCompleted: () {
//           ref.read(cartProvider.notifier).clearCart();
//           setState(() {
//             _selectedCustomer = Customer.consumidorFinal;
//           });
//         },
//       ),
//     ).then((_) {
//       if (mounted) _requestScannerFocus();
//     });
//   }

//   // ==================== ABRIR GAVETA ====================

//   void _openCashDrawer() async {
//     final printerState = ref.read(printerProvider);
    
//     if (!printerState.isConnected) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Impressora não conectada'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       return;
//     }

//     try {
//       await ref.read(printerProvider.notifier).openCashDrawer();
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Gaveta aberta'),
//             duration: Duration(seconds: 1),
//           ),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Erro ao abrir gaveta: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }

//   // ==================== FAVORITOS ====================

//   void _openFavoritesScreen() {
//     Navigator.of(context).push(
//       MaterialPageRoute(builder: (_) => const FavoritesScreen()),
//     ).then((_) {
//       if (mounted) _requestScannerFocus();
//     });
//   }

//   // ==================== BUILD ====================

//   @override
//   Widget build(BuildContext context) {
//     final companyDataState = ref.watch(companyDataProvider);
//     final authState = ref.watch(authProvider);
//     final docSetState = ref.watch(documentSetProvider);
//     final suspendedState = ref.watch(suspendedSalesProvider);

//     if (!authState.isAuthenticated) {
//       return const LoginScreen();
//     }

//     return KeyboardListener(
//       focusNode: _scannerFocusNode,
//       autofocus: true,
//       onKeyEvent: _handleKeyEvent,
//       child: Scaffold(
//         appBar: _buildAppBar(
//           isLoading: companyDataState.isLoading,
//           isScannerActive: _scannerHasFocus,
//         ),
//         body: SafeArea(
//           child: Row(
//             children: [
//               // Painel de produtos (60%)
//               Expanded(
//                 flex: 6,
//                 child: ProductSearchPanel(
//                   onProductTap: _onProductTap,
//                   onSearchFocusLost: _requestScannerFocus,
//                 ),
//               ),
//               // Divisor
//               const VerticalDivider(width: 1),
//               // Painel do recibo (40%)
//               Expanded(
//                 flex: 4,
//                 child: ReceiptPanel(
//                   customer: _selectedCustomer,
//                   documentType: docSetState.selectedDocumentType,
//                   suspendedCount: suspendedState.sales.length,
//                   onDocumentTypeTap: _showDocumentTypeSelector,
//                   onCustomerSearchTap: _showCustomerSearch,
//                   onSuspendedSalesTap: _showSuspendedSales,
//                   onItemTap: _showItemOptionsDialog,
//                   onCancelTap: _cancelSale,
//                   onSuspendTap: _suspendCurrentSale,
//                   onFinalizeTap: _finalizeSale,
//                   onOpenDrawerTap: _openCashDrawer,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // ==================== BARCODE SCANNER ====================

//   void _handleKeyEvent(KeyEvent event) {
//     if (event is! KeyDownEvent) return;

//     final now = DateTime.now();

//     if (_lastKeyTime != null) {
//       final elapsed = now.difference(_lastKeyTime!).inMilliseconds;
//       if (elapsed > _maxKeyInterval) {
//         _barcodeBuffer.clear();
//       }
//     }

//     _lastKeyTime = now;

//     if (event.logicalKey == LogicalKeyboardKey.enter ||
//         event.logicalKey == LogicalKeyboardKey.numpadEnter) {
//       _processBarcode();
//       return;
//     }

//     final char = _getCharFromKey(event);
//     if (char != null) {
//       _barcodeBuffer.write(char);
//     }
//   }

//   void _processBarcode() {
//     final barcode = _barcodeBuffer.toString().trim();
//     _barcodeBuffer.clear();

//     if (barcode.length >= 3) {
//       AppLogger.i('📦 Barcode detectado: $barcode');
//       ref.read(barcodeScannerProvider.notifier).processBarcode(barcode);
//     }
//   }

//   String? _getCharFromKey(KeyDownEvent event) {
//     final char = event.character;
//     if (char != null && char.isNotEmpty && _isValidBarcodeChar(char)) {
//       return char;
//     }

//     final keyLabel = event.logicalKey.keyLabel;
//     if (keyLabel.length == 1 && _isValidBarcodeChar(keyLabel)) {
//       return keyLabel;
//     }

//     return null;
//   }

//   bool _isValidBarcodeChar(String char) {
//     if (char.length != 1) return false;
//     final code = char.codeUnitAt(0);

//     return (code >= 48 && code <= 57) || // 0-9
//         (code >= 65 && code <= 90) || // A-Z
//         (code >= 97 && code <= 122) || // a-z
//         code == 45 || // -
//         code == 46; // .
//   }

//   PreferredSizeWidget _buildAppBar(
//       {bool isLoading = false, bool isScannerActive = false,}) {
//     final user = ref.watch(currentUserProvider);

//     return AppBar(
//       title: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           // ═══════════════════════════════════════════════════════════════════
//           // LOGO DA EMPRESA (em vez do nome em texto)
//           // ═══════════════════════════════════════════════════════════════════
//           Image.asset(
//             'assets/img/logo.png',
//             height: 40, // Altura do logo no AppBar
//             fit: BoxFit.contain,
//             errorBuilder: (context, error, stackTrace) {
//               // Fallback para texto se o logo não carregar
//               return const Text('Loja da Madalena');
//             },
//           ),
//           if (isLoading) ...[
//             const SizedBox(width: 12),
//             const SizedBox(
//               width: 16,
//               height: 16,
//               child: CircularProgressIndicator(
//                 strokeWidth: 2,
//                 color: Colors.white,
//               ),
//             ),
//           ],
//         ],
//       ),
//       backgroundColor: Theme.of(context).colorScheme.primary,
//       foregroundColor: Theme.of(context).colorScheme.onPrimary,
//       actions: [
//         // Indicador do scanner (clicável para recuperar foco)
//         Tooltip(
//           message: isScannerActive
//               ? 'Scanner activo - clique para verificar'
//               : 'Scanner inactivo - clique para activar',
//           child: InkWell(
//             onTap: _requestScannerFocus,
//             borderRadius: BorderRadius.circular(12),
//             child: Container(
//               margin: const EdgeInsets.symmetric(horizontal: 8),
//               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//               decoration: BoxDecoration(
//                 color: isScannerActive
//                     ? Colors.green.withValues(alpha: 0.3)
//                     : Colors.red.withValues(alpha: 0.3),
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(
//                   color: isScannerActive ? Colors.green : Colors.red,
//                   width: 1.5,
//                 ),
//               ),
//               child: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(
//                     isScannerActive
//                         ? Icons.qr_code_scanner
//                         : Icons.qr_code_scanner,
//                     size: 16,
//                     color: Colors.white,
//                   ),
//                   const SizedBox(width: 4),
//                   Text(
//                     isScannerActive ? 'Scanner' : 'Scanner OFF',
//                     style: const TextStyle(fontSize: 11, color: Colors.white),
//                   ),
//                   if (!isScannerActive) ...[
//                     const SizedBox(width: 4),
//                     const Icon(Icons.touch_app,
//                         size: 12, color: Colors.white70,),
//                   ],
//                 ],
//               ),
//             ),
//           ),
//         ),
//         // Botão recarregar dados
//         IconButton(
//           icon: const Icon(Icons.refresh),
//           onPressed: isLoading
//               ? null
//               : () {
//                   ref.read(companyDataProvider.notifier).reloadCompanyData();
//                 },
//           tooltip: 'Recarregar dados',
//         ),
//         // Utilizador actual
//         if (user != null)
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 8),
//             child: Center(
//               child: Container(
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                 decoration: BoxDecoration(
//                   color: Colors.white.withValues(alpha: 0.2),
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     const Icon(Icons.person, size: 16),
//                     const SizedBox(width: 6),
//                     Text(user.displayName,
//                         style: const TextStyle(fontSize: 13),),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         // ═══════════════════════════════════════════════════════════════════
//         // BOTÃO FAVORITOS (NOVO)
//         // ═══════════════════════════════════════════════════════════════════
//         IconButton(
//           icon: const Icon(Icons.star),
//           onPressed: _openFavoritesScreen,
//           tooltip: 'Gerir Favoritos',
//         ),
//         // Botão definições
//         IconButton(
//           icon: const Icon(Icons.settings),
//           onPressed: () => Navigator.of(context).push(
//             MaterialPageRoute(builder: (_) => const SettingsScreen()),
//           ),
//           tooltip: 'Configurações',
//         ),
//         // Botão logout
//         IconButton(
//           icon: const Icon(Icons.logout),
//           onPressed: _confirmLogout,
//           tooltip: 'Sair',
//         ),
//       ],
//     );
//   }

//   Future<void> _confirmLogout() async {
//     final confirm = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Sair'),
//         content: const Text('Deseja realmente sair?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: const Text('Cancelar'),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.pop(context, true),
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//             child: const Text('Sair'),
//           ),
//         ],
//       ),
//     );
//     if (confirm == true) {
//       ref.read(companyDataProvider.notifier).clearData();
//       ref.read(authProvider.notifier).logout();
//     }
//   }
// }
