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

  factory PrintResult.ok([String? message]) => PrintResult(
        success: true,
        message: message ?? 'Impressão concluída',
      );

  factory PrintResult.fail(String error) => PrintResult(
        success: false,
        error: error,
      );

  final bool success;
  final String? message;
  final String? error;
}

/// Item do talão
class ReceiptItem {
  const ReceiptItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.taxRate,
    this.discount = 0,
    this.unit = 'un',
  });

  final String name;
  final double quantity;
  final double unitPrice;
  final double total;
  final double taxRate;
  final double discount;
  final String unit;
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
  static const List<int> _cmdInit = [0x1B, 0x40]; // ESC @ - Initialize
  static const List<int> _cmdFeedAndCut = [0x1D, 0x56, 0x41, 0x03]; // Feed and cut
  static const List<int> _cmdAlignLeft = [0x1B, 0x61, 0x00]; // ESC a 0
  static const List<int> _cmdAlignCenter = [0x1B, 0x61, 0x01]; // ESC a 1
  static const List<int> _cmdAlignRight = [0x1B, 0x61, 0x02]; // ESC a 2
  static const List<int> _cmdBoldOn = [0x1B, 0x45, 0x01]; // ESC E 1
  static const List<int> _cmdBoldOff = [0x1B, 0x45, 0x00]; // ESC E 0
  static const List<int> _cmdDoubleHeight = [0x1B, 0x21, 0x10]; // ESC ! 16
  static const List<int> _cmdDoubleSize = [0x1B, 0x21, 0x30]; // ESC ! 48
  static const List<int> _cmdNormalSize = [0x1B, 0x21, 0x00]; // ESC ! 0
  static const List<int> _cmdFeed1 = [0x0A]; // Line feed
  static const List<int> _cmdFeed3 = [0x1B, 0x64, 0x03]; // ESC d 3 - Feed 3 lines
  
  // Comandos de abertura de gaveta para EPSON TM-T20II
  // ESC p m t1 t2: m=pino(0/1), t1=ON time, t2=OFF time
  // Tempos: t1*2ms ON, t2*2ms OFF
  // Pino 2 (conector drawer kick) - m=0
  static const List<int> _cmdOpenDrawerPin2 = [0x1B, 0x70, 0x00, 0x19, 0xFA]; // ESC p 0 25 250
  // Pino 5 (alternativo) - m=1
  static const List<int> _cmdOpenDrawerPin5 = [0x1B, 0x70, 0x01, 0x19, 0xFA]; // ESC p 1 25 250

  /// Configura a impressora
  void configure(PrinterConfig config) {
    _config = config;
    AppLogger.i('🖨️ Impressora configurada: ${config.name}');
  }

  /// Obtém a configuração actual
  PrinterConfig? get config => _config;

  /// Verifica se está configurada
  bool get isConfigured => _config?.isConfigured ?? false;

  /// Verifica se está activa
  bool get isEnabled => _config?.isEnabled ?? false;

  /// Lista impressoras disponíveis (instaladas no sistema)
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

  /// Obtém nomes das impressoras disponíveis
  Future<List<String>> listPrinterNames() async {
    final printers = await listPrinters();
    return printers.map((p) => p.name).toList();
  }

  /// Obtém impressora por nome
  Printer? getPrinterByName(String name) {
    try {
      return _availablePrinters.firstWhere(
        (p) => p.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Testa a conexão com a impressora
  Future<PrintResult> testConnection() async {
    if (_config == null || !_config!.isConfigured) {
      return PrintResult.fail('Impressora não configurada');
    }

    if (_config!.connectionType == PrinterConnectionType.network) {
      return await _testNetworkConnection();
    } else {
      return await _testUsbConnection();
    }
  }

  Future<PrintResult> _testNetworkConnection() async {
    try {
      _socket = await Socket.connect(
        _config!.address,
        _config!.port,
        timeout: const Duration(seconds: 5),
      );
      await _socket!.close();
      _socket = null;
      return PrintResult.ok('Conexão de rede OK');
    } on SocketException catch (e) {
      return PrintResult.fail('Falha na conexão: ${e.message}');
    } catch (e) {
      return PrintResult.fail('Erro: $e');
    }
  }

  Future<PrintResult> _testUsbConnection() async {
    try {
      final printers = await listPrinters();
      final printer = printers.firstWhere(
        (p) => p.name.toLowerCase() == _config!.name.toLowerCase(),
        orElse: () => throw Exception('Impressora não encontrada'),
      );
      
      if (printer.isAvailable) {
        return PrintResult.ok('Impressora USB disponível: ${printer.name}');
      } else {
        return PrintResult.fail('Impressora USB não disponível');
      }
    } catch (e) {
      return PrintResult.fail('Erro: $e');
    }
  }

  /// Imprime página de teste
  Future<PrintResult> printTestPage() async {
    if (_config == null || !_config!.isConfigured) {
      return PrintResult.fail('Impressora não configurada');
    }

    if (_config!.connectionType == PrinterConnectionType.network) {
      return await _printTestPageNetwork();
    } else {
      return await _printTestPageUsb();
    }
  }

  Future<PrintResult> _printTestPageNetwork() async {
    final bytes = <int>[];
    bytes.addAll(_cmdInit);
    bytes.addAll(_cmdAlignCenter);
    bytes.addAll(_cmdDoubleSize);
    bytes.addAll(_textToBytes('TESTE'));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_cmdNormalSize);
    bytes.addAll(_textToBytes('POS Moloni App'));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_textToBytes('------------------------'));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_cmdAlignLeft);
    bytes.addAll(_textToBytes('Impressora: ${_config!.name}'));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_textToBytes('IP: ${_config!.address}'));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_textToBytes('Porta: ${_config!.port}'));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_textToBytes('Largura: ${_config!.paperWidth}mm'));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_textToBytes('------------------------'));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_cmdAlignCenter);
    bytes.addAll(_textToBytes('Teste OK!'));
    bytes.addAll(_cmdFeed3);
    bytes.addAll(_cmdFeedAndCut);

    return await _printNetwork(bytes);
  }

  Future<PrintResult> _printTestPageUsb() async {
    try {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('TESTE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('POS Moloni App'),
                pw.SizedBox(height: 8),
                pw.Text('------------------------'),
                pw.Text('Impressora: ${_config!.name}'),
                pw.Text('Tipo: USB'),
                pw.Text('Largura: ${_config!.paperWidth}mm'),
                pw.Text('------------------------'),
                pw.SizedBox(height: 8),
                pw.Text('Teste OK!'),
              ],
            );
          },
        ),
      );

      final pdfBytes = await doc.save();
      return await _printPdfUsb(pdfBytes);
    } catch (e) {
      return PrintResult.fail('Erro ao criar PDF de teste: $e');
    }
  }

  /// Imprime PDF
  Future<PrintResult> printPdf(Uint8List pdfBytes) async {
    if (_config == null || !_config!.isConfigured) {
      return PrintResult.fail('Impressora não configurada');
    }

    if (_config!.connectionType == PrinterConnectionType.usb) {
      return await _printPdfUsb(pdfBytes);
    } else {
      return await _printPdfUsb(pdfBytes);
    }
  }

  Future<PrintResult> _printPdfUsb(Uint8List pdfBytes) async {
    try {
      final printers = await listPrinters();
      final printer = printers.firstWhere(
        (p) => p.name.toLowerCase() == _config!.name.toLowerCase(),
        orElse: () => throw Exception('Impressora "${_config!.name}" não encontrada'),
      );

      final result = await Printing.directPrintPdf(
        printer: printer,
        onLayout: (_) async => pdfBytes,
        name: 'Talão POS',
      );

      if (result) {
        return PrintResult.ok('Impressão enviada');
      } else {
        return PrintResult.fail('Falha ao enviar impressão');
      }
    } catch (e) {
      AppLogger.e('Erro ao imprimir PDF USB: $e');
      return PrintResult.fail('Erro: $e');
    }
  }

  /// Abre a gaveta de dinheiro
  /// Para EPSON TM-T20II via USB no Windows
  Future<PrintResult> openCashDrawer() async {
    if (_config == null || !_config!.isConfigured) {
      return PrintResult.fail('Impressora não configurada');
    }

    AppLogger.i('🗄️ Tentando abrir gaveta via ${_config!.connectionType.name}...');
    AppLogger.i('🗄️ Impressora: ${_config!.name}');

    if (_config!.connectionType == PrinterConnectionType.network) {
      return await _openDrawerNetwork();
    } else {
      return await _openDrawerUsb();
    }
  }

  /// Abre gaveta via impressora de rede (ESC/POS directo)
  Future<PrintResult> _openDrawerNetwork() async {
    try {
      final bytes = <int>[];
      bytes.addAll(_cmdInit);
      bytes.addAll(_cmdOpenDrawerPin2);

      return await _printNetwork(bytes);
    } catch (e) {
      return PrintResult.fail('Erro ao abrir gaveta: $e');
    }
  }

  /// Abre gaveta via impressora USB no Windows
  /// IMPLEMENTAÇÃO SIMPLES: Usa ficheiro temporário + copy /b
  Future<PrintResult> _openDrawerUsb() async {
    if (!Platform.isWindows) {
      return PrintResult.fail('Abertura de gaveta USB só suportada no Windows');
    }

    final printerName = _config!.name;
    AppLogger.i('🗄️ Abrindo gaveta USB: $printerName');

    // Tentar primeiro o pino 2, depois o pino 5
    var result = await _sendRawBytesToPrinter(printerName, [
      ..._cmdInit,
      ..._cmdOpenDrawerPin2,
    ]);

    if (result.success) {
      AppLogger.i('✅ Gaveta aberta (pino 2)');
      return result;
    }

    AppLogger.w('Pino 2 falhou: ${result.error}, tentando pino 5...');
    
    result = await _sendRawBytesToPrinter(printerName, [
      ..._cmdInit,
      ..._cmdOpenDrawerPin5,
    ]);

    if (result.success) {
      AppLogger.i('✅ Gaveta aberta (pino 5)');
      return result;
    }

    AppLogger.e('❌ Ambos os pinos falharam: ${result.error}');
    return PrintResult.fail('Não foi possível abrir a gaveta: ${result.error}');
  }

  /// Envia bytes RAW directamente para a impressora Windows
  /// Cria um script PowerShell temporário para evitar problemas de escape
  Future<PrintResult> _sendRawBytesToPrinter(String printerName, List<int> bytes) async {
    try {
      AppLogger.d('🗄️ Impressora: $printerName');
      AppLogger.d('🗄️ Bytes a enviar: ${bytes.length}');
      
      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Criar ficheiro com os bytes
      final dataFile = File('${tempDir.path}\\drawer_data_$timestamp.bin');
      await dataFile.writeAsBytes(bytes, flush: true);
      AppLogger.d('🗄️ Dados: ${dataFile.path}');
      
      // Criar script PowerShell
      final scriptFile = File('${tempDir.path}\\drawer_script_$timestamp.ps1');
      final scriptContent = '''
\$ErrorActionPreference = "SilentlyContinue"
\$printerName = "$printerName"
\$dataPath = "${dataFile.path.replaceAll('\\', '\\\\')}"

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public class RawPrint {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public class DOCINFO {
        [MarshalAs(UnmanagedType.LPWStr)] public string pDocName;
        [MarshalAs(UnmanagedType.LPWStr)] public string pOutputFile;
        [MarshalAs(UnmanagedType.LPWStr)] public string pDataType;
    }

    [DllImport("winspool.drv", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool OpenPrinter(string pPrinterName, out IntPtr phPrinter, IntPtr pDefault);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool ClosePrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool StartDocPrinter(IntPtr hPrinter, int Level, [In] DOCINFO pDocInfo);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool EndDocPrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool StartPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool EndPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool WritePrinter(IntPtr hPrinter, byte[] pBytes, int dwCount, out int dwWritten);
}
'@

\$data = [System.IO.File]::ReadAllBytes(\$dataPath)

\$hPrinter = [IntPtr]::Zero
if (-not [RawPrint]::OpenPrinter(\$printerName, [ref]\$hPrinter, [IntPtr]::Zero)) {
    Write-Output "FAIL:OpenPrinter"
    exit 1
}

\$di = New-Object RawPrint+DOCINFO
\$di.pDocName = "ESC/POS"
\$di.pDataType = "RAW"

if (-not [RawPrint]::StartDocPrinter(\$hPrinter, 1, \$di)) {
    [RawPrint]::ClosePrinter(\$hPrinter)
    Write-Output "FAIL:StartDocPrinter"
    exit 1
}

if (-not [RawPrint]::StartPagePrinter(\$hPrinter)) {
    [RawPrint]::EndDocPrinter(\$hPrinter)
    [RawPrint]::ClosePrinter(\$hPrinter)
    Write-Output "FAIL:StartPagePrinter"
    exit 1
}

\$written = 0
if (-not [RawPrint]::WritePrinter(\$hPrinter, \$data, \$data.Length, [ref]\$written)) {
    [RawPrint]::EndPagePrinter(\$hPrinter)
    [RawPrint]::EndDocPrinter(\$hPrinter)
    [RawPrint]::ClosePrinter(\$hPrinter)
    Write-Output "FAIL:WritePrinter"
    exit 1
}

[RawPrint]::EndPagePrinter(\$hPrinter)
[RawPrint]::EndDocPrinter(\$hPrinter)
[RawPrint]::ClosePrinter(\$hPrinter)

Write-Output "SUCCESS:\$written"
''';
      
      await scriptFile.writeAsString(scriptContent, flush: true);
      AppLogger.d('🗄️ Script: ${scriptFile.path}');
      
      // Executar script
      AppLogger.d('🗄️ Executando script PowerShell...');
      
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', scriptFile.path],
        runInShell: true,
      );
      
      final stdout = result.stdout.toString().trim();
      final stderr = result.stderr.toString().trim();
      
      AppLogger.d('🗄️ stdout: $stdout');
      if (stderr.isNotEmpty) {
        AppLogger.d('🗄️ stderr: $stderr');
      }
      AppLogger.d('🗄️ exitCode: ${result.exitCode}');
      
      // Limpar ficheiros temporários
      try {
        await dataFile.delete();
        await scriptFile.delete();
      } catch (_) {}
      
      if (stdout.startsWith('SUCCESS')) {
        return PrintResult.ok('${stdout.substring(8)} bytes enviados');
      } else if (stdout.startsWith('FAIL:')) {
        return PrintResult.fail(stdout.substring(5));
      } else {
        return PrintResult.fail('Erro: $stdout $stderr');
      }
    } catch (e) {
      AppLogger.e('❌ Erro: $e');
      return PrintResult.fail('Erro: $e');
    }
  }

  /// Imprime via rede (ESC/POS)
  Future<PrintResult> _printNetwork(List<int> data) async {
    try {
      _socket = await Socket.connect(
        _config!.address,
        _config!.port,
        timeout: const Duration(seconds: 10),
      );

      _socket!.add(Uint8List.fromList(data));
      await _socket!.flush();
      await _socket!.close();
      _socket = null;

      AppLogger.i('✅ Impressão de rede concluída');
      return PrintResult.ok();
    } on SocketException catch (e) {
      AppLogger.e('❌ Erro de socket: $e');
      return PrintResult.fail('Erro de conexão: ${e.message}');
    } catch (e) {
      return PrintResult.fail('Erro: $e');
    }
  }

  /// Converte texto para bytes (com suporte a caracteres portugueses)
  List<int> _textToBytes(String text) {
    // Codepage 860 (Português) - mapeamento básico
    final map = <String, int>{
      'á': 0xA0, 'à': 0x85, 'â': 0x83, 'ã': 0xC6,
      'é': 0x82, 'è': 0x8A, 'ê': 0x88,
      'í': 0xA1, 'ì': 0x8D,
      'ó': 0xA2, 'ò': 0x95, 'ô': 0x93, 'õ': 0xE4,
      'ú': 0xA3, 'ù': 0x97,
      'ç': 0x87,
      'Á': 0xB5, 'À': 0xB7, 'Â': 0xB6, 'Ã': 0xC7,
      'É': 0x90, 'È': 0xD4, 'Ê': 0xD2,
      'Í': 0xD6, 'Ì': 0xDE,
      'Ó': 0xE0, 'Ò': 0xE3, 'Ô': 0xE2, 'Õ': 0xE5,
      'Ú': 0xE9, 'Ù': 0xEB,
      'Ç': 0x80,
      '€': 0xEE,
    };

    final bytes = <int>[];
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (map.containsKey(char)) {
        bytes.add(map[char]!);
      } else {
        final code = char.codeUnitAt(0);
        bytes.add(code < 256 ? code : 0x3F); // ? para caracteres não suportados
      }
    }
    return bytes;
  }

  /// Imprime talão completo
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
    if (_config == null || !_config!.isConfigured) {
      return PrintResult.fail('Impressora não configurada');
    }

    if (_config!.connectionType == PrinterConnectionType.network) {
      return await _printReceiptNetwork(
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
        qrCode: qrCode,
        footerMessage: footerMessage,
        globalDiscount: globalDiscount,
        globalDiscountValue: globalDiscountValue,
        itemsDiscountValue: itemsDiscountValue,
      );
    } else {
      return await _printReceiptUsb(
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
        qrCode: qrCode,
        footerMessage: footerMessage,
        globalDiscount: globalDiscount,
        globalDiscountValue: globalDiscountValue,
        itemsDiscountValue: itemsDiscountValue,
      );
    }
  }

  /// Imprime talão via rede (ESC/POS)
  Future<PrintResult> _printReceiptNetwork({
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
    final width = _config!.charsPerLine;
    final bytes = <int>[];

    bytes.addAll(_cmdInit);
    bytes.addAll(_cmdAlignCenter);

    // Cabeçalho
    bytes.addAll(_cmdBoldOn);
    bytes.addAll(_textToBytes(companyName));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_cmdBoldOff);
    bytes.addAll(_textToBytes('NIF: $companyVat'));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_textToBytes(companyAddress));
    bytes.addAll(_cmdFeed1);

    bytes.addAll(_textToBytes(_line(width)));
    bytes.addAll(_cmdFeed1);

    // Documento
    bytes.addAll(_cmdDoubleHeight);
    bytes.addAll(_cmdBoldOn);
    bytes.addAll(_textToBytes('$documentType $documentNumber'));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_cmdNormalSize);
    bytes.addAll(_cmdBoldOff);

    bytes.addAll(_textToBytes('$date $time'));
    bytes.addAll(_cmdFeed1);

    if (atcud != null && atcud.isNotEmpty) {
      bytes.addAll(_textToBytes('ATCUD: $atcud'));
      bytes.addAll(_cmdFeed1);
    }

    bytes.addAll(_textToBytes(_line(width)));
    bytes.addAll(_cmdFeed1);

    // Cliente
    if (customerName != null && customerName.isNotEmpty) {
      bytes.addAll(_cmdAlignLeft);
      bytes.addAll(_textToBytes('Cliente: $customerName'));
      bytes.addAll(_cmdFeed1);
      if (customerVat != null && customerVat.isNotEmpty) {
        bytes.addAll(_textToBytes('NIF: $customerVat'));
        bytes.addAll(_cmdFeed1);
      }
      bytes.addAll(_textToBytes(_line(width)));
      bytes.addAll(_cmdFeed1);
    }

    // Itens
    bytes.addAll(_cmdAlignLeft);
    for (final item in items) {
      bytes.addAll(_textToBytes(_truncate(item.name, width)));
      bytes.addAll(_cmdFeed1);

      final qtyStr = '  ${_formatQty(item.quantity, item.unit)} x ${item.unitPrice.toStringAsFixed(2)}';
      final totalStr = item.total.toStringAsFixed(2);
      final spaces = width - qtyStr.length - totalStr.length;
      bytes.addAll(_textToBytes('$qtyStr${' ' * (spaces > 0 ? spaces : 1)}$totalStr'));
      bytes.addAll(_cmdFeed1);

      if (item.discount > 0) {
        final discStr = '    Desc. ${item.discount.toStringAsFixed(0)}%';
        final discVal = '-${(item.total * item.discount / 100).toStringAsFixed(2)}';
        final discSpaces = width - discStr.length - discVal.length;
        bytes.addAll(_textToBytes('$discStr${' ' * (discSpaces > 0 ? discSpaces : 1)}$discVal'));
        bytes.addAll(_cmdFeed1);
      }
    }

    bytes.addAll(_textToBytes(_line(width)));
    bytes.addAll(_cmdFeed1);

    // Totais
    bytes.addAll(_cmdAlignRight);

    if (globalDiscountValue > 0 || itemsDiscountValue > 0) {
      _addLine(bytes, 'Subtotal', '${subtotal.toStringAsFixed(2)} EUR', width);
    }

    if (itemsDiscountValue > 0) {
      _addLine(bytes, 'Desc. artigos', '-${itemsDiscountValue.toStringAsFixed(2)} EUR', width);
    }

    if (globalDiscountValue > 0) {
      _addLine(bytes, 'Desc. ${globalDiscount.toStringAsFixed(0)}%', '-${globalDiscountValue.toStringAsFixed(2)} EUR', width);
    }

    _addLine(bytes, 'IVA', '${taxTotal.toStringAsFixed(2)} EUR', width);

    bytes.addAll(_cmdBoldOn);
    bytes.addAll(_cmdDoubleHeight);
    _addLine(bytes, 'TOTAL', '${total.toStringAsFixed(2)} EUR', width);
    bytes.addAll(_cmdNormalSize);
    bytes.addAll(_cmdBoldOff);

    bytes.addAll(_cmdFeed1);
    bytes.addAll(_textToBytes(_line(width)));
    bytes.addAll(_cmdFeed1);

    // Pagamento
    bytes.addAll(_cmdAlignCenter);
    bytes.addAll(_textToBytes('Pagamento: $paymentMethod'));
    bytes.addAll(_cmdFeed1);

    // Rodapé
    bytes.addAll(_cmdFeed1);
    if (footerMessage != null && footerMessage.isNotEmpty) {
      bytes.addAll(_textToBytes(footerMessage));
      bytes.addAll(_cmdFeed1);
    }
    bytes.addAll(_textToBytes('Obrigado pela preferencia!'));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_textToBytes('Processado por computador'));
    bytes.addAll(_cmdFeed3);

    bytes.addAll(_cmdFeedAndCut);

    return await _printNetwork(bytes);
  }

  /// Imprime talão via USB (PDF)
  Future<PrintResult> _printReceiptUsb({
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
    try {
      final doc = pw.Document();
      final pageFormat = _config!.paperWidth == 58 
          ? PdfPageFormat.roll57 
          : PdfPageFormat.roll80;

      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(8),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(companyName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('NIF: $companyVat', style: const pw.TextStyle(fontSize: 10)),
                pw.Text(companyAddress, style: const pw.TextStyle(fontSize: 10)),
                pw.Divider(),
                
                pw.Text('$documentType $documentNumber', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text('$date $time', style: const pw.TextStyle(fontSize: 10)),
                if (atcud != null && atcud.isNotEmpty)
                  pw.Text('ATCUD: $atcud', style: const pw.TextStyle(fontSize: 10)),
                pw.Divider(),

                if (customerName != null && customerName.isNotEmpty) ...[
                  pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Cliente: $customerName', style: const pw.TextStyle(fontSize: 10)),
                        if (customerVat != null && customerVat.isNotEmpty)
                          pw.Text('NIF: $customerVat', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  pw.Divider(),
                ],

                ...items.map((item) => pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(item.name, style: const pw.TextStyle(fontSize: 10)),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('  ${_formatQty(item.quantity, item.unit)} x ${item.unitPrice.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                        pw.Text(item.total.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                    if (item.discount > 0)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('    Desc. ${item.discount.toStringAsFixed(0)}%', style: const pw.TextStyle(fontSize: 9)),
                          pw.Text('-${(item.total * item.discount / 100).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                  ],
                ),),
                pw.Divider(),

                if (globalDiscountValue > 0 || itemsDiscountValue > 0)
                  _pdfLine('Subtotal', '${subtotal.toStringAsFixed(2)} EUR'),
                if (itemsDiscountValue > 0)
                  _pdfLine('Desc. artigos', '-${itemsDiscountValue.toStringAsFixed(2)} EUR'),
                if (globalDiscountValue > 0)
                  _pdfLine('Desc. ${globalDiscount.toStringAsFixed(0)}%', '-${globalDiscountValue.toStringAsFixed(2)} EUR'),
                _pdfLine('IVA', '${taxTotal.toStringAsFixed(2)} EUR'),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('${total.toStringAsFixed(2)} EUR', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Divider(),

                pw.Text('Pagamento: $paymentMethod', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 8),

                if (footerMessage != null && footerMessage.isNotEmpty)
                  pw.Text(footerMessage, style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Obrigado pela preferencia!', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Processado por computador', style: const pw.TextStyle(fontSize: 8)),
              ],
            );
          },
        ),
      );

      final pdfBytes = await doc.save();
      return await _printPdfUsb(pdfBytes);
    } catch (e) {
      AppLogger.e('Erro ao criar PDF do talão: $e');
      return PrintResult.fail('Erro: $e');
    }
  }

  pw.Widget _pdfLine(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  String _line(int width) => '-' * width;

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  String _formatQty(double qty, String unit) {
    if (qty == qty.roundToDouble()) {
      return '${qty.toInt()} $unit';
    }
    return '${qty.toStringAsFixed(3)} $unit';
  }

  void _addLine(List<int> bytes, String label, String value, int width) {
    final spaces = width - label.length - value.length;
    bytes.addAll(_textToBytes('$label${' ' * (spaces > 0 ? spaces : 1)}$value'));
    bytes.addAll(_cmdFeed1);
  }

  /// Fecha conexões
  void dispose() {
    _socket?.destroy();
    _socket = null;
  }
}
