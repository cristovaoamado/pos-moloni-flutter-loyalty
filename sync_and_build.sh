#!/bin/bash
# sync_and_build.sh
# Script para sincronizar com GitHub e garantir build limpo
# 
# Uso:
#   chmod +x sync_and_build.sh
#   ./sync_and_build.sh

set -e  # Parar em caso de erro

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Sincronização e Build Limpo - POS Moloni                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================
# 1. VERIFICAR SE HÁ ALTERAÇÕES NÃO GUARDADAS
# ============================================
echo -e "${YELLOW}[1/8] Verificando alterações locais...${NC}"

if [[ -n $(git status --porcelain) ]]; then
    echo -e "${RED}⚠️  Existem alterações não guardadas!${NC}"
    echo ""
    git status --short
    echo ""
    read -p "Queres fazer stash das alterações? (s/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        git stash push -m "Auto-stash antes de sync $(date +%Y%m%d_%H%M%S)"
        echo -e "${GREEN}✓ Alterações guardadas em stash${NC}"
    else
        echo -e "${RED}Abortado. Faz commit ou stash das alterações primeiro.${NC}"
        exit 1
    fi
fi

# ============================================
# 2. BUSCAR ÚLTIMAS ALTERAÇÕES DO GITHUB
# ============================================
echo -e "${YELLOW}[2/8] Buscando alterações do GitHub...${NC}"

git fetch origin
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" != "$REMOTE" ]; then
    echo -e "${CYAN}Existem alterações remotas. A fazer pull...${NC}"
    git pull origin main --rebase
    echo -e "${GREEN}✓ Código atualizado${NC}"
else
    echo -e "${GREEN}✓ Já está atualizado com origin/main${NC}"
fi

# ============================================
# 3. LIMPAR BUILD ANTERIOR
# ============================================
echo -e "${YELLOW}[3/8] Limpando builds anteriores...${NC}"

flutter clean
echo -e "${GREEN}✓ Flutter clean concluído${NC}"

# ============================================
# 4. REMOVER FICHEIROS GERADOS
# ============================================
echo -e "${YELLOW}[4/8] Removendo ficheiros gerados...${NC}"

# Remover .g.dart, .freezed.dart, .gr.dart
find lib -name "*.g.dart" -type f -delete 2>/dev/null || true
find lib -name "*.freezed.dart" -type f -delete 2>/dev/null || true
find lib -name "*.gr.dart" -type f -delete 2>/dev/null || true

# Remover cache do build_runner
rm -rf .dart_tool/build 2>/dev/null || true

echo -e "${GREEN}✓ Ficheiros gerados removidos${NC}"

# ============================================
# 5. REINSTALAR DEPENDÊNCIAS
# ============================================
echo -e "${YELLOW}[5/8] Instalando dependências...${NC}"

flutter pub get
echo -e "${GREEN}✓ Dependências instaladas${NC}"

# ============================================
# 6. REGENERAR CÓDIGO
# ============================================
echo -e "${YELLOW}[6/8] Gerando código (build_runner)...${NC}"

dart run build_runner clean 2>/dev/null || true
dart run build_runner build --delete-conflicting-outputs

# Contar ficheiros gerados
GENERATED_COUNT=$(find lib -name "*.g.dart" -type f 2>/dev/null | wc -l)
echo -e "${GREEN}✓ Código gerado ($GENERATED_COUNT ficheiros .g.dart)${NC}"

# ============================================
# 7. ANALISAR CÓDIGO
# ============================================
echo -e "${YELLOW}[7/8] Analisando código...${NC}"

flutter analyze --no-fatal-infos || true
echo -e "${GREEN}✓ Análise concluída${NC}"

# ============================================
# 8. BUILD DE TESTE (opcional)
# ============================================
echo ""
read -p "Queres fazer build de teste? (s/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${YELLOW}[8/8] Fazendo build...${NC}"
    
    # Detectar plataforma
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Plataforma: macOS"
        flutter build macos --release
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        echo "Plataforma: Windows"
        flutter build windows --release
    else
        echo "Plataforma: Linux"
        flutter build linux --release
    fi
    
    echo -e "${GREEN}✓ Build concluído com sucesso!${NC}"
else
    echo -e "${CYAN}Build ignorado${NC}"
fi

# ============================================
# RESUMO
# ============================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo -e "${GREEN}✅ Sincronização completa!${NC}"
echo ""
echo "Próximos passos:"
echo "  1. Testa a aplicação localmente"
echo "  2. Se tudo OK, faz commit e push:"
echo "     git add ."
echo "     git commit -m 'Sync and clean build'"
echo "     git push origin main"
echo ""
echo "═══════════════════════════════════════════════════════════════"
