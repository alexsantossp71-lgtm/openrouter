# openrouter — Gerador de Imagens AI

Gerador de imagens por Inteligência Artificial usando **Flask + Replicate API (Playground v2.5)**.

## 🚀 Funcionalidades

- Geração de imagens via texto (prompt)
- Parâmetros configuráveis: tamanho, steps, scheduler
- Backend com validação, rate limiting e health check
- Frontend moderno com dark theme e histórico

## 📦 Tecnologias

- **Backend:** Python (Flask)
- **Frontend:** HTML/CSS/JavaScript
- **IA:** Replicate API (Playground v2.5)

## 🚀 Como usar

### 1. Configurar

```bash
# Instalar dependências
pip install -r requirements.txt

# Definir API key (ou usar variável de ambiente)
export REPLICATE_API_TOKEN=r8_sua_token_aqui
```

### 2. Rodar

```bash
python app.py
```

Acesse: `http://localhost:5000`

### 3. Gerar imagem

Via API:
```bash
curl -X POST http://localhost:5000/gerar \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Um gato astronauta cyberpunk"}'
```

## 📁 Estrutura

```
├── app.py              # Backend Flask
├── index.html          # Frontend
├── requirements.txt    # Dependências
└── .env.example        # Variáveis de ambiente
```

## 🔑 Variáveis de ambiente

| Variável | Obrigatória | Descrição |
|----------|-------------|-----------|
| `REPLICATE_API_TOKEN` | ✅ | Sua chave da API Replicate |

## 📄 Licença

MIT License — veja o arquivo [LICENSE](LICENSE).
