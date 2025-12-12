import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/features/barcode/presentation/providers/barcode_scanner_provider.dart';

/// Widget que escuta eventos de teclado do barcode scanner
/// Envolve o conteúdo da app e captura eventos de scanners USB/Bluetooth
class BarcodeScannerListener extends ConsumerStatefulWidget {
  const BarcodeScannerListener({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  ConsumerState<BarcodeScannerListener> createState() =>
      _BarcodeScannerListenerState();
}

class _BarcodeScannerListenerState
    extends ConsumerState<BarcodeScannerListener> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Garantir foco inicial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enabled) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        // Delegar ao serviço de barcode scanner
        final service = ref.read(barcodeScannerServiceProvider);
        service.handleKeyEvent(event);
      },
      child: GestureDetector(
        // Re-focar quando o utilizador toca fora de um campo de texto
        behavior: HitTestBehavior.translucent,
        onTap: () {
          // Só focar se não há outro campo de texto focado
          final currentFocus = FocusScope.of(context).focusedChild;
          if (currentFocus == null || currentFocus == _focusNode) {
            _focusNode.requestFocus();
          }
        },
        child: widget.child,
      ),
    );
  }
}

/// Widget alternativo usando Focus com onKeyEvent (API moderna)
class BarcodeScannerFocusListener extends ConsumerStatefulWidget {
  const BarcodeScannerFocusListener({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  ConsumerState<BarcodeScannerFocusListener> createState() =>
      _BarcodeScannerFocusListenerState();
}

class _BarcodeScannerFocusListenerState
    extends ConsumerState<BarcodeScannerFocusListener> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enabled) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Só processa eventos de key down
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final service = ref.read(barcodeScannerServiceProvider);
    service.handleKeyEvent(event);

    // Retorna ignored para permitir que outros widgets também processem
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          final currentFocus = FocusScope.of(context).focusedChild;
          if (currentFocus == null || currentFocus == _focusNode) {
            _focusNode.requestFocus();
          }
        },
        child: widget.child,
      ),
    );
  }
}
