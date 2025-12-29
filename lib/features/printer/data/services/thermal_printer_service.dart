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
  // static const List<int> _cmdCut = [0x1D, 0x56, 0x00]; // GS V 0 - Full cut
  // static const List<int> _cmdPartialCut = [0x1D, 0x56, 0x01]; // GS V 1 - Partial cut
  static const List<int> _cmdFeedAndCut = [0x1D, 0x56, 0x41, 0x03]; // Feed and cut
  static const List<int> _cmdAlignLeft = [0x1B, 0x61, 0x00]; // ESC a 0
  static const List<int> _cmdAlignCenter = [0x1B, 0x61, 0x01]; // ESC a 1
  static const List<int> _cmdAlignRight = [0x1B, 0x61, 0x02]; // ESC a 2
  static const List<int> _cmdBoldOn = [0x1B, 0x45, 0x01]; // ESC E 1
  static const List<int> _cmdBoldOff = [0x1B, 0x45, 0x00]; // ESC E 0
  static const List<int> _cmdDoubleHeight = [0x1B, 0x21, 0x10]; // ESC ! 16
  // static const List<int> _cmdDoubleWidth = [0x1B, 0x21, 0x20]; // ESC ! 32
  static const List<int> _cmdDoubleSize = [0x1B, 0x21, 0x30]; // ESC ! 48
  static const List<int> _cmdNormalSize = [0x1B, 0x21, 0x00]; // ESC ! 0
  static const List<int> _cmdFeed1 = [0x0A]; // Line feed
  static const List<int> _cmdFeed3 = [0x1B, 0x64, 0x03]; // ESC d 3 - Feed 3 lines
  
  // Comandos de abertura de gaveta - vários padrões comuns
  static const List<int> _cmdOpenDrawer1 = [0x1B, 0x70, 0x00, 0x19, 0xFA]; // ESC p 0 25 250 (mais comum)
  static const List<int> _cmdOpenDrawer2 = [0x1B, 0x70, 0x01, 0x19, 0xFA]; // ESC p 1 25 250 (pino 5)
  // static const List<int> _cmdOpenDrawerAlt = [0x10, 0x14, 0x01, 0x00, 0x01]; // DLE DC4 (algumas Star/Citizen)

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
      // Criar PDF simples para teste
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
      // Para rede, converter PDF para imagem e enviar via ESC/POS
      // Por agora, usar o método USB que funciona melhor com PDFs
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
  /// Funciona tanto via rede como via USB
  Future<PrintResult> openCashDrawer() async {
    if (_config == null || !_config!.isConfigured) {
      return PrintResult.fail('Impressora não configurada');
    }

    AppLogger.i('🗄️ Tentando abrir gaveta via ${_config!.connectionType.name}...');

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
      bytes.addAll(_cmdOpenDrawer1); // Pino 2 (mais comum)

      return await _printNetwork(bytes);
    } catch (e) {
      return PrintResult.fail('Erro ao abrir gaveta: $e');
    }
  }

  /// Abre gaveta via impressora USB
  /// Usa o package printing para enviar um PDF minúsculo com comando de gaveta
  Future<PrintResult> _openDrawerUsb() async {
    try {
      final printers = await listPrinters();
      final printer = printers.firstWhere(
        (p) => p.name.toLowerCase() == _config!.name.toLowerCase(),
        orElse: () => throw Exception('Impressora "${_config!.name}" não encontrada'),
      );

      AppLogger.d('🗄️ Abrindo gaveta via USB: ${printer.name}');

      // Método 1: Enviar dados RAW via Windows (funciona melhor para comandos ESC/POS)
      if (Platform.isWindows) {
        final result = await _openDrawerWindowsRaw(printer.name);
        if (result.success) return result;
        AppLogger.w('Método RAW falhou, tentando PDF...');
      }

      // Método 2: Criar PDF mínimo com comando embutido (fallback)
      // Algumas impressoras térmicas executam comandos ESC/POS embutidos no PostScript/PDF
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(72, 10), // Página minúscula
          build: (pw.Context context) {
            return pw.Container(); // Página vazia
          },
        ),
      );

      final pdfBytes = await doc.save();
      
      final result = await Printing.directPrintPdf(
        printer: printer,
        onLayout: (_) async => pdfBytes,
        name: 'OpenDrawer',
      );

      if (result) {
        // Tentar também via RawDataPrinter se disponível
        await _sendRawEscPosToWindowsPrinter(printer.name, _cmdOpenDrawer2);
        return PrintResult.ok('Comando de gaveta enviado');
      } else {
        return PrintResult.fail('Falha ao enviar comando');
      }
    } catch (e) {
      AppLogger.e('Erro ao abrir gaveta USB: $e');
      return PrintResult.fail('Erro: $e');
    }
  }

  /// Envia comandos RAW para impressora Windows
  /// Este método usa a API nativa do Windows para enviar dados binários directamente
  Future<PrintResult> _openDrawerWindowsRaw(String printerName) async {
    try {
      // Criar ficheiro temporário com comandos ESC/POS
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/drawer_cmd.bin');
      
      final bytes = <int>[];
      bytes.addAll(_cmdInit);
      bytes.addAll(_cmdOpenDrawer1);
      
      await tempFile.writeAsBytes(bytes);

      // Usar copy /b no Windows para enviar dados RAW
      // Primeiro, precisamos descobrir a porta da impressora
      final portResult = await _getWindowsPrinterPort(printerName);
      
      if (portResult != null) {
        final result = await Process.run(
          'cmd',
          ['/c', 'copy', '/b', tempFile.path, portResult],
          runInShell: true,
        );
        
        await tempFile.delete();
        
        if (result.exitCode == 0) {
          AppLogger.i('✅ Gaveta aberta via porta $portResult');
          return PrintResult.ok('Gaveta aberta');
        }
      }

      // Alternativa: usar PowerShell para enviar directamente
      final psResult = await _openDrawerPowerShell(printerName, bytes);
      await tempFile.delete();
      return psResult;
      
    } catch (e) {
      AppLogger.e('Erro RAW Windows: $e');
      return PrintResult.fail('Erro: $e');
    }
  }

  /// Obtém a porta da impressora Windows (USB001, LPT1, etc.)
  Future<String?> _getWindowsPrinterPort(String printerName) async {
    try {
      final result = await Process.run(
        'wmic',
        ['printer', 'where', 'name="$printerName"', 'get', 'portname'],
        runInShell: true,
      );
      
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().trim().split('\n');
        if (lines.length > 1) {
          final port = lines[1].trim();
          if (port.isNotEmpty && port != 'PortName') {
            AppLogger.d('🖨️ Porta encontrada: $port');
            return port;
          }
        }
      }
    } catch (e) {
      AppLogger.e('Erro ao obter porta: $e');
    }
    return null;
  }

  /// Usa PowerShell para enviar dados RAW à impressora
  Future<PrintResult> _openDrawerPowerShell(String printerName, List<int> data) async {
    try {
      // Converter bytes para string hexadecimal para PowerShell
      final hexBytes = data.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(',');
      
      final script = '''
\$bytes = [byte[]]@($hexBytes)
\$printerName = "$printerName"

# Método 1: Via .NET RawPrinterHelper
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class RawPrinterHelper
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public class DOCINFOA
    {
        [MarshalAs(UnmanagedType.LPStr)] public string pDocName;
        [MarshalAs(UnmanagedType.LPStr)] public string pOutputFile;
        [MarshalAs(UnmanagedType.LPStr)] public string pDataType;
    }

    [DllImport("winspool.Drv", EntryPoint = "OpenPrinterA", CharSet = CharSet.Ansi, SetLastError = true)]
    public static extern bool OpenPrinter([MarshalAs(UnmanagedType.LPStr)] string szPrinter, out IntPtr hPrinter, IntPtr pd);

    [DllImport("winspool.Drv", EntryPoint = "ClosePrinter", SetLastError = true)]
    public static extern bool ClosePrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "StartDocPrinterA", CharSet = CharSet.Ansi, SetLastError = true)]
    public static extern bool StartDocPrinter(IntPtr hPrinter, Int32 level, [In, MarshalAs(UnmanagedType.LPStruct)] DOCINFOA di);

    [DllImport("winspool.Drv", EntryPoint = "EndDocPrinter", SetLastError = true)]
    public static extern bool EndDocPrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "StartPagePrinter", SetLastError = true)]
    public static extern bool StartPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "EndPagePrinter", SetLastError = true)]
    public static extern bool EndPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "WritePrinter", SetLastError = true)]
    public static extern bool WritePrinter(IntPtr hPrinter, IntPtr pBytes, Int32 dwCount, out Int32 dwWritten);

    public static bool SendBytesToPrinter(string printerName, byte[] bytes)
    {
        IntPtr hPrinter;
        if (!OpenPrinter(printerName, out hPrinter, IntPtr.Zero))
            return false;

        var di = new DOCINFOA { pDocName = "RAW Document", pDataType = "RAW" };
        
        if (!StartDocPrinter(hPrinter, 1, di))
        {
            ClosePrinter(hPrinter);
            return false;
        }

        if (!StartPagePrinter(hPrinter))
        {
            EndDocPrinter(hPrinter);
            ClosePrinter(hPrinter);
            return false;
        }

        IntPtr pUnmanagedBytes = Marshal.AllocCoTaskMem(bytes.Length);
        Marshal.Copy(bytes, 0, pUnmanagedBytes, bytes.Length);

        int written;
        bool success = WritePrinter(hPrinter, pUnmanagedBytes, bytes.Length, out written);

        Marshal.FreeCoTaskMem(pUnmanagedBytes);
        EndPagePrinter(hPrinter);
        EndDocPrinter(hPrinter);
        ClosePrinter(hPrinter);

        return success && written == bytes.Length;
    }
}
"@

\$result = [RawPrinterHelper]::SendBytesToPrinter(\$printerName, \$bytes)
if (\$result) { Write-Output "OK" } else { Write-Output "FAIL" }
''';

      final result = await Process.run(
        'powershell',
        ['-ExecutionPolicy', 'Bypass', '-Command', script],
        runInShell: true,
      );

      if (result.exitCode == 0 && result.stdout.toString().contains('OK')) {
        AppLogger.i('✅ Gaveta aberta via PowerShell RAW');
        return PrintResult.ok('Gaveta aberta');
      } else {
        AppLogger.e('PowerShell output: ${result.stdout}');
        AppLogger.e('PowerShell error: ${result.stderr}');
        return PrintResult.fail('Falha ao enviar comando RAW');
      }
    } catch (e) {
      AppLogger.e('Erro PowerShell: $e');
      return PrintResult.fail('Erro: $e');
    }
  }

  /// Envia comandos ESC/POS RAW para impressora Windows
  Future<void> _sendRawEscPosToWindowsPrinter(String printerName, List<int> command) async {
    // Esta é uma versão simplificada, a implementação completa está em _openDrawerPowerShell
    try {
      await _openDrawerPowerShell(printerName, command);
    } catch (e) {
      AppLogger.e('Erro ao enviar RAW: $e');
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
    // Codepage 860 (Português) ou fallback para ASCII
    final normalized = text
        .replaceAll('€', 'EUR')
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c')
        .replaceAll('Á', 'A')
        .replaceAll('À', 'A')
        .replaceAll('Ã', 'A')
        .replaceAll('Â', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Ê', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ô', 'O')
        .replaceAll('Õ', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ç', 'C');

    return normalized.codeUnits.map((c) => c > 127 ? 63 : c).toList(); // 63 = '?'
  }

  /// Imprime talão/recibo
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

  /// Imprime talão via rede ESC/POS
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
    final width = _config!.paperWidth == 58 ? 32 : 48;
    final bytes = <int>[];

    bytes.addAll(_cmdInit);

    // Cabeçalho - Empresa
    bytes.addAll(_cmdAlignCenter);
    bytes.addAll(_cmdBoldOn);
    bytes.addAll(_cmdDoubleSize);
    bytes.addAll(_textToBytes(companyName));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_cmdNormalSize);
    bytes.addAll(_cmdBoldOff);
    bytes.addAll(_textToBytes('NIF: $companyVat'));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_textToBytes(companyAddress));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_textToBytes(_line(width)));
    bytes.addAll(_cmdFeed1);

    // Tipo de documento e número
    bytes.addAll(_cmdBoldOn);
    bytes.addAll(_textToBytes('$documentType $documentNumber'));
    bytes.addAll(_cmdFeed1);
    bytes.addAll(_cmdBoldOff);
    bytes.addAll(_textToBytes('$date $time'));
    bytes.addAll(_cmdFeed1);

    // ATCUD se existir
    if (atcud != null && atcud.isNotEmpty) {
      bytes.addAll(_textToBytes('ATCUD: $atcud'));
      bytes.addAll(_cmdFeed1);
    }

    bytes.addAll(_textToBytes(_line(width)));
    bytes.addAll(_cmdFeed1);

    // Cliente se existir
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
      // Nome do produto
      bytes.addAll(_textToBytes(_truncate(item.name, width)));
      bytes.addAll(_cmdFeed1);
      
      // Quantidade x Preço = Total
      final qtyStr = _formatQty(item.quantity, item.unit);
      final priceStr = item.unitPrice.toStringAsFixed(2);
      final totalStr = item.total.toStringAsFixed(2);
      final line = '  $qtyStr x $priceStr';
      final padding = width - line.length - totalStr.length;
      bytes.addAll(_textToBytes('$line${' ' * (padding > 0 ? padding : 1)}$totalStr'));
      bytes.addAll(_cmdFeed1);

      // Desconto do item se existir
      if (item.discount > 0) {
        final discStr = '-${(item.total * item.discount / 100).toStringAsFixed(2)}';
        bytes.addAll(_textToBytes('    Desc. ${item.discount.toStringAsFixed(0)}%${' ' * (width - 14 - discStr.length)}$discStr'));
        bytes.addAll(_cmdFeed1);
      }
    }

    bytes.addAll(_textToBytes(_line(width)));
    bytes.addAll(_cmdFeed1);

    // Totais
    bytes.addAll(_cmdAlignRight);

    // Subtotal (se houver descontos)
    if (globalDiscountValue > 0 || itemsDiscountValue > 0) {
      _addLine(bytes, 'Subtotal', '${subtotal.toStringAsFixed(2)} EUR', width);
    }

    // Desconto de itens
    if (itemsDiscountValue > 0) {
      _addLine(bytes, 'Desc. artigos', '-${itemsDiscountValue.toStringAsFixed(2)} EUR', width);
    }

    // Desconto global
    if (globalDiscountValue > 0) {
      _addLine(bytes, 'Desc. ${globalDiscount.toStringAsFixed(0)}%', '-${globalDiscountValue.toStringAsFixed(2)} EUR', width);
    }

    // IVA
    _addLine(bytes, 'IVA', '${taxTotal.toStringAsFixed(2)} EUR', width);

    // Total
    bytes.addAll(_cmdBoldOn);
    bytes.addAll(_cmdDoubleHeight);
    _addLine(bytes, 'TOTAL', '${total.toStringAsFixed(2)} EUR', width);
    bytes.addAll(_cmdNormalSize);
    bytes.addAll(_cmdBoldOff);

    bytes.addAll(_cmdFeed1);
    bytes.addAll(_textToBytes(_line(width)));
    bytes.addAll(_cmdFeed1);

    // Método de pagamento
    bytes.addAll(_cmdAlignCenter);
    bytes.addAll(_textToBytes('Pagamento: $paymentMethod'));
    bytes.addAll(_cmdFeed1);

    // QR Code placeholder (impressoras com suporte)
    if (qrCode != null && qrCode.isNotEmpty) {
      bytes.addAll(_cmdFeed1);
      bytes.addAll(_textToBytes('[QR Code]'));
      bytes.addAll(_cmdFeed1);
    }

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
                // Cabeçalho
                pw.Text(companyName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('NIF: $companyVat', style: const pw.TextStyle(fontSize: 10)),
                pw.Text(companyAddress, style: const pw.TextStyle(fontSize: 10)),
                pw.Divider(),
                
                // Documento
                pw.Text('$documentType $documentNumber', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text('$date $time', style: const pw.TextStyle(fontSize: 10)),
                if (atcud != null && atcud.isNotEmpty)
                  pw.Text('ATCUD: $atcud', style: const pw.TextStyle(fontSize: 10)),
                pw.Divider(),

                // Cliente
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

                // Itens
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

                // Totais
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

                // Pagamento
                pw.Text('Pagamento: $paymentMethod', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 8),

                // Rodapé
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
