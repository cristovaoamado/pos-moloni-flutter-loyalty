import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/checkout/domain/entities/document.dart';
import 'package:pos_moloni_app/features/cart/domain/entities/cart_item.dart';
import 'package:pos_moloni_app/features/customers/domain/entities/customer.dart';

/// Serviço de impressão multiplataforma (foco em Windows)
class PrintService {
  /// Imprime um documento PDF
  static Future<bool> printPdf(Uint8List pdfBytes, {String? documentName}) async {
    try {
      AppLogger.i('🖨️ Iniciando impressão...');

      // Usar o package printing para impressão multiplataforma
      final result = await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: documentName ?? 'Documento',
      );

      if (result) {
        AppLogger.i('✅ Documento enviado para impressão');
      } else {
        AppLogger.w('⚠️ Impressão cancelada ou falhou');
      }

      return result;
    } catch (e) {
      AppLogger.e('❌ Erro na impressão', error: e);
      return false;
    }
  }

  /// Abre diálogo de impressão com preview
  static Future<bool> printWithPreview(Uint8List pdfBytes, {String? documentName}) async {
    try {
      AppLogger.i('🖨️ Abrindo preview de impressão...');

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: '${documentName ?? 'documento'}.pdf',
      );

      return true;
    } catch (e) {
      AppLogger.e('❌ Erro ao abrir preview', error: e);
      return false;
    }
  }

  /// Lista impressoras disponíveis
  static Future<List<Printer>> getAvailablePrinters() async {
    try {
      final printers = await Printing.listPrinters();
      AppLogger.d('🖨️ ${printers.length} impressoras encontradas');
      return printers;
    } catch (e) {
      AppLogger.e('Erro ao listar impressoras', error: e);
      return [];
    }
  }

  /// Imprime directamente numa impressora específica
  static Future<bool> printToPrinter(
    Uint8List pdfBytes,
    Printer printer, {
    String? documentName,
  }) async {
    try {
      AppLogger.i('🖨️ Imprimindo em: ${printer.name}');

      final result = await Printing.directPrintPdf(
        printer: printer,
        onLayout: (format) async => pdfBytes,
        name: documentName ?? 'Documento',
      );

      if (result) {
        AppLogger.i('✅ Impresso com sucesso');
      }

      return result;
    } catch (e) {
      AppLogger.e('❌ Erro ao imprimir', error: e);
      return false;
    }
  }

  /// Gera um recibo/talão simples em PDF
  static Future<Uint8List> generateReceipt({
    required Document document,
    required List<CartItem> items,
    required Customer customer,
    String? companyName,
    String? companyVat,
    String? companyAddress,
  }) async {
    final pdf = pw.Document();

    // Configuração para talão (largura típica de 80mm)
    const pageFormat = PdfPageFormat(
      80 * PdfPageFormat.mm,
      double.infinity, // Altura automática
      marginAll: 5 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Cabeçalho - Empresa
              if (companyName != null)
                pw.Center(
                  child: pw.Text(
                    companyName,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              if (companyVat != null)
                pw.Center(
                  child: pw.Text('NIF: $companyVat', style: const pw.TextStyle(fontSize: 8)),
                ),
              if (companyAddress != null)
                pw.Center(
                  child: pw.Text(companyAddress, style: const pw.TextStyle(fontSize: 8)),
                ),

              pw.SizedBox(height: 10),
              pw.Divider(),

              // Tipo e número do documento
              pw.Center(
                child: pw.Text(
                  document.number,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  document.formattedDate,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),

              pw.SizedBox(height: 8),

              // Cliente
              pw.Text(
                'Cliente: ${customer.name}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              if (customer.vat.isNotEmpty && customer.vat != '999999990')
                pw.Text(
                  'NIF: ${customer.vat}',
                  style: const pw.TextStyle(fontSize: 9),
                ),

              pw.SizedBox(height: 8),
              pw.Divider(),

              // Itens
              ...items.map((item) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          flex: 3,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                item.name,
                                style: const pw.TextStyle(fontSize: 9),
                              ),
                              pw.Text(
                                '${item.formattedQuantity} x ${item.unitPrice.toStringAsFixed(2)}€',
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                            ],
                          ),
                        ),
                        pw.Text(
                          '${item.total.toStringAsFixed(2)}€',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),),

              pw.SizedBox(height: 8),
              pw.Divider(),

              // Totais
              _buildTotalRow('Subtotal', document.netValue),
              _buildTotalRow('IVA', document.taxValue),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${document.grossValue.toStringAsFixed(2)}€',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 8),
              pw.Divider(),

              // Pagamentos
              if (document.payments.isNotEmpty) ...[
                pw.Text(
                  'Pagamento:',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                ...document.payments.map((p) => pw.Text(
                      '${p.paymentMethodName}: ${p.value.toStringAsFixed(2)}€',
                      style: const pw.TextStyle(fontSize: 9),
                    ),),
                pw.SizedBox(height: 8),
              ],

              // Rodapé
              pw.Center(
                child: pw.Text(
                  'Obrigado pela preferência!',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Processado por computador',
                  style: const pw.TextStyle(fontSize: 7),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildTotalRow(String label, double value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        pw.Text('${value.toStringAsFixed(2)}€', style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  /// Guarda PDF em ficheiro
  static Future<String> savePdfToFile(Uint8List pdfBytes, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName.pdf');
    await file.writeAsBytes(pdfBytes);
    AppLogger.d('📄 PDF guardado: ${file.path}');
    return file.path;
  }

  /// Abre PDF no visualizador padrão do sistema (Windows)
  static Future<bool> openPdf(String filePath) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', filePath]);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', [filePath]);
        return true;
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [filePath]);
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.e('Erro ao abrir PDF', error: e);
      return false;
    }
  }

  /// Abre PDF a partir de bytes (guarda temporariamente e abre)
  static Future<bool> openPdfFromBytes(Uint8List pdfBytes, String fileName) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);
      return await openPdf(filePath);
    } catch (e) {
      AppLogger.e('Erro ao abrir PDF', error: e);
      return false;
    }
  }
}
