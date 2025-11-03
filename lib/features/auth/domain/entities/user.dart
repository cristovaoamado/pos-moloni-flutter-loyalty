import 'package:equatable/equatable.dart';

/// Entity que representa um utilizador autenticado
class User extends Equatable {

  const User({
    required this.id,
    required this.username,
    this.email,
    this.name,
  });
  final String id;
  final String username;
  final String? email;
  final String? name;

  /// Nome para display (prioriza name, senão username)
  String get displayName => name ?? username;

  /// Iniciais para avatar
  String get initials {
    final displayName = this.displayName;
    final parts = displayName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName.substring(0, 1).toUpperCase();
  }

  @override
  List<Object?> get props => [id, username, email, name];

  @override
  String toString() => 'User(id: $id, username: $username, name: $name)';
}