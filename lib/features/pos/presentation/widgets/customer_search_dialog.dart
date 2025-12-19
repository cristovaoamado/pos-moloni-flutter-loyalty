import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/features/customers/domain/entities/customer.dart';
import 'package:pos_moloni_app/features/customers/presentation/providers/customer_provider.dart';

/// Diálogo de pesquisa e criação de clientes
class CustomerSearchDialog extends ConsumerStatefulWidget {
  const CustomerSearchDialog({
    super.key,
    required this.onCustomerSelected,
  });

  final Function(Customer) onCustomerSelected;

  @override
  ConsumerState<CustomerSearchDialog> createState() => _CustomerSearchDialogState();
}

class _CustomerSearchDialogState extends ConsumerState<CustomerSearchDialog> {
  final _searchController = TextEditingController();
  bool _showCreateForm = false;

  // Controladores do formulário de criação
  final _nameController = TextEditingController();
  final _vatController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _vatController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _zipCodeController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    ref.read(customerProvider.notifier).search(query);
  }

  Future<void> _createCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    final customer = await ref.read(customerProvider.notifier).create(
          name: _nameController.text.trim(),
          vat: _vatController.text.trim(),
          email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
          phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
          address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
          zipCode: _zipCodeController.text.trim().isNotEmpty ? _zipCodeController.text.trim() : null,
          city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
        );

    if (customer != null && mounted) {
      widget.onCustomerSelected(customer);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cliente "${customer.name}" criado com sucesso'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _selectConsumidorFinal() {
    widget.onCustomerSelected(Customer.consumidorFinal);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final customerState = ref.watch(customerProvider);

    return Dialog(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero, // SEM cantos arredondados
      ),
      child: Container(
        width: 550,
        height: 500,
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            // Header
            _buildHeader(context),
            
            // Conteúdo
            Expanded(
              child: _showCreateForm 
                  ? _buildCreateForm(context, customerState)
                  : _buildSearchContent(context, customerState),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    // IGUAL ao checkout e item_options: primary com texto branco, sem borderRadius
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary, // IGUAL aos outros dialogs
        // SEM borderRadius - cantos rectos
      ),
      child: Row(
        children: [
          if (_showCreateForm)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => setState(() => _showCreateForm = false),
              tooltip: 'Voltar à pesquisa',
            ),
          Expanded(
            child: Text(
              _showCreateForm ? 'Novo Cliente' : 'Pesquisa de Clientes',
              style: const TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: Colors.white, // Texto branco
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchContent(BuildContext context, CustomerState state) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pesquise por nome, NIF ou número de cliente'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: 'Nome, NIF ou número...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: state.isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      ref.read(customerProvider.notifier).clearSearch();
                                    },
                                  )
                                : null,
                      ),
                      autofocus: true,
                      onChanged: _onSearch,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _showCreateForm = true),
                    icon: const Icon(Icons.add),
                    label: const Text('Novo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        
        // Botão Consumidor Final
        ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.person_outline),
          ),
          title: const Text('Consumidor Final'),
          subtitle: const Text('NIF: 999999990'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _selectConsumidorFinal,
        ),
        const Divider(height: 1),
        
        // Resultados
        Expanded(
          child: state.searchError != null
              ? _buildErrorState(state.searchError!)
              : state.searchResults.isEmpty
                  ? _buildEmptyState()
                  : _buildResultsList(state.searchResults),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 8),
            Text(
              'Digite para pesquisar clientes',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      );
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 8),
          const Text('Nenhum cliente encontrado'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => setState(() => _showCreateForm = true),
            icon: const Icon(Icons.add),
            label: const Text('Criar novo cliente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 8),
          Text('Erro: $error', textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildResultsList(List<Customer> customers) {
    return ListView.separated(
      itemCount: customers.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final customer = customers[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            child: Text(
              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(customer.name),
          subtitle: Text('NIF: ${customer.formattedVat}'),
          trailing: customer.number != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '#${customer.number}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : null,
          onTap: () {
            widget.onCustomerSelected(customer);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildCreateForm(BuildContext context, CustomerState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Nome (obrigatório)
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nome é obrigatório';
                }
                return null;
              },
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),

            // NIF (obrigatório)
            TextFormField(
              controller: _vatController,
              decoration: const InputDecoration(
                labelText: 'NIF *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'NIF é obrigatório';
                }
                if (value.trim().length != 9) {
                  return 'NIF deve ter 9 dígitos';
                }
                return null;
              },
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),

            // Email
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),

            // Telefone
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Telefone',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),

            // Morada
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Morada',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home),
              ),
            ),
            const SizedBox(height: 12),

            // Código Postal e Cidade
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _zipCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Código Postal',
                      border: OutlineInputBorder(),
                      hintText: '0000-000',
                    ),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        // Validar formato português
                        final regex = RegExp(r'^\d{4}-\d{3}$');
                        if (!regex.hasMatch(value)) {
                          return 'Formato: 0000-000';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'Cidade',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Erro
            if (state.createError != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.createError!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),

            // Botão criar
            ElevatedButton.icon(
              onPressed: state.isCreating ? null : _createCustomer,
              icon: state.isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(state.isCreating ? 'A criar...' : 'Criar Cliente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
