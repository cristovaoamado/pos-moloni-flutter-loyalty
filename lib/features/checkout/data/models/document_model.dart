import 'package:pos_moloni_app/features/checkout/domain/entities/document.dart';

/// Model para serialização de documentos
class DocumentModel extends Document {
  const DocumentModel({
    required super.id,
    required super.documentSetId,
    required super.number,
    required super.ourReference,
    required super.yourReference,
    required super.date,
    required super.expirationDate,
    required super.customerId,
    required super.customerName,
    required super.customerVat,
    required super.netValue,
    required super.taxValue,
    required super.grossValue,
    required super.status,
    super.pdfUrl,
    super.products,
    super.payments,
  });

  /// Cria model a partir de JSON da API Moloni
  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    // Parsear produtos
    final productsJson = json['products'] as List? ?? [];
    final products = productsJson
        .map((p) => DocumentProductModel.fromJson(p as Map<String, dynamic>))
        .toList();

    // Parsear pagamentos
    final paymentsJson = json['payments'] as List? ?? [];
    final payments = paymentsJson
        .map((p) => DocumentPaymentModel.fromJson(p as Map<String, dynamic>))
        .toList();

    return DocumentModel(
      id: json['document_id'] as int? ?? 0,
      documentSetId: json['document_set_id'] as int? ?? 0,
      number: _parseString(json['number']),
      ourReference: _parseString(json['our_reference']),
      yourReference: _parseString(json['your_reference']),
      date: _parseDate(json['date']),
      expirationDate: _parseDate(json['expiration_date']),
      customerId: json['customer_id'] as int? ?? 0,
      customerName: _parseString(json['entity_name']) .isNotEmpty 
                   ? _parseString(json['entity_name'])
                   : _parseString(json['customer_name']),
      customerVat: _parseString(json['entity_vat']).isNotEmpty
                  ? _parseString(json['entity_vat'])
                  : _parseString(json['customer_vat']),
      netValue: _parseDouble(json['net_value']),
      taxValue: _parseDouble(json['taxes_value']),
      grossValue: _parseDouble(json['gross_value']),
      status: DocumentStatus.fromValue(json['status'] as int? ?? 0),
      pdfUrl: json['pdf_url']?.toString(),
      products: products,
      payments: payments,
    );
  }

  static String _parseString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Converte para JSON para enviar à API
  Map<String, dynamic> toJson() {
    return {
      'document_id': id,
      'document_set_id': documentSetId,
      'number': number,
      'our_reference': ourReference,
      'your_reference': yourReference,
      'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'expiration_date': '${expirationDate.year}-${expirationDate.month.toString().padLeft(2, '0')}-${expirationDate.day.toString().padLeft(2, '0')}',
      'customer_id': customerId,
      'net_value': netValue,
      'taxes_value': taxValue,
      'gross_value': grossValue,
      'status': status.value,
    };
  }
}

class DocumentProductModel extends DocumentProduct {
  const DocumentProductModel({
    required super.productId,
    required super.name,
    required super.reference,
    required super.quantity,
    required super.unitPrice,
    required super.discount,
    required super.taxValue,
    required super.total,
  });

  factory DocumentProductModel.fromJson(Map<String, dynamic> json) {
    return DocumentProductModel(
      productId: json['product_id'] as int? ?? 0,
      name: _parseString(json['name']),
      reference: _parseString(json['reference']),
      quantity: _parseDouble(json['qty']),
      unitPrice: _parseDouble(json['price']),
      discount: _parseDouble(json['discount']),
      taxValue: _parseDouble(json['taxes_value']),
      total: _parseDouble(json['gross_value']),
    );
  }

  static String _parseString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'name': name,
      'reference': reference,
      'qty': quantity,
      'price': unitPrice,
      'discount': discount,
    };
  }
}

class DocumentPaymentModel extends DocumentPayment {
  const DocumentPaymentModel({
    required super.paymentMethodId,
    required super.paymentMethodName,
    required super.value,
    super.notes,
  });

  factory DocumentPaymentModel.fromJson(Map<String, dynamic> json) {
    return DocumentPaymentModel(
      paymentMethodId: json['payment_method_id'] as int? ?? 0,
      paymentMethodName: _parseString(json['payment_method_name']),
      value: _parseDouble(json['value']),
      notes: json['notes']?.toString(),
    );
  }

  static String _parseString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'payment_method_id': paymentMethodId,
      'value': value,
      if (notes != null) 'notes': notes,
    };
  }
}
