import 'package:hive/hive.dart';

import 'package:pos_moloni_app/features/cart/domain/entities/cart_item.dart';
import 'package:pos_moloni_app/features/document_sets/domain/entities/document_set.dart';
import 'package:pos_moloni_app/features/pos/presentation/models/pos_models.dart';
import 'package:pos_moloni_app/features/products/domain/entities/product.dart';
import 'package:pos_moloni_app/features/products/domain/entities/tax.dart';

part 'suspended_sale_model.g.dart';

/// Modelo de venda suspensa para persistencia
@HiveType(typeId: 10)
class SuspendedSaleModel extends HiveObject {
  SuspendedSaleModel({
    required this.id,
    required this.items,
    required this.customerId,
    required this.customerName,
    required this.customerVat,
    this.documentTypeCode,
    this.documentTypeName,
    this.documentSetId,
    this.documentSetName,
    required this.createdAt,
    this.note,
    this.isPersistent = false,
  });

  /// Cria a partir de SuspendedSale
  factory SuspendedSaleModel.fromEntity(SuspendedSale sale) {
    return SuspendedSaleModel(
      id: sale.id,
      items: sale.items.map((item) => SuspendedSaleItemModel.fromEntity(item)).toList(),
      customerId: sale.customer.id,
      customerName: sale.customer.name,
      customerVat: sale.customer.vat,
      documentTypeCode: sale.documentOption?.documentType.code,
      documentTypeName: sale.documentOption?.documentType.name,
      documentSetId: sale.documentOption?.documentSet.id,
      documentSetName: sale.documentOption?.documentSet.name,
      createdAt: sale.createdAt,
      note: sale.note,
      isPersistent: sale.isPersistent,
    );
  }

  @HiveField(0)
  final String id;

  @HiveField(1)
  final List<SuspendedSaleItemModel> items;

  @HiveField(2)
  final int customerId;

  @HiveField(3)
  final String customerName;

  @HiveField(4)
  final String customerVat;

  @HiveField(5)
  final String? documentTypeCode;

  @HiveField(6)
  final String? documentTypeName;

  @HiveField(7)
  final int? documentSetId;

  @HiveField(8)
  final String? documentSetName;

  @HiveField(9)
  final DateTime createdAt;

  @HiveField(10)
  final String? note;

  @HiveField(11)
  final bool isPersistent;

  /// Converte para SuspendedSale (entidade de dominio)
  SuspendedSale toEntity({
    List<DocumentTypeOption>? availableDocumentOptions,
  }) {
    // Reconstruir customer
    final customer = customerId == 0
        ? Customer.consumidorFinal
        : Customer(
            id: customerId,
            name: customerName,
            vat: customerVat,
          );

    // Tentar encontrar o DocumentTypeOption correspondente
    DocumentTypeOption? documentOption;
    if (documentSetId != null && documentTypeCode != null && availableDocumentOptions != null) {
      try {
        documentOption = availableDocumentOptions.firstWhere(
          (opt) => opt.documentSet.id == documentSetId && opt.documentType.code == documentTypeCode,
        );
      } catch (_) {
        // Nao encontrou
        documentOption = null;
      }
    }

    return SuspendedSale(
      id: id,
      items: items.map((item) => item.toEntity()).toList(),
      customer: customer,
      documentOption: documentOption,
      createdAt: createdAt,
      note: note,
      isPersistent: isPersistent,
    );
  }

  /// Total da venda
  double get total => items.fold(0.0, (sum, item) => sum + item.total);
}

/// Item de venda suspensa para persistencia
@HiveType(typeId: 11)
class SuspendedSaleItemModel extends HiveObject {
  SuspendedSaleItemModel({
    required this.productId,
    required this.productName,
    required this.productReference,
    required this.productPrice,
    required this.productTaxRate,
    required this.productCategoryId,
    this.productImage,
    this.productEan,
    this.productMeasureUnit,
    required this.quantity,
    this.discount = 0.0,
    this.customPrice,
    required this.taxes,
  });

  /// Cria a partir de CartItem
  /// NOTA: Guarda o preco SEM IVA (product.price) para ser consistente com a API
  factory SuspendedSaleItemModel.fromEntity(CartItem item) {
    return SuspendedSaleItemModel(
      productId: item.product.id,
      productName: item.product.name,
      productReference: item.product.reference,
      productPrice: item.product.price, // Preco SEM IVA
      productTaxRate: item.product.totalTaxRate,
      productCategoryId: item.product.categoryId,
      productImage: item.product.image,
      productEan: item.product.ean,
      productMeasureUnit: item.product.measureUnit,
      quantity: item.quantity,
      discount: item.discount,
      customPrice: item.customPrice,
      taxes: item.product.taxes.map((t) => SuspendedSaleTaxModel.fromEntity(t)).toList(),
    );
  }

  @HiveField(0)
  final int productId;

  @HiveField(1)
  final String productName;

  @HiveField(2)
  final String productReference;

  @HiveField(3)
  final double productPrice; // Preco SEM IVA

  @HiveField(4)
  final double productTaxRate;

  @HiveField(5)
  final String? productImage;

  @HiveField(6)
  final String? productEan;

  @HiveField(7)
  final String? productMeasureUnit;

  @HiveField(8)
  final double quantity;

  @HiveField(9)
  final double discount;

  @HiveField(10)
  final double? customPrice;

  @HiveField(11)
  final List<SuspendedSaleTaxModel> taxes;

  @HiveField(12)
  final int productCategoryId;

  /// Preco unitario SEM IVA
  double get unitPrice => customPrice ?? productPrice;

  /// Preco unitario COM IVA (para display)
  double get unitPriceWithTax => unitPrice * (1 + productTaxRate / 100);

  /// Total do item COM IVA
  double get total {
    final subtotal = unitPrice * quantity;
    final discountValue = subtotal * (discount / 100);
    final subtotalWithDiscount = subtotal - discountValue;
    final taxValue = subtotalWithDiscount * (productTaxRate / 100);
    return subtotalWithDiscount + taxValue;
  }

  /// Converte para CartItem
  CartItem toEntity() {
    final product = Product(
      id: productId,
      name: productName,
      reference: productReference,
      price: productPrice, // Preco SEM IVA
      categoryId: productCategoryId,
      taxes: taxes.map((t) => t.toEntity()).toList(),
      image: productImage,
      ean: productEan,
      measureUnit: productMeasureUnit,
    );

    return CartItem(
      product: product,
      quantity: quantity,
      discount: discount,
      customPrice: customPrice,
    );
  }
}

/// Imposto para persistencia
@HiveType(typeId: 12)
class SuspendedSaleTaxModel extends HiveObject {
  SuspendedSaleTaxModel({
    required this.id,
    required this.value,
    this.order = 0,
    this.cumulative = false,
    this.name = 'IVA',
  });

  factory SuspendedSaleTaxModel.fromEntity(Tax tax) {
    return SuspendedSaleTaxModel(
      id: tax.id,
      value: tax.value,
      order: tax.order,
      cumulative: tax.cumulative,
      name: tax.name,
    );
  }

  @HiveField(0)
  final int id;

  @HiveField(1)
  final double value;

  @HiveField(2)
  final int order;

  @HiveField(3)
  final bool cumulative;

  @HiveField(4)
  final String name;

  Tax toEntity() => Tax(
    id: id,
    name: name,
    value: value,
    order: order,
    cumulative: cumulative,
  );
}
