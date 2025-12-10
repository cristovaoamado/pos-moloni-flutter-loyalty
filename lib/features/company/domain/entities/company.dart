import 'package:equatable/equatable.dart';

/// Entidade que representa uma empresa no Moloni
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
    this.countryId,
    this.phone,
    this.fax,
    this.website,
    this.capital,
    this.commercialRegistrationNumber,
    this.registryOffice,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String vat;
  final String email;
  final String address;
  final String city;
  final String zipCode;
  final String? country;
  final int? countryId;
  final String? phone;
  final String? fax;
  final String? website;
  final String? capital;
  final String? commercialRegistrationNumber;
  final String? registryOffice;
  final String? imageUrl;

  /// Verifica se tem imagem
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  /// Morada completa formatada
  String get fullAddress {
    final parts = <String>[];
    if (address.isNotEmpty) parts.add(address);
    if (zipCode.isNotEmpty || city.isNotEmpty) {
      parts.add('$zipCode $city'.trim());
    }
    if (country != null && country!.isNotEmpty && country != 'PT') {
      parts.add(country!);
    }
    return parts.join(', ');
  }

  /// Morada formatada para múltiplas linhas
  String get fullAddressMultiline {
    final parts = <String>[];
    if (address.isNotEmpty) parts.add(address);
    if (zipCode.isNotEmpty || city.isNotEmpty) {
      parts.add('$zipCode $city'.trim());
    }
    return parts.join('\n');
  }

  /// Cria copia com novos valores
  Company copyWith({
    int? id,
    String? name,
    String? vat,
    String? email,
    String? address,
    String? city,
    String? zipCode,
    String? country,
    int? countryId,
    String? phone,
    String? fax,
    String? website,
    String? capital,
    String? commercialRegistrationNumber,
    String? registryOffice,
    String? imageUrl,
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      vat: vat ?? this.vat,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      zipCode: zipCode ?? this.zipCode,
      country: country ?? this.country,
      countryId: countryId ?? this.countryId,
      phone: phone ?? this.phone,
      fax: fax ?? this.fax,
      website: website ?? this.website,
      capital: capital ?? this.capital,
      commercialRegistrationNumber: commercialRegistrationNumber ?? this.commercialRegistrationNumber,
      registryOffice: registryOffice ?? this.registryOffice,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  /// Cria Company a partir do JSON da API (companies/getOne)
  factory Company.fromApiJson(Map<String, dynamic> json) {
    // Extrair imagem - construir URL completa
    String? imageUrl;
    final imageValue = json['image'];
    if (imageValue != null && imageValue.toString().isNotEmpty) {
      imageUrl = 'https://www.moloni.pt/_imagens/?img=${imageValue.toString()}';
    }

    return Company(
      id: json['company_id'] as int? ?? 0,
      name: json['name']?.toString() ?? '',
      vat: json['vat']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      zipCode: json['zip_code']?.toString() ?? '',
      country: (json['country'] as Map<String, dynamic>?)?['name']?.toString(),
      countryId: json['country_id'] as int?,
      phone: json['phone']?.toString(),
      fax: json['fax']?.toString(),
      website: json['website']?.toString(),
      capital: json['capital']?.toString(),
      commercialRegistrationNumber: json['commercial_registration_number']?.toString(),
      registryOffice: json['registry_office']?.toString(),
      imageUrl: imageUrl,
    );
  }

  @override
  List<Object?> get props => [id, name, vat, imageUrl];

  @override
  String toString() => 'Company(id: $id, name: $name, vat: $vat, hasImage: $hasImage)';
}
