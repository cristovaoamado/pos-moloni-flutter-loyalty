import 'package:pos_moloni_app/features/customers/domain/entities/customer.dart';

/// Model que estende Customer e adiciona serialização JSON
class CustomerModel extends Customer {
  const CustomerModel({
    required super.id,
    required super.name,
    required super.vat,
    super.number,
    super.email,
    super.phone,
    super.address,
    super.zipCode,
    super.city,
    super.countryId,
    super.languageId,
    super.maturityDateId,
    super.paymentMethodId,
    super.deliveryMethodId,
    super.salespersonId,
  });

  /// Cria model a partir de JSON (API Moloni)
  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['customer_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      vat: json['vat'] as String? ?? '',
      number: json['number'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      zipCode: json['zip_code'] as String?,
      city: json['city'] as String?,
      countryId: json['country_id'] as int?,
      languageId: json['language_id'] as int?,
      maturityDateId: json['maturity_date_id'] as int?,
      paymentMethodId: json['payment_method_id'] as int?,
      deliveryMethodId: json['delivery_method_id'] as int?,
      salespersonId: json['salesman_id'] as int?,
    );
  }

  /// Converte model para JSON (para criar/atualizar)
  Map<String, dynamic> toJson() {
    return {
      if (id > 0) 'customer_id': id,
      'name': name,
      'vat': vat,
      if (number != null && number!.isNotEmpty) 'number': number,
      if (email != null && email!.isNotEmpty) 'email': email,
      if (phone != null && phone!.isNotEmpty) 'phone': phone,
      if (address != null && address!.isNotEmpty) 'address': address,
      if (zipCode != null && zipCode!.isNotEmpty) 'zip_code': zipCode,
      if (city != null && city!.isNotEmpty) 'city': city,
      if (countryId != null) 'country_id': countryId,
      if (languageId != null) 'language_id': languageId,
      if (maturityDateId != null) 'maturity_date_id': maturityDateId,
      if (paymentMethodId != null) 'payment_method_id': paymentMethodId,
      if (deliveryMethodId != null) 'delivery_method_id': deliveryMethodId,
      if (salespersonId != null) 'salesman_id': salespersonId,
    };
  }

  /// Converte Model para Entity
  Customer toEntity() {
    return Customer(
      id: id,
      name: name,
      vat: vat,
      number: number,
      email: email,
      phone: phone,
      address: address,
      zipCode: zipCode,
      city: city,
      countryId: countryId,
      languageId: languageId,
      maturityDateId: maturityDateId,
      paymentMethodId: paymentMethodId,
      deliveryMethodId: deliveryMethodId,
      salespersonId: salespersonId,
    );
  }

  /// Cria cópia com alterações
  CustomerModel copyWith({
    int? id,
    String? name,
    String? vat,
    String? number,
    String? email,
    String? phone,
    String? address,
    String? zipCode,
    String? city,
    int? countryId,
    int? languageId,
    int? maturityDateId,
    int? paymentMethodId,
    int? deliveryMethodId,
    int? salespersonId,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      vat: vat ?? this.vat,
      number: number ?? this.number,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      zipCode: zipCode ?? this.zipCode,
      city: city ?? this.city,
      countryId: countryId ?? this.countryId,
      languageId: languageId ?? this.languageId,
      maturityDateId: maturityDateId ?? this.maturityDateId,
      paymentMethodId: paymentMethodId ?? this.paymentMethodId,
      deliveryMethodId: deliveryMethodId ?? this.deliveryMethodId,
      salespersonId: salespersonId ?? this.salespersonId,
    );
  }
}
