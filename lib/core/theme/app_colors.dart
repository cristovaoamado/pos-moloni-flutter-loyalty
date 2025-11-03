import 'package:flutter/material.dart';

/// Cores da aplicação
class AppColors {
  // Cores principais
  static const Color primary = Color(0xFF2196F3); // Azul
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF64B5F6);
  
  static const Color secondary = Color(0xFF4CAF50); // Verde
  static const Color secondaryDark = Color(0xFF388E3C);
  static const Color secondaryLight = Color(0xFF81C784);
  
  static const Color accent = Color(0xFFFF9800); // Laranja
  
  // Cores de estado
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  
  // Cores neutras
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);
  
  // Cores de texto
  static const Color textPrimary = grey900;
  static const Color textSecondary = grey600;
  static const Color textHint = grey400;
  static const Color textDisabled = grey400;
  
  // Cores de background
  static const Color background = white;
  static const Color backgroundLight = grey50;
  static const Color backgroundDark = grey100;
  
  // Cores de superfície (cards, containers)
  static const Color surface = white;
  static const Color surfaceVariant = grey100;
  
  // Cores de divider
  static const Color divider = grey300;
  
  // Cores específicas da aplicação
  static const Color cartEmpty = grey300;
  static const Color cartActive = primary;
  
  static const Color productAvailable = success;
  static const Color productOutOfStock = error;
  
  static const Color discountBadge = error;
  static const Color newBadge = accent;
  
  // Gradientes
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient successGradient = LinearGradient(
    colors: [success, secondaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Opacidades
  static const double opacityDisabled = 0.38;
  static const double opacityMedium = 0.54;
  static const double opacityHigh = 0.87;
  
  // Sombras
  static List<BoxShadow> get defaultShadow => [
        BoxShadow(
          color: black.withValues(alpha: 0.1),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
  
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: black.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
  
  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: black.withValues(alpha: 0.12),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];
}
