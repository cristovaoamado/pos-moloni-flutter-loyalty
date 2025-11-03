# 📋 Guia de Instalação - POS Moloni App

## ✅ Estrutura já criada pelo script

O script já criou toda a estrutura de pastas e ficheiros vazios. Agora precisa **copiar o conteúdo** dos artefatos para os ficheiros correspondentes.

---

## 📂 Ficheiros Core a copiar

### 1. **Constants**
```bash
# Copiar conteúdo para:
lib/core/constants/app_constants.dart
lib/core/constants/api_constants.dart
```

### 2. **Errors**
```bash
# Copiar conteúdo para:
lib/core/errors/exceptions.dart
lib/core/errors/failures.dart
```

### 3. **Network**
```bash
# Copiar conteúdo para:
lib/core/network/api_client.dart
lib/core/network/network_info.dart
```

### 4. **Utils**
```bash
# Copiar conteúdo para:
lib/core/utils/logger.dart
lib/core/utils/formatters.dart
lib/core/utils/validators.dart
```

### 5. **Theme**
```bash
# Copiar conteúdo para:
lib/core/theme/app_colors.dart
lib/core/theme/app_theme.dart
```

### 6. **App**
```bash
# Copiar conteúdo para:
lib/main.dart
lib/app.dart
```

---

## 🚀 Como copiar os ficheiros (Mac)

### Opção 1: Copiar manualmente
1. Abra o ficheiro no VS Code (ex: `lib/core/errors/exceptions.dart`)
2. Copie o conteúdo do artefato correspondente
3. Cole no ficheiro
4. Salve (Cmd+S)

### Opção 2: Usar script auxiliar

Crie um ficheiro `copy_core_files.sh`:

```bash
#!/bin/bash

# Este script ajuda a identificar ficheiros que precisam de conteúdo

echo "🔍 Verificando ficheiros Core..."
echo ""

CORE_FILES=(
  "lib/core/constants/app_constants.dart"
  "lib/core/constants/api_constants.dart"
  "lib/core/errors/exceptions.dart"
  "lib/core/errors/failures.dart"
  "lib/core/network/api_client.dart"
  "lib/core/network/network_info.dart"
  "lib/core/utils/logger.dart"
  "lib/core/utils/formatters.dart"
  "lib/core/utils/validators.dart"
  "lib/core/theme/app_colors.dart"
  "lib/core/theme/app_theme.dart"
  "lib/main.dart"
  "lib/app.dart"
)

for file in "${CORE_FILES[@]}"; do
  if [ -f "$file" ]; then
    size=$(wc -c < "$file")
    if [ $size -lt 100 ]; then
      echo "❌ $file (vazio - copiar conteúdo)"
    else
      echo "✅ $file (OK)"
    fi
  else
    echo "⚠️  $file (não encontrado)"
  fi
done

echo ""
echo "📝 Total de ficheiros: ${#CORE_FILES[@]}"
```

Execute:
```bash
chmod +x copy_core_files.sh
./copy_core_files.sh
```

---

## 🧪 Testar compilação

Depois de copiar **todos** os ficheiros Core, execute:

```bash
# 1. Limpar build anterior
flutter clean

# 2. Instalar dependências
flutter pub get

# 3. Verificar problemas
flutter analyze

# 4. Executar app
flutter run
```

---

## ⚠️ Possíveis erros e soluções

### Erro: "Target of URI doesn't exist"
**Solução:** Ficheiro ainda não tem conteúdo. Copie do artefato correspondente.

### Erro: "The function 'X' isn't defined"
**Solução:** Falta importar package ou copiar ficheiro dependency.

### Erro: "undefined_identifier"
**Solução:** Verifique se todos os ficheiros Core foram copiados.

---

## 📊 Ordem de cópia recomendada

Para evitar erros de dependências:

1. ✅ **Constants** (não dependem de nada)
2. ✅ **Errors** (dependem de equatable)
3. ✅ **Utils/Logger** (depende de logger package)
4. ✅ **Utils/Formatters** (depende de intl + constants)
5. ✅ **Utils/Validators** (depende de constants)
6. ✅ **Theme** (depende de constants)
7. ✅ **Network/NetworkInfo** (depende de connectivity_plus)
8. ✅ **Network/ApiClient** (depende de dio + errors + logger + constants)
9. ✅ **Main** (depende de app + logger + constants)
10. ✅ **App** (depende de theme + constants + logger)

---

## 🎯 Checklist Final

Antes de testar, confirme:

- [ ] Todos os 13 ficheiros Core foram copiados
- [ ] `pubspec.yaml` tem todas as dependências
- [ ] `flutter pub get` executado com sucesso
- [ ] `flutter analyze` não reporta erros graves
- [ ] App compila sem erros

---

## 📞 Próximos Passos

Após confirmar que tudo compila:

1. **Implementar Feature Auth** (Login + Auto-login + Tokens)
2. **Implementar Feature Company** (Seleção de empresa)
3. **Implementar Feature Products** (Pesquisa + Cache + Barcode)
4. **Implementar Feature Cart** (Gestão de carrinho)
5. **Implementar Feature Sales** (Finalizar venda + Pagamentos)
6. **Implementar Feature POS** (Tela principal)

---

## ❓ Dúvidas?

Se encontrar algum erro durante a cópia:
- Verifique se o conteúdo foi copiado completamente
- Confirme que não há caracteres especiais corrompidos
- Execute `flutter clean` e tente novamente
