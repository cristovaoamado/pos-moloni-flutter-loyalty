import 'package:equatable/equatable.dart';

/// Entity que representa um imposto (IVA, etc.)
class Tax extends Equatable {

  const Tax({
    required this.id,
    required this.value,
    this.order = 0,
    this.cumulative = false,
  });
  final int id;
  final double value;
  final int order;
  final bool cumulative;

  /// Taxa formatada (ex: 23%)
  String get formattedRate => '${value.toStringAsFixed(0)}%';

  @override
  List<Object?> get props => [id, value, order, cumulative];

  @override
  String toString() => 'Tax(id: $id, value: $value%)';
}