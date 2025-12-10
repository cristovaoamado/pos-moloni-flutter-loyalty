import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/company/domain/entities/company.dart';
import 'package:pos_moloni_app/features/company/presentation/providers/company_data_provider.dart';
import 'package:pos_moloni_app/features/company/presentation/providers/company_provider.dart';
import 'package:pos_moloni_app/features/pos/presentation/screens/pos_screen.dart';

class CompanySelectionScreen extends ConsumerStatefulWidget {
  const CompanySelectionScreen({super.key});

  @override
  ConsumerState<CompanySelectionScreen> createState() => _CompanySelectionScreenState();
}

class _CompanySelectionScreenState extends ConsumerState<CompanySelectionScreen> {
  bool _isSelecting = false;

  @override
  void initState() {
    super.initState();
    // Carregar lista de empresas ao iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(companyProvider.notifier).loadCompanies();
    });
  }

  Future<void> _selectCompany(Company company) async {
    if (_isSelecting) return;
    
    setState(() => _isSelecting = true);

    try {
      AppLogger.i('A seleccionar empresa: ${company.name}');
      AppLogger.i('A image empresa: ${company.imageUrl}');
      AppLogger.i('tem image empresa: ${company.hasImage}');
      
      // 1. Seleccionar empresa (guarda na storage)
      final success = await ref.read(companyProvider.notifier).selectCompany(company);
      
      if (!success) {
        throw Exception('Erro ao seleccionar empresa');
      }

      // 2. Carregar dados da empresa (series, metodos pagamento, etc)
      await ref.read(companyDataProvider.notifier).loadCompanyData(company);

      // 3. Navegar para POS
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const PosScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      AppLogger.e('Erro ao seleccionar empresa', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao seleccionar empresa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSelecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyState = ref.watch(companyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Empresa'),
        automaticallyImplyLeading: false,
      ),
      body: _buildBody(companyState),
    );
  }

  Widget _buildBody(CompanyState state) {
    // Loading
    if (state.isLoading) {
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
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                state.error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.read(companyProvider.notifier).loadCompanies(),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    // Sem empresas
    if (state.companies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.business_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              const Text(
                'Nenhuma empresa encontrada',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Verifique as suas credenciais Moloni',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.read(companyProvider.notifier).loadCompanies(),
                icon: const Icon(Icons.refresh),
                label: const Text('Recarregar'),
              ),
            ],
          ),
        ),
      );
    }

    // Lista de empresas
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: state.companies.length,
          itemBuilder: (context, index) {
            final company = state.companies[index];
            return _buildCompanyCard(company);
          },
        ),
        
        // Overlay de loading ao seleccionar
        if (_isSelecting)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('A carregar dados da empresa...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCompanyCard(Company company) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: _isSelecting ? null : () => _selectCompany(company),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.business,
                  size: 28,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (company.vat.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'NIF: ${company.vat}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                    if (company.city.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        company.city,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Arrow
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
