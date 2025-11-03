import 'package:pos_moloni_app/features/company/domain/entities/company.dart';

/// Model que estende Company e adiciona serialização JSON
class CompanyModel extends Company {
  const CompanyModel({
    required super.id,
    required super.name,
    required super.vat,
    required super.email,
    required super.address,
    required super.city,
    required super.zipCode,
    super.country,
    super.phone,
  });

  /// Converte Entity para Model
  factory CompanyModel.fromEntity(Company entity) {
    return CompanyModel(
      id: entity.id,
      name: entity.name,
      vat: entity.vat,
      email: entity.email,
      address: entity.address,
      city: entity.city,
      zipCode: entity.zipCode,
      country: entity.country,
      phone: entity.phone,
    );
  }

  /// Cria model a partir de JSON (API Moloni)
  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      id: json['company_id'] as int,
      name: json['name'] as String? ?? '',
      vat: _parseString(json['vat']),
      email: _parseString(json['email']),
      address: _parseString(json['address']),
      city: _parseString(json['city']),
      zipCode: _parseString(json['zip_code']),
      country: _parseString(json['country']),
      phone: _parseString(json['phone']),
    );
  }

  /// Helper para converter valores que podem ser Map ou String
  static String _parseString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map) return value['title'] ?? value['name'] ?? '';
    return value.toString();
  }

  /// Converte model para JSON
  Map<String, dynamic> toJson() {
    return {
      'company_id': id,
      'name': name,
      'vat': vat,
      'email': email,
      'address': address,
      'city': city,
      'zip_code': zipCode,
      'country': country,
      'phone': phone,
    };
  }

  /// Converte Model para Entity
  Company toEntity() {
    return Company(
      id: id,
      name: name,
      vat: vat,
      email: email,
      address: address,
      city: city,
      zipCode: zipCode,
      country: country,
      phone: phone,
    );
  }
}
