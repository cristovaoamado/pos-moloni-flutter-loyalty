import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:pos_moloni_app/features/cart/domain/entities/cart_item.dart';

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

class _ItemOptionsDialogState extends State<ItemOptionsDialog> with SingleTickerProviderStateMixin {
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
  late double _currentPrice;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);

    _currentQty = widget.item.quantity;
    _currentDiscount = widget.item.discount;
    _currentPrice = widget.item.unitPrice;

    _qtyController = TextEditingController(text: _formatNumber(_currentQty));
    _discountController = TextEditingController(
      text: _currentDiscount > 0 ? _currentDiscount.toStringAsFixed(0) : '',
    );
    _priceController = TextEditingController(text: _currentPrice.toStringAsFixed(2));

    // Selecionar texto e dar focus após o frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusCurrentTab();
    });

    // Listener para mudança de tab
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
    _tabController.dispose();
    _qtyController.dispose();
    _discountController.dispose();
    _priceController.dispose();
    _qtyFocusNode.dispose();
    _discountFocusNode.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    // Remove zeros à direita mas mantém até 3 casas decimais
    String formatted = value.toStringAsFixed(3);
    while (formatted.endsWith('0')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    if (formatted.endsWith('.')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    return formatted;
  }

  /// Converte nome da unidade para abreviatura
  String _getUnitAbbreviation(String unit) {
    final lowerUnit = unit.toLowerCase();
    
    // Mapeamento de unidades para abreviaturas
    const abbreviations = {
      'quilograma': 'Kg',
      'quilogramas': 'Kg',
      'kilogram': 'Kg',
      'kilograma': 'Kg',
      'kg': 'Kg',
      'grama': 'g',
      'gramas': 'g',
      'g': 'g',
      'litro': 'Lt',
      'litros': 'Lt',
      'lt': 'Lt',
      'l': 'Lt',
      'mililitro': 'ml',
      'mililitros': 'ml',
      'ml': 'ml',
      'metro': 'm',
      'metros': 'm',
      'm': 'm',
      'centimetro': 'cm',
      'centimetros': 'cm',
      'cm': 'cm',
      'unidade': 'Un',
      'unidades': 'Un',
      'un': 'Un',
      'uni': 'Un',
      'caixa': 'Cx',
      'caixas': 'Cx',
      'cx': 'Cx',
      'pacote': 'Pct',
      'pacotes': 'Pct',
      'pct': 'Pct',
      'par': 'Par',
      'pares': 'Par',
      'duzia': 'Dz',
      'duzias': 'Dz',
      'dz': 'Dz',
    };

    return abbreviations[lowerUnit] ?? unit;
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
    widget.onPriceChanged(_currentPrice);
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
        child: Container(
          width: 400,
          height: 400,
          padding: const EdgeInsets.all(0),
          child: Column(
            children: [
              _buildHeader(context),
              TabBar(
                controller: _tabController,
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
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Ref: ${widget.item.product.reference}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CircleButton(
                icon: Icons.remove,
                onPressed: () => _updateQuantity(-1),
                size: 56,
              ),
              const SizedBox(width: 16),
              // Input + Label da unidade (fora da caixa)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _qtyController,
                      focusNode: _qtyFocusNode,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  const SizedBox(width: 8),
                  Text(
                    _getUnitAbbreviation(widget.item.measureUnit),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              _CircleButton(
                icon: Icons.add,
                onPressed: () => _updateQuantity(1),
                size: 56,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Total: ${(_currentQty * _currentPrice * (1 - _currentDiscount / 100) * (1 + widget.item.taxRate / 100)).toStringAsFixed(2)} €',
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

  Widget _buildDiscountTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Input + Label % (fora da caixa)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _discountController,
                  focusNode: _discountFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    hintText: '0',
                    hintStyle: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
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
          // Botões rápidos + botão limpar na mesma linha
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...[5, 10, 15, 20].map((d) {
                final isSelected = _currentDiscount == d.toDouble();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentDiscount = d.toDouble();
                        _discountController.text = d.toString();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected ? Colors.orange.shade700 : Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      minimumSize: const Size(50, 40),
                      side: isSelected ? const BorderSide(color: Colors.white, width: 2) : null,
                    ),
                    child: Text(
                      '$d%',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                );
              }),
              if (_currentDiscount > 0) ...[
                const SizedBox(width: 8),
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
            ],
          ),
          const SizedBox(height: 16),
          if (_currentDiscount > 0)
            Text(
              'Desconto: -${(_currentQty * _currentPrice * _currentDiscount / 100).toStringAsFixed(2)} €',
              style: const TextStyle(fontSize: 16, color: Colors.orange, fontWeight: FontWeight.w500),
            ),
        ],
      ),
    );
  }

  Widget _buildPriceTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Preço original: ${widget.item.product.price.toStringAsFixed(2)} €',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 20),
          // Input + Label € (fora da caixa)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _priceController,
                  focusNode: _priceFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  onChanged: (value) {
                    final price = double.tryParse(value);
                    if (price != null && price >= 0) {
                      setState(() => _currentPrice = price);
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
          if (_currentPrice != widget.item.product.price)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _currentPrice = widget.item.product.price;
                  _priceController.text = _currentPrice.toStringAsFixed(2);
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

/// Botão circular para +/-
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onPressed,
    this.size = 48,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;

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
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        child: Icon(icon, size: size * 0.5),
      ),
    );
  }
}
