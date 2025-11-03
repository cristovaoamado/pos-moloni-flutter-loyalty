import 'package:intl/intl.dart';
import 'package:pos_moloni_app/core/constants/app_constants.dart';

/// Formatadores centralizados da aplicação
class AppFormatters {
  // Formatadores de números
  static final _currencyFormat = NumberFormat(AppConstants.currencyFormat, 'pt_PT');
  static final _percentFormat = NumberFormat('##0.00', 'pt_PT');
  static final _quantityFormat = NumberFormat('##0.###', 'pt_PT');
  
  // Formatadores de datas
  static final _dateFormat = DateFormat(AppConstants.dateFormat, 'pt_PT');
  static final _dateTimeFormat = DateFormat(AppConstants.dateTimeFormat, 'pt_PT');
  static final _timeFormat = DateFormat(AppConstants.timeFormat, 'pt_PT');

  /// Formata valor monetário
  /// Ex: 1234.56 → "1.234,56 €"
  static String currency(num? value) {
    if (value == null) return '0,00 ${AppConstants.currencySymbol}';
    return '${_currencyFormat.format(value)} ${AppConstants.currencySymbol}';
  }

  /// Formata valor monetário sem símbolo
  /// Ex: 1234.56 → "1.234,56"
  static String currencyWithoutSymbol(num? value) {
    if (value == null) return '0,00';
    return _currencyFormat.format(value);
  }

  /// Formata percentagem
  /// Ex: 23 → "23,00%"
  static String percentage(num? value) {
    if (value == null) return '0,00%';
    return '${_percentFormat.format(value)}%';
  }

  /// Formata quantidade
  /// Ex: 1.5 → "1,5" | 1.0 → "1" | 1.234 → "1,234"
  static String quantity(num? value) {
    if (value == null) return '0';
    return _quantityFormat.format(value);
  }

  /// Formata data
  /// Ex: 2025-01-15 → "15/01/2025"
  static String date(DateTime? date) {
    if (date == null) return '-';
    return _dateFormat.format(date);
  }

  /// Formata data e hora
  /// Ex: 2025-01-15 14:30 → "15/01/2025 14:30"
  static String dateTime(DateTime? date) {
    if (date == null) return '-';
    return _dateTimeFormat.format(date);
  }

  /// Formata hora
  /// Ex: 14:30 → "14:30"
  static String time(DateTime? date) {
    if (date == null) return '-';
    return _timeFormat.format(date);
  }

  /// Formata data relativa (hoje, ontem, etc.)
  /// Ex: hoje → "Hoje" | ontem → "Ontem" | 15/01/2025
  static String relativeDate(DateTime? date) {
    if (date == null) return '-';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    final difference = today.difference(dateOnly).inDays;
    
    if (difference == 0) return 'Hoje';
    if (difference == 1) return 'Ontem';
    if (difference == -1) return 'Amanhã';
    if (difference > 1 && difference < 7) return '$difference dias atrás';
    
    return AppFormatters.date(date);
  }

  /// Formata NIF português
  /// Ex: 123456789 → "123 456 789"
  static String nif(String? nif) {
    if (nif == null || nif.isEmpty) return '-';
    if (nif.length != 9) return nif;
    
    return '${nif.substring(0, 3)} ${nif.substring(3, 6)} ${nif.substring(6, 9)}';
  }

  /// Formata telefone
  /// Ex: 912345678 → "912 345 678"
  static String phone(String? phone) {
    if (phone == null || phone.isEmpty) return '-';
    
    // Remove tudo que não é dígito
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    
    if (digitsOnly.length == 9) {
      return '${digitsOnly.substring(0, 3)} ${digitsOnly.substring(3, 6)} ${digitsOnly.substring(6, 9)}';
    }
    
    return phone;
  }

  /// Formata código de barras (EAN)
  /// Ex: 1234567890123 → "1234567 890123"
  static String ean(String? ean) {
    if (ean == null || ean.isEmpty) return '-';
    
    if (ean.length == 13) {
      return '${ean.substring(0, 7)} ${ean.substring(7, 13)}';
    } else if (ean.length == 8) {
      return '${ean.substring(0, 4)} ${ean.substring(4, 8)}';
    }
    
    return ean;
  }

  /// Formata referência de produto
  /// Ex: PRD001 → "PRD-001"
  static String reference(String? ref) {
    if (ref == null || ref.isEmpty) return '-';
    return ref;
  }

  /// Trunca texto longo
  /// Ex: "Este é um texto muito longo..." (max 20) → "Este é um texto m..."
  static String truncate(String? text, int maxLength) {
    if (text == null || text.isEmpty) return '-';
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  /// Formata bytes em tamanho legível
  /// Ex: 1024 → "1 KB" | 1048576 → "1 MB"
  static String fileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '0 B';
    
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    var size = bytes.toDouble();
    
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  /// Capitaliza primeira letra
  /// Ex: "joão silva" → "João silva"
  static String capitalize(String? text) {
    if (text == null || text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Capitaliza todas as palavras
  /// Ex: "joão silva" → "João Silva"
  static String capitalizeWords(String? text) {
    if (text == null || text.isEmpty) return '';
    
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Remove acentos
  /// Ex: "José Açores" → "Jose Acores"
  static String removeAccents(String text) {
    const withAccents = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    const withoutAccents = 'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';
    
    var result = text;
    for (var i = 0; i < withAccents.length; i++) {
      result = result.replaceAll(withAccents[i], withoutAccents[i]);
    }
    return result;
  }

  /// Formata duração
  /// Ex: Duration(seconds: 90) → "1:30"
  static String duration(Duration? duration) {
    if (duration == null) return '0:00';
    
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Parse de string para double (suporta vírgula e ponto)
  /// Ex: "1.234,56" → 1234.56 | "1,234.56" → 1234.56
  static double? parseDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    
    // Remove espaços
    value = value.trim();
    
    // Substitui vírgula por ponto
    value = value.replaceAll(',', '.');
    
    // Remove pontos de milhares (se houver mais de um ponto)
    if (value.split('.').length > 2) {
      final parts = value.split('.');
      value = '${parts.sublist(0, parts.length - 1).join('')}.${parts.last}';
    }
    
    return double.tryParse(value);
  }

  /// Parse de string para int
  static int? parseInt(String? value) {
    if (value == null || value.isEmpty) return null;
    return int.tryParse(value.trim());
  }
}
