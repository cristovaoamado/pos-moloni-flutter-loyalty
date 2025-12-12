import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/constants/api_constants.dart';
import 'package:pos_moloni_app/core/services/storage_service.dart';
import 'package:pos_moloni_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:pos_moloni_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:pos_moloni_app/features/company/domain/entities/company.dart';
import 'package:pos_moloni_app/features/company/presentation/providers/company_data_provider.dart';
import 'package:pos_moloni_app/features/company/presentation/providers/company_provider.dart';
import 'package:pos_moloni_app/features/printer/domain/entities/printer_config.dart';
import 'package:pos_moloni_app/features/printer/presentation/providers/printer_provider.dart';
import 'package:pos_moloni_app/features/products/presentation/providers/product_provider.dart';
import 'package:pos_moloni_app/features/scale/services/scale_service.dart';

/// Ecrã de Configurações
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storage = PlatformStorage.instance;

  // Controllers
  final _apiUrlController = TextEditingController();
  final _clientIdController = TextEditingController();
  final _clientSecretController = TextEditingController();

  // Estado
  bool _isLoading = true;
  bool _isSaving = false;
  bool _showClientSecret = false;
  String? _savedUsername;
  String? _savedPassword;
  Company? _selectedCompany;
  List<Company> _availableCompanies = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _clientIdController.dispose();
    _clientSecretController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      // Carregar configurações da API
      final apiUrl = await _storage.read(key: ApiConstants.keyApiUrl);
      final clientId = await _storage.read(key: ApiConstants.keyClientId);
      final clientSecret =
          await _storage.read(key: ApiConstants.keyClientSecret);

      // Carregar credenciais de login guardadas
      final username = await _storage.read(key: 'moloni_username');
      final password = await _storage.read(key: 'moloni_password');

      // Carregar empresa selecionada
      final companyId = await _storage.read(key: ApiConstants.keyCompanyId);
      final companyName = await _storage.read(key: 'company_name');
      final companyVat = await _storage.read(key: 'company_vat');
      final companyEmail = await _storage.read(key: 'company_email');
      final companyAddress = await _storage.read(key: 'company_address');
      final companyCity = await _storage.read(key: 'company_city');
      final companyZipCode = await _storage.read(key: 'company_zip_code');

      if (mounted) {
        setState(() {
          _apiUrlController.text = apiUrl ?? ApiConstants.defaultMoloniApiUrl;
          _clientIdController.text = clientId ?? '';
          _clientSecretController.text = clientSecret ?? '';
          _savedUsername = username;
          _savedPassword = password;

          if (companyId != null && companyName != null) {
            _selectedCompany = Company(
              id: int.tryParse(companyId) ?? 0,
              name: companyName,
              vat: companyVat ?? '',
              email: companyEmail ?? '',
              address: companyAddress ?? '',
              city: companyCity ?? '',
              zipCode: companyZipCode ?? '',
            );
          }

          _isLoading = false;
        });
      }

      // Carregar lista de empresas disponíveis
      _loadCompanies();
    } catch (e) {
      debugPrint('Erro ao carregar configurações: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadCompanies() async {
    final companyState = ref.read(companyProvider);
    if (companyState.companies.isNotEmpty) {
      setState(() {
        _availableCompanies = companyState.companies;
        // Atualizar empresa selecionada com dados completos
        if (_selectedCompany != null) {
          final found = _availableCompanies.firstWhere(
            (c) => c.id == _selectedCompany!.id,
            orElse: () => _selectedCompany!,
          );
          _selectedCompany = found;
        }
      });
    } else {
      // Tentar carregar empresas
      await ref.read(companyProvider.notifier).loadCompanies();
      final newState = ref.read(companyProvider);
      if (mounted && newState.companies.isNotEmpty) {
        setState(() {
          _availableCompanies = newState.companies;
        });
      }
    }
  }

  Future<void> _saveApiSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await _storage.write(
        key: ApiConstants.keyApiUrl,
        value: _apiUrlController.text.trim(),
      );
      await _storage.write(
        key: ApiConstants.keyClientId,
        value: _clientIdController.text.trim(),
      );
      await _storage.write(
        key: ApiConstants.keyClientSecret,
        value: _clientSecretController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações da API guardadas'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _changeCompany() async {
    if (_availableCompanies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma empresa disponível')),
      );
      return;
    }

    final selected = await showDialog<Company>(
      context: context,
      builder: (context) => _CompanySelectionDialog(
        companies: _availableCompanies,
        currentCompany: _selectedCompany,
      ),
    );

    if (selected != null && selected.id != _selectedCompany?.id) {
      if (!mounted) return;
      // Mostrar diálogo de confirmação
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Alterar Empresa?'),
          content: Text(
            'Ao alterar para "${selected.name}", todos os dados da sessão actual serão limpos:\n\n'
            '• Carrinho de compras\n'
            '• Pesquisas de produtos\n'
            '• Séries de documentos\n\n'
            'O POS será reiniciado.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Mostrar loading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('A mudar de empresa...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      try {
        // 1. LIMPAR todos os dados da empresa anterior
        ref.read(companyDataProvider.notifier).clearData();
        ref.read(cartProvider.notifier).clearCart();
        ref.read(productProvider.notifier).clearSearchResults();

        // 2. Guardar nova empresa no storage
        await _storage.write(
          key: ApiConstants.keyCompanyId,
          value: selected.id.toString(),
        );
        await _storage.write(key: 'company_name', value: selected.name);
        await _storage.write(key: 'company_vat', value: selected.vat);
        await _storage.write(key: 'company_email', value: selected.email);
        await _storage.write(key: 'company_address', value: selected.address);
        await _storage.write(key: 'company_city', value: selected.city);
        await _storage.write(key: 'company_zip_code', value: selected.zipCode);

        // 3. Actualizar provider da empresa (isto vai triggerar o reload dos dados)
        ref.read(companyProvider.notifier).selectCompany(selected);

        // 4. Forçar recarregamento de todos os dados da nova empresa
        await ref.read(companyDataProvider.notifier).loadCompanyData(selected);

        setState(() => _selectedCompany = selected);

        // Fechar loading
        if (mounted) {
          Navigator.pop(context); // Fecha o loading dialog
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text('Empresa alterada para: ${selected.name}'),),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );

          // Voltar ao POS (reiniciar)
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        // Fechar loading em caso de erro
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao mudar de empresa: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _clearLoginData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar dados de login?'),
        content: const Text(
          'As credenciais guardadas serão apagadas. '
          'Terá de fazer login novamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _storage.delete(key: 'moloni_username');
      await _storage.delete(key: 'moloni_password');

      setState(() {
        _savedUsername = null;
        _savedPassword = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados de login limpos')),
        );
      }
    }
  }

  Future<void> _resetAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Repor tudo?'),
        content: const Text(
          'ATENÇÃO: Todas as configurações, dados de login e empresa '
          'serão apagados. A aplicação voltará ao estado inicial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Apagar Tudo'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _storage.deleteAll();
      ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ==================== SESSÃO ATUAL ====================
                    _buildSectionHeader('Sessão Atual', Icons.person),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              'Utilizador',
                              authState.user?.displayName ?? 'Não autenticado',
                              icon: Icons.account_circle,
                            ),
                            const Divider(),
                            _buildInfoRow(
                              'Estado',
                              authState.isAuthenticated
                                  ? 'Autenticado'
                                  : 'Não autenticado',
                              icon: authState.isAuthenticated
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              valueColor: authState.isAuthenticated
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==================== EMPRESA ====================
                    _buildSectionHeader('Empresa', Icons.business),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              'Empresa selecionada',
                              _selectedCompany?.name ?? 'Nenhuma',
                              icon: Icons.store,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _changeCompany,
                                icon: const Icon(Icons.swap_horiz),
                                label: const Text('Alterar Empresa'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==================== CREDENCIAIS GUARDADAS ====================
                    _buildSectionHeader('Credenciais Guardadas', Icons.key),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              'Username',
                              _savedUsername ?? 'Não guardado',
                              icon: Icons.person_outline,
                            ),
                            const Divider(),
                            _buildInfoRow(
                              'Password',
                              _savedPassword != null
                                  ? '••••••••'
                                  : 'Não guardada',
                              icon: Icons.lock_outline,
                            ),
                            if (_savedUsername != null ||
                                _savedPassword != null) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _clearLoginData,
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Limpar credenciais'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              'As credenciais são usadas para login automático',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.outline,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==================== API MOLONI ====================
                    _buildSectionHeader('API Moloni', Icons.api),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _apiUrlController,
                              decoration: const InputDecoration(
                                labelText: 'URL da API',
                                hintText: 'https://api.moloni.pt/v1',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.link),
                              ),
                              validator: (v) => v?.trim().isEmpty == true
                                  ? 'Obrigatório'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _clientIdController,
                              decoration: const InputDecoration(
                                labelText: 'Client ID',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.badge),
                              ),
                              validator: (v) => v?.trim().isEmpty == true
                                  ? 'Obrigatório'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _clientSecretController,
                              obscureText: !_showClientSecret,
                              decoration: InputDecoration(
                                labelText: 'Client Secret',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.vpn_key),
                                suffixIcon: IconButton(
                                  icon: Icon(_showClientSecret
                                      ? Icons.visibility_off
                                      : Icons.visibility,),
                                  onPressed: () => setState(() =>
                                      _showClientSecret = !_showClientSecret,),
                                ),
                              ),
                              validator: (v) => v?.trim().isEmpty == true
                                  ? 'Obrigatório'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isSaving ? null : _saveApiSettings,
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save),
                                label: Text(
                                    _isSaving ? 'A guardar...' : 'Guardar API',),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==================== IMPRESSORA ====================
                    _buildSectionHeader('Impressora', Icons.print),
                    const _PrinterSettingsCard(),

                    const SizedBox(height: 24),

                    // ==================== BALANÇA ====================
                    _buildSectionHeader('Balança', Icons.scale),
                    const _ScaleSettingsCard(),

                    const SizedBox(height: 24),

                    // ==================== INFO ====================
                    _buildSectionHeader('Informações', Icons.info_outline),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              'Plataforma',
                              _getPlatformName(),
                              icon: Icons.devices,
                            ),
                            const Divider(),
                            _buildInfoRow(
                              'Versão',
                              '1.0.0',
                              icon: Icons.info,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==================== AÇÕES ====================
                    ElevatedButton.icon(
                      onPressed: _resetAll,
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Repor Configuração'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    IconData? icon,
    Color? valueColor,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon,
              size: 20,
              color: valueColor ?? Theme.of(context).colorScheme.outline,),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
        ),
      ],
    );
  }

  String _getPlatformName() {
    if (kIsWeb) return 'Web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.linux:
        return 'Linux';
      default:
        return 'Desconhecido';
    }
  }
}

/// Diálogo de seleção de empresa
class _CompanySelectionDialog extends StatelessWidget {
  const _CompanySelectionDialog({
    required this.companies,
    this.currentCompany,
  });

  final List<Company> companies;
  final Company? currentCompany;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.business),
          SizedBox(width: 12),
          Text('Selecionar Empresa'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: companies.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final company = companies[index];
            final isSelected = company.id == currentCompany?.id;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.business,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
              title: Text(
                company.name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check,
                      color: Theme.of(context).colorScheme.primary,)
                  : null,
              selected: isSelected,
              onTap: () => Navigator.pop(context, company),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

/// Card de configurações da impressora
class _PrinterSettingsCard extends ConsumerStatefulWidget {
  const _PrinterSettingsCard();

  @override
  ConsumerState<_PrinterSettingsCard> createState() =>
      _PrinterSettingsCardState();
}

class _PrinterSettingsCardState extends ConsumerState<_PrinterSettingsCard> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadControllers();
  }

  void _loadControllers() {
    final config = ref.read(printerProvider).config;
    _ipController.text = config.address;
    _portController.text = config.port.toString();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final printerState = ref.watch(printerProvider);
    final config = printerState.config;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Switch activo/inactivo
            SwitchListTile(
              title: const Text('Impressora Activa'),
              subtitle: Text(config.isEnabled
                  ? 'Impressão automática activa'
                  : 'Impressão desactivada',),
              value: config.isEnabled,
              onChanged: (value) {
                ref.read(printerProvider.notifier).setEnabled(value);
              },
              secondary: Icon(
                config.isEnabled ? Icons.print : Icons.print_disabled,
                color: config.isEnabled ? Colors.green : Colors.grey,
              ),
            ),

            const Divider(),

            // Tipo de conexão
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tipo de Conexão',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<PrinterConnectionType>(
                    segments: const [
                      ButtonSegment(
                        value: PrinterConnectionType.usb,
                        label: Text('USB'),
                        icon: Icon(Icons.usb),
                      ),
                      ButtonSegment(
                        value: PrinterConnectionType.network,
                        label: Text('Rede'),
                        icon: Icon(Icons.wifi),
                      ),
                    ],
                    selected: {config.connectionType},
                    onSelectionChanged: (selection) {
                      ref
                          .read(printerProvider.notifier)
                          .setConnectionType(selection.first);
                      _loadControllers();
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Configuração específica por tipo
            if (config.connectionType == PrinterConnectionType.usb)
              _buildUsbConfig(config, printerState)
            else
              _buildNetworkConfig(config),

            const Divider(height: 32),

            // Largura do papel
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Largura do Papel',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 58,
                        label: Text('58mm'),
                      ),
                      ButtonSegment(
                        value: 80,
                        label: Text('80mm'),
                      ),
                    ],
                    selected: {config.paperWidth},
                    onSelectionChanged: (selection) {
                      ref
                          .read(printerProvider.notifier)
                          .setPaperWidth(selection.first);
                    },
                  ),
                ],
              ),
            ),

            const Divider(height: 32),

            // Opções adicionais
            SwitchListTile(
              title: const Text('Imprimir automaticamente'),
              subtitle: const Text('Imprimir talão após cada venda'),
              value: config.autoPrint,
              onChanged: (value) {
                ref.read(printerProvider.notifier).setAutoPrint(value);
              },
              dense: true,
            ),

            SwitchListTile(
              title: const Text('Imprimir cópia'),
              subtitle: const Text('Imprimir segunda via do talão'),
              value: config.printCopy,
              onChanged: (value) {
                ref.read(printerProvider.notifier).setPrintCopy(value);
              },
              dense: true,
            ),

            const Divider(height: 32),

            // Resultado do último teste
            if (printerState.lastTestResult != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: printerState.lastTestResult!.success
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: printerState.lastTestResult!.success
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      printerState.lastTestResult!.success
                          ? Icons.check_circle
                          : Icons.error,
                      color: printerState.lastTestResult!.success
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        printerState.lastTestResult!.success
                            ? printerState.lastTestResult!.message ?? 'Sucesso'
                            : printerState.lastTestResult!.error ?? 'Erro',
                      ),
                    ),
                  ],
                ),
              ),

            // Botões de teste
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: printerState.isTesting || !config.isConfigured
                        ? null
                        : () =>
                            ref.read(printerProvider.notifier).testConnection(),
                    icon: printerState.isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_find),
                    label: Text(printerState.isTesting
                        ? 'A testar...'
                        : 'Testar Conexão',),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: printerState.isPrinting || !config.isConfigured
                        ? null
                        : () =>
                            ref.read(printerProvider.notifier).printTestPage(),
                    icon: printerState.isPrinting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print),
                    label: Text(printerState.isPrinting
                        ? 'A imprimir...'
                        : 'Imprimir Teste',),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsbConfig(PrinterConfig config, PrinterState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Impressora USB',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () =>
                  ref.read(printerProvider.notifier).refreshPrinters(),
              tooltip: 'Actualizar lista',
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (state.availablePrinters.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Theme.of(context).colorScheme.outline,),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Nenhuma impressora USB encontrada'),
                ),
              ],
            ),
          )
        else
          DropdownButtonFormField<String>(
            value: config.name.isEmpty ? null : config.name,
            decoration: const InputDecoration(
              labelText: 'Selecionar Impressora',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.print),
            ),
            items: state.availablePrinters.map((printer) {
              return DropdownMenuItem(
                value: printer,
                child: Text(printer),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                ref.read(printerProvider.notifier).setPrinterName(value);
              }
            },
          ),
      ],
    );
  }

  Widget _buildNetworkConfig(PrinterConfig config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Endereço de Rede',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'Endereço IP',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.computer),
                  hintText: '192.168.1.100',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  ref.read(printerProvider.notifier).setNetworkAddress(value);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Porta',
                  border: OutlineInputBorder(),
                  hintText: '9100',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final port = int.tryParse(value);
                  if (port != null) {
                    ref.read(printerProvider.notifier).setPort(port);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Card de configurações da balança
class _ScaleSettingsCard extends StatefulWidget {
  const _ScaleSettingsCard();

  @override
  State<_ScaleSettingsCard> createState() => _ScaleSettingsCardState();
}

class _ScaleSettingsCardState extends State<_ScaleSettingsCard> {
  final _scaleService = ScaleService();

  bool _isLoading = true;
  bool _isTesting = false;
  bool _isEnabled = false;
  String? _selectedPort;
  List<String> _availablePorts = [];
  int _baudRate = 9600;
  ScaleProtocol _protocol = ScaleProtocol.dibal;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _scaleService.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);

    try {
      await _scaleService.loadConfig();
      _refreshPorts();

      final config = _scaleService.config;
      setState(() {
        _isEnabled = config.serialPort.isNotEmpty;
        _selectedPort = config.serialPort.isEmpty ? null : config.serialPort;
        _baudRate = config.baudRate;
        _protocol = config.protocol;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _refreshPorts() {
    setState(() {
      _availablePorts = ScaleService.getAvailablePorts();
    });
  }

  Future<void> _saveConfig() async {
    final config = ScaleConfig(
      connectionType: ScaleConnectionType.serial,
      protocol: _protocol,
      serialPort: _selectedPort ?? '',
      baudRate: _baudRate,
      dataBits: 8,
      stopBits: 1,
      parity: 0, // None
    );

    await _scaleService.saveConfig(config);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuração da balança guardada'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    if (_selectedPort == null) {
      setState(() {
        _testResult = 'Selecione uma porta primeiro';
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
      _testSuccess = null;
    });

    try {
      // Guardar config temporariamente para teste
      final config = ScaleConfig(
        connectionType: ScaleConnectionType.serial,
        protocol: _protocol,
        serialPort: _selectedPort!,
        baudRate: _baudRate,
        dataBits: 8,
        stopBits: 1,
        parity: 0,
      );

      await _scaleService.saveConfig(config);

      final reading = await _scaleService.readWeight();

      if (reading != null) {
        setState(() {
          _testResult =
              'Peso lido: ${reading.weight.toStringAsFixed(3)} ${reading.unit}';
          _testSuccess = true;
        });
      } else {
        setState(() {
          _testResult = 'Sem resposta da balança. Verifique a conexão.';
          _testSuccess = false;
        });
      }
    } catch (e) {
      setState(() {
        _testResult = 'Erro: $e';
        _testSuccess = false;
      });
    } finally {
      setState(() => _isTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Switch activo/inactivo
            SwitchListTile(
              title: const Text('Balança Activa'),
              subtitle: Text(_isEnabled
                  ? 'Leitura de peso activa'
                  : 'Balança desactivada',),
              value: _isEnabled,
              onChanged: (value) {
                setState(() => _isEnabled = value);
                if (!value) {
                  _scaleService.saveConfig(ScaleConfig(
                    connectionType: ScaleConnectionType.serial,
                    protocol: _protocol,
                    serialPort: '',
                    baudRate: _baudRate,
                  ),);
                }
              },
              secondary: Icon(
                _isEnabled ? Icons.scale : Icons.scale_outlined,
                color: _isEnabled ? Colors.teal : Colors.grey,
              ),
            ),

            if (_isEnabled) ...[
              const Divider(),

              // Porta série
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Porta Série (RS-232)',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: _refreshPorts,
                          tooltip: 'Actualizar portas',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_availablePorts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber,
                                color: Theme.of(context).colorScheme.error,),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Nenhuma porta série encontrada.\n'
                                'Verifique se o adaptador USB-Serial está ligado.',
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: _selectedPort,
                        decoration: const InputDecoration(
                          labelText: 'Selecionar Porta',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.usb),
                        ),
                        items: _availablePorts.map((port) {
                          final info = ScaleService.getPortInfo(port);
                          final description = info['description'] ?? '';
                          return DropdownMenuItem(
                            value: port,
                            child: Text(
                              description.isNotEmpty
                                  ? '$port ($description)'
                                  : port,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedPort = value);
                        },
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Protocolo
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modelo da Balança',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ScaleProtocol>(
                    value: _protocol,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.precision_manufacturing),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: ScaleProtocol.dibal,
                        child: Text('Dibal (G-310, G-325, etc.)'),
                      ),
                      DropdownMenuItem(
                        value: ScaleProtocol.toledo,
                        child: Text('Toledo'),
                      ),
                      DropdownMenuItem(
                        value: ScaleProtocol.mettlerToledo,
                        child: Text('Mettler-Toledo'),
                      ),
                      DropdownMenuItem(
                        value: ScaleProtocol.cas,
                        child: Text('CAS'),
                      ),
                      DropdownMenuItem(
                        value: ScaleProtocol.epelsa,
                        child: Text('Epelsa'),
                      ),
                      DropdownMenuItem(
                        value: ScaleProtocol.generic,
                        child: Text('Genérico'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _protocol = value);
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Baud Rate
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Velocidade (Baud Rate)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 4800, label: Text('4800')),
                      ButtonSegment(value: 9600, label: Text('9600')),
                      ButtonSegment(value: 19200, label: Text('19200')),
                      ButtonSegment(value: 38400, label: Text('38400')),
                    ],
                    selected: {_baudRate},
                    onSelectionChanged: (selection) {
                      setState(() => _baudRate = selection.first);
                    },
                  ),
                ],
              ),

              const Divider(height: 32),

              // Resultado do teste
              if (_testResult != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _testSuccess == true
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _testSuccess == true ? Colors.green : Colors.red,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _testSuccess == true ? Icons.check_circle : Icons.error,
                        color: _testSuccess == true ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_testResult!)),
                    ],
                  ),
                ),

              // Botões
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isTesting || _selectedPort == null
                          ? null
                          : _testConnection,
                      icon: _isTesting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_find),
                      label:
                          Text(_isTesting ? 'A testar...' : 'Testar Leitura'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _selectedPort == null ? null : _saveConfig,
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
