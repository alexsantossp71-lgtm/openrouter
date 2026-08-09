# 🚀 Como colocar na internet

## Opção A: GitHub Codespaces (mais rápido – o que vamos fazer)

### Pré-requisitos

- Conta no [GitHub](https://github.com)
- Conta na [Replicate](https://replicate.com) com uma API token

### Passo a passo

#### 1. Criar um Codespace

No seu repositório GitHub, clique no botão verde **<> Code** → aba **Codespaces** → **Create codespace on main** (ou na branch `arena/019fe3dd-openrouter`).

#### 2. Configurar a API Token da Replicate

No Codespace que acabou de abrir:

```bash
# Defina a variável de ambiente (na session atual)
export REPLICATE_API_TOKEN=r8_sua_token_aqui

# Ou crie um arquivo .env (não commitar!)

# Teste se está certo:
echo $REPLICATE_API_TOKEN
# Deve mostrar: r8_...
```

> Para persistentar entre reinícios do Codespace, adicione no arquivo `~/.bashrc` do Codespace:
> ```bash
> echo 'export REPLICATE_API_TOKEN=r8_sua_token_aqui' >> ~/.bashrc
> ```

#### 3. Instalar dependências (primeira vez só)

```bash
pip install -r requirements.txt
```

#### 4. Rodar o servidor

```bash
python app.py
```

O servidor vai subir em `http://localhost:5000`.

#### 5. Expor publicamente (importantíssimo!)

No canto inferior direito do Codespace, clique no botão **Ports** (portas) → localize a porta **5000** → clique nos **três pontos (⋯)** → **Port Visibility** → **Public**.

Ou use o comando no terminal:
```bash
# Isso expõe a porta 5000 publicamente
gh codespace port visibility 5000:public
```

#### 6. Acessar o app

Acesse no navegador:
```
https://SEU-CODESPACE-NAME-5000.app.github.dev/gerar
```

O frontend também fica disponível em:
```
https://SEU-CODESPACE-NAME-5000.app.github.dev/
```

(basta abrir o `index.html` direto nesse URL)

---

### Configurar portas como públicas por padrão (para não repetir)

Crie ou edite o arquivo `.devcontainer/devcontainer.json` e adicione:

```json
"portsAttributes": {
    "5000": {
        "visibility": "public"
    }
}
```

---

### Limitações do Codespaces (pra ficar esperto)

| Limitação | O que isso significa |
|-----------|----------------------|
| Plans gratuitos têm limite de horas | Se parar de usar, o Codespace pode ser pausado/excluído |
| URL muda se recriar o Codespace | Se for recriar, o URL muda (é baseado no nome do codespace) |
| Não é "set and forget" | É feito para desenvolvimento/demo, não para produto em produção |

---

## Opção B: Railway (mais permanente – recomendado depois)

### Passo a passo rápido

1. Acesse [railway.app](https://railway.app) e faça login com GitHub
2. Clique em **New Project** → **Deploy from GitHub repo**
3. Selecione este repositório
4. Railway detecta o `Dockerfile` automaticamente
5. Adicione a variável de ambiente `REPLICATE_API_TOKEN` nas configurações do projeto
6. Deploy automático!

**Vantagens:** URL permanente (ex: `https://seu-app.railway.app`), HTTPS incluso, mais estável que Codespaces.

---

## Opção C: Render (alternativa ao Railway)

1. Acesse [render.com](https://render.com) e faça login
2. **New → Web Service** → conecte o GitHub repo
3. Selecione o `Dockerfile`
4. Adicione `REPLICATE_API_TOKEN` nas variáveis de ambiente
5. Deploy!

---

## Index.html e o backend URL

O `index.html` usa **relative URL** (`/gerar`) por padrão. Isso significa:

- Se frontend e backend estiverem no **mesmo domínio** (ex: ambos no Codespaces ou Railway): **funciona sem configuração**
- Se estiverem em **domínios diferentes** (ex: frontend no Vercel, backend no Railway): configure a meta tag no `index.html`:

```html
<meta name="backend-url" content="https://seu-backend.railway.app/gerar">
```

Ou defina via JavaScript antes do carregamento do script:

```html
<script>
    window.backendUrl = "https://seu-backend.railway.app/gerar";
</script>
```
