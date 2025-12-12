import 'package:flutter/material.dart';

/// Cores da aplicação - Tema Castanho Chocolate & Olive
class AppColors {
  // ═══════════════════════════════════════════════════════════════════════════
  // CORES PRINCIPAIS - Castanho Chocolate
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color primary = Color.fromARGB(255, 77, 56, 3);       // Chocolate médio
  static const Color primaryDark = Color(0xFF3E2723);   // Chocolate escuro
  static const Color primaryLight = Color(0xFF8D6E63);  // Chocolate claro
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CORES SECUNDÁRIAS - Olive/Verde Azeitona
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color secondary = Color(0xFF6B8E23);     // Olive (Verde Azeitona)
  static const Color secondaryDark = Color(0xFF556B2F); // Dark Olive Green
  static const Color secondaryLight = Color(0xFF9ACD32);// Yellow Green (Olive claro)
  
  // ═══════════════════════════════════════════════════════════════════════════
  // COR DE DESTAQUE
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color accent = Color(0xFFD4A574);        // Caramelo/Bege dourado
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CORES DE ESTADO
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color success = Color(0xFF6B8E23);       // Olive (sucesso)
  static const Color warning = Color(0xFFD4A574);       // Caramelo (aviso)
  static const Color error = Color(0xFFC62828);         // Vermelho escuro
  static const Color info = Color(0xFF5D4037);          // Chocolate (info)
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CORES NEUTRAS
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  
  // Tons de cinza com subtom quente (castanho)
  static const Color grey50 = Color(0xFFFAF8F5);   // Quase branco com tom quente
  static const Color grey100 = Color(0xFFF5F0EB);  // Bege muito claro
  static const Color grey200 = Color(0xFFEBE3DB);  // Bege claro
  static const Color grey300 = Color(0xFFD7CCC8);  // Brown 100
  static const Color grey400 = Color(0xFFBCAAA4);  // Brown 200
  static const Color grey500 = Color(0xFFA1887F);  // Brown 300
  static const Color grey600 = Color(0xFF8D6E63);  // Brown 400
  static const Color grey700 = Color(0xFF6D4C41);  // Brown 500
  static const Color grey800 = Color(0xFF4E342E);  // Brown 700
  static const Color grey900 = Color(0xFF3E2723);  // Brown 900
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CORES DE TEXTO
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color textPrimary = Color(0xFF3E2723);   // Chocolate escuro
  static const Color textSecondary = Color(0xFF6D4C41); // Castanho médio
  static const Color textHint = Color(0xFFA1887F);      // Castanho claro
  static const Color textDisabled = Color(0xFFBCAAA4);  // Castanho muito claro
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CORES DE BACKGROUND
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color background = Color(0xFFFAF8F5);      // Creme/Off-white quente
  static const Color backgroundLight = Color(0xFFFFFBF5); // Quase branco
  static const Color backgroundDark = Color(0xFFF5F0EB);  // Bege claro
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CORES DE SUPERFÍCIE (cards, containers)
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color surface = white;
  static const Color surfaceVariant = Color(0xFFF5F0EB); // Bege muito claro
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CORES DE DIVIDER
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color divider = Color(0xFFD7CCC8); // Brown 100
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CORES ESPECÍFICAS DA APLICAÇÃO
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color cartEmpty = Color(0xFFBCAAA4);     // Castanho claro
  static const Color cartActive = primary;               // Chocolate
  
  static const Color productAvailable = secondary;       // Olive (disponível)
  static const Color productOutOfStock = error;          // Vermelho (esgotado)
  
  static const Color discountBadge = Color(0xFFC62828); // Vermelho escuro
  static const Color newBadge = secondary;               // Olive (novo)
  
  // Cores adicionais para POS
  static const Color priceTag = Color(0xFF5D4037);      // Chocolate (preços)
  static const Color quantityBadge = secondary;          // Olive (quantidades)
  static const Color selectedItem = Color(0xFFEFEBE9);  // Brown 50 (item selecionado)
  
  // ═══════════════════════════════════════════════════════════════════════════
  // GRADIENTES
  // ═══════════════════════════════════════════════════════════════════════════
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient successGradient = LinearGradient(
    colors: [secondary, secondaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFF8D6E63), Color(0xFF5D4037)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  // ═══════════════════════════════════════════════════════════════════════════
  // OPACIDADES
  // ═══════════════════════════════════════════════════════════════════════════
  static const double opacityDisabled = 0.38;
  static const double opacityMedium = 0.54;
  static const double opacityHigh = 0.87;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // SOMBRAS (com tom quente)
  // ═══════════════════════════════════════════════════════════════════════════
  static List<BoxShadow> get defaultShadow => [
        BoxShadow(
          color: primaryDark.withValues(alpha: 0.1),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
  
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: primaryDark.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
  
  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: primaryDark.withValues(alpha: 0.12),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];
}
