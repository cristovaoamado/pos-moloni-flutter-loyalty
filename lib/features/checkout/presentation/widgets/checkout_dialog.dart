import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/features/cart/domain/entities/cart_item.dart';
import 'package:pos_moloni_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:pos_moloni_app/features/checkout/data/datasources/document_remote_datasource.dart';
import 'package:pos_moloni_app/features/checkout/domain/entities/document.dart';
import 'package:pos_moloni_app/features/checkout/presentation/providers/checkout_provider.dart';
import 'package:pos_moloni_app/features/checkout/presentation/widgets/checkout_success_dialog.dart';
import 'package:pos_moloni_app/features/checkout/services/receipt_generator.dart';
import 'package:pos_moloni_app/features/customers/domain/entities/customer.dart';
import 'package:pos_moloni_app/features/document_sets/domain/entities/document_set.dart';
import 'package:pos_moloni_app/features/loyalty/loyalty.dart';

/// Diálogo de checkout/pagamento com 2 colunas (Pagamento + Fidelização)
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
  final double globalDiscount;
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

  // LOYALTY: Estado adicional
  int _pointsToRedeem = 0;
  bool _isConfirmed = false;
  int? _pendingSaleId;
  RegisterSaleResult? _saleResult;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.total.toStringAsFixed(2);
    _amountPaid = widget.total;
    _preselectNumerario();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedPaymentMethod == null) _preselectNumerario();
      _amountFocus.requestFocus();
      _amountController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _amountController.text.length,
      );
    });
  }

  void _preselectNumerario() {
    final methods = ref.read(checkoutProvider).paymentMethods;
    if (methods.isEmpty) return;
    
    final numerario = methods.where((m) {
      final name = m.name.toLowerCase();
      return name.contains('numerario') || name.contains('numerário') || 
             name.contains('dinheiro') || name.contains('cash');
    }).firstOrNull;
    
    setState(() => _selectedPaymentMethod = numerario ?? methods.first);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  double get _finalTotal {
    if (_saleResult != null) return _saleResult!.finalAmount;
    final discount = _pointsToRedeem / 100;
    return (widget.total - discount).clamp(0, widget.total);
  }

  double get _change => (_amountPaid - _finalTotal).clamp(0, double.infinity);
  bool get _canConfirm => _amountPaid >= _finalTotal && _selectedPaymentMethod != null && !_isConfirmed;
  bool get _canFinalize => _isConfirmed && !_isProcessing;

  Future<void> _confirmSale() async {
    if (!_canConfirm || _isProcessing) return;
    setState(() { _isProcessing = true; _error = null; });

    try {
      final loyaltyState = ref.read(loyaltyProvider);
      
      if (loyaltyState.isEnabled && loyaltyState.currentCustomer != null) {
        final result = await ref.read(loyaltyProvider.notifier).registerSale(
          amount: widget.total,
          paymentMethod: _selectedPaymentMethod?.name,
          pointsToRedeem: _pointsToRedeem,
        );

        if (result != null) {
          setState(() {
            _saleResult = result;
            _pendingSaleId = result.saleId;
            _isConfirmed = true;
            _isProcessing = false;
            _amountController.text = result.finalAmount.toStringAsFixed(2);
            _amountPaid = result.finalAmount;
          });
        } else {
          final loyaltyError = ref.read(loyaltyProvider).error;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Aviso: ${loyaltyError ?? "Erro"}'), backgroundColor: Colors.orange),
            );
          }
          setState(() { _isConfirmed = true; _isProcessing = false; });
        }
      } else {
        setState(() { _isConfirmed = true; _isProcessing = false; });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Aviso: $e'), backgroundColor: Colors.orange),
        );
        setState(() { _isConfirmed = true; _isProcessing = false; });
      }
    }
  }

  Future<void> _finalizeSale() async {
    if (!_canFinalize || _isProcessing) return;
    setState(() { _isProcessing = true; _error = null; });

    try {
      // Calcular o desconto especial dos pontos (valor em €)
      final specialDiscount = _saleResult?.discountApplied ?? (_pointsToRedeem / 100);
      
      // Construir dados de fidelização para o talão
      LoyaltyReceiptData? loyaltyData;
      final loyaltyState = ref.read(loyaltyProvider);
      if (loyaltyState.currentCustomer != null && _saleResult != null) {
        loyaltyData = LoyaltyReceiptData(
          cardNumber: loyaltyState.currentCustomer!.card?.cardNumber ?? '',
          previousBalance: (loyaltyState.currentCustomer!.card?.pointsBalance ?? 0) + _saleResult!.pointsRedeemed - _saleResult!.pointsEarned,
          pointsEarned: _saleResult!.pointsEarned,
          pointsRedeemed: _saleResult!.pointsRedeemed,
          newBalance: _saleResult!.newPointsBalance ?? loyaltyState.currentCustomer!.card?.pointsBalance ?? 0,
          discountApplied: _saleResult!.discountApplied,
          customerName: loyaltyState.currentCustomer!.name,
          tierName: loyaltyState.currentCustomer!.card?.tier.name,
        );
      }
      
      final success = await ref.read(checkoutProvider.notifier).processCheckout(
        documentTypeOption: widget.documentTypeOption,
        customer: widget.customer,
        items: widget.items,
        payments: [PaymentInfo(methodId: _selectedPaymentMethod!.id, value: _finalTotal)],
        globalDiscount: widget.globalDiscount,
        globalDiscountValue: widget.globalDiscountValue,
        specialDiscount: specialDiscount, // Desconto dos pontos de fidelização em €
        loyaltyData: loyaltyData, // Dados para o talão
      );

      if (success && mounted) {
        final checkoutState = ref.read(checkoutProvider);
        
        if (_pendingSaleId != null) {
          await ref.read(loyaltyProvider.notifier).completeSale(
            documentReference: checkoutState.document?.number,
            documentId: checkoutState.document?.id,
          );
        }

        if (!mounted) return;
        
        Navigator.of(context).pop(true);
        
        if (checkoutState.document != null) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => CheckoutSuccessDialog(
              document: checkoutState.document!,
              change: _change,
              loyaltySaleResult: _saleResult,
              onClose: () {
                Navigator.of(dialogContext).pop();
                ref.read(checkoutProvider.notifier).reset();
              },
            ),
          );
        }
      } else if (mounted) {
        final checkoutState = ref.read(checkoutProvider);
        setState(() { _error = checkoutState.error ?? 'Erro ao processar'; _isProcessing = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isProcessing = false; });
    }
  }

  Future<void> _cancelCheckout() async {
    if (_pendingSaleId != null) {
      await ref.read(loyaltyProvider.notifier).cancelPendingSale(reason: 'Cancelado');
    }
    ref.read(cartProvider.notifier).clearCart();
    
    if (!mounted) return;
    
    Navigator.of(context).pop(false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Venda cancelada'), backgroundColor: Colors.orange),
    );
  }

  void _onAmountChanged(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    setState(() => _amountPaid = parsed ?? 0);
  }

  void _setQuickAmount(double amount) {
    _amountController.text = amount.toStringAsFixed(2);
    _onAmountChanged(amount.toString());
    _amountFocus.requestFocus();
    _amountController.selection = TextSelection(baseOffset: 0, extentOffset: _amountController.text.length);
  }

  void _setExactAmount() {
    _amountController.text = _finalTotal.toStringAsFixed(2);
    _onAmountChanged(_finalTotal.toString());
    _amountFocus.requestFocus();
    _amountController.selection = TextSelection(baseOffset: 0, extentOffset: _amountController.text.length);
  }

  @override
  Widget build(BuildContext context) {
    final checkoutState = ref.watch(checkoutProvider);
    final loyaltyState = ref.watch(loyaltyProvider);
    final paymentMethods = checkoutState.paymentMethods;
    
    if (paymentMethods.isNotEmpty && _selectedPaymentMethod == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _preselectNumerario());
    }

    return Dialog(
      child: Container(
        width: loyaltyState.isEnabled ? 850 : 600,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.95),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: loyaltyState.isEnabled
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildPaymentColumn(paymentMethods)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: LoyaltyCheckoutWidget(
                              cartTotal: widget.total,
                              onPointsToRedeemChanged: (points) {
                                if (!_isConfirmed) setState(() => _pointsToRedeem = points);
                              },
                            ),
                          ),
                        ],
                      )
                    : _buildPaymentColumn(paymentMethods),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _isConfirmed ? Colors.green : Theme.of(context).colorScheme.primary),
      child: Row(
        children: [
          Icon(_isConfirmed ? Icons.check_circle : Icons.payment, color: Colors.white),
          const SizedBox(width: 12),
          Text(_isConfirmed ? 'Venda Confirmada' : 'Pagamento',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(widget.documentTypeOption.shortName, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildPaymentColumn(List<PaymentMethod> paymentMethods) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.person_outline, size: 18),
            const SizedBox(width: 8),
            Text(widget.customer.name, style: const TextStyle(fontSize: 12)),
            const Spacer(),
            Text('${widget.items.length} artigo${widget.items.length != 1 ? 's' : ''}',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFD4A574), borderRadius: BorderRadius.circular(8)),
          child: Column(
            children: [
              Text('Total a Pagar', style: TextStyle(fontSize: 14, color: Colors.brown.shade900)),
              const SizedBox(height: 4),
              Text('${_finalTotal.toStringAsFixed(2)} €',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.brown.shade900)),
              if (_saleResult != null && _saleResult!.discountApplied > 0)
                Text('(${_saleResult!.discountApplied.toStringAsFixed(2)} € desconto)',
                    style: TextStyle(fontSize: 12, color: Colors.brown.shade700)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_saleResult != null) ...[
          LoyaltySaleResultWidget(
            pointsEarned: _saleResult!.pointsEarned,
            pointsRedeemed: _saleResult!.pointsRedeemed,
            discountApplied: _saleResult!.discountApplied,
            newBalance: _saleResult!.newPointsBalance,
            customerName: _saleResult!.customerName,
            tierName: _saleResult!.tierName,
          ),
          const SizedBox(height: 12),
        ],
        const Text('Método de Pagamento', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: paymentMethods.map((method) {
            final isSelected = _selectedPaymentMethod?.id == method.id;
            return SizedBox(
              width: 130,
              child: Material(
                color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: _isConfirmed ? null : () => setState(() => _selectedPaymentMethod = method),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getPaymentIcon(method.name), size: 24,
                            color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(height: 4),
                        Text(method.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12,
                                color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        const Text('Valor Entregue', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _amountController,
                focusNode: _amountFocus,
                enabled: !_isConfirmed,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(suffixText: '€', border: const OutlineInputBorder(),
                    filled: true, fillColor: Theme.of(context).colorScheme.surface),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                onChanged: _onAmountChanged,
                onSubmitted: (_) {
                  if (_canConfirm) {
                    _confirmSale();
                  } else if (_canFinalize) {
                    _finalizeSale();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _isConfirmed ? null : _setExactAmount, icon: const Icon(Icons.check), tooltip: 'Valor exacto'),
          ],
        ),
        if (!_isConfirmed) ...[
          const SizedBox(height: 12),
          Row(
            children: [5.0, 10.0, 20.0, 50.0].map((amount) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: amount != 50.0 ? 8 : 0),
                  child: ElevatedButton(
                    onPressed: () => _setQuickAmount(amount),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                      foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('${amount.toInt()}€', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        if (_amountPaid > _finalTotal) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.money, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text('Troco: ${_change.toStringAsFixed(2)} €',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
              ],
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200)),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade700))),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
      child: Row(
        children: [
          TextButton(onPressed: _isProcessing ? null : () => Navigator.of(context).pop(false), child: const Text('Voltar')),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _cancelCheckout,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Cancelar'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100, foregroundColor: Colors.red.shade700),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : (_isConfirmed ? (_canFinalize ? _finalizeSale : null) : (_canConfirm ? _confirmSale : null)),
            icon: _isProcessing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_isConfirmed ? Icons.check : Icons.arrow_forward),
            label: Text(_isProcessing ? 'A processar...' : (_isConfirmed ? 'Finalizar' : 'Confirmar')),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isConfirmed ? Colors.green : Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPaymentIcon(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('numerário') || lowerName.contains('numerario') || lowerName.contains('dinheiro')) return Icons.payments;
    if (lowerName.contains('multibanco') || lowerName.contains('mb') || lowerName.contains('terminal')) return Icons.credit_card;
    if (lowerName.contains('transferência') || lowerName.contains('transferencia') || lowerName.contains('iban')) return Icons.account_balance;
    if (lowerName.contains('mbway') || lowerName.contains('mb way')) return Icons.phone_android;
    if (lowerName.contains('cheque')) return Icons.description;
    return Icons.payment;
  }
}
