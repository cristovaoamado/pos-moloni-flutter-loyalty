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
  late double _currentPriceWithTax; // Preço COM IVA (PVP) - o que o utilizador vê/edita

  /// Taxa de IVA do produto
  double get _taxRate => widget.item.taxRate;

  /// Converte preço COM IVA para preço SEM IVA
  double get _priceWithoutTax => _currentPriceWithTax / (1 + _taxRate / 100);

  // Estado da balança
  final ScaleService _scaleService = ScaleService();
  bool _isReadingScale = false;
  String? _scaleError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);

    _currentQty = widget.item.quantity;
    _currentDiscount = widget.item.discount;
    _currentPriceWithTax = widget.item.unitPriceWithTax; // Preço COM IVA (PVP)

    _qtyController = TextEditingController(text: _formatNumber(_currentQty));
    _discountController = TextEditingController(
      text: _currentDiscount > 0 ? _currentDiscount.toStringAsFixed(0) : '',
    );
    _priceController = TextEditingController(text: _currentPriceWithTax.toStringAsFixed(2));

    // Carregar configuração da balança
    _scaleService.loadConfig();

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
    _scaleService.dispose();
    super.dispose();
  }

  /// Lê o peso da balança
  Future<void> _readFromScale() async {
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
                  Text('Peso lido: ${reading.weight.toStringAsFixed(3)} ${reading.unit}'),
                  if (!reading.isStable) ...[
                    const SizedBox(width: 8),
                    const Text('(instável)', style: TextStyle(fontStyle: FontStyle.italic)),
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
          _scaleError = 'Não foi possível ler o peso';
        });
      }
    } catch (e) {
      setState(() {
        _isReadingScale = false;
        _scaleError = 'Erro: $e';
      });
    }
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

  void _updateQuantity(double delta) {
    setState(() {
      _currentQty = (_currentQty + delta).clamp(0.01, 9999.0);
      _qtyController.text = _formatNumber(_currentQty);
    });
  }

  void _confirm() {
    widget.onQuantityChanged(_currentQty);
    widget.onDiscountChanged(_currentDiscount);
    // Enviar preço SEM IVA (a API Moloni espera preço sem IVA)
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
          borderRadius: BorderRadius.zero, // SEM cantos arredondados
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
    // IGUAL AO CHECKOUT: usa colorScheme.primary com texto branco
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary, // IGUAL ao checkout
        // SEM borderRadius - cantos rectos
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
                    color: Colors.white, // Texto branco
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Ref: ${widget.item.product.reference}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7), // Texto branco semi-transparente
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
    // Verificar se a unidade é pesável (kg, g, etc.)
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
              // Botão - com cor igual ao método de pagamento selecionado (primary)
              _CircleButton(
                icon: Icons.remove,
                onPressed: () => _updateQuantity(-1),
                size: 56,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              const SizedBox(width: 16),
              // Input SEM label de unidade (removido Kg, Un, etc.)
              SizedBox(
                width: 140,
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
              const SizedBox(width: 16),
              // Botão + com cor igual ao método de pagamento selecionado (primary)
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
          
          // Botão de leitura da balança (só para produtos pesáveis)
          // Cor igual aos botões de valor rápido (secondaryContainer com texto verde)
          if (isWeighable) ...[
            ElevatedButton.icon(
              onPressed: _isReadingScale ? null : _readFromScale,
              icon: _isReadingScale
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    )
                  : const Icon(Icons.scale, size: 20),
              label: Text(_isReadingScale ? 'A ler...' : 'Ler da Balança'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer, // Lima/verde claro
                foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer, // Texto verde
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

  Widget _buildDiscountTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
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
          // Botões rápidos - MESMA COR dos botões de valor entregue (secondaryContainer)
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
                        ? Theme.of(context).colorScheme.primary // Selecionado = primary
                        : Theme.of(context).colorScheme.secondaryContainer, // Normal = lima/verde
                    foregroundColor: isSelected 
                        ? Colors.white 
                        : Theme.of(context).colorScheme.onSecondaryContainer,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    minimumSize: const Size(50, 40),
                    side: isSelected ? const BorderSide(color: Colors.white, width: 2) : null,
                  ),
                  child: Text(
                    '$d%',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
          // Input + Label € (fora da caixa) - Preço COM IVA (PVP)
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
                  _priceController.text = _currentPriceWithTax.toStringAsFixed(2);
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
