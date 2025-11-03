import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/constants/app_constants.dart';
import 'package:pos_moloni_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:pos_moloni_app/features/company/presentation/providers/company_provider.dart';
import 'package:pos_moloni_app/features/settings/presentation/screens/settings_screen.dart';

/// Tela Principal do POS (Ponto de Venda)
class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final selectedCompany = ref.watch(companyProvider).selectedCompany;

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedCompany?.name ?? AppConstants.appName),
        actions: [
          // Botão de configurações
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            tooltip: 'Configurações',
          ),
          
          // Botão de trocar empresa
          IconButton(
            icon: const Icon(Icons.business),
            onPressed: () {
              // Limpar empresa selecionada e voltar para seleção
              ref.read(companyProvider.notifier).clearError();
              // TO DO: Navegar para CompanySelectionScreen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Funcionalidade de trocar empresa em desenvolvimento'),
                ),
              );
            },
            tooltip: 'Trocar empresa',
          ),

          // Botão de logout
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Confirmar logout
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sair'),
                  content: const Text('Deseja realmente sair?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Sair'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                ref.read(authProvider.notifier).logout();
              }
            },
            tooltip: 'Sair',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding * 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícone
                Icon(
                  Icons.point_of_sale_rounded,
                  size: 120,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 32),

                // Título
                Text(
                  'Ponto de Venda',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Empresa
                if (selectedCompany != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.business,
                          size: 16,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          selectedCompany.name,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // Utilizador
                if (user != null) ...[
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    child: Text(
                      user.initials,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Olá, ${user.displayName}!',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 48),
                ],

                // Status
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Sistema pronto',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _StatusChip('Auth', true),
                          _StatusChip('Settings', true),
                          _StatusChip('Company', true),
                          _StatusChip('Products', false),
                          _StatusChip('Cart', false),
                          _StatusChip('Sales', false),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Próximo passo
                Text(
                  'Próximo: Implementar gestão de produtos e carrinho',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip de status
class _StatusChip extends StatelessWidget {

  const _StatusChip(this.label, this.implemented);
  final String label;
  final bool implemented;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: implemented
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: implemented
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: implemented ? FontWeight.w600 : FontWeight.normal,
        fontSize: 12,
      ),
      avatar: Icon(
        implemented ? Icons.check_circle : Icons.radio_button_unchecked,
        size: 16,
        color: implemented
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
