# 🎨 openrouter — Gerador de Imagens IA

Gerador de imagens por Inteligência Artificial usando **Flask + Replicate API**
(modelo Playground v2.5).

> ⚠️ **Atenção:** este repositório não possui relação com a plataforma
> [OpenRouter](https://openrouter.ai). O nome é apenas legado.

## ✨ Funcionalidades

- Geração de imagens a partir de um prompt de texto
- Parâmetros configuráveis: largura, altura e número de passos
- **Rate limiting** por IP (proteção básica contra abuso)
- **Health check** (`/health`)
- Frontend com **dark theme**, validação de prompt e **histórico** local

## 📦 Tecnologias

- **Backend:** Python (Flask) + Gunicorn
- **Frontend:** HTML/CSS/JavaScript puro (sem build)
- **IA:** Replicate API (Playground v2.5)

## 🚀 Como rodar

### 1. Configurar

```bash
pip install -r requirements.txt
cp .env.example .env        # edite e preencha a chave
export REPLICATE_API_TOKEN=r8_sua_token_aqui   # ou carregue pelo .env
```

### 2. Rodar (dev)

```bash
python app.py
```

Acesse `http://localhost:5000`.

### 3. Gerar imagem

Via API:

```bash
curl -X POST http://localhost:5000/gerar \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Um gato astronauta cyberpunk"}'
```

Via Docker:

```bash
docker build -t ai-image-gen .
docker run -p 5000:5000 --env-file .env ai-image-gen
```

## 📁 Estrutura

```
├── app.py                  # Backend Flask
├── requirements.txt        # Dependências Python
├── .env.example            # Variáveis de ambiente (modelo)
├── Dockerfile              # Container de produção
├── static/                 # Frontend estático (deployed no GitHub Pages)
│   ├── index.html
│   ├── style.css
│   └── script.js
└── .github/workflows/
    ├── ci.yml              # Validação em PR/push
    └── pages.yml           # Deploy do frontend no GitHub Pages
```

## 🌐 GitHub Pages

O frontend estático é publicado automaticamente em
`https://<usuario>.github.io/<repositorio>/` pela action `pages.yml`.
Como o Pages serve apenas conteúdo estático, a **geração de imagens exige o
backend rodando** — configure a URL do backend no formulário do frontend
(campo "URL do backend").

## 🔑 Variáveis de ambiente

| Variável | Obrigatória | Descrição |
|----------|-------------|-----------|
| `REPLICATE_API_TOKEN` | ✅ | Chave da API Replicate |
| `REPLICATE_MODEL` | ❌ | Modelo Replicate (padrão: Playground v2.5 1024px) |
| `RATE_LIMIT` | ❌ | Máx. de requisições por janela (padrão: 5) |
| `RATE_LIMIT_WINDOW` | ❌ | Janela em segundos (padrão: 60) |
| `PORT` | ❌ | Porta do servidor (padrão: 5000) |

## 📄 Licença

MIT — veja [LICENSE](LICENSE).