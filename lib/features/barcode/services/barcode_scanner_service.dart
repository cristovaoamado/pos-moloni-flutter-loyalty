import 'dart:async';

import 'package:flutter/services.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';

/// Callback quando um código de barras é detectado
typedef OnBarcodeScanned = void Function(String barcode);

/// Serviço que escuta eventos de barcode scanner
/// Os scanners USB/Bluetooth tipicamente funcionam como teclados,
/// enviando caracteres rapidamente terminados com Enter
class BarcodeScannerService {
  BarcodeScannerService();

  /// Buffer para acumular caracteres do scanner
  final StringBuffer _buffer = StringBuffer();
  
  /// Timer para detectar fim da sequência
  Timer? _debounceTimer;
  
  /// Timestamp da última tecla pressionada
  DateTime? _lastKeyTime;
  
  /// Callback quando barcode é detectado
  OnBarcodeScanned? _onBarcodeScanned;
  
  /// Se o serviço está activo
  bool _isListening = false;
  
  /// Último código de barras processado
  String? _lastBarcode;
  
  /// Timestamp do último código processado
  DateTime? _lastBarcodeTime;
  
  /// Tempo máximo entre teclas para considerar como scanner (ms)
  /// Scanners são muito rápidos, tipicamente < 50ms entre caracteres
  static const int _maxKeyInterval = 100;
  
  /// Comprimento mínimo para considerar como código de barras
  static const int _minBarcodeLength = 3;
  
  /// Tempo de debounce após última tecla (ms)
  static const int _debounceTime = 150;
  
  /// Tempo mínimo entre leituras do MESMO código de barras (ms)
  /// Evita leituras duplicadas quando o scanner é muito rápido
  static const int _duplicateCooldown = 500;

  /// Inicia a escuta de eventos de barcode
  void startListening(OnBarcodeScanned onBarcodeScanned) {
    if (_isListening) return;
    
    _onBarcodeScanned = onBarcodeScanned;
    _isListening = true;
    
    AppLogger.i('🔊 Barcode scanner service iniciado');
  }

  /// Para a escuta de eventos
  void stopListening() {
    _isListening = false;
    _onBarcodeScanned = null;
    _clearBuffer();
    
    AppLogger.i('🔇 Barcode scanner service parado');
  }

  /// Processa um evento de tecla
  /// Deve ser chamado pelo widget que tem o KeyboardListener
  bool handleKeyEvent(KeyEvent event) {
    if (!_isListening || _onBarcodeScanned == null) return false;
    
    // Só processar key down
    if (event is! KeyDownEvent) return false;
    
    final now = DateTime.now();
    
    // Se passou muito tempo desde a última tecla, limpar buffer
    if (_lastKeyTime != null) {
      final elapsed = now.difference(_lastKeyTime!).inMilliseconds;
      if (elapsed > _maxKeyInterval) {
        _clearBuffer();
      }
    }
    
    _lastKeyTime = now;
    
    // Verificar se é Enter (fim do código de barras)
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _processBarcode();
      return true;
    }
    
    // Adicionar caractere ao buffer
    final char = _getCharFromKey(event);
    if (char != null) {
      _buffer.write(char);
      
      // Reiniciar timer de debounce
      _debounceTimer?.cancel();
      _debounceTimer = Timer(
        const Duration(milliseconds: _debounceTime),
        _processBarcode,
      );
      
      return true;
    }
    
    return false;
  }

  /// Processa o buffer como código de barras
  void _processBarcode() {
    _debounceTimer?.cancel();
    
    final barcode = _buffer.toString().trim();
    _clearBuffer();
    
    if (barcode.length >= _minBarcodeLength) {
      // Verificar se é leitura duplicada (mesmo código em pouco tempo)
      final now = DateTime.now();
      if (_lastBarcode == barcode && _lastBarcodeTime != null) {
        final elapsed = now.difference(_lastBarcodeTime!).inMilliseconds;
        if (elapsed < _duplicateCooldown) {
          AppLogger.d('📦 Barcode ignorado (duplicado em ${elapsed}ms): $barcode');
          return;
        }
      }
      
      // Guardar para detecção de duplicados
      _lastBarcode = barcode;
      _lastBarcodeTime = now;
      
      AppLogger.i('📦 Barcode detectado: $barcode');
      _onBarcodeScanned?.call(barcode);
    }
  }

  /// Limpa o buffer
  void _clearBuffer() {
    _buffer.clear();
    _debounceTimer?.cancel();
  }

  /// Extrai o caractere de um KeyEvent
  String? _getCharFromKey(KeyDownEvent event) {
    // Tentar obter o caractere do label da tecla
    final label = event.character;
    if (label != null && label.isNotEmpty) {
      // Filtrar apenas caracteres válidos para códigos de barras
      if (_isValidBarcodeChar(label)) {
        return label;
      }
    }
    
    // Tentar pelo keyLabel
    final keyLabel = event.logicalKey.keyLabel;
    if (keyLabel.length == 1 && _isValidBarcodeChar(keyLabel)) {
      return keyLabel;
    }
    
    return null;
  }

  /// Verifica se o caractere é válido para código de barras
  bool _isValidBarcodeChar(String char) {
    if (char.length != 1) return false;
    final code = char.codeUnitAt(0);
    
    // Aceitar:
    // - Dígitos (0-9)
    // - Letras (A-Z, a-z)
    // - Hífen (-)
    // - Ponto (.)
    return (code >= 48 && code <= 57) ||  // 0-9
           (code >= 65 && code <= 90) ||  // A-Z
           (code >= 97 && code <= 122) || // a-z
           code == 45 ||                   // -
           code == 46;                     // .
  }

  /// Processa um código de barras manualmente (para testes ou input direto)
  void processManualBarcode(String barcode) {
    if (!_isListening || _onBarcodeScanned == null) return;
    
    final trimmed = barcode.trim();
    if (trimmed.length >= _minBarcodeLength) {
      AppLogger.i('📦 Barcode manual: $trimmed');
      _onBarcodeScanned?.call(trimmed);
    }
  }

  /// Dispose do serviço
  void dispose() {
    stopListening();
  }
}
