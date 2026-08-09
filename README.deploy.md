# 🚀 Deploy Automático — AI Image Generator

Guia completo para deploy, CI/CD, notificações, rollback e health check.

---

## 📋 Visão Geral do CI/CD

```
┌──────────────────────────────────────────────────────────────────┐
│                    FLUXO DE DEPLOY                              │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  push / PR  ──▶  validate (lint + docker build)                 │
│                       │                                         │
│                       ▼                                         │
│                  deploy (staging ou produção)                    │
│                       │                                         │
│                       ▼                                         │
│                  healthcheck (/health)                           │
│                       │                                         │
│              ┌────────┴────────┐                               │
│              ▼                 ▼                                │
│         ✅ saudável        ❌ falha                            │
│              │                 │                                │
│              ▼                 ▼                                │
│         notificar          rollback + notificar                 │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🔐 Secrets necessários (GitHub Actions)

Configure em: **Repo → Settings → Secrets and variables → Actions → New repository secret**

### Obrigatórios

| Secret | Valor | Para que serve |
|--------|-------|---------------|
| `REPLICATE_API_TOKEN` | `r8_xxx...` da Replicate | Todo deploy (backend) |

### Opcionais — Railway

| Secret | Onde pegar |
|--------|-----------|
| `RAILWAY_TOKEN` | https://railway.app/account → "API Token" |

### Opcionais — Render

| Secret | Onde pegar |
|--------|-----------|
| `RENDER_API_KEY` | https://dashboard.render.com/u/settings#api-keys |
| `RENDER_SERVICE_ID` | Dashboard Render → Web Service → ID (ex: `srv-abc123`) |
| `RENDER_SERVICE_ID_STAGING` | ID do serviço de staging (se tiver separado) |

### Opcionais — Notificações

| Secret | Onde pegar |
|--------|-----------|
| `SLACK_WEBHOOK_URL` | Slack App → Incoming Webhooks → Add to Slack |
| `DISCORD_WEBHOOK_URL` | Discord Server → Settings → Integrations → Webhooks → New Webhook |
| `SENDGRID_API_KEY` | https://app.sendgrid.com/settings/api_keys |
| `NOTIFY_EMAIL` | Qualquer e-mail para receber notificações |
| `NOTIFY_FROM_EMAIL` | E-mail "from" (deve estar verificado no SendGrid) |

---

## 🚂 Opção 1: Deploy no Railway

### Setup inicial

```bash
# 1. Criar projeto no Railway
#    Railway.app → New Project → Deploy from GitHub repo
#    Selecione: alexsantossp71-lgtm/openrouter

# 2. Railway detecta automaticamente o Dockerfile

# 3. Adicionar variáveis no Railway (Variables → New)
REPLICATE_API_TOKEN=r8_xxx...

# 4. Copiar o RAILWAY_TOKEN para o GitHub Secrets do repo
```

### Workflow automático

O arquivo `.github/workflows/deploy-railway-advanced.yml`:

- Dispara em push nas branches: `main`, `arena/*`, `feat/*`, `fix/*`, `release/*`
- Ou manualmente via **Actions → "Deploy Avançado Railway" → Run workflow**

```yaml
# Fluxo:
# 1. Validação (lint + Docker build)
# 2. Deploy no Railway
# 3. Health check (até 5 tentativas, 10s de intervalo)
# 4. Se falhar → rollback automático
# 5. Notificação Slack/Discord/E-mail
```

### Staging vs Produção no Railway

O Railway não tem ambientes nativos como staging/produção separados. Para simular:

**Opção A — Um serviço com duas branchs:**
- `main` → deploy em produção
- `arena/*`, `feat/*` → deploy em staging (mesmo serviço, code diferente)

**Opção B — Dois serviços no Railway:**
- `ai-image-gen-prod` → ligado na branch `main`
- `ai-image-gen-staging` → ligado na branch `develop`

Configure os dois serviços no Railway e use `RAILWAY_TOKEN` com escopo do serviço correto.

---

## 🟢 Opção 2: Deploy no Render

### Setup inicial

```bash
# 1. Render.com → New → Web Service
#    Conecte o GitHub repo alexsantossp71-lgtm/openrouter

# 2. Configure:
#    - Build Command: ( deixe em branco — usa Dockerfile )
#    - Start Command: ( deixe em branco — usa CMD do Dockerfile )
#    - Instance Type: Free

# 3. Adicione variáveis de ambiente no Render:
REPLICATE_API_TOKEN=r8_xxx...
# (rolar para baixo e adicionar)

# 4. Copie RENDER_API_KEY e RENDER_SERVICE_ID para o GitHub Secrets
```

### Workflow automático

O arquivo `.github/workflows/deploy-render-advanced.yml`:

- Dispara em push nas mesmas branches
- Health check pós-deploy
- Notificação Slack/Discord/E-mail

> ⚠️ **Rollback no Render:** O Render não suporta rollback via API. Se o health check falhar, o workflow avisa mas não reverte automaticamente. Você precisa fazer rollback manualmente pelo dashboard ou restaurar um backup.

---

## 📊 Health Check Automático

### Como funciona

```
Depois do deploy, oActions executa:
  GET https://seu-servico.onrender.com/health

Resposta esperada: HTTP 200 + JSON
  {
    "status": "ok",
    "model": "playgroundai/playground-v2.5-1024px-aesthetic",
    "timestamp": 1234567890
  }

Configuração:
  - Healthcheck Timeout: 300s (5 minutos)
  - Retries: 5
  - Interval: 10s entre tentativas
```

### Endpoints de health check

| Endpoint | Método | Resposta |
|----------|--------|----------|
| `/health` | GET | Status do serviço, modelo, timestamp |
| `/` | GET | Serve o index.html (se aplicável) |

---

## 🔄 Rollback Automático

### Quando ocorre

```
Health check falha
      │
      ▼
ROLLBACK_ON_FAILURE=true (default)
      │
      ▼
Rollback triggerado
      │
      ▼
Notificação: "Deploy falhou — rollback realizado"
```

### No Railway

O rollback é feito via `railway deploy` novamente, apontando para o código do commit anterior. O Actions usa o penúltimo commit como fallback.

### No Render

**Não há rollback automático** (limitação da API do Render). O Actions apenas notifica o incidente. Para rollback manual:

1. Acesse o dashboard do Render
2. Vá em **Deploys** do serviço
3. Clique no deploy anterior que estava funcionando
4. Clique em **Rollback** (se disponível) ou re-deploy

### Configurar rollback

No workflow, edite as variáveis:

```yaml
env:
    ROLLBACK_ON_FAILURE: "true"    # "false" para desativar
    HEALTHCHECK_RETRIES: 5
    HEALTHCHECK_INTERVAL: 10
```

Ou no `workflow_dispatch`:

```yaml
inputs:
    force_rollback:
        description: "Fazer rollback mesmo se o deploy 'parece' sucesso?"
        default: "false"
```

---

## 🔔 Notificações

### Slack

**Pré-requisito:** Criar um Incoming Webhook no Slack

1. Acesse https://api.slack.com/apps?new_app=1
2. Crie um app → Add features → Incoming Webhooks
3. Ative e adicione ao canal desejado
4. Copie a URL do webhook
5. Adicione como secret `SLACK_WEBHOOK_URL` no GitHub

**Mensagem enviada:**

```
✅ Deploy concedido — alexsantossp71-lgtm/openrouter
Branch: main
Commit: abc1234 — Adiciona deploy automático
Por: alice
🔗 Ver execução: https://github.com/.../actions/runs/12345
```

### Discord

**Pré-requisito:** Criar um Webhook no Discord

1. Direito no servidor → Server Settings → Integrations → Webhooks
2. New Webhook → escolha o canal
3. Copie a URL
4. Adicione como secret `DISCORD_WEBHOOK_URL`

### E-mail (SendGrid)

**Pré-requisito:** Conta SendGrid

1. https://app.sendgrid.com/ → Settings → API Keys → Create API Key
2. Adicione como `SENDGRID_API_KEY`
3. Adicione o e-mail de destino como `NOTIFY_EMAIL`
4. Adicione o e-mail "from" como `NOTIFY_FROM_EMAIL` (deve estar verificado no SendGrid)

**E-mail enviado:**

```
Subject: Deploy concluído: alexsantossp71-lgtm/openrouter

Deploy concluído
Repositório: alexsantossp71-lgtm/openrouter
Branch: main
Commit: abc1234 — Adiciona deploy automático
Deployado por: alice
Ver execução: https://github.com/.../actions/runs/12345
```

### Qual combinação usar?

| Cenário | Recomendação |
|---------|-------------|
| Time pequeno, rápido | Slack + Discord |
| Time distribuído | Slack + E-mail |
| Formal / auditoria | E-mail (SendGrid) |
| Tudo | Slack + Discord + E-mail |

---

## 🧪 Testar o CI/CD

```bash
# 1. Dar um push qualquer
git commit --allow-empty -m "Test: CI/CD pipeline"
git push origin arena/019fe3dd-openrouter

# 2. Acompanhar no GitHub
#    Repo → Actions → ver o workflow rodando
```

Ou use o `workflow_dispatch` (rodar manualmente):

1. GitHub → Actions → "Deploy Avançado Railway" (ou Render)
2. Clique em **Run workflow**
3. Escolha branch e ambiente
4. Clique em **Run workflow** novamente

---

## 🛠 Scripts e Makefiles

### `deploy.sh` — Deploy manual

```bash
export REPLICATE_API_TOKEN=r8_...
export RAILWAY_TOKEN=...

./deploy.sh validate    # valida antes de commitar
./deploy.sh local       # roda localmente
./deploy.sh railway     # deploy no Railway
./deploy.sh render      # trigger no Render
```

### `Makefile` — Comandos rápidos

```bash
make install           # instala dependências
make run               # servidor local
make test              # testa sintaxe + lint
make lint              # só lint
make docker-build      # builda a imagem Docker
make docker-run        # roda o container
make deploy-railway   # deploy no Railway (precisa das vars)
make deploy-render    # trigger no Render (precisa das vars)
make clean             # remove caches
make help              # mostra todos os comandos
```

### `scripts/notify.sh` — Notificações manuais

```bash
export SLACK_WEBHOOK_URL=https://hooks.slack.com/...
export DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
export SENDGRID_API_KEY=SG....
export NOTIFY_EMAIL=equipe@empresa.com

./scripts/notify.sh slack "Deploy concluído!"
./scripts/notify.sh discord "Deploy concluído!"
./scripts/notify.sh email "Deploy" "<p>Deploy concluído!</p>" "equipe@empresa.com"
./scripts/notify.sh all "Deploy concluído por alice!"
./scripts/notify.sh status verbose   # mostra configurações atuais
```

---

## 🌍 URLs de acesso

### Depois do deploy, acesse:

| Serviço | URL de exemplo |
|---------|---------------|
| Railway | `https://seu-app.railway.app/` |
| Render | `https://seu-app.onrender.com/` |
| Codespaces | `https://seu-codepace-5000.app.github.dev/` |

### Endpoints disponíveis

| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/` | GET | Frontend (index.html) |
| `/gerar` | POST | Gera imagem (JSON: `{ "prompt": "..." }`) |
| `/health` | GET | Health check (JSON: `{ "status": "ok" }`) |

---

## 📁 Arquivos do CI/CD

```
.github/
├── workflows/
│   ├── ci-pr.yml               ← CI básico para PRs
│   ├── pr-validation.yml       ← Validação avançada de PRs
│   ├── deploy-railway.yml      ← Deploy Railway (simples)
│   ├── deploy-railway-advanced.yml  ← Deploy Railway avançado
│   ├── deploy-render.yml       ← Deploy Render (simples)
│   └── deploy-render-advanced.yml  ← Deploy Render avançado

deploy.sh                       ← Script de deploy manual
Makefile                        ← Comandos make
scripts/
└── notify.sh                   ← Script de notificação multi-canal

config.example.yml              ← Template de configuração
.env.example                    ← Variáveis de ambiente
Procfile                        ← Para Railway/Render
Dockerfile                      ← Container para produção
```

---

## ⚡ Fluxo recomendado para time

```
1. Desenvolvedor faz feature em feat/xxx
         │
         ▼
2. Abre PR para main
         │
         ▼
3. CI dispara: lint + build + validação
         │
         ▼
4. Reviewer aprova e faz merge
         │
         ▼
5. Push na main dispara deploy-automático (staging ou produção)
         │
         ▼
6. Health check valida
         │
    ┌────┴────┐
    ▼         ▼
  ✅ OK    ❌ Falha
    │         │
    ▼         ▼
  notificar  rollback + notificar
```

---

## ❓ Troubleshooting

| Problema | Solução |
|----------|---------|
| Workflow não dispara | Verifique se o push foi na branch configurada |
| Health check falha |-Verifique se o serviço subiu com sucesso (logs no Railway/Render) |
| Rollback falha | Verifique permissões do token Railway/Render |
| Notificação não chega | Verifique se o webhook URL está válido (teste com `curl`) |
| `REPLICATE_API_TOKEN` não encontrada | Adicione como secret no GitHub e no serviço de hosting |
| Deploy demora muito | O Render/free pode demorar 2-3 min na primeira inicialização (cold start) |

---

> **Próximos passos sugeridos:**
> - Adicionar testes reais (pytest) ao invés de só `py_compile`
> - Configurar múltiplos ambientes no Railway (prod vs staging)
> - Adicionar monitoramento (Uptime Robot, Pingdom) fora do GitHub Actions
> - Configurar CDN para servir as imagens geradas
