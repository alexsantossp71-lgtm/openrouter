#!/usr/bin/env bash
# =============================================================================
# scripts/notify.sh — Ferramenta de notificação multi-canal
# =============================================================================
# Uso:
#   ./scripts/notify.sh slack       "Mensagem" [webhook_url]
#   ./scripts/notify.sh discord     "Mensagem" [webhook_url]
#   ./scripts/notify.sh email       "Assunto" "Corpo HTML" [to_email]
#   ./scripts/notify.sh all         "Mensagem resumida" [webhook_url] [sendgrid_key] [to_email]
#   ./scripts/notify.sh status      [verbose]
#
# Variáveis de ambiente (alternativas às args):
#   SLACK_WEBHOOK_URL
#   DISCORD_WEBHOOK_URL
#   SENDGRID_API_KEY
#   NOTIFY_EMAIL
#   NOTIFY_FROM_EMAIL
# =============================================================================

set -euo pipefail

# Cores
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; RESET='\033[0m'

log_info()  { echo -e "${CYAN}ℹ️  $*${RESET}"; }
log_ok()    { echo -e "${GREEN}✅ $*${RESET}"; }
log_warn()  { echo -e "${YELLOW}⚠️  $*${RESET}"; }
log_err()   { echo -e "${RED}❌ $*${RESET}" >&2; }

# ---------------------------------------------------------------------------
# Slack
# ---------------------------------------------------------------------------
notify_slack() {
    local message="${1:-}"

    if [[ -z "$message" ]]; then
        log_err "Nenhuma mensagem fornecida para Slack"
        return 1
    fi

    local webhook="${SLACK_WEBHOOK_URL:-${2:-}}"
    if [[ -z "$webhook" ]]; then
        log_warn "SLACK_WEBHOOK_URL não configurada — pulando"
        return 0
    fi

    local color="good"
    local emoji="✅"

    if [[ "$message" == *"falha"* || "$message" == *"erro"* || "$message" == *"fail"* ]]; then
        color="danger"; emoji="❌"
    elif [[ "$message" == *"rollback"* ]]; then
        color="#ff9900"; emoji="🔄"
    fi

    local body
    body=$(cat <<JSON
{
    "text": "${message}",
    "attachments": [{
        "color": "${color}",
        "footer": "AI Image Generator · $(date -u '+%Y-%m-%d %H:%M UTC')",
        "ts": $(date +%s)
    }]
}
JSON
)

    if curl -s -X POST -H 'Content-type: application/json' \
            --data "$body" "$webhook" > /dev/null; then
        log_ok "Mensagem enviada para Slack"
    else
        log_err "Falha ao enviar notificação Slack"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Discord
# ---------------------------------------------------------------------------
notify_discord() {
    local message="${1:-}"

    if [[ -z "$message" ]]; then
        log_err "Nenhuma mensagem fornecida para Discord"
        return 1
    fi

    local webhook="${DISCORD_WEBHOOK_URL:-${2:-}}"
    if [[ -z "$webhook" ]]; then
        log_warn "DISCORD_WEBHOOK_URL não configurada — pulando"
        return 0
    fi

    local color="3066993"  # verde
    if [[ "$message" == *"falha"* || "$message" == *"erro"* || "$message" == *"fail"* ]]; then
        color="15158332"  # vermelho
    elif [[ "$message" == *"rollback"* ]]; then
        color="15158332"
    fi

    local body
    body=$(cat <<JSON
{
    "content": "${message}",
    "embeds": [{
        "color": ${color},
        "footer": {"text": "AI Image Generator · $(date -u '+%Y-%m-%d %H:%M UTC')"}
    }]
}
JSON
)

    if curl -s -X POST -H 'Content-type: application/json' \
            --data "$body" "$webhook" > /dev/null; then
        log_ok "Mensagem enviada para Discord"
    else
        log_err "Falha ao enviar notificação Discord"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# E-mail via SendGrid
# ---------------------------------------------------------------------------
notify_email() {
    local subject="${1:-Deploy Notification}"
    local body_html="${2:-}"
    local to_email="${NOTIFY_EMAIL:-${3:-}}"

    if [[ -z "$body_html" ]]; then
        log_err "Corpo do e-mail não fornecido"
        return 1
    fi

    local api_key="${SENDGRID_API_KEY:-${4:-}}"
    local from_email="${NOTIFY_FROM_EMAIL:-deploy-bot@ai-image-generator.local}"

    if [[ -z "$api_key" ]]; then
        log_warn "SENDGRID_API_KEY não configurada — pulando e-mail"
        return 0
    fi

    if [[ -z "$to_email" ]]; then
        log_warn "NOTIFY_EMAIL não configurada — pulando e-mail"
        return 0
    fi

    local body
    body=$(cat <<JSON
{
    "personalizations": [{
        "to": [{"email": "${to_email}"}]
    }],
    "from": {"email": "${from_email}", "name": "AI Image Generator"},
    "subject": "${subject}",
    "content": [{
        "type": "text/html",
        "value": "$(echo "$body_html" | sed 's/"/\\"/g')"
    }]
}
JSON
)

    if curl -s -X POST https://api.sendgrid.com/v3/mail/send \
            -H "Authorization: Bearer ${api_key}" \
            -H "Content-Type: application/json" \
            -d "$body" > /dev/null; then
        log_ok "E-mail enviado para ${to_email}"
    else
        log_err "Falha ao enviar e-mail"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Todas as plataformas
# ---------------------------------------------------------------------------
notify_all() {
    local message="${1:-Deploy notificado}"
    local slack_webhook="${SLACK_WEBHOOK_URL:-${2:-}}"
    local sendgrid_key="${SENDGRID_API_KEY:-${3:-}}"
    local to_email="${NOTIFY_EMAIL:-${4:-}}"

    log_info "Enviando notificação para todas as plataformas..."

    # Slack
    if [[ -n "$slack_webhook" ]]; then
        notify_slack "$message" "$slack_webhook" || true
    fi

    # Discord
    if [[ -n "${DISCORD_WEBHOOK_URL:-}" ]]; then
        notify_discord "$message" || true
    fi

    # E-mail
    if [[ -n "$sendgrid_key" && -n "$to_email" ]]; then
        notify_email "Deploy AI Image Generator" "<p>$message</p>" "$to_email" "$sendgrid_key" || true
    fi

    log_ok "Notificações enviadas (quaisquer que tenham sido configuradas)"
}

# ---------------------------------------------------------------------------
# Status
# ---------------------------------------------------------------------------
notify_status() {
    local verbose="${1:-false}"

    echo -e "${CYAN}=== Status das configurações de notificação ===${RESET}"
    echo ""
    echo -e "Slack:    ${SLACK_WEBHOOK_URL:+✅ configurado ${CYAN}(${SLACK_WEBHOOK_URL:0:30}...)${RESET} ${SLACK_WEBHOOK_URL:-⚠️  não configurado}"
    echo -e "Discord:  ${DISCORD_WEBHOOK_URL:+✅ configurado ${CYAN}(${DISCORD_WEBHOOK_URL:0:30}...)${RESET} ${DISCORD_WEBHOOK_URL:-⚠️  não configurado}"
    echo -e "SendGrid: ${SENDGRID_API_KEY:+✅ configurado ${CYAN}(chave ${SENDGRID_API_KEY:0:8}...)${RESET} ${SENDGRID_API_KEY:-⚠️  não configurado}"
    echo -e "E-mail:   ${NOTIFY_EMAIL:+✅ ${CYAN}${NOTIFY_EMAIL}${RESET}} ${NOTIFY_EMAIL:-⚠️  não configurado}"
    echo -e "From:     ${NOTIFY_FROM_EMAIL:+✅ ${CYAN}${NOTIFY_FROM_EMAIL}${RESET}} ${NOTIFY_FROM_EMAIL:-⚠️  não configurado}"
    echo ""

    if [[ "$verbose" == "verbose" ]]; then
        echo -e "${YELLOW}Dica:${RESET} Configure no GitHub Actions:"
        echo "  Settings → Secrets and variables → Actions → New repository secret"
        echo ""
        echo "Secrets necessárias:"
        echo "  SLACK_WEBHOOK_URL  — criar um webhook no Slack (App → Incoming Webhooks)"
        echo "  DISCORD_WEBHOOK_URL — criar um webhook no Discord (Server Settings → Integrations → Webhooks)"
        echo "  SENDGRID_API_KEY   — API key no SendGrid (Settings → API Keys)"
        echo "  NOTIFY_EMAIL       — e-mail para receber notificações"
        echo "  NOTIFY_FROM_EMAIL  — e-mail 'from' (deve ser verificado no SendGrid)"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
usage() {
    cat <<EOF
Uso: $(basename "$0") <comando> [args]

Comandos:
    slack       "Mensagem" [webhook_url]
    discord     "Mensagem" [webhook_url]
    email       "Assunto" "Corpo HTML" [to_email]
    all         "Mensagem" [slack_webhook] [sendgrid_key] [to_email]
    status      [verbose]     — mostra configurações atuais

Variáveis de ambiente:
    SLACK_WEBHOOK_URL
    DISCORD_WEBHOOK_URL
    SENDGRID_API_KEY
    NOTIFY_EMAIL
    NOTIFY_FROM_EMAIL

Exemplos:
    export SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
    ./scripts/notify.sh slack "Deploy concluído com sucesso!"

    export SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
    export DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
    export SENDGRID_API_KEY=SG....
    export NOTIFY_EMAIL=equipe@empresa.com
    ./scripts/notify.sh all "Deploy em produção realizado por alice"
EOF
}

if [[ $# -lt 1 ]]; then
    usage
    exit 0
fi

case "$1" in
    slack)   notify_slack "$@" ;;
    discord) notify_discord "$@" ;;
    email)   notify_email "$@" ;;
    all)     shift; notify_all "$@" ;;
    status)  notify_status "${2:-}" ;;
    -h|--help|help) usage ;;
    *)
        log_err "Comando desconhecido: $1"
        usage
        exit 1
        ;;
esac
