import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/checkout/domain/entities/document.dart';
import 'package:pos_moloni_app/features/checkout/presentation/providers/checkout_provider.dart';
import 'package:pos_moloni_app/features/checkout/services/print_service.dart';
import 'package:pos_moloni_app/features/printer/presentation/providers/printer_provider.dart';
import 'package:pos_moloni_app/features/loyalty/data/models/sale_models.dart';

/// Diálogo de sucesso após checkout
class CheckoutSuccessDialog extends ConsumerStatefulWidget {
  const CheckoutSuccessDialog({
    super.key,
    required this.document,
    required this.change,
    required this.onClose,
    this.loyaltySaleResult,
  });

  final Document document;
  final double change;
  final VoidCallback onClose;
  final RegisterSaleResult? loyaltySaleResult;

  @override
  ConsumerState<CheckoutSuccessDialog> createState() => _CheckoutSuccessDialogState();
}

class _CheckoutSuccessDialogState extends ConsumerState<CheckoutSuccessDialog> {
  bool _isPrinting = false;
  bool _isOpening = false;
  String? _printMessage;
  bool _printSuccess = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoPrint();
    });
  }

  void _checkAutoPrint() {
    final printerState = ref.read(printerProvider);
    final checkoutState = ref.read(checkoutProvider);

    if (printerState.config.isEnabled &&
        printerState.config.autoPrint &&
        checkoutState.pdfBytes != null) {
      AppLogger.i('🖨️ Auto-print activado, a imprimir...');
      _printDocument();
    }
  }

  Future<void> _printDocument() async {
    final checkoutState = ref.read(checkoutProvider);
    final printerState = ref.read(printerProvider);

    if (checkoutState.pdfBytes == null) {
      setState(() {
        _printMessage = 'PDF não disponível';
        _printSuccess = false;
      });
      return;
    }

    setState(() {
      _isPrinting = true;
      _printMessage = null;
    });

    try {
      bool success = false;

      if (printerState.config.isEnabled && printerState.config.isConfigured) {
        AppLogger.i('🖨️ Imprimindo directamente em: ${printerState.config.name}');

        success = await PrintService.printDirectToConfiguredPrinter(
          checkoutState.pdfBytes!,
          printerState.config.name,
          documentName: widget.document.number,
        );

        if (success) {
          setState(() {
            _printMessage = 'Documento enviado para ${printerState.config.name}';
            _printSuccess = true;
          });
        } else {
          AppLogger.w('⚠️ Falhou na impressora configurada, a abrir diálogo...');
          success = await PrintService.printPdfWithDialog(
            checkoutState.pdfBytes!,
            documentName: widget.document.number,
          );

          if (success) {
            setState(() {
              _printMessage = 'Documento impresso';
              _printSuccess = true;
            });
          }
        }
      } else {
        AppLogger.i('🖨️ Sem impressora configurada, a abrir diálogo...');
        success = await PrintService.printPdfWithDialog(
          checkoutState.pdfBytes!,
          documentName: widget.document.number,
        );

        if (success) {
          setState(() {
            _printMessage = 'Documento impresso';
            _printSuccess = true;
          });
        }
      }

      if (!success && mounted) {
        setState(() {
          _printMessage = 'Impressão cancelada ou falhou';
          _printSuccess = false;
        });
      }
    } catch (e) {
      AppLogger.e('Erro ao imprimir', error: e);
      if (mounted) {
        setState(() {
          _printMessage = 'Erro ao imprimir: $e';
          _printSuccess = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  Future<void> _openPdf() async {
    final checkoutState = ref.read(checkoutProvider);

    if (checkoutState.pdfBytes == null) {
      setState(() {
        _printMessage = 'PDF não disponível';
        _printSuccess = false;
      });
      return;
    }

    setState(() {
      _isOpening = true;
      _printMessage = null;
    });

    try {
      await PrintService.openPdfFromBytes(
        checkoutState.pdfBytes!,
        'documento_${widget.document.id}',
      );
    } catch (e) {
      AppLogger.e('Erro ao abrir PDF', error: e);
      if (mounted) {
        setState(() {
          _printMessage = 'Erro ao abrir PDF';
          _printSuccess = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isOpening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkoutState = ref.watch(checkoutProvider);
    final printerState = ref.watch(printerProvider);
    final hasPdf = checkoutState.pdfBytes != null;
    final hasPrinterConfigured = printerState.config.isEnabled && printerState.config.isConfigured;
    final hasLoyalty = widget.loyaltySaleResult != null;

    return Dialog(
      child: Container(
        width: 450,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header com ícone de sucesso
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: Colors.green),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.green, size: 48),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Venda Concluída!',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            // Detalhes do documento - scrollável
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Número do documento e Total lado a lado
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          // Documento
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.receipt, size: 16, color: Theme.of(context).colorScheme.outline),
                                    const SizedBox(width: 6),
                                    Text('Documento', style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(widget.document.number, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text(widget.document.formattedDate, style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
                              ],
                            ),
                          ),
                          // Separador vertical
                          Container(
                            height: 50,
                            width: 1,
                            color: Theme.of(context).dividerColor,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          // Total
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text('Total', style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
                                    const SizedBox(width: 6),
                                    Icon(Icons.euro, size: 16, color: Theme.of(context).colorScheme.outline),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(widget.document.formattedTotal, 
                                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Troco (se houver)
                    if (widget.change > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.money, color: Colors.green.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text('Troco: ', style: TextStyle(color: Colors.green.shade700, fontSize: 14)),
                            Text('${widget.change.toStringAsFixed(2)} €', 
                                style: TextStyle(color: Colors.green.shade700, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],

                    // ═══════════════════════════════════════════════════════════
                    // LOYALTY: Info de pontos
                    // ═══════════════════════════════════════════════════════════
                    if (hasLoyalty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.loyalty, color: Colors.blue.shade700, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Fidelização',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                                ),
                                if (widget.loyaltySaleResult!.customerName != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '- ${widget.loyaltySaleResult!.customerName}',
                                    style: TextStyle(color: Colors.blue.shade600, fontSize: 13),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                if (widget.loyaltySaleResult!.pointsEarned > 0)
                                  _buildLoyaltyChip(
                                    icon: Icons.add_circle,
                                    color: Colors.green,
                                    label: '+${widget.loyaltySaleResult!.pointsEarned}',
                                    sublabel: 'ganhos',
                                  ),
                                if (widget.loyaltySaleResult!.pointsRedeemed > 0)
                                  _buildLoyaltyChip(
                                    icon: Icons.remove_circle,
                                    color: Colors.orange,
                                    label: '-${widget.loyaltySaleResult!.pointsRedeemed}',
                                    sublabel: 'usados',
                                  ),
                                if (widget.loyaltySaleResult!.newPointsBalance != null)
                                  _buildLoyaltyChip(
                                    icon: Icons.account_balance_wallet,
                                    color: Colors.blue,
                                    label: '${widget.loyaltySaleResult!.newPointsBalance}',
                                    sublabel: 'saldo',
                                  ),
                              ],
                            ),
                            if (widget.loyaltySaleResult!.discountApplied > 0) ...[
                              const SizedBox(height: 8),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'Desconto: ${widget.loyaltySaleResult!.discountApplied.toStringAsFixed(2)} €',
                                    style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Info da impressora configurada
                    if (hasPrinterConfigured) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.print, size: 16, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Impressora: ${printerState.config.name}',
                                style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (printerState.config.autoPrint)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade700,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('AUTO', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Botões de ação
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: hasPdf && !_isPrinting ? _printDocument : null,
                            icon: _isPrinting
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.print),
                            label: Text(_isPrinting ? 'A imprimir...' : hasPrinterConfigured ? 'Imprimir' : 'Imprimir...'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: hasPdf && !_isOpening ? _openPdf : null,
                            icon: _isOpening
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.visibility),
                            label: Text(_isOpening ? 'A abrir...' : 'Ver PDF'),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                          ),
                        ),
                      ],
                    ),

                    // Indicador de loading do PDF
                    if (!hasPdf) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 8),
                          Text('A carregar PDF...', style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
                        ],
                      ),
                    ],

                    // Mensagem de impressão
                    if (_printMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _printSuccess ? Colors.green.shade50 : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _printSuccess ? Colors.green.shade200 : Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _printSuccess ? Icons.check_circle : Icons.warning_amber,
                              color: _printSuccess ? Colors.green.shade700 : Colors.orange.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _printMessage!,
                                style: TextStyle(color: _printSuccess ? Colors.green.shade700 : Colors.orange.shade700, fontSize: 12),
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

            // Botão fechar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
              child: ElevatedButton(
                onPressed: widget.onClose,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Nova Venda', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoyaltyChip({required IconData icon, required Color color, required String label, required String sublabel}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        Text(sublabel, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
      ],
    );
  }

}
