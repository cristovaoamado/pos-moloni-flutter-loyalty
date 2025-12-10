import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/services/storage_service.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/printer/data/services/thermal_printer_service.dart';
import 'package:pos_moloni_app/features/printer/domain/entities/printer_config.dart';

/// Estado da impressora
class PrinterState {
  const PrinterState({
    this.config = const PrinterConfig(),
    this.isLoading = false,
    this.isTesting = false,
    this.isPrinting = false,
    this.lastTestResult,
    this.availablePrinters = const [],
    this.error,
  });

  final PrinterConfig config;
  final bool isLoading;
  final bool isTesting;
  final bool isPrinting;
  final PrintResult? lastTestResult;
  final List<String> availablePrinters;
  final String? error;

  PrinterState copyWith({
    PrinterConfig? config,
    bool? isLoading,
    bool? isTesting,
    bool? isPrinting,
    PrintResult? lastTestResult,
    List<String>? availablePrinters,
    String? error,
    bool clearError = false,
    bool clearTestResult = false,
  }) {
    return PrinterState(
      config: config ?? this.config,
      isLoading: isLoading ?? this.isLoading,
      isTesting: isTesting ?? this.isTesting,
      isPrinting: isPrinting ?? this.isPrinting,
      lastTestResult: clearTestResult ? null : (lastTestResult ?? this.lastTestResult),
      availablePrinters: availablePrinters ?? this.availablePrinters,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

const _printerConfigKey = 'printer_config';

final printerProvider = StateNotifierProvider<PrinterNotifier, PrinterState>((ref) {
  return PrinterNotifier();
});

class PrinterNotifier extends StateNotifier<PrinterState> {
  PrinterNotifier() : super(const PrinterState()) {
    _loadConfig();
  }

  final _service = ThermalPrinterService.instance;
  final _storage = PlatformStorage.instance;

  Future<void> _loadConfig() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final json = await _storage.read(key: _printerConfigKey);
      
      if (json != null) {
        final config = PrinterConfig.fromJson(jsonDecode(json));
        _service.configure(config);
        state = state.copyWith(config: config, isLoading: false);
        AppLogger.i('🖨️ Configuração da impressora carregada');
      } else {
        state = state.copyWith(isLoading: false);
      }

      // Carregar lista de impressoras instaladas
      await refreshPrinters();
    } catch (e) {
      AppLogger.e('❌ Erro ao carregar config da impressora: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao carregar configuração',
      );
    }
  }

  Future<void> updateConfig(PrinterConfig config) async {
    state = state.copyWith(config: config, clearError: true);
    _service.configure(config);
    await _saveConfig();
  }

  Future<void> setEnabled(bool enabled) async {
    final newConfig = state.config.copyWith(isEnabled: enabled);
    await updateConfig(newConfig);
  }

  Future<void> setConnectionType(PrinterConnectionType type) async {
    final newConfig = state.config.copyWith(
      connectionType: type,
      address: '',
      name: '',
    );
    await updateConfig(newConfig);
  }

  Future<void> setPrinterName(String name) async {
    final newConfig = state.config.copyWith(name: name);
    await updateConfig(newConfig);
  }

  Future<void> setNetworkAddress(String address) async {
    final newConfig = state.config.copyWith(address: address, name: 'Rede: $address');
    await updateConfig(newConfig);
  }

  Future<void> setPort(int port) async {
    final newConfig = state.config.copyWith(port: port);
    await updateConfig(newConfig);
  }

  Future<void> setPaperWidth(int width) async {
    final newConfig = state.config.copyWith(paperWidth: width);
    await updateConfig(newConfig);
  }

  Future<void> setAutoPrint(bool autoPrint) async {
    final newConfig = state.config.copyWith(autoPrint: autoPrint);
    await updateConfig(newConfig);
  }

  Future<void> setPrintCopy(bool printCopy) async {
    final newConfig = state.config.copyWith(printCopy: printCopy);
    await updateConfig(newConfig);
  }

  Future<void> _saveConfig() async {
    try {
      await _storage.write(
        key: _printerConfigKey,
        value: jsonEncode(state.config.toJson()),
      );
      AppLogger.i('✅ Configuração da impressora guardada');
    } catch (e) {
      AppLogger.e('❌ Erro ao guardar config: $e');
    }
  }

  Future<void> testConnection() async {
    state = state.copyWith(isTesting: true, clearTestResult: true, clearError: true);

    try {
      final result = await _service.testConnection();
      state = state.copyWith(
        isTesting: false,
        lastTestResult: result,
      );
    } catch (e) {
      state = state.copyWith(
        isTesting: false,
        lastTestResult: PrintResult.fail('Erro: $e'),
      );
    }
  }

  Future<void> printTestPage() async {
    state = state.copyWith(isPrinting: true, clearError: true);

    try {
      final result = await _service.printTestPage();
      state = state.copyWith(
        isPrinting: false,
        lastTestResult: result,
      );
    } catch (e) {
      state = state.copyWith(
        isPrinting: false,
        error: 'Erro: $e',
      );
    }
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
    if (!state.config.isEnabled) {
      return PrintResult.fail('Impressora desactivada');
    }

    state = state.copyWith(isPrinting: true, clearError: true);

    try {
      final result = await _service.printReceipt(
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

      state = state.copyWith(isPrinting: false);
      return result;
    } catch (e) {
      state = state.copyWith(isPrinting: false, error: 'Erro: $e');
      return PrintResult.fail('Erro: $e');
    }
  }

  Future<PrintResult> openCashDrawer() async {
    return await _service.openCashDrawer();
  }

  /// Recarrega lista de impressoras instaladas no sistema
  Future<void> refreshPrinters() async {
    try {
      // Usar package printing para listar impressoras instaladas
      final printers = await _service.listPrinterNames();
      state = state.copyWith(availablePrinters: printers);
      AppLogger.d('🖨️ ${printers.length} impressoras encontradas: $printers');
    } catch (e) {
      AppLogger.e('Erro ao listar impressoras: $e');
    }
  }
}
