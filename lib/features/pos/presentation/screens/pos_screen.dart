import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/constants/app_constants.dart';
import 'package:pos_moloni_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:pos_moloni_app/features/cart/domain/entities/cart_item.dart';
import 'package:pos_moloni_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:pos_moloni_app/features/checkout/presentation/widgets/checkout_dialog.dart';
import 'package:pos_moloni_app/features/company/presentation/providers/company_provider.dart';
import 'package:pos_moloni_app/features/document_sets/presentation/providers/document_set_provider.dart';
import 'package:pos_moloni_app/features/products/domain/entities/product.dart';
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

  @override
  void initState() {
    super.initState();
    // Carregar séries de documentos e vendas suspensas ao iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(documentSetProvider.notifier).loadDocumentSets();
      // Carregar vendas suspensas persistentes
      final docOptions = ref.read(documentSetProvider).documentTypeOptions;
      ref.read(suspendedSalesProvider.notifier).loadPersistentSales(
        documentOptions: docOptions,
      );
    });
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
    );
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
    );
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
    );
  }

  // ==================== VENDAS SUSPENSAS ====================

  void _showSuspendedSales() {
    showDialog(
      context: context,
      builder: (context) => SuspendedSalesDialog(
        onRestore: _restoreSuspendedSale,
      ),
    );
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

    // Suspender usando o provider
    await ref.read(suspendedSalesProvider.notifier).suspendSale(
      items: cart.items,
      customer: _selectedCustomer,
      documentOption: selectedOption,
      note: result.note,
      persistent: result.isPersistent,
    );

    // Limpar carrinho
    ref.read(cartProvider.notifier).clearCart();
    setState(() => _selectedCustomer = Customer.consumidorFinal);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isPersistent
                ? 'Venda suspensa e guardada permanentemente'
                : 'Venda suspensa',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _restoreSuspendedSale(SuspendedSale sale) async {
    final cart = ref.read(cartProvider);

    // Se há items no carrinho, confirmar substituição
    if (cart.items.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Substituir carrinho?'),
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

    // Abrir diálogo de checkout
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CheckoutDialog(
        documentTypeOption: selectedOption,
        customer: _selectedCustomer,
        items: cart.items,
        total: cart.total,
      ),
    );

    // Se checkout foi bem sucedido, limpar carrinho
    if (result == true) {
      ref.read(cartProvider.notifier).clearCart();
      setState(() => _selectedCustomer = Customer.consumidorFinal);
    }
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
    );
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    final selectedCompany = ref.watch(companyProvider).selectedCompany;
    final docSetState = ref.watch(documentSetProvider);
    final suspendedState = ref.watch(suspendedSalesProvider);

    return Scaffold(
      appBar: _buildAppBar(selectedCompany?.name ?? AppConstants.appName),
      body: Row(
        children: [
          // Painel de Pesquisa (esquerda - ~65%)
          Expanded(
            flex: 7,
            child: ProductSearchPanel(onProductTap: _onProductTap),
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
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String title) {
    final user = ref.watch(currentUserProvider);

    return AppBar(
      title: Text(title),
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      actions: [
        if (user != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
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
      ref.read(authProvider.notifier).logout();
    }
  }
}
