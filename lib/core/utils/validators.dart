import 'package:pos_moloni_app/core/constants/app_constants.dart';

/// Validadores centralizados da aplicação
/// Retornam String? - null se válido, mensagem de erro se inválido
class AppValidators {
  /// Valida campo obrigatório
  static String? required(String? value, [String fieldName = 'Campo']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName obrigatório';
    }
    return null;
  }

  /// Valida email
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email obrigatório';
    }
    
    final emailRegex = RegExp(AppConstants.emailPattern);
    if (!emailRegex.hasMatch(value)) {
      return 'Email inválido';
    }
    
    return null;
  }

  /// Valida password
  static String? password(String? value, {int minLength = AppConstants.minPasswordLength}) {
    if (value == null || value.isEmpty) {
      return 'Password obrigatória';
    }
    
    if (value.length < minLength) {
      return 'Password deve ter pelo menos $minLength caracteres';
    }
    
    return null;
  }

  /// Valida confirmação de password
  static String? confirmPassword(String? value, String? originalPassword) {
    if (value == null || value.isEmpty) {
      return 'Confirme a password';
    }
    
    if (value != originalPassword) {
      return 'Passwords não coincidem';
    }
    
    return null;
  }

  /// Valida NIF português
  static String? nif(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'NIF obrigatório';
    }
    
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    
    if (digitsOnly.length != 9) {
      return 'NIF deve ter 9 dígitos';
    }
    
    // Validar checksum do NIF
    if (!_isValidNif(digitsOnly)) {
      return 'NIF inválido';
    }
    
    return null;
  }

  /// Valida telefone
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Telefone obrigatório';
    }
    
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    
    if (digitsOnly.length < 9) {
      return 'Telefone inválido';
    }
    
    return null;
  }

  /// Valida código postal português (XXXX-XXX)
  static String? postalCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Código postal obrigatório';
    }
    
    final regex = RegExp(r'^\d{4}-\d{3}$');
    if (!regex.hasMatch(value)) {
      return 'Formato: 0000-000';
    }
    
    return null;
  }

  /// Valida número (double)
  static String? number(String? value, {String fieldName = 'Valor'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName obrigatório';
    }
    
    final cleanValue = value.replaceAll(',', '.');
    if (double.tryParse(cleanValue) == null) {
      return '$fieldName inválido';
    }
    
    return null;
  }

  /// Valida número inteiro
  static String? integer(String? value, {String fieldName = 'Valor'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName obrigatório';
    }
    
    if (int.tryParse(value) == null) {
      return '$fieldName deve ser número inteiro';
    }
    
    return null;
  }

  /// Valida número positivo
  static String? positiveNumber(String? value, {String fieldName = 'Valor'}) {
    final numberError = number(value, fieldName: fieldName);
    if (numberError != null) return numberError;
    
    final cleanValue = value!.replaceAll(',', '.');
    final num = double.parse(cleanValue);
    
    if (num <= 0) {
      return '$fieldName deve ser positivo';
    }
    
    return null;
  }

  /// Valida intervalo numérico
  static String? numberRange(
    String? value, {
    required double min,
    required double max,
    String fieldName = 'Valor',
  }) {
    final numberError = number(value, fieldName: fieldName);
    if (numberError != null) return numberError;
    
    final cleanValue = value!.replaceAll(',', '.');
    final num = double.parse(cleanValue);
    
    if (num < min || num > max) {
      return '$fieldName deve estar entre $min e $max';
    }
    
    return null;
  }

  /// Valida quantidade
  static String? quantity(String? value) {
    return numberRange(
      value,
      min: AppConstants.minQuantity,
      max: AppConstants.maxQuantity,
      fieldName: 'Quantidade',
    );
  }

  /// Valida desconto (0-100%)
  static String? discount(String? value) {
    return numberRange(
      value,
      min: AppConstants.minDiscount,
      max: AppConstants.maxDiscount,
      fieldName: 'Desconto',
    );
  }

  /// Valida preço
  static String? price(String? value) {
    return positiveNumber(value, fieldName: 'Preço');
  }

  /// Valida comprimento mínimo
  static String? minLength(String? value, int min, [String fieldName = 'Campo']) {
    if (value == null || value.isEmpty) {
      return '$fieldName obrigatório';
    }
    
    if (value.length < min) {
      return '$fieldName deve ter pelo menos $min caracteres';
    }
    
    return null;
  }

  /// Valida comprimento máximo
  static String? maxLength(String? value, int max, [String fieldName = 'Campo']) {
    if (value != null && value.length > max) {
      return '$fieldName não pode ter mais de $max caracteres';
    }
    
    return null;
  }

  /// Valida EAN (código de barras)
  static String? ean(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // EAN é opcional
    }
    
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    
    if (digitsOnly.length != 8 && digitsOnly.length != 13) {
      return 'EAN deve ter 8 ou 13 dígitos';
    }
    
    // Validar checksum do EAN
    if (!_isValidEan(digitsOnly)) {
      return 'EAN inválido';
    }
    
    return null;
  }

  /// Valida URL
  static String? url(String? value, {String fieldName = 'URL'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName obrigatória';
    }
    
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return '$fieldName inválida';
    }
    
    return null;
  }

  /// Valida data (não pode ser futura)
  static String? pastDate(DateTime? date, {String fieldName = 'Data'}) {
    if (date == null) {
      return '$fieldName obrigatória';
    }
    
    if (date.isAfter(DateTime.now())) {
      return '$fieldName não pode ser futura';
    }
    
    return null;
  }

  /// Valida data (não pode ser passada)
  static String? futureDate(DateTime? date, {String fieldName = 'Data'}) {
    if (date == null) {
      return '$fieldName obrigatória';
    }
    
    if (date.isBefore(DateTime.now())) {
      return '$fieldName não pode ser passada';
    }
    
    return null;
  }

  // ========== Métodos auxiliares privados ==========

  /// Valida checksum do NIF português
  static bool _isValidNif(String nif) {
    if (nif.length != 9) return false;
    
    // Primeiro dígito deve ser 1, 2, 3, 5, 6, 8 ou 9
    final firstDigit = int.parse(nif[0]);
    if (![1, 2, 3, 5, 6, 8, 9].contains(firstDigit)) {
      return false;
    }
    
    // Calcular checksum
    var sum = 0;
    for (var i = 0; i < 8; i++) {
      sum += int.parse(nif[i]) * (9 - i);
    }
    
    var checkDigit = 11 - (sum % 11);
    if (checkDigit >= 10) checkDigit = 0;
    
    return checkDigit == int.parse(nif[8]);
  }

  /// Valida checksum do EAN
  static bool _isValidEan(String ean) {
    var sum = 0;
    
    for (var i = 0; i < ean.length - 1; i++) {
      final digit = int.parse(ean[i]);
      sum += i % 2 == 0 ? digit : digit * 3;
    }
    
    final checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit == int.parse(ean[ean.length - 1]);
  }

  /// Combina múltiplos validadores
  static String? combine(String? value, List<String? Function(String?)> validators) {
    for (final validator in validators) {
      final error = validator(value);
      if (error != null) return error;
    }
    return null;
  }
}

/// Extension para facilitar validação em TextFormField
extension ValidatorExtension on String? {
  String? get isRequired => AppValidators.required(this);
  String? get isEmail => AppValidators.email(this);
  String? get isNif => AppValidators.nif(this);
  String? get isPhone => AppValidators.phone(this);
  String? get isNumber => AppValidators.number(this);
  String? get isPositive => AppValidators.positiveNumber(this);
  String? get isPrice => AppValidators.price(this);
  String? get isQuantity => AppValidators.quantity(this);
  String? get isDiscount => AppValidators.discount(this);
}
