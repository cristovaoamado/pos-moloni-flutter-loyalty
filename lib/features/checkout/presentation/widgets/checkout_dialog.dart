import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/features/cart/domain/entities/cart_item.dart';
import 'package:pos_moloni_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:pos_moloni_app/features/checkout/data/datasources/document_remote_datasource.dart';
import 'package:pos_moloni_app/features/checkout/domain/entities/document.dart';
import 'package:pos_moloni_app/features/checkout/presentation/providers/checkout_provider.dart';
import 'package:pos_moloni_app/features/checkout/presentation/widgets/checkout_success_dialog.dart';
import 'package:pos_moloni_app/features/customers/domain/entities/customer.dart';
import 'package:pos_moloni_app/features/document_sets/domain/entities/document_set.dart';

/// Diálogo de checkout/pagamento
class CheckoutDialog extends ConsumerStatefulWidget {
  const CheckoutDialog({
    super.key,
    required this.documentTypeOption,
    required this.customer,
    required this.items,
    required this.total,
    this.globalDiscount = 0,
    this.globalDiscountValue = 0,
  });

  final DocumentTypeOption documentTypeOption;
  final Customer customer;
  final List<CartItem> items;
  final double total;
  /// Desconto global em percentagem (0-100)
  final double globalDiscount;
  /// Valor do desconto global em EUR
  final double globalDiscountValue;

  @override
  ConsumerState<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends ConsumerState<CheckoutDialog> {
  final _amountController = TextEditingController();
  final _amountFocus = FocusNode();
  
  PaymentMethod? _selectedPaymentMethod;
  double _amountPaid = 0;
  bool _isProcessing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.total.toStringAsFixed(2);
    _amountPaid = widget.total;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final methods = ref.read(checkoutProvider).paymentMethods;
      if (methods.isNotEmpty && _selectedPaymentMethod == null) {
        final numerario = methods.where((m) {
          final name = m.name.toLowerCase();
          return name.contains('numerario') || 
                 name.contains('numerário') || 
                 name.contains('dinheiro') ||
                 name.contains('cash');
        }).firstOrNull;
        
        setState(() {
          _selectedPaymentMethod = numerario ?? methods.first;
        });
      }
      
      _amountFocus.requestFocus();
      _amountController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _amountController.text.length,
      );
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  double get _change => (_amountPaid - widget.total).clamp(0, double.infinity);
  bool get _canFinalize => _amountPaid >= widget.total && _selectedPaymentMethod != null;

  Future<void> _processPayment() async {
    if (!_canFinalize || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      // Passar descontos ao processCheckout
      final success = await ref.read(checkoutProvider.notifier).processCheckout(
        documentTypeOption: widget.documentTypeOption,
        customer: widget.customer,
        items: widget.items,
        payments: [
          PaymentInfo(
            methodId: _selectedPaymentMethod!.id,
            value: widget.total,
          ),
        ],
        globalDiscount: widget.globalDiscount,
        globalDiscountValue: widget.globalDiscountValue,
      );

      if (success && mounted) {
        Navigator.of(context).pop(true);
        
        final checkoutState = ref.read(checkoutProvider);
        if (checkoutState.document != null) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => CheckoutSuccessDialog(
              document: checkoutState.document!,
              change: _change,
              onClose: () {
                Navigator.of(context).pop();
                ref.read(checkoutProvider.notifier).reset();
              },
            ),
          );
        }
      } else if (mounted) {
        final checkoutState = ref.read(checkoutProvider);
        setState(() {
          _error = checkoutState.error ?? 'Erro ao processar pagamento';
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isProcessing = false;
        });
      }
    }
  }

  void _onAmountChanged(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    setState(() {
      _amountPaid = parsed ?? 0;
    });
  }

  void _setQuickAmount(double amount) {
    _amountController.text = amount.toStringAsFixed(2);
    _onAmountChanged(amount.toString());
    _amountFocus.requestFocus();
    _amountController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _amountController.text.length,
    );
  }

  void _setExactAmount() {
    _amountController.text = widget.total.toStringAsFixed(2);
    _onAmountChanged(widget.total.toString());
    _amountFocus.requestFocus();
    _amountController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _amountController.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final paymentMethods = ref.watch(checkoutProvider).paymentMethods;
    final hasDiscount = widget.globalDiscount > 0 || widget.globalDiscountValue > 0;

    return Dialog(
      child: Container(
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payment, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    'Pagamento',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.documentTypeOption.shortName,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            // Conteúdo scrollável
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Info do cliente
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          widget.customer.name,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const Spacer(),
                        Text(
                          '${widget.items.length} artigo${widget.items.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Total a pagar (com desconto se existir)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Total a Pagar',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.total.toStringAsFixed(2)} €',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          // Mostrar desconto aplicado
                          if (hasDiscount) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.discount, size: 16, color: Colors.green),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Desconto: ${widget.globalDiscount.toStringAsFixed(0)}% (-${widget.globalDiscountValue.toStringAsFixed(2)} €)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Métodos de pagamento
                    const Text(
                      'Método de Pagamento',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: paymentMethods.map((method) {
                        final isSelected = _selectedPaymentMethod?.id == method.id;
                        return InkWell(
                          onTap: () => setState(() => _selectedPaymentMethod = method),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 100,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getPaymentIcon(method.name),
                                  color: isSelected
                                      ? Colors.white
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                  size: 24,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  method.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                    color: isSelected
                                        ? Colors.white
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // Valor entregue
                    const Text(
                      'Valor Entregue',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            focusNode: _amountFocus,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              suffixText: '€',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                            ],
                            onChanged: _onAmountChanged,
                            onSubmitted: (_) {
                              if (_canFinalize) _processPayment();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _setExactAmount,
                          icon: const Icon(Icons.check),
                          tooltip: 'Valor exacto',
                        ),
                      ],
                    ),

                    // Botões de valor rápido
                    const SizedBox(height: 12),
                    Row(
                      children: [5.0, 10.0, 20.0, 50.0].map((amount) {
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: amount != 50.0 ? 8 : 0,
                            ),
                            child: ElevatedButton(
                              onPressed: () => _setQuickAmount(amount),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(
                                '${amount.toInt()}€',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    // Troco
                    if (_amountPaid > widget.total) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.money, color: Colors.green.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Troco: ${_change.toStringAsFixed(2)} €',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Erro
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _isProcessing ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _canFinalize && !_isProcessing ? _processPayment : null,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(_isProcessing ? 'A processar...' : 'Finalizar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPaymentIcon(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('numerário') || 
        lowerName.contains('numerario') || 
        lowerName.contains('dinheiro')) {
      return Icons.payments;
    } else if (lowerName.contains('multibanco') || 
               lowerName.contains('mb') ||
               lowerName.contains('terminal')) {
      return Icons.credit_card;
    } else if (lowerName.contains('transferência') || 
               lowerName.contains('transferencia') ||
               lowerName.contains('iban')) {
      return Icons.account_balance;
    } else if (lowerName.contains('mbway') || 
               lowerName.contains('mb way')) {
      return Icons.phone_android;
    } else if (lowerName.contains('cheque')) {
      return Icons.description;
    }
    return Icons.payment;
  }
}
