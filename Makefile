# =============================================================================
# Makefile — AI Image Generator
# =============================================================================
# Comandos úteis para desenvolvimento e deploy.
# Execute com: make <alvo>
# =============================================================================

.PHONY: help install run test lint docker-build docker-run deploy-railway \
        deploy-render clean .env

# Variáveis
PYTHON      := python3
PIP         := pip
PORT        := 5000
IMAGE_NAME  := ai-image-gen
CONTAINER_NAME := ai-image-gen-container
REQUIREMENTS := requirements.txt

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
help:
	@echo "════════════════════════════════════════════════════════"
	@echo "  AI Image Generator — Makefile de comandos"
	@echo "════════════════════════════════════════════════════════"
	@echo ""
	@echo "Desenvolvimento:"
	@echo "  make install       Instalar dependências Python"
	@echo "  make run           Rodar servidor local (localhost:5000)"
	@echo "  make test          Validar sintaxe e linting"
	@echo "  make lint          Rodar flake8 nos arquivos Python"
	@echo ""
	@echo "Docker:"
	@echo "  make docker-build  Build da imagem Docker"
	@echo "  make docker-run    Rodar container Docker (lista a porta $(PORT))"
	@echo "  make docker-stop   Parar e remover container"
	@echo ""
	@echo "Deploy (requer variáveis de ambiente configuradas):"
	@echo "  make deploy-railway   Deploy no Railway (via Railway CLI)"
	@echo "  make deploy-render    Trigger deploy no Render (via API)"
	@echo ""
	@echo "Utilitários:"
	@echo "  make clean     Remover caches e artefatos"
	@echo "  make .env      Criar .env a partir de .env.example"
	@echo "  make help      Mostrar esta ajuda"
	@echo ""
	@echo "Variáveis de ambiente obrigatórias para deploy:"
	@echo "  export REPLICATE_API_TOKEN=r8_..."
	@echo "  export RAILWAY_TOKEN=...        (para make deploy-railway)"
	@echo "  export RENDER_API_KEY=...      (para make deploy-render)"
	@echo "  export RENDER_SERVICE_ID=...   (para make deploy-render)"
	@echo ""

# ---------------------------------------------------------------------------
# Desenvolvimento
# ---------------------------------------------------------------------------
install:
	$(PIP) install --upgrade pip
	$(PIP) install -r $(REQUIREMENTS)
	$(PIP) install flake8 pycodestyle  # para linting
	@echo "$(GREEN)✅ Dependências instaladas$(RESET)"

run:
	@echo "$(CYAN)🚀 Servidor rodando em http://localhost:$(PORT)$(RESET)"
	@echo "$(CYAN)   Pare com Ctrl+C$(RESET)"
	$(PYTHON) app.py

test: lint
	@echo "$(GREEN)✅ Todos os testes passaram$(RESET)"

lint:
	@echo "$(CYAN)🔍 Linting...(flake8)$(RESET)"
	flake8 app.py --max-line-length=120 --ignore=E501,W503 --statistics || true
	@echo "$(CYAN)✅ Linting concluído$(RESET)"

# ---------------------------------------------------------------------------
# Docker
# ---------------------------------------------------------------------------
docker-build:
	docker build -t $(IMAGE_NAME):latest .
	@echo "$(GREEN)✅ Imagem $(IMAGE_NAME):latest construída$(RESET)"

docker-run: docker-build
	docker run -d --name $(CONTAINER_NAME) \
		-p $(PORT):$(PORT) \
		-e REPLICATE_API_TOKEN=$(REPLICATE_API_TOKEN) \
		$(IMAGE_NAME):latest
	@echo "$(GREEN)✅ Container rodando em http://localhost:$(PORT)$(RESET)"
	@echo "$(CYAN)   Logs: docker logs -f $(CONTAINER_NAME)$(RESET)"

docker-stop:
	docker stop $(CONTAINER_NAME) 2>/dev/null || true
	docker rm $(CONTAINER_NAME) 2>/dev/null || true
	@echo "$(CYAN)🧹 Container removido$(RESET)"

# ---------------------------------------------------------------------------
# Deploy
# ---------------------------------------------------------------------------
deploy-railway:
	@echo "$(CYAN)🚂 Deploy no Railway...$(RESET)"
	@if [ -z "$(REPLICATE_API_TOKEN)" ]; then echo "$(RED)❌ REPLICATE_API_TOKEN não definida$(RESET)"; exit 1; fi
	@if [ -z "$(RAILWAY_TOKEN)" ]; then echo "$(RED)❌ RAILWAY_TOKEN não definida$(RESET)"; exit 1; fi
	curl -fsSL https://railway.app/install.sh | sh > /dev/null 2>&1
	railway login --token "$(RAILWAY_TOKEN)" > /dev/null 2>&1
	railway deploy --source . --no-wait
	@echo "$(GREEN)✅ Deploy enviado para Railway$(RESET)"

deploy-render:
	@echo "$(CYAN)🟢 Triggerando deploy no Render...$(RESET)"
	@if [ -z "$(REPLICATE_API_TOKEN)" ]; then echo "$(RED)❌ REPLICATE_API_TOKEN não definida$(RESET)"; exit 1; fi
	@if [ -z "$(RENDER_API_KEY)" ]; then echo "$(RED)❌ RENDER_API_KEY não definida$(RESET)"; exit 1; fi
	@if [ -z "$(RENDER_SERVICE_ID)" ]; then echo "$(RED)❌ RENDER_SERVICE_ID não definida$(RESET)"; exit 1; fi
	curl -s -X POST \
		"https://api.render.com/v1/services/$(RENDER_SERVICE_ID)/deploys" \
		-H "Authorization: Bearer $(RENDER_API_KEY)" \
		-H "Content-Type: application/json" \
		-d '{"clearCache": false}'
	@echo "$(GREEN)✅ Deploy triggerado no Render$(RESET)"

# ---------------------------------------------------------------------------
# Utilitários
# ---------------------------------------------------------------------------
clean:
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	rm -rf .pytest_cache .mypy_cache .ruff_cache 2>/dev/null || true
	rm -rf *.egg-info dist build 2>/dev/null || true
	@echo "$(CYAN)🧹 Limpeza concluída$(RESET)"

.env:
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "$(YELLOW)⚠️  Arquivo .env criado! edite-o e coloque sua REPLICATE_API_TOKEN$(RESET)"; \
	else \
		echo "$(YELLOW)⚠️  .env já existe — não vou sobrescrever$(RESET)"; \
	fi

# ---------------------------------------------------------------------------
# Cores (para uso nos comandos acima)
# ---------------------------------------------------------------------------
GREEN  := \033[0;32m
CYAN   := \033[0;36m
YELLOW := \033[1;33m
RED    := \033[0;31m
RESET  := \033[0m
