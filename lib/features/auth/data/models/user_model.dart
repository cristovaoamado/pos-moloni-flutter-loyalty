import 'package:pos_moloni_app/features/auth/domain/entities/user.dart';

/// Model que estende User e adiciona serialização JSON
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.username,
    super.email,
    super.name,
  });

  /// Converte Entity para Model
  factory UserModel.fromEntity(User entity) {
    return UserModel(
      id: entity.id,
      username: entity.username,
      email: entity.email,
      name: entity.name,
    );
  }

  /// Cria model a partir de JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? json['user_id']?.toString() ?? '',
      username: json['username'] as String? ?? json['email'] as String? ?? '',
      email: json['email'] as String?,
      name: json['name'] as String? ?? json['full_name'] as String?,
    );
  }

  /// Converte model para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'name': name,
    };
  }

  /// Converte Model para Entity
  User toEntity() {
    return User(
      id: id,
      username: username,
      email: email,
      name: name,
    );
  }

  /// Cria cópia com alterações
  UserModel copyWith({
    String? id,
    String? username,
    String? email,
    String? name,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      name: name ?? this.name,
    );
  }
}
