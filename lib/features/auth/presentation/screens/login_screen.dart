import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/constants/app_constants.dart';
import 'package:pos_moloni_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:pos_moloni_app/features/auth/presentation/widgets/login_form.dart';
import 'package:pos_moloni_app/features/settings/presentation/providers/settings_provider.dart';
import 'package:pos_moloni_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:pos_moloni_app/features/company/presentation/screens/company_selection_screen.dart';

/// Tela de Login
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  @override
  void initState() {
    super.initState();
    
    // Escutar mudanças no estado de autenticação
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listen<AuthState>(authProvider, (previous, next) {
        // Se autenticado, navegar para seleção de empresa
        if (next.isAuthenticated && !next.isLoading) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const CompanySelectionScreen()),
          );
        }

        // Se houver erro, mostrar snackbar
        if (next.error != null && !next.isLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.error!),
              backgroundColor: Colors.red,
            ),
          );
          
          // Limpar erro após mostrar
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              ref.read(authProvider.notifier).clearError();
            }
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final hasValidSettings = ref.watch(hasValidSettingsProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.defaultPadding * 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo ou ícone
                Icon(
                  Icons.point_of_sale_rounded,
                  size: 100,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),

                // Título
                Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),

                // Subtítulo
                Text(
                  'Faça login para continuar',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 48),

                // Aviso se não tiver configurações
                if (!hasValidSettings) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Configuração necessária',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Configure as credenciais da API Moloni antes de fazer login.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Formulário de login
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: const LoginForm(),
                ),
                const SizedBox(height: 24),

                // Botão para configurações
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Configurações'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasValidSettings
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : Theme.of(context).colorScheme.primary,
                    foregroundColor: hasValidSettings
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.white,
                  ),
                ),

                // Loading indicator no rodapé (se estiver carregando)
                if (authState.isLoading) ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
