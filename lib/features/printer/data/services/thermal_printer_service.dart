import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/printer/domain/entities/printer_config.dart';

/// Resultado da impressão
class PrintResult {
  const PrintResult({
    required this.success,
    this.message,
    this.error,
  });

  final bool success;
  final String? message;
  final String? error;

  factory PrintResult.ok([String? message]) => PrintResult(
        success: true,
        message: message ?? 'Impressão concluída',
      );

  factory PrintResult.fail(String error) => PrintResult(
        success: false,
        error: error,
      );
}

/// Serviço de impressão térmica
/// Suporta:
/// - Impressoras instaladas no Windows (via package printing)
/// - Impressoras de rede ESC/POS (via socket directo)
class ThermalPrinterService {
  ThermalPrinterService._();
  static final instance = ThermalPrinterService._();

  Socket? _socket;
  PrinterConfig? _config;
  List<Printer> _availablePrinters = [];

  // Comandos ESC/POS
  static const List<int> _cmdInit = [0x1B, 0x40];
  static const List<int> _cmdFeedAndCut = [0x1D, 0x56, 0x41, 0x03];
  static const List<int> _cmdAlignLeft = [0x1B, 0x61, 0x00];
  static const List<int> _cmdAlignCenter = [0x1B, 0x61, 0x01];
  static const List<int> _cmdAlignRight = [0x1B, 0x61, 0x02];
  static const List<int> _cmdBoldOn = [0x1B, 0x45, 0x01];
  static const List<int> _cmdBoldOff = [0x1B, 0x45, 0x00];
  static const List<int> _cmdDoubleHeight = [0x1B, 0x21, 0x10];
  static const List<int> _cmdDoubleSize = [0x1B, 0x21, 0x30];
  static const List<int> _cmdNormalSize = [0x1B, 0x21, 0x00];
  static const List<int> _cmdFeed1 = [0x0A];
  static const List<int> _cmdFeed3 = [0x1B, 0x64, 0x03];
  static const List<int> _cmdOpenDrawer = [0x1B, 0x70, 0x00, 0x19, 0xFA];

  void configure(PrinterConfig config) {
    _config = config;
    AppLogger.i('🖨️ Impressora configurada: ${config.name}');
  }

  PrinterConfig? get config => _config;
  bool get isConfigured => _config?.isConfigured ?? false;
  bool get isEnabled => _config?.isEnabled ?? false;

  /// Lista impressoras instaladas no sistema
  Future<List<Printer>> listPrinters() async {
    try {
      _availablePrinters = await Printing.listPrinters();
      AppLogger.d('🖨️ ${_availablePrinters.length} impressoras encontradas');
      for (final p in _availablePrinters) {
        AppLogger.d('   - ${p.name} (${p.url})');
      }
      return _availablePrinters;
    } catch (e) {
      AppLogger.e('Erro ao listar impressoras: $e');
      return [];
    }
  }

  Future<List<String>> listPrinterNames() async {
    final printers = await listPrinters();
    return printers.map((p) => p.name).toList();
  }

  Printer? getPrinterByName(String name) {
    try {
      return _availablePrinters.firstWhere((p) => p.name == name);
    } catch (e) {
      return null;
    }
  }

  Future<PrintResult> testConnection() async {
    if (_config == null || !_config!.isConfigured) {
      return PrintResult.fail('Impressora não configurada');
    }

    try {
      switch (_config!.connectionType) {
        case PrinterConnectionType.network:
          return await _testNetworkConnection();
        case PrinterConnectionType.usb:
          return await _testUsbConnection();
        case PrinterConnectionType.bluetooth:
          return PrintResult.fail('Bluetooth não suportado');
      }
    } catch (e) {
      return PrintResult.fail('Erro: $e');
    }
  }

  Future<PrintResult> _testNetworkConnection() async {
    try {
      final socket = await Socket.connect(
        _config!.address,
        _config!.port,
        timeout: const Duration(seconds: 5),
      );
      socket.add(Uint8List.fromList(_cmdInit));
      await socket.flush();
      await socket.close();
      return PrintResult.ok('Conexão de rede OK');
    } on SocketException catch (e) {
      return PrintResult.fail('Não foi possível conectar: ${e.message}');
    }
  }

  Future<PrintResult> _testUsbConnection() async {
    try {
      await listPrinters();
      final printer = getPrinterByName(_config!.name);
      if (printer != null) {
        return PrintResult.ok('Impressora encontrada: ${printer.name}');
      } else {
        final available = _availablePrinters.map((p) => p.name).join(', ');
        return PrintResult.fail(
          'Impressora "${_config!.name}" não encontrada.\nDisponíveis: $available'
        );
      }
    } catch (e) {
      return PrintResult.fail('Erro: $e');
    }
  }

  Future<PrintResult> printTestPage() async {
    if (_config == null || !_config!.isConfigured) {
      return PrintResult.fail('Impressora não configurada');
    }

    switch (_config!.connectionType) {
      case PrinterConnectionType.network:
        return await _printNetwork(_buildTestPageEscPos());
      case PrinterConnectionType.usb:
        return await _printTestPagePdf();
      case PrinterConnectionType.bluetooth:
        return PrintResult.fail('Bluetooth não suportado');
    }
  }

  Future<PrintResult> _printTestPagePdf() async {
    try {
      final pdf = pw.Document();
      final width = _config!.paperWidth == 58 ? 58.0 : 80.0;
      final now = DateTime.now();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(width * PdfPageFormat.mm, 200 * PdfPageFormat.mm, marginAll: 3 * PdfPageFormat.mm),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('TESTE DE IMPRESSAO', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.Text('Impressora: ${_config!.name}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Tipo: USB/Instalada', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Largura: ${_config!.paperWidth}mm', style: const pw.TextStyle(fontSize: 9)),
              pw.Divider(),
              pw.Text('${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute}', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 10),
              pw.Text('Impressora OK!', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      );

      return await _printPdfToUsbPrinter(await pdf.save(), 'Teste');
    } catch (e) {
      return PrintResult.fail('Erro: $e');
    }
  }

  List<int> _buildTestPageEscPos() {
    final bytes = <int>[];
    final width = _config!.charsPerLine;
    final now = DateTime.now();

    bytes.addAll(_cmdInit);
    bytes.addAll(_cmdAlignCenter);
    bytes.addAll(_cmdDoubleSize);
    bytes.addAll(_textToBytes('TESTE DE IMPRESSAO'));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_cmdNormalSize);
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_textToBytes('=' * width));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_cmdAlignLeft);
    bytes.addAll(_textToBytes('Impressora: ${_config!.name}'));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_textToBytes('Conexao: Rede'));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_textToBytes('IP: ${_config!.address}:${_config!.port}'));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_textToBytes('-' * width));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_textToBytes('${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute}'));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_textToBytes('=' * width));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_cmdAlignCenter);
    bytes.addAll(_cmdBoldOn);
    bytes.addAll(_textToBytes('Impressora OK!'));
    bytes.addAll(_cmdBoldOff);
    bytes.addAll(_cmdFeed3);
    bytes.addAll(_cmdFeedAndCut);

    return bytes;
  }

  Future<PrintResult> printReceipt({
    required String companyName,
    required String companyVat,
    required String companyAddress,
    required String documentType,
    required String documentNumber,
    required String date,
    required String time,
    required List<ReceiptItem> items,
    required double subtotal,
    required double taxTotal,
    required double total,
    required String paymentMethod,
    String? customerName,
    String? customerVat,
    String? atcud,
    String? qrCode,
    String? footerMessage,
    double globalDiscount = 0,
    double globalDiscountValue = 0,
    double itemsDiscountValue = 0,
  }) async {
    if (_config == null || !_config!.isEnabled) {
      return PrintResult.fail('Impressora não activa');
    }

    try {
      final params = _ReceiptParams(
        companyName: companyName,
        companyVat: companyVat,
        companyAddress: companyAddress,
        documentType: documentType,
        documentNumber: documentNumber,
        date: date,
        time: time,
        items: items,
        subtotal: subtotal,
        taxTotal: taxTotal,
        total: total,
        paymentMethod: paymentMethod,
        customerName: customerName,
        customerVat: customerVat,
        atcud: atcud,
        footerMessage: footerMessage,
        globalDiscount: globalDiscount,
        globalDiscountValue: globalDiscountValue,
        itemsDiscountValue: itemsDiscountValue,
      );

      PrintResult result;

      switch (_config!.connectionType) {
        case PrinterConnectionType.network:
          result = await _printNetwork(_buildReceiptEscPos(params));
          break;
        case PrinterConnectionType.usb:
          final pdfBytes = await _buildReceiptPdf(params);
          result = await _printPdfToUsbPrinter(pdfBytes, documentNumber);
          break;
        case PrinterConnectionType.bluetooth:
          return PrintResult.fail('Bluetooth não suportado');
      }

      if (result.success && _config!.printCopy) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (_config!.connectionType == PrinterConnectionType.network) {
          await _printNetwork(_buildReceiptEscPos(params));
        } else {
          final pdfBytes = await _buildReceiptPdf(params);
          await _printPdfToUsbPrinter(pdfBytes, '$documentNumber (cópia)');
        }
      }

      return result;
    } catch (e) {
      return PrintResult.fail('Erro: $e');
    }
  }

  Future<Uint8List> _buildReceiptPdf(_ReceiptParams p) async {
    final pdf = pw.Document();
    final width = _config!.paperWidth == 58 ? 58.0 : 80.0;
    final hasDiscount = p.itemsDiscountValue > 0 || p.globalDiscountValue > 0;
    final totalDiscount = p.itemsDiscountValue + p.globalDiscountValue;
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(width * PdfPageFormat.mm, double.infinity, marginAll: 3 * PdfPageFormat.mm),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Cabeçalho
            pw.Center(child: pw.Text(p.companyName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
            pw.Center(child: pw.Text('NIF: ${p.companyVat}', style: const pw.TextStyle(fontSize: 8))),
            pw.Center(child: pw.Text(p.companyAddress, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
            pw.SizedBox(height: 8),
            
            // Documento
            pw.Center(child: pw.Text(p.documentType, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
            pw.Center(child: pw.Text(p.documentNumber, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
            pw.Center(child: pw.Text('${p.date}  ${p.time}', style: const pw.TextStyle(fontSize: 8))),
            if (p.atcud != null) pw.Center(child: pw.Text('ATCUD: ${p.atcud}', style: const pw.TextStyle(fontSize: 8))),
            pw.Divider(thickness: 0.5),
            
            // Cliente
            if (p.customerName != null && p.customerName!.isNotEmpty) ...[
              pw.Text('Cliente: ${p.customerName}', style: const pw.TextStyle(fontSize: 8)),
              if (p.customerVat != null) pw.Text('NIF: ${p.customerVat}', style: const pw.TextStyle(fontSize: 8)),
              pw.Divider(thickness: 0.5),
            ],
            
            // Items
            ...p.items.map((item) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(item.name, style: const pw.TextStyle(fontSize: 9)),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('  ${item.quantity} x ${item.unitPrice.toStringAsFixed(2)} EUR', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('${item.total.toStringAsFixed(2)} EUR', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  if (item.hasDiscount)
                    pw.Text('  Desc. ${item.discount.toStringAsFixed(0)}%: -${item.discountValue.toStringAsFixed(2)} EUR', 
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.orange800)),
                ],
              ),
            )),
            
            pw.Divider(thickness: 0.5),
            
            // Totais
            _pdfRow('Subtotal:', '${(p.subtotal + totalDiscount).toStringAsFixed(2)} EUR'),
            if (hasDiscount) ...[
              _pdfRow('Descontos:', '-${totalDiscount.toStringAsFixed(2)} EUR', color: PdfColors.green800),
              _pdfRow('Subtotal Liq.:', '${p.subtotal.toStringAsFixed(2)} EUR'),
            ],
            _pdfRow('IVA:', '${p.taxTotal.toStringAsFixed(2)} EUR'),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text('${p.total.toStringAsFixed(2)} EUR', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            
            pw.Divider(thickness: 0.5),
            
            // Descontos detalhados
            if (hasDiscount) ...[
              pw.Center(child: pw.Text('DESCONTOS APLICADOS', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
              ...p.items.where((i) => i.hasDiscount).map((i) => pw.Text(
                '${i.name}: ${i.discount.toStringAsFixed(0)}% = -${i.discountValue.toStringAsFixed(2)} EUR',
                style: const pw.TextStyle(fontSize: 8),
              )),
              if (p.globalDiscount > 0)
                pw.Text('Desc. global ${p.globalDiscount.toStringAsFixed(0)}%: -${p.globalDiscountValue.toStringAsFixed(2)} EUR',
                  style: const pw.TextStyle(fontSize: 8)),
              _pdfRow('Total descontos:', '-${totalDiscount.toStringAsFixed(2)} EUR', bold: true),
              pw.Divider(thickness: 0.5),
            ],
            
            // Pagamento
            pw.Center(child: pw.Text('PAGAMENTO', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
            _pdfRow('Metodo:', p.paymentMethod),
            
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 8),
            
            // Rodapé
            pw.Center(child: pw.Text(p.footerMessage ?? 'Obrigado pela preferencia!', style: const pw.TextStyle(fontSize: 9))),
            pw.Center(child: pw.Text('Processado por computador', style: const pw.TextStyle(fontSize: 7))),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _pdfRow(String label, String value, {PdfColor? color, bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: 9,
      fontWeight: bold ? pw.FontWeight.bold : null,
      color: color,
    );
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(value, style: style),
      ],
    );
  }

  List<int> _buildReceiptEscPos(_ReceiptParams p) {
    final bytes = <int>[];
    final width = _config!.charsPerLine;
    final hasDiscount = p.itemsDiscountValue > 0 || p.globalDiscountValue > 0;
    final totalDiscount = p.itemsDiscountValue + p.globalDiscountValue;

    bytes.addAll(_cmdInit);

    // Cabeçalho
    bytes.addAll(_cmdAlignCenter);
    bytes.addAll(_cmdBoldOn);
    bytes.addAll(_cmdDoubleHeight);
    bytes.addAll(_textToBytes(p.companyName));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_cmdNormalSize);
    bytes.addAll(_cmdBoldOff);
    bytes.addAll(_textToBytes('NIF: ${p.companyVat}'));
    bytes.addAll(_cmdFeed1);
    for (final line in _wrapText(p.companyAddress, width)) {
      bytes.addAll(_textToBytes(line));
      bytes.addAll(_cmdFeed1);
    }
    bytes.addAll(_cmdFeed1);

    // Documento
    bytes.addAll(_cmdBoldOn);
    bytes.addAll(_cmdDoubleHeight);
    bytes.addAll(_textToBytes(p.documentType));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_cmdNormalSize);
    bytes.addAll(_textToBytes(p.documentNumber));
    bytes.addAll(_cmdBoldOff);
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_textToBytes('${p.date}  ${p.time}'));
    bytes.addAll(_cmdFeed1);
    if (p.atcud != null) {
      bytes.addAll(_textToBytes('ATCUD: ${p.atcud}'));
      bytes.addAll(_cmdFeed1);
    }
    bytes.addAll(_textToBytes('-' * width));
    bytes.addAll(_cmdFeed1);

    // Cliente
    if (p.customerName != null && p.customerName!.isNotEmpty) {
      bytes.addAll(_cmdAlignLeft);
      bytes.addAll(_textToBytes('Cliente: ${p.customerName}'));
      bytes.addAll(_cmdFeed1);
      if (p.customerVat != null) {
        bytes.addAll(_textToBytes('NIF: ${p.customerVat}'));
        bytes.addAll(_cmdFeed1);
      }
      bytes.addAll(_textToBytes('-' * width));
      bytes.addAll(_cmdFeed1);
    }

    // Items
    bytes.addAll(_cmdAlignLeft);
    for (final item in p.items) {
      for (final line in _wrapText(item.name, width - 10)) {
        bytes.addAll(_textToBytes(line));
        bytes.addAll(_cmdFeed1);
      }
      bytes.addAll(_textToBytes('  ${item.quantity} x ${_formatMoney(item.unitPrice)}'));
      bytes.addAll(_cmdFeed1);
      if (item.hasDiscount) {
        bytes.addAll(_textToBytes('  Desc. ${item.discount.toStringAsFixed(0)}%: -${_formatMoney(item.discountValue)}'));
        bytes.addAll(_cmdFeed1);
      }
      _addLine(bytes, '  Total:', _formatMoney(item.total), width);
    }
    bytes.addAll(_textToBytes('-' * width));
    bytes.addAll(_cmdFeed1);

    // Totais
    bytes.addAll(_cmdAlignRight);
    _addLine(bytes, 'Subtotal:', _formatMoney(p.subtotal + totalDiscount), width);
    if (hasDiscount) {
      _addLine(bytes, 'Descontos:', '-${_formatMoney(totalDiscount)}', width);
      _addLine(bytes, 'Subtotal Liq.:', _formatMoney(p.subtotal), width);
    }
    _addLine(bytes, 'IVA:', _formatMoney(p.taxTotal), width);
    bytes.addAll(_cmdBoldOn);
    bytes.addAll(_cmdDoubleHeight);
    final totalLabel = 'TOTAL:';
    final totalValue = _formatMoney(p.total);
    final spacesTotal = (width ~/ 2) - totalLabel.length - totalValue.length;
    bytes.addAll(_textToBytes('$totalLabel${' ' * spacesTotal}$totalValue'));
    bytes.addAll(_cmdNormalSize);
    bytes.addAll(_cmdBoldOff);
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_textToBytes('-' * width));
    bytes.addAll(_cmdFeed1);

    // Descontos detalhados
    if (hasDiscount) {
      bytes.addAll(_cmdAlignCenter);
      bytes.addAll(_cmdBoldOn);
      bytes.addAll(_textToBytes('DESCONTOS APLICADOS'));
      bytes.addAll(_cmdBoldOff);
      bytes.addAll(_cmdFeed1);
      bytes.addAll(_cmdAlignLeft);
      for (final item in p.items.where((i) => i.hasDiscount)) {
        final name = item.name.length > 20 ? '${item.name.substring(0, 20)}...' : item.name;
        bytes.addAll(_textToBytes(name));
        bytes.addAll(_cmdFeed1);
        bytes.addAll(_textToBytes('  ${item.discount.toStringAsFixed(0)}%: -${_formatMoney(item.discountValue)}'));
        bytes.addAll(_cmdFeed1);
      }
      if (p.globalDiscount > 0) {
        _addLine(bytes, 'Desc. global ${p.globalDiscount.toStringAsFixed(0)}%:', '-${_formatMoney(p.globalDiscountValue)}', width);
      }
      bytes.addAll(_cmdBoldOn);
      _addLine(bytes, 'Total descontos:', '-${_formatMoney(totalDiscount)}', width);
      bytes.addAll(_cmdBoldOff);
      bytes.addAll(_textToBytes('-' * width));
      bytes.addAll(_cmdFeed1);
    }

    // Pagamento
    bytes.addAll(_cmdAlignCenter);
    bytes.addAll(_cmdBoldOn);
    bytes.addAll(_textToBytes('PAGAMENTO'));
    bytes.addAll(_cmdBoldOff);
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_cmdAlignLeft);
    _addLine(bytes, 'Metodo:', p.paymentMethod, width);
    bytes.addAll(_textToBytes('=' * width));
    bytes.addAll(_cmdFeed1);

    // Rodapé
    bytes.addAll(_cmdAlignCenter);
    bytes.addAll(_textToBytes(p.footerMessage ?? 'Obrigado pela preferencia!'));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_textToBytes('Processado por computador'));
    bytes.addAll(_cmdFeed3);
    bytes.addAll(_cmdFeedAndCut);

    return bytes;
  }

  void _addLine(List<int> bytes, String label, String value, int width) {
    final spaces = width - label.length - value.length;
    bytes.addAll(_textToBytes('$label${' ' * (spaces > 0 ? spaces : 1)}$value'));
    bytes.addAll(_cmdFeed1);
  }

  Future<PrintResult> _printPdfToUsbPrinter(Uint8List pdfBytes, String documentName) async {
    try {
      if (_availablePrinters.isEmpty) await listPrinters();
      
      final printer = getPrinterByName(_config!.name);
      if (printer == null) {
        return PrintResult.fail('Impressora "${_config!.name}" não encontrada');
      }

      AppLogger.i('🖨️ Imprimindo "$documentName" em: ${printer.name}');

      final result = await Printing.directPrintPdf(
        printer: printer,
        onLayout: (format) async => pdfBytes,
        name: documentName,
      );

      return result ? PrintResult.ok() : PrintResult.fail('Impressão falhou');
    } catch (e) {
      return PrintResult.fail('Erro: $e');
    }
  }

  Future<PrintResult> openCashDrawer() async {
    if (_config == null || !_config!.isConfigured) {
      return PrintResult.fail('Impressora não configurada');
    }
    if (_config!.connectionType != PrinterConnectionType.network) {
      return PrintResult.fail('Gaveta só disponível em impressoras de rede');
    }

    try {
      final bytes = <int>[];
      bytes.addAll(_cmdInit);
      bytes.addAll(_cmdOpenDrawer);
      return await _printNetwork(bytes);
    } catch (e) {
      return PrintResult.fail('Erro: $e');
    }
  }

  Future<PrintResult> _printNetwork(List<int> data) async {
    try {
      _socket = await Socket.connect(_config!.address, _config!.port, timeout: const Duration(seconds: 10));
      _socket!.add(Uint8List.fromList(data));
      await _socket!.flush();
      await _socket!.close();
      _socket = null;
      AppLogger.i('✅ Impressão de rede concluída');
      return PrintResult.ok();
    } on SocketException catch (e) {
      return PrintResult.fail('Erro de conexão: ${e.message}');
    }
  }

  List<int> _textToBytes(String text) {
    return text
        .replaceAll('€', 'EUR')
        .replaceAll('á', 'a').replaceAll('à', 'a').replaceAll('ã', 'a').replaceAll('â', 'a')
        .replaceAll('é', 'e').replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o').replaceAll('ô', 'o').replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c')
        .replaceAll('Á', 'A').replaceAll('À', 'A').replaceAll('Ã', 'A').replaceAll('Â', 'A')
        .replaceAll('É', 'E').replaceAll('Ê', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O').replaceAll('Ô', 'O').replaceAll('Õ', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ç', 'C')
        .codeUnits;
  }

  String _formatMoney(double value) => '${value.toStringAsFixed(2)} EUR';

  List<String> _wrapText(String text, int maxWidth) {
    if (text.length <= maxWidth) return [text];
    final lines = <String>[];
    var remaining = text;
    while (remaining.length > maxWidth) {
      var breakPoint = remaining.lastIndexOf(' ', maxWidth);
      if (breakPoint == -1) breakPoint = maxWidth;
      lines.add(remaining.substring(0, breakPoint).trim());
      remaining = remaining.substring(breakPoint).trim();
    }
    if (remaining.isNotEmpty) lines.add(remaining);
    return lines;
  }
}

class _ReceiptParams {
  final String companyName, companyVat, companyAddress, documentType, documentNumber, date, time, paymentMethod;
  final List<ReceiptItem> items;
  final double subtotal, taxTotal, total, globalDiscount, globalDiscountValue, itemsDiscountValue;
  final String? customerName, customerVat, atcud, footerMessage;

  _ReceiptParams({
    required this.companyName, required this.companyVat, required this.companyAddress,
    required this.documentType, required this.documentNumber, required this.date, required this.time,
    required this.items, required this.subtotal, required this.taxTotal, required this.total,
    required this.paymentMethod, this.customerName, this.customerVat, this.atcud, this.footerMessage,
    this.globalDiscount = 0, this.globalDiscountValue = 0, this.itemsDiscountValue = 0,
  });
}

class ReceiptItem {
  final String name;
  final double quantity, unitPrice, total, taxRate, discount;

  const ReceiptItem({
    required this.name, required this.quantity, required this.unitPrice, required this.total,
    this.taxRate = 23, this.discount = 0,
  });

  bool get hasDiscount => discount > 0;
  double get discountValue => (quantity * unitPrice) * (discount / 100);
}
