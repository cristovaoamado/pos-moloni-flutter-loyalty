import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/constants/app_constants.dart';
import 'package:pos_moloni_app/core/theme/app_theme.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:pos_moloni_app/features/auth/presentation/screens/login_screen.dart';
import 'package:pos_moloni_app/features/company/presentation/providers/company_provider.dart';
import 'package:pos_moloni_app/features/company/presentation/screens/company_selection_screen.dart';
import 'package:pos_moloni_app/features/pos/presentation/screens/pos_screen.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AppLogger.i('🎨 Building MyApp');

    // Observar estado de autenticação
    final authState = ref.watch(authProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,

      // Navegação baseada em estado de autenticação
      home: _buildHome(authState),

      // Builder para capturar contexto global (útil para SnackBars, Dialogs)
      builder: (context, child) {
        // Prevenir que o texto escale além do normal (acessibilidade)
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        );
      },
    );
  }

  Widget _buildHome(AuthState authState) {
    // Se estiver carregando (verificando auto-login)
    if (authState.isLoading && !authState.isAuthenticated) {
      return const _SplashScreen();
    }

    // Se autenticado
    if (authState.isAuthenticated) {
      // Verificar se tem empresa selecionada
      return const _AuthenticatedFlow();
    }

    // Se não autenticado, mostrar tela de login
    return const LoginScreen();
  }
}

/// Tela de splash (loading inicial)
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.point_of_sale_rounded,
              size: 100,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'A carregar...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Fluxo quando autenticado (verifica empresa)
class _AuthenticatedFlow extends ConsumerWidget {
  const _AuthenticatedFlow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Observar o estado completo para reagir a mudanças
    final companyState = ref.watch(companyProvider);
    final hasSelectedCompany = companyState.selectedCompany != null;

    // Se já tem empresa selecionada, ir para POS
    if (hasSelectedCompany) {
      return const PosScreen();
    }

    // Se não tem empresa, mostrar seleção
    return const CompanySelectionScreen();
  }
}
