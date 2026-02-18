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
import 'package:pos_moloni_app/features/printer/presentation/providers/printer_provider.dart';

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
  int _pointsToRedeem = 0;
  bool _isConfirmed = false;
  int? _pendingSaleId;
  RegisterSaleResult? _saleResult;

  @override
  void initState() {
    super.initState();
    _initializeAmounts();
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

  void _initializeAmounts() {
    _amountController.text = widget.total.toStringAsFixed(2);
    _amountPaid = widget.total;
  }

  void _preselectNumerario() {
    final methods = ref.read(checkoutProvider).paymentMethods;
    if (methods.isEmpty) return;
    final numerario = methods.where((m) {
      final name = m.name.toLowerCase();
      return name.contains('numerario') ||
          name.contains('numerário') ||
          name.contains('dinheiro');
    }).firstOrNull;
    setState(() => _selectedPaymentMethod = numerario ?? methods.first);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  /// Lista de referências dos produtos no carrinho
  List<String> get _cartProductReferences =>
      widget.items.map((i) => i.product.reference).toList();

  /// Lista de CheckoutItems para a API
  List<CheckoutItem> get _checkoutItems => widget.items
      .map((i) => CheckoutItem(
            productReference: i.product.reference,
            productName: i.product.name,
            quantity: i.quantity.toInt(),
            unitPrice: i.unitPriceWithTax,
          ))
      .toList();

  /// Calcula o desconto total de pontos em EUR
  double get _pointsDiscountValue => _pointsToRedeem / 100;

  /// Calcula o desconto de cupão
  double get _couponDiscountValue {
    final loyaltyState = ref.read(loyaltyProvider);
    return loyaltyState.couponCalculation?.totalDiscount ?? 0;
  }

  /// Calcula o desconto total (pontos + cupão)
  double get _totalDiscountValue => _pointsDiscountValue + _couponDiscountValue;

  /// Calcula o total final a pagar
  /// IMPORTANTE: Depois de confirmar, usa o valor do _saleResult
  double get _finalTotal {
    // Se já confirmou e tem resultado da API, usa esse valor
    if (_isConfirmed && _saleResult != null) {
      return _saleResult!.finalAmount;
    }
    // Caso contrário, calcula localmente
    return (widget.total - _totalDiscountValue).clamp(0, widget.total);
  }

  /// Calcula o troco
  double get _change => (_amountPaid - _finalTotal).clamp(0, double.infinity);

  /// Pode confirmar se tem valor suficiente e método de pagamento
  bool get _canConfirm =>
      _amountPaid >= _finalTotal &&
      _selectedPaymentMethod != null &&
      !_isConfirmed;

  /// Pode finalizar se já confirmou
  bool get _canFinalize => _isConfirmed && !_isProcessing;

  /// Abre a gaveta de dinheiro
  /// Usa o mesmo provider que o pos_screen para consistência
  Future<void> _openCashDrawer() async {
    try {
      final result = await ref.read(printerProvider.notifier).openCashDrawer();
      if (!result.success) {
        debugPrint('Aviso: Não foi possível abrir a gaveta - ${result.error}');
      }
    } catch (e) {
      // Falha silenciosa - não deve impedir a venda
      debugPrint('Erro ao abrir gaveta: $e');
    }
  }

  /// Confirma a venda (Passo 1)
  /// Regista na API de fidelização e bloqueia alterações
  /// TAMBÉM ABRE A GAVETA DE DINHEIRO
  Future<void> _confirmSale() async {
    if (!_canConfirm || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    // ========== ABRIR GAVETA DE DINHEIRO ==========
    // Abre a gaveta assim que o utilizador confirma o pagamento
    // Isto permite que o operador prepare o troco enquanto processa
    _openCashDrawer();
    // ==============================================

    try {
      final loyaltyState = ref.read(loyaltyProvider);

      // Registar venda no loyalty se estiver activo (com ou sem cartão)
      // Isto permite guardar todas as transações no sistema de fidelização
      if (loyaltyState.isEnabled && loyaltyState.isConnected) {
        // Chamar API de fidelização
        final result = await ref.read(loyaltyProvider.notifier).registerSale(
              amount: widget.total,
              paymentMethod: _selectedPaymentMethod?.name,
              pointsToRedeem: _pointsToRedeem,
              items: _checkoutItems,
            );

        if (result != null) {
          // Sucesso - actualizar estado com valores da API
          setState(() {
            _saleResult = result;
            _pendingSaleId = result.saleId;
            _isConfirmed = true;
            _isProcessing = false;
            // Actualizar o valor a pagar para o valor final da API
            // Isto garante que o utilizador vê o valor correcto
            _amountController.text = result.finalAmount.toStringAsFixed(2);
            _amountPaid = result.finalAmount;
          });
        } else {
          // Falhou na API, mas continua sem fidelização
          final loyaltyError = ref.read(loyaltyProvider).error;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Aviso: ${loyaltyError ?? "Erro na fidelização"}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          setState(() {
            _isConfirmed = true;
            _isProcessing = false;
          });
        }
      } else {
        // Sem fidelização activa ou não conectado
        setState(() {
          _isConfirmed = true;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aviso: $e'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _isConfirmed = true;
          _isProcessing = false;
        });
      }
    }
  }

  /// Finaliza a venda (Passo 2)
  /// Cria o documento no Moloni e sincroniza com fidelização
  Future<void> _finalizeSale() async {
    if (!_canFinalize || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final loyaltyState = ref.read(loyaltyProvider);

      // Calcular desconto especial (pontos + cupão)
      // Se temos _saleResult, usar os valores confirmados pela API
      final double specialDiscount;
      if (_saleResult != null) {
        specialDiscount = _saleResult!.totalDiscount;
      } else {
        specialDiscount = _totalDiscountValue;
      }

      // Preparar dados de fidelização para o talão
      LoyaltyReceiptData? loyaltyData;
      if (loyaltyState.currentCustomer != null && _saleResult != null) {
        final card = loyaltyState.currentCustomer!.card;
        final previousBalance = (card?.pointsBalance ?? 0) +
            _saleResult!.pointsRedeemed -
            _saleResult!.pointsEarned;

        loyaltyData = LoyaltyReceiptData(
          cardNumber: card?.cardNumber ?? '',
          previousBalance: previousBalance,
          pointsEarned: _saleResult!.pointsEarned,
          pointsRedeemed: _saleResult!.pointsRedeemed,
          newBalance: _saleResult!.newPointsBalance ?? card?.pointsBalance ?? 0,
          discountApplied: _saleResult!.totalDiscount,
          customerName: loyaltyState.currentCustomer!.name,
          tierName: card?.tier.name,
        );
      }

      // Criar documento no Moloni
      final success = await ref.read(checkoutProvider.notifier).processCheckout(
            documentTypeOption: widget.documentTypeOption,
            customer: widget.customer,
            items: widget.items,
            payments: [
              PaymentInfo(
                methodId: _selectedPaymentMethod!.id,
                value: _finalTotal,
              ),
            ],
            globalDiscount: widget.globalDiscount,
            globalDiscountValue: widget.globalDiscountValue,
            specialDiscount: specialDiscount,
            loyaltyData: loyaltyData,
          );

      if (success && mounted) {
        final checkoutState = ref.read(checkoutProvider);

        // Sincronizar com API de fidelização
        if (_pendingSaleId != null) {
          await ref.read(loyaltyProvider.notifier).completeSale(
                documentReference: checkoutState.document?.number,
                documentId: checkoutState.document?.id,
              );
        }

        if (!mounted) return;

        // Fechar diálogo e mostrar sucesso
        Navigator.of(context).pop(true);

        if (checkoutState.document != null) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => CheckoutSuccessDialog(
              document: checkoutState.document!,
              change: _change,
              loyaltySaleResult: _saleResult,
              onClose: () {
                Navigator.of(ctx).pop();
                ref.read(checkoutProvider.notifier).reset();
              },
            ),
          );
        }
      } else if (mounted) {
        final checkoutState = ref.read(checkoutProvider);
        setState(() {
          _error = checkoutState.error ?? 'Erro ao processar';
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

  /// Cancela o checkout
  Future<void> _cancelCheckout() async {
    // Cancelar venda pendente na API de fidelização
    if (_pendingSaleId != null) {
      await ref
          .read(loyaltyProvider.notifier)
          .cancelPendingSale(reason: 'Cancelado pelo utilizador');
    }

    // Limpar carrinho
    ref.read(cartProvider.notifier).clearCart();

    if (!mounted) return;

    Navigator.of(context).pop(false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Venda cancelada'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  /// Actualiza o valor pago quando o utilizador edita
  void _onAmountChanged(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.')) ?? 0;
    setState(() => _amountPaid = parsed);
  }

  /// Define um valor rápido (5€, 10€, 20€, 50€)
  void _setQuickAmount(double amount) {
    _amountController.text = amount.toStringAsFixed(2);
    _onAmountChanged(amount.toString());
    _amountFocus.requestFocus();
  }

  /// Define o valor exacto
  void _setExactAmount() {
    _amountController.text = _finalTotal.toStringAsFixed(2);
    setState(() => _amountPaid = _finalTotal);
    _amountFocus.requestFocus();
  }

  /// Actualiza o valor total quando pontos ou cupão mudam
  /// CORRIGIDO: Chama setState() correctamente
  void _updateTotalAmount() {
    if (_isConfirmed) return; // Não actualizar depois de confirmar

    // Usar WidgetsBinding para garantir que o widget está montado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isConfirmed) return;

      final newTotal = _finalTotal;
      setState(() {
        _amountController.text = newTotal.toStringAsFixed(2);
        _amountPaid = newTotal;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final checkoutState = ref.watch(checkoutProvider);
    final loyaltyState = ref.watch(loyaltyProvider);
    final paymentMethods = checkoutState.paymentMethods;

    // Pré-seleccionar método de pagamento se ainda não foi feito
    if (paymentMethods.isNotEmpty && _selectedPaymentMethod == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _preselectNumerario());
    }

    return Dialog(
      child: Container(
        width: loyaltyState.isEnabled ? 850 : 600,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.95,
        ),
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
                              cartProductReferences: _cartProductReferences,
                              checkoutItems: _checkoutItems,
                              onPointsToRedeemChanged: (pts) {
                                if (!_isConfirmed) {
                                  setState(() => _pointsToRedeem = pts);
                                  _updateTotalAmount();
                                }
                              },
                              onCouponChanged: (_) {
                                if (!_isConfirmed) {
                                  _updateTotalAmount();
                                }
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
      decoration: BoxDecoration(
        color: _isConfirmed ? Colors.green : Theme.of(context).colorScheme.primary,
      ),
      child: Row(
        children: [
          Icon(
            _isConfirmed ? Icons.check_circle : Icons.payment,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Text(
            _isConfirmed ? 'Venda Confirmada' : 'Pagamento',
            style: const TextStyle(
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
    );
  }

  Widget _buildPaymentColumn(List<PaymentMethod> paymentMethods) {
    // Mostrar descontos: antes de confirmar usa cálculo local, depois usa _saleResult
    final double displayDiscount;
    if (_isConfirmed && _saleResult != null) {
      displayDiscount = _saleResult!.totalDiscount;
    } else {
      displayDiscount = _totalDiscountValue;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Info do cliente
        Row(
          children: [
            const Icon(Icons.person_outline, size: 18),
            const SizedBox(width: 8),
            Text(widget.customer.name, style: const TextStyle(fontSize: 12)),
            const Spacer(),
            Text(
              '${widget.items.length} artigo${widget.items.length != 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Total a pagar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFD4A574),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                'Total a Pagar',
                style: TextStyle(fontSize: 14, color: Colors.brown.shade900),
              ),
              const SizedBox(height: 4),
              Text(
                '${_finalTotal.toStringAsFixed(2)} €',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown.shade900,
                ),
              ),
              // Mostrar desconto aplicado
              if (displayDiscount > 0)
                Text(
                  '(${displayDiscount.toStringAsFixed(2)} € desconto)',
                  style: TextStyle(fontSize: 12, color: Colors.brown.shade700),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Resultado da fidelização (após confirmar)
        if (_saleResult != null) ...[
          LoyaltySaleResultWidget(
            pointsEarned: _saleResult!.pointsEarned,
            pointsRedeemed: _saleResult!.pointsRedeemed,
            discountApplied: _saleResult!.discountApplied,
            newBalance: _saleResult!.newPointsBalance,
            customerName: _saleResult!.customerName,
            tierName: _saleResult!.tierName,
            couponApplied: _saleResult!.couponApplied,
          ),
          const SizedBox(height: 12),
        ],

        // Método de pagamento
        const Text(
          'Método de Pagamento',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: paymentMethods.map((m) {
            final isSelected = _selectedPaymentMethod?.id == m.id;
            return SizedBox(
              width: 130,
              child: Material(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: _isConfirmed
                      ? null
                      : () => setState(() => _selectedPaymentMethod = m),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getPaymentIcon(m.name),
                          size: 24,
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          m.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 12),

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
                enabled: !_isConfirmed,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                  if (_canConfirm) {
                    _confirmSale();
                  } else if (_canFinalize) {
                    _finalizeSale();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _isConfirmed ? null : _setExactAmount,
              icon: const Icon(Icons.check),
              tooltip: 'Valor exacto',
            ),
          ],
        ),

        // Botões de valor rápido
        if (!_isConfirmed) ...[
          const SizedBox(height: 12),
          Row(
            children: [5.0, 10.0, 20.0, 50.0].map((a) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: a != 50.0 ? 8 : 0),
                  child: ElevatedButton(
                    onPressed: () => _setQuickAmount(a),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.secondaryContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onSecondaryContainer,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      '${a.toInt()}€',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],

        // Troco
        if (_amountPaid > _finalTotal) ...[
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
    );
  }

  Widget _buildFooter() {
    return Container(
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
            child: const Text('Voltar'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _cancelCheckout,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Cancelar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade100,
              foregroundColor: Colors.red.shade700,
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _isProcessing
                ? null
                : (_isConfirmed
                    ? (_canFinalize ? _finalizeSale : null)
                    : (_canConfirm ? _confirmSale : null)),
            icon: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_isConfirmed ? Icons.check : Icons.arrow_forward),
            label: Text(
              _isProcessing
                  ? 'A processar...'
                  : (_isConfirmed ? 'Finalizar' : 'Confirmar'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isConfirmed ? Colors.green : Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPaymentIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('numerário') ||
        n.contains('numerario') ||
        n.contains('dinheiro')) {
      return Icons.payments;
    }
    if (n.contains('multibanco') ||
        n.contains('mb') ||
        n.contains('terminal')) {
      return Icons.credit_card;
    }
    if (n.contains('transferência') || n.contains('transferencia')) {
      return Icons.account_balance;
    }
    if (n.contains('mbway')) {
      return Icons.phone_android;
    }
    if (n.contains('cheque')) {
      return Icons.description;
    }
    return Icons.payment;
  }
}
