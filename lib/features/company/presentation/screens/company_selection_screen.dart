import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/constants/app_constants.dart';
import 'package:pos_moloni_app/features/company/domain/entities/company.dart';
import 'package:pos_moloni_app/features/company/presentation/providers/company_provider.dart';

/// Tela de Seleção de Empresa
class CompanySelectionScreen extends ConsumerStatefulWidget {
  const CompanySelectionScreen({super.key});

  @override
  ConsumerState<CompanySelectionScreen> createState() => _CompanySelectionScreenState();
}

class _CompanySelectionScreenState extends ConsumerState<CompanySelectionScreen> {
  @override
  void initState() {
    super.initState();

    // Carregar empresas ao inicializar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(companyProvider.notifier).loadCompanies();
    });
  }

  Future<void> _handleSelectCompany(Company company) async {
    final success = await ref.read(companyProvider.notifier).selectCompany(company);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Empresa "${company.name}" selecionada'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );

      // Navegar para PosScreen (substituindo a tela atual)
      // O app.dart já vai detectar que tem empresa e mostrar PosScreen
      // Então não precisamos fazer nada - ele vai atualizar automaticamente
    } else {
      final error = ref.read(companyProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Erro ao selecionar empresa'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyState = ref.watch(companyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecione uma Empresa'),
      ),
      body: SafeArea(
        child: _buildBody(companyState),
      ),
    );
  }

  Widget _buildBody(CompanyState state) {
    // Loading
    if (state.isLoading && state.companies.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('A carregar empresas...'),
          ],
        ),
      );
    }

    // Erro
    if (state.error != null && state.companies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding * 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Erro ao carregar empresas',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                state.error!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(companyProvider.notifier).loadCompanies();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    // Lista vazia
    if (state.companies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding * 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.business_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'Nenhuma empresa encontrada',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Contacte o suporte',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Lista de empresas
    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      itemCount: state.companies.length,
      itemBuilder: (context, index) {
        final company = state.companies[index];
        return _CompanyCard(
          company: company,
          onTap: () => _handleSelectCompany(company),
        );
      },
    );
  }
}

/// Card de empresa
class _CompanyCard extends StatelessWidget {

  const _CompanyCard({
    required this.company,
    required this.onTap,
  });
  final Company company;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Row(
            children: [
              // Ícone
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.business,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),

              // Informações
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome da empresa
                    Text(
                      company.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),

                    // NIF
                    Text(
                      'NIF: ${company.vat}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 2),

                    // Cidade
                    Text(
                      company.city,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),

              // Ícone de seleção
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
