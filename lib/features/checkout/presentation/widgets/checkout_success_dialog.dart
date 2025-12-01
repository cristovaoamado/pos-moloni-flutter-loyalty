import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/checkout/domain/entities/document.dart';
import 'package:pos_moloni_app/features/checkout/presentation/providers/checkout_provider.dart';
import 'package:pos_moloni_app/features/checkout/services/print_service.dart';

/// Diálogo de sucesso após checkout
class CheckoutSuccessDialog extends ConsumerStatefulWidget {
  const CheckoutSuccessDialog({
    super.key,
    required this.document,
    required this.change,
    required this.onClose,
  });

  final Document document;
  final double change;
  final VoidCallback onClose;

  @override
  ConsumerState<CheckoutSuccessDialog> createState() => _CheckoutSuccessDialogState();
}

class _CheckoutSuccessDialogState extends ConsumerState<CheckoutSuccessDialog> {
  bool _isPrinting = false;
  bool _isOpening = false;
  String? _printError;

  Future<void> _printDocument() async {
    final checkoutState = ref.read(checkoutProvider);
    
    if (checkoutState.pdfBytes == null) {
      setState(() => _printError = 'PDF não disponível');
      return;
    }

    setState(() {
      _isPrinting = true;
      _printError = null;
    });

    try {
      final success = await PrintService.printPdf(
        checkoutState.pdfBytes!,
        documentName: widget.document.number,
      );

      if (!success && mounted) {
        setState(() => _printError = 'Impressão cancelada');
      }
    } catch (e) {
      AppLogger.e('Erro ao imprimir', error: e);
      if (mounted) {
        setState(() => _printError = 'Erro ao imprimir: $e');
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
      setState(() => _printError = 'PDF não disponível');
      return;
    }

    setState(() {
      _isOpening = true;
      _printError = null;
    });

    try {
      await PrintService.openPdfFromBytes(
        checkoutState.pdfBytes!,
        'documento_${widget.document.id}',
      );
    } catch (e) {
      AppLogger.e('Erro ao abrir PDF', error: e);
      if (mounted) {
        setState(() => _printError = 'Erro ao abrir PDF');
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
    final hasPdf = checkoutState.pdfBytes != null;

    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header com ícone de sucesso
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.green,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Venda Concluída!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Detalhes do documento
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Número do documento
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Documento',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.document.number,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.document.formattedDate,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Total e troco
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          context,
                          'Total',
                          widget.document.formattedTotal,
                          Icons.receipt,
                        ),
                      ),
                      if (widget.change > 0) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoCard(
                            context,
                            'Troco',
                            '${widget.change.toStringAsFixed(2)} €',
                            Icons.money,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Botões de ação
                  Row(
                    children: [
                      // Botão de imprimir
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: hasPdf && !_isPrinting ? _printDocument : null,
                          icon: _isPrinting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.print),
                          label: Text(_isPrinting ? 'A imprimir...' : 'Imprimir'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Botão de ver PDF
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: hasPdf && !_isOpening ? _openPdf : null,
                          icon: _isOpening
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.visibility),
                          label: Text(_isOpening ? 'A abrir...' : 'Ver PDF'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
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
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'A carregar PDF...',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Erro de impressão
                  if (_printError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, 
                            color: Colors.orange.shade700, 
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _printError!,
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Botão fechar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: ElevatedButton(
                onPressed: widget.onClose,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Nova Venda'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (color ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color ?? Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
