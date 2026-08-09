#!/usr/bin/env bash
# =============================================================================
# deploy.sh — Deploy manual do AI Image Generator
# =============================================================================
# Uso:
#   ./deploy.sh railway   — deploy no Railway (requer RAILWAY_TOKEN)
#   ./deploy.sh render    — deploy no Render (requer RENDER_API_KEY + SERVICE_ID)
#   ./deploy.sh local     — roda localmente para teste (porta 5000)
#   ./deploy.sh validate  — valida o código antes de commitar
#
# Variáveis de ambiente:
#   REPLICATE_API_TOKEN  — obrigatória para qualquer deploy
#   RAILWAY_TOKEN        — para deploy no Railway
#   RENDER_API_KEY       — para deploy no Render
#   RENDER_SERVICE_ID    — para deploy no Render
#
# Exemplo:
#   export REPLICATE_API_TOKEN=r8_abc...
#   export RAILWAY_TOKEN=...
#   ./deploy.sh railway
# =============================================================================

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

log_info()  { echo -e "${CYAN}ℹ️  $*${RESET}"; }
log_ok()    { echo -e "${GREEN}✅ $*${RESET}"; }
log_warn()  { echo -e "${YELLOW}⚠️  $*${RESET}"; }
log_err()   { echo -e "${RED}❌ $*${RESET}" >&2; }

# ---------------------------------------------------------------------------
# Validações iniciais
# ---------------------------------------------------------------------------
validate_prereqs() {
    if [[ -z "${REPLICATE_API_TOKEN:-}" ]]; then
        log_err "REPLICATE_API_TOKEN não está definida."
        echo "   Gere uma em: https://replicate.com/account/api-tokens"
        echo "   Exporte antes de rodar: export REPLICATE_API_TOKEN=r8_..."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Validação do código (para rodar antes de commitar)
# ---------------------------------------------------------------------------
cmd_validate() {
    log_info "Validando código..."

    log_info "1. Verificando sintaxe Python..."
    python -m py_compile app.py && log_ok "Sintaxe OK"

    log_info "2. Instalando dependências e verificando..."
    pip install -r requirements.txt --quiet && log_ok "Dependências OK"

    log_info "3. Validando Dockerfile..."
    docker build -t ai-image-gen:validate . && log_ok "Dockerfile OK"

    log_info "4. Verificando variáveis de ambiente..."
    echo "   REPLICATE_API_TOKEN: ${REPLICATE_API_TOKEN:+⚫ configurada ✓}"
    echo "   (não vou expor o valor por segurança)"

    log_ok "Tudo validado com sucesso!"
}

# ---------------------------------------------------------------------------
# Deploy local (para teste rápido)
# ---------------------------------------------------------------------------
cmd_local() {
    validate_prereqs
    log_info "Iniciando servidor local em http://localhost:5000 ..."
    log_info "Pare com Ctrl+C"
    echo ""
    python app.py
}

# ---------------------------------------------------------------------------
# Deploy no Railway
# ---------------------------------------------------------------------------
cmd_railway() {
    validate_prereqs

    if [[ -z "${RAILWAY_TOKEN:-}" ]]; then
        log_err "RAILWAY_TOKEN não está definida."
        echo "   Configure no Railway: https://railway.app/account"
        echo "   Exporte: export RAILWAY_TOKEN=..."
        exit 1
    fi

    log_info "🚂 Deploy no Railway..."
    log_info "Branch: ${GITHUB_REF_NAME:-main}"

    # Instalar Railway CLI
    log_info "Instalando Railway CLI..."
    curl -fsSL https://railway.app/install.sh | sh > /dev/null 2>&1
    log_ok "CLI instalado"

    # Login
    log_info "Authenticating..."
    railway login --token "$RAILWAY_TOKEN" > /dev/null 2>&1
    log_ok "Logado no Railway"

    # Deploy
    log_info "Enviando código para o Railway..."
    railway deploy --source . --no-wait
    log_ok "Deploy enviado! Verifique o status em https://railway.app"
}

# ---------------------------------------------------------------------------
# Deploy no Render
# ---------------------------------------------------------------------------
cmd_render() {
    validate_prereqs

    if [[ -z "${RENDER_API_KEY:-}" || -z "${RENDER_SERVICE_ID:-}" ]]; then
        log_err "RENDER_API_KEY e RENDER_SERVICE_ID são obrigatórias."
        echo "   API Key:  https://dashboard.render.com/u/settings#api-keys"
        echo "   Service ID: no dashboard do serviço Render"
        echo "   Exporte:"
        echo "     export RENDER_API_KEY=..."
        echo "     export RENDER_SERVICE_ID=srv-..."
        exit 1
    fi

    log_info "🟢 Triggerando deploy no Render..."
    log_info "Serviço: ${RENDER_SERVICE_ID}"

    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        "https://api.render.com/v1/services/${RENDER_SERVICE_ID}/deploys" \
        -H "Authorization: Bearer ${RENDER_API_KEY}" \
        -H "Content-Type: application/json" \
        -d '{"clearCache": false}')

    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | sed '$d')

    if [[ "$HTTP_CODE" == "201" || "$HTTP_CODE" == "200" ]]; then
        DEPLOY_URL=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('url','N/A'))" 2>/dev/null || echo "ver no dashboard")
        log_ok "Deploy triggerado com sucesso!"
        log_info "URL do deploy: ${DEPLOY_URL}"
    else
        log_err "Falha ao triggerar deploy (HTTP ${HTTP_CODE})"
        echo "$BODY"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
usage() {
    cat <<EOF
Uso: $(basename "$0") <comando>

Comandos:
    validate   Validar código antes de commitar
    local      Rodar servidor localmente (http://localhost:5000)
    railway    Deploy no Railway (requer RAILWAY_TOKEN)
    render     Trigger deploy no Render (requer RENDER_API_KEY + RENDER_SERVICE_ID)

Variáveis de ambiente:
    REPLICATE_API_TOKEN   Chave da API Replicate (obrigatória)
    RAILWAY_TOKEN         Token do Railway (para deploy railway)
    RENDER_API_KEY        API Key do Render (para deploy render)
    RENDER_SERVICE_ID     ID do serviço Render (para deploy render)

Exemplos:
    export REPLICATE_API_TOKEN=r8_...
    export RAILWAY_TOKEN=...
    $(basename "$0") railway

    export REPLICATE_API_TOKEN=r8_...
    $(basename "$0") local

EOF
    exit 0
}

# If no arguments
if [[ $# -lt 1 ]]; then
    usage
fi

case "$1" in
    validate) cmd_validate ;;
    local)    cmd_local ;;
    railway)  cmd_railway ;;
    render)   cmd_render ;;
    -h|--help|help) usage ;;
    *)
        log_err "Comando desconhecido: $1"
        usage
        ;;
esac
