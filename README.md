# POS Moloni App

Aplicação de Ponto de Venda (POS) integrada com a API Moloni, desenvolvida em Flutter com Clean Architecture.

## 🏗️ Arquitetura

Este projeto segue os princípios da Clean Architecture, dividindo o código em três camadas principais:

- **Domain**: Lógica de negócio pura (Entities, Repositories, Use Cases)
- **Data**: Implementações de repositórios e comunicação com APIs/Database
- **Presentation**: UI, Widgets e Gestão de Estado (Riverpod)

## 📁 Estrutura de Pastas

```
lib/
├── core/               # Funcionalidades compartilhadas
├── features/           # Features modulares
│   ├── auth/          # Autenticação
│   ├── company/       # Empresas
│   ├── products/      # Produtos
│   ├── cart/          # Carrinho
│   ├── sales/         # Vendas
│   ├── pos/           # POS Screen
│   ├── printer/       # Impressão
│   ├── barcode/       # Leitura de código de barras
│   └── settings/      # Configurações
└── shared/            # Widgets compartilhados
```

## 🚀 Como começar

### Pré-requisitos

- Flutter SDK >=3.0.0
- Dart SDK >=3.0.0

### Instalação

1. Clone o repositório
2. Execute `flutter pub get`
3. Execute `flutter pub run build_runner build --delete-conflicting-outputs`
4. Execute `flutter run`

## 🧪 Testes

```bash
# Testes unitários
flutter test

# Testes de integração
flutter test integration_test
```

## 📦 Packages Principais

- **flutter_riverpod**: Gestão de estado
- **dio**: HTTP client
- **dartz**: Functional programming (Either)
- **hive**: Database local
- **mobile_scanner**: Leitor de código de barras
- **print_bluetooth_thermal**: Impressão térmica

## 🔧 Code Generation

Para gerar código (Freezed, JSON Serialization):

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## 📄 Licença

Este projeto é privado e confidencial.
