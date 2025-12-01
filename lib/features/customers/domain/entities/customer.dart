import 'package:equatable/equatable.dart';

/// Entidade que representa um cliente
class Customer extends Equatable {
  const Customer({
    required this.id,
    required this.name,
    required this.vat,
    this.number,
    this.email,
    this.phone,
    this.address,
    this.zipCode,
    this.city,
    this.countryId,
    this.languageId,
    this.maturityDateId,
    this.paymentMethodId,
    this.deliveryMethodId,
    this.salespersonId,
  });

  final int id;
  final String name;
  final String vat;
  final String? number;
  final String? email;
  final String? phone;
  final String? address;
  final String? zipCode;
  final String? city;
  final int? countryId;
  final int? languageId;
  final int? maturityDateId;
  final int? paymentMethodId;
  final int? deliveryMethodId;
  final int? salespersonId;

  /// Cliente final (consumidor anónimo)
  static const Customer consumidorFinal = Customer(
    id: 0,
    name: 'Consumidor Final',
    vat: '999999990',
  );

  /// Verifica se é consumidor final
  bool get isConsumidorFinal => id == 0 || vat == '999999990';

  /// Formata NIF para exibição
  String get formattedVat => vat.isEmpty ? '-' : vat;

  @override
  List<Object?> get props => [
        id,
        name,
        vat,
        number,
        email,
        phone,
        address,
        zipCode,
        city,
        countryId,
      ];
}
