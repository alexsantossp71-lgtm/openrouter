# 🚀 Rodar no GitHub Codespaces

Este projeto roda em um **GitHub Codespace** — um ambiente de desenvolvimento na nuvem do GitHub. Sem necessidade de deploy complexo.

## 📋 Pré-requisitos

- Conta no [GitHub](https://github.com)
- Conta na [Replicate](https://replicate.com) com uma **API token**

## 🚀 Como usar

### Passo 1: Criar o Codespace

1. Acesse: https://github.com/alexsantossp71-lgtm/openrouter
2. Clique no botão verde **<> Code**
3. Selecione a aba **Codespaces**
4. Clique em **Create codespace on main** (ou na branch `arena/019fe3dd-openrouter`)

### Passo 2: Configurar a API Token

No terminal do Codespace que abrir:

```bash
# Defina sua chave da API Replicate
export REPLICATE_API_TOKEN=r8_sua_token_aqui

# Teste se está certo
echo $REPLICATE_API_TOKEN
# Deve mostrar: r8_...
```

> 💡 Dica: para não perder a token entre reinícios, adicione no `~/.bashrc`:
> ```bash
> echo 'export REPLICATE_API_TOKEN=r8_sua_token_aqui' >> ~/.bashrc
> ```

### Passo 3: Instalar dependências (primeira vez só)

O Codespace já instala automaticamente via `postCreateCommand` no devcontainer, mas se quiser garantir:

```bash
pip install -r requirements.txt
```

### Passo 4: Rodar o servidor

```bash
python app.py
```

O servidor vai subir em `http://localhost:5000`.

### Passo 5: Acessar o app

A porta 5000 já fica exposta publicamente pelo Codespace. Acesse:

```
https://SEU-CODESPACE-NAME-5000.app.github.dev/gerar
```

Ou simplesmente clique no link que aparece na aba **Ports** no canto inferior do Codespace.

---

## 🔧 Arquivos importantes

| Arquivo | O que faz |
|---------|-----------|
| `app.py` | Backend Flask — API para gerar imagens via Replicate |
| `index.html` | Frontend — interface para digitar prompts e ver imagens |
| `requirements.txt` | Dependências Python (flask, flask-cors, replicate) |
| `.devcontainer/devcontainer.json` | Configuração do ambiente Codespace |
| `Dockerfile` | Container (opcional, para uso fora do Codespace) |

---

## ⚙️ Variáveis de ambiente

| Variável | Obrigatória? | Descrição |
|----------|-------------|-----------|
| `REPLICATE_API_TOKEN` | ✅ Sim | Sua chave da API Replicate |
| `FLASK_DEBUG` | ❌ Não | Define como `1` para mod de desenvolvimento |
| `PORT` | ❌ Não | Porta do servidor (default: 5000) |

---

## 🧪 Testar rápido

```bash
# 1. Instala tudo
pip install -r requirements.txt

# 2. Define a token (substitua pela sua)
export REPLICATE_API_TOKEN=r8_sua_token_aqui

# 3. Roda o servidor
python app.py

# 4. Em outro terminal, testa a API
curl -X POST http://localhost:5000/gerar \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Um gato astronauta cyberpunk"}'
```

---

## 🌐 URLs de acesso

| Recurso | URL |
|---------|-----|
| Frontend (index.html) | `https://SEU-CODESPACE-5000.app.github.dev/` |
| API de geração | `https://SEU-CODESPACE-5000.app.github.dev/gerar` |
| Health check | `https://SEU-CODESPACE-5000.app.github.dev/health` |

---

## ❓ Troubleshooting

| Problema | Solução |
|----------|---------|
| `REPLICATE_API_TOKEN` não encontrada | Defina a variável de ambiente antes de rodar o app |
| Porta 5000 não aparece | No Codespace, vá em **Ports** → clique nos **⋯** → **Port Visibility → Public** |
| Imagem não gera | Verifique se a token da Replicate está correta e se o prompt não viola as diretrizes |
| App não atualiza | Reinicie o servidor (Ctrl+C e rode `python app.py` novamente) |

---

## 🧹 Limpezas optionais

Se quiser remover arquivos desnecessários que não servem para Codespaces:

```bash
# Esses arquivos são para deploy em Railway/Render — pode apagar se só usar Codespaces
rm deploy.sh Makefile scripts/notify.sh config.example.yml
```
