import 'package:equatable/equatable.dart';

/// Entity que representa uma empresa
class Company extends Equatable {

  const Company({
    required this.id,
    required this.name,
    required this.vat,
    required this.email,
    required this.address,
    required this.city,
    required this.zipCode,
    this.country,
    this.phone,
  });
  final int id;
  final String name;
  final String vat;
  final String email;
  final String address;
  final String city;
  final String zipCode;
  final String? country;
  final String? phone;

  /// Nome completo formatado
  String get fullName => name;

  /// Endereço completo formatado
  String get fullAddress => '$address, $zipCode $city';

  @override
  List<Object?> get props => [
        id,
        name,
        vat,
        email,
        address,
        city,
        zipCode,
        country,
        phone,
      ];

  @override
  String toString() => 'Company(id: $id, name: $name, vat: $vat)';
}
