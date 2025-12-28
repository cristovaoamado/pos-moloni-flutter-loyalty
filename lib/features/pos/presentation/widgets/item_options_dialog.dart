import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:pos_moloni_app/features/cart/domain/entities/cart_item.dart';
import 'package:pos_moloni_app/features/scale/services/scale_service.dart';

/// Diálogo de opções do item com tabs (Quantidade, Desconto, Preço)
class ItemOptionsDialog extends StatefulWidget {
  const ItemOptionsDialog({
    super.key,
    required this.item,
    required this.onQuantityChanged,
    required this.onDiscountChanged,
    required this.onPriceChanged,
    required this.onRemove,
    this.initialTab = 0,
  });

  final CartItem item;
  final Function(double) onQuantityChanged;
  final Function(double) onDiscountChanged;
  final Function(double) onPriceChanged;
  final VoidCallback onRemove;
  final int initialTab;

  @override
  State<ItemOptionsDialog> createState() => _ItemOptionsDialogState();
}

class _ItemOptionsDialogState extends State<ItemOptionsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _qtyController;
  late TextEditingController _discountController;
  late TextEditingController _priceController;

  // Focus nodes
  final _qtyFocusNode = FocusNode();
  final _discountFocusNode = FocusNode();
  final _priceFocusNode = FocusNode();

  late double _currentQty;
  late double _currentDiscount;
  late double _currentPriceWithTax;

  double get _taxRate => widget.item.taxRate;
  double get _priceWithoutTax => _currentPriceWithTax / (1 + _taxRate / 100);

  // Estado da balança - usa singleton
  final ScaleService _scaleService = ScaleService.instance;
  bool _isReadingScale = false;
  String? _scaleError;
  
  // Subscrição para o estado da conexão
  StreamSubscription<ScaleConnectionState>? _connectionSubscription;
  ScaleConnectionState _scaleConnectionState = ScaleConnectionState.disconnected;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 3, vsync: this, initialIndex: widget.initialTab);

    _currentQty = widget.item.quantity;
    _currentDiscount = widget.item.discount;
    _currentPriceWithTax = widget.item.unitPriceWithTax;

    _qtyController = TextEditingController(text: _formatNumber(_currentQty));
    _discountController = TextEditingController(
      text: _currentDiscount > 0 ? _currentDiscount.toStringAsFixed(0) : '',
    );
    _priceController =
        TextEditingController(text: _currentPriceWithTax.toStringAsFixed(2));

    // Obter estado inicial da conexão
    _scaleConnectionState = _scaleService.connectionState;
    
    // Subscrever às mudanças de estado da balança
    _connectionSubscription = _scaleService.connectionStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _scaleConnectionState = state;
          // Limpar erro se reconectou com sucesso
          if (state == ScaleConnectionState.connected) {
            _scaleError = null;
          }
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusCurrentTab();
    });

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _focusCurrentTab();
      }
    });
  }

  void _focusCurrentTab() {
    switch (_tabController.index) {
      case 0:
        _qtyFocusNode.requestFocus();
        _qtyController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _qtyController.text.length,
        );
        break;
      case 1:
        _discountFocusNode.requestFocus();
        _discountController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _discountController.text.length,
        );
        break;
      case 2:
        _priceFocusNode.requestFocus();
        _priceController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _priceController.text.length,
        );
        break;
    }
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _tabController.dispose();
    _qtyController.dispose();
    _discountController.dispose();
    _priceController.dispose();
    _qtyFocusNode.dispose();
    _discountFocusNode.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  Future<void> _readFromScale() async {
    if (!_scaleService.isConfigured) {
      setState(() {
        _scaleError = 'Balança não configurada. Configura nas Definições.';
      });
      return;
    }

    setState(() {
      _isReadingScale = true;
      _scaleError = null;
    });

    try {
      final reading = await _scaleService.readWeight();

      if (reading != null) {
        setState(() {
          _currentQty = reading.weight;
          _qtyController.text = _formatNumber(_currentQty);
          _isReadingScale = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.scale, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                      'Peso lido: ${reading.weight.toStringAsFixed(3)} ${reading.unit}'),
                  if (!reading.isStable) ...[
                    const SizedBox(width: 8),
                    const Text('(instável)',
                        style: TextStyle(fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _isReadingScale = false;
          _scaleError = _getScaleErrorMessage();
        });
      }
    } catch (e) {
      setState(() {
        _isReadingScale = false;
        _scaleError = 'Erro: $e';
      });
    }
  }

  /// Retorna mensagem de erro apropriada baseada no estado da conexão
  String _getScaleErrorMessage() {
    switch (_scaleConnectionState) {
      case ScaleConnectionState.disconnected:
        return 'Balança desconectada. Verifique o cabo.';
      case ScaleConnectionState.reconnecting:
        return 'A tentar reconectar à balança...';
      case ScaleConnectionState.connecting:
        return 'A conectar à balança...';
      case ScaleConnectionState.connected:
        return 'Não foi possível ler o peso. Tente novamente.';
    }
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    String formatted = value.toStringAsFixed(3);
    while (formatted.endsWith('0')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    if (formatted.endsWith('.')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    return formatted;
  }

  void _updateQuantity(double delta) {
    setState(() {
      _currentQty = (_currentQty + delta).clamp(0.01, 9999.0);
      _qtyController.text = _formatNumber(_currentQty);
    });
  }

  void _confirm() {
    widget.onQuantityChanged(_currentQty);
    widget.onDiscountChanged(_currentDiscount);
    widget.onPriceChanged(_priceWithoutTax);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          _confirm();
        }
      },
      child: Dialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        child: Container(
          width: 400,
          height: 400,
          padding: const EdgeInsets.all(0),
          child: Column(
            children: [
              _buildHeader(context),
              TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).colorScheme.primary,
                indicatorColor: Theme.of(context).colorScheme.primary,
                tabs: const [
                  Tab(text: 'Quantidade'),
                  Tab(text: 'Desconto'),
                  Tab(text: 'Preço'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildQuantityTab(context),
                    _buildDiscountTab(context),
                    _buildPriceTab(context),
                  ],
                ),
              ),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Ref: ${widget.item.product.reference}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () {
              widget.onRemove();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Eliminar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _confirm,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Confirmar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityTab(BuildContext context) {
    final unit = widget.item.measureUnit.toLowerCase();
    final isWeighable = unit.contains('kg') ||
        unit.contains('g') ||
        unit == 'quilograma' ||
        unit == 'quilogramas' ||
        unit == 'grama' ||
        unit == 'gramas';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CircleButton(
                icon: Icons.remove,
                onPressed: () => _updateQuantity(-1),
                size: 56,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _qtyController,
                  focusNode: _qtyFocusNode,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  onChanged: (value) {
                    final qty = double.tryParse(value);
                    if (qty != null && qty > 0) {
                      setState(() => _currentQty = qty);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              _CircleButton(
                icon: Icons.add,
                onPressed: () => _updateQuantity(1),
                size: 56,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isWeighable) ...[
            // Indicador de estado da balança
            _buildScaleStatusIndicator(context),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isReadingScale || 
                  _scaleConnectionState == ScaleConnectionState.reconnecting
                  ? null 
                  : _readFromScale,
              icon: _isReadingScale
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    )
                  : Icon(
                      _scaleConnectionState == ScaleConnectionState.connected
                          ? Icons.scale
                          : Icons.scale_outlined,
                      size: 20,
                    ),
              label: Text(_getScaleButtonLabel()),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onSecondaryContainer,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            if (_scaleError != null) ...[
              const SizedBox(height: 8),
              Text(
                _scaleError!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          Text(
            'Total: ${(_currentQty * _currentPriceWithTax * (1 - _currentDiscount / 100)).toStringAsFixed(2)} €',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói o indicador de estado da balança
  Widget _buildScaleStatusIndicator(BuildContext context) {
    final Color statusColor;
    final IconData statusIcon;
    final String statusText;

    switch (_scaleConnectionState) {
      case ScaleConnectionState.connected:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Balança conectada';
        break;
      case ScaleConnectionState.connecting:
        statusColor = Colors.orange;
        statusIcon = Icons.sync;
        statusText = 'A conectar...';
        break;
      case ScaleConnectionState.reconnecting:
        statusColor = Colors.orange;
        statusIcon = Icons.sync;
        statusText = 'A reconectar...';
        break;
      case ScaleConnectionState.disconnected:
        statusColor = Colors.red;
        statusIcon = Icons.error_outline;
        statusText = 'Balança desconectada';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_scaleConnectionState == ScaleConnectionState.connecting ||
              _scaleConnectionState == ScaleConnectionState.reconnecting)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: statusColor,
              ),
            )
          else
            Icon(statusIcon, size: 14, color: statusColor),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Retorna o label do botão da balança baseado no estado
  String _getScaleButtonLabel() {
    if (_isReadingScale) return 'A ler...';
    
    switch (_scaleConnectionState) {
      case ScaleConnectionState.connected:
        return 'Ler da Balança';
      case ScaleConnectionState.connecting:
        return 'A conectar...';
      case ScaleConnectionState.reconnecting:
        return 'A reconectar...';
      case ScaleConnectionState.disconnected:
        return 'Balança offline';
    }
  }

  Widget _buildDiscountTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _discountController,
                  focusNode: _discountFocusNode,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    hintText: '0',
                    hintStyle: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  onChanged: (value) {
                    final discount = double.tryParse(value) ?? 0.0;
                    setState(() => _currentDiscount = discount.clamp(0, 100));
                  },
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '%',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              ...[5, 10, 15, 20].map((d) {
                final isSelected = _currentDiscount == d.toDouble();
                return ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _currentDiscount = d.toDouble();
                      _discountController.text = d.toString();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.secondaryContainer,
                    foregroundColor: isSelected
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSecondaryContainer,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    minimumSize: const Size(50, 40),
                    side: isSelected
                        ? const BorderSide(color: Colors.white, width: 2)
                        : null,
                  ),
                  child: Text(
                    '$d%',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                );
              }),
              if (_currentDiscount > 0)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _currentDiscount = 0;
                      _discountController.clear();
                    });
                  },
                  icon: const Icon(Icons.clear),
                  tooltip: 'Remover desconto',
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.red,
                    backgroundColor: Colors.red.shade50,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_currentDiscount > 0)
            Text(
              'Desconto: -${(_currentQty * _currentPriceWithTax * _currentDiscount / 100).toStringAsFixed(2)} €',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPriceTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Preço original: ${widget.item.product.priceWithTax.toStringAsFixed(2)} €',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _priceController,
                  focusNode: _priceFocusNode,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  onChanged: (value) {
                    final price = double.tryParse(value);
                    if (price != null && price >= 0) {
                      setState(() => _currentPriceWithTax = price);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '€',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_currentPriceWithTax != widget.item.product.priceWithTax)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _currentPriceWithTax = widget.item.product.priceWithTax;
                  _priceController.text =
                      _currentPriceWithTax.toStringAsFixed(2);
                });
              },
              icon: const Icon(Icons.restore, size: 18),
              label: const Text('Repor preço original'),
            ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onPressed,
    this.size = 48,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
        ),
        child: Icon(icon, size: size * 0.5),
      ),
    );
  }
}
