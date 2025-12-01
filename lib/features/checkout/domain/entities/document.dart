import 'package:equatable/equatable.dart';

/// Entidade que representa um documento fiscal criado
class Document extends Equatable {
  const Document({
    required this.id,
    required this.documentSetId,
    required this.number,
    required this.ourReference,
    required this.yourReference,
    required this.date,
    required this.expirationDate,
    required this.customerId,
    required this.customerName,
    required this.customerVat,
    required this.netValue,
    required this.taxValue,
    required this.grossValue,
    required this.status,
    this.pdfUrl,
    this.products = const [],
    this.payments = const [],
  });

  final int id;
  final int documentSetId;
  final String number; // Ex: "FS 2024/1"
  final String ourReference;
  final String yourReference;
  final DateTime date;
  final DateTime expirationDate;
  final int customerId;
  final String customerName;
  final String customerVat;
  final double netValue; // Valor sem IVA
  final double taxValue; // Valor do IVA
  final double grossValue; // Valor total com IVA
  final DocumentStatus status;
  final String? pdfUrl;
  final List<DocumentProduct> products;
  final List<DocumentPayment> payments;

  /// Número formatado para exibição
  String get displayNumber => number;

  /// Data formatada
  String get formattedDate {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  /// Valor total formatado
  String get formattedTotal => '${grossValue.toStringAsFixed(2)} €';

  @override
  List<Object?> get props => [
        id,
        documentSetId,
        number,
        date,
        customerId,
        grossValue,
        status,
      ];
}

/// Produto dentro de um documento
class DocumentProduct extends Equatable {
  const DocumentProduct({
    required this.productId,
    required this.name,
    required this.reference,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.taxValue,
    required this.total,
  });

  final int productId;
  final String name;
  final String reference;
  final double quantity;
  final double unitPrice;
  final double discount; // Percentagem
  final double taxValue;
  final double total;

  @override
  List<Object?> get props => [productId, quantity, total];
}

/// Pagamento associado ao documento
class DocumentPayment extends Equatable {
  const DocumentPayment({
    required this.paymentMethodId,
    required this.paymentMethodName,
    required this.value,
    this.notes,
  });

  final int paymentMethodId;
  final String paymentMethodName;
  final double value;
  final String? notes;

  @override
  List<Object?> get props => [paymentMethodId, value];
}

/// Estado do documento
enum DocumentStatus {
  draft(0, 'Rascunho'),
  closed(1, 'Fechado'),
  canceled(2, 'Anulado');

  const DocumentStatus(this.value, this.label);

  final int value;
  final String label;

  static DocumentStatus fromValue(int value) {
    return DocumentStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => DocumentStatus.draft,
    );
  }
}

/// Método de pagamento
class PaymentMethod extends Equatable {
  const PaymentMethod({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  /// Métodos de pagamento para POS (apenas Numerário e Multibanco)
  static const PaymentMethod cash = PaymentMethod(id: 1, name: 'Numerário');
  static const PaymentMethod card = PaymentMethod(id: 2, name: 'Multibanco');

  static List<PaymentMethod> get defaultMethods => [
        cash,
        card,
      ];

  @override
  List<Object?> get props => [id, name];
}
