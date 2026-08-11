# Gerador de Imagens IA — OpenRouter

![CI](https://img.shields.io/github/actions/workflow/status/alexsantossp71-lgtm/openrouter/ci.yml?label=CI)
![Pages](https://img.shields.io/github/actions/workflow/status/alexsantossp71-lgtm/openrouter/pages.yml?label=Pages)
![Python](https://img.shields.io/badge/Python-3.12+-3776AB?logo=python)
![Docker](https://img.shields.io/badge/Docker-ready-2496ED?logo=docker)
![License](https://img.shields.io/github/license/alexsantossp71-lgtm/openrouter)
![Status](https://img.shields.io/badge/status-ativo-009688)

Backend Flask que expõe `POST /gerar` integrado ao **Replicate**.
Recebe `prompt`, `width`, `height`, `steps`, retorna a URL da imagem
gerada. Serve um front estático (`index.html`) com campo de configuração
da URL do backend (persistido no `localStorage`).

> ⚠️ Requer chave da API **Replicate** (`REPLICATE_API_TOKEN`). O container
> não inclui chaves — passe via `--env-file` ou variável no deploy.

---

## Estrutura

```
openrouter/
├── .github/workflows/
│   ├── ci.yml         # Testes + lint + build Docker
│   └── pages.yml     # Deploy do front estático
├── app.py            # Flask + rate limit + /health
├── Dockerfile        # python:3.12-slim + gunicorn
├── requirements.txt  # runtime
├── requirements-dev.txt # pytest + mocks
├── static/           # Front-end (index.html, script.js, style.css)
├── tests/            # Pytest (mocks do replicate.run)
├── .env.example
└── LICENSE
```

---

## Executar local

```bash
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt

# Copie .env.example -> .env e adicione REPLICATE_API_TOKEN
cp .env.example .env

python app.py
# http://localhost:5000
```

---

## Executar com Docker

```bash
docker build -t openrouter .
docker run -d -p 5000:5000 --env-file .env openrouter
```

---

## Executar testes

```bash
pip install -r requirements-dev.txt
pytest -v
```

---

## Endpoints

| Método | Rota | Descrição |
|--------|------|-----------|
| `GET`  | `/`  | Front estático (index.html) |
| `GET`  | `/health` | Health (`{"status":"ok"}`) |
| `POST` | `/gerar` | Gera imagem via Replicate |

### `POST /gerar`

Body JSON:

```json
{
  "prompt": "sunset on Mars",
  "width": 1024,
  "height": 1024,
  "steps": 25
}
```

Respostas:

- `200`: `{ url: "https://..." }`
- `400`: `{ erro: "O campo 'prompt' é obrigatório." }` ou `Prompt muito longo.`
- `429`: `{ erro: "Limite de requisições atingido." }`
- `500`: `{ erro: "..." }` (erro do Replicate)

---

## Variáveis de ambiente

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `REPLICATE_API_TOKEN` | obrigatório | Chave do Replicate |
| `REPLICATE_MODEL` | `playground...` | Modelo padrão |
| `RATE_LIMIT` | 5 | Requisições por minuto |
| `RATE_LIMIT_WINDOW` | 60 | Janela de segundos |
| `PORT` | 5000 | Porta do servidor |

---

## Limitações conhecidas

- Rate limiter é **em memória** (não persiste em múltiplos workers).
- Não armazena imagens; apenas retorna URL do Replicate (link temporário).
- Sem autenticação (use proxy ou gateway para proteger `/gerar` em produção).

---

## Licença

MIT — veja `LICENSE`.
