import 'package:pos_moloni_app/features/cart/domain/entities/cart_item.dart';
import 'package:pos_moloni_app/features/customers/domain/entities/customer.dart';
import 'package:pos_moloni_app/features/document_sets/domain/entities/document_set.dart';

// Re-exportar Customer para compatibilidade
export 'package:pos_moloni_app/features/customers/domain/entities/customer.dart';

/// Modelo de venda suspensa
class SuspendedSale {
  SuspendedSale({
    required this.id,
    required this.items,
    required this.customer,
    required this.documentOption,
    required this.createdAt,
    this.note,
    this.isPersistent = false,
  });

  final String id;
  final List<CartItem> items;
  final Customer customer;
  final DocumentTypeOption? documentOption;
  final DateTime createdAt;
  final String? note;
  final bool isPersistent; // Se true, a venda é guardada localmente

  double get total => items.fold(0.0, (sum, item) => sum + item.total);

  /// Cria uma cópia com novos valores
  SuspendedSale copyWith({
    String? id,
    List<CartItem>? items,
    Customer? customer,
    DocumentTypeOption? documentOption,
    DateTime? createdAt,
    String? note,
    bool? isPersistent,
  }) {
    return SuspendedSale(
      id: id ?? this.id,
      items: items ?? this.items,
      customer: customer ?? this.customer,
      documentOption: documentOption ?? this.documentOption,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
      isPersistent: isPersistent ?? this.isPersistent,
    );
  }
}
