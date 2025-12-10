import 'package:equatable/equatable.dart';

/// Entity que representa um imposto (IVA, etc.)
class Tax extends Equatable {

  const Tax({
    required this.id,
    required this.name,
    required this.value,
    this.order = 0,
    this.cumulative = false,
  });
  
  final int id;
  final String name;      // Nome do imposto (ex: "IVA - Reduzida", "IVA - Normal")
  final double value;     // Percentagem do imposto (ex: 6, 13, 23)
  final int order;
  final bool cumulative;

  /// Taxa formatada (ex: 6%)
  String get formattedRate => '${value.toStringAsFixed(0)}%';
  
  /// Nome curto baseado na taxa
  String get shortName {
    if (value <= 6) return 'IVA Red.';
    if (value <= 13) return 'IVA Int.';
    if (value <= 23) return 'IVA Norm.';
    return 'IVA $value%';
  }

  @override
  List<Object?> get props => [id, name, value, order, cumulative];

  @override
  String toString() => 'Tax(id: $id, name: $name, value: $value%)';
}
