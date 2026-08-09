"""
Gerador de Imagens AI - Playground v2.5 via Replicate
=========================================================
Melhorado: validação, rate limiting, logging, configuração via variáveis,
           health check, melhores mensagens de erro.
"""

import os
import logging
import time
import replicate
from functools import wraps
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from collections import defaultdict
from threading import Lock

# ---------------------------------------------------------------------------
# Configuração de logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("image-generator")

# ---------------------------------------------------------------------------
# Aplicação Flask
# ---------------------------------------------------------------------------
app = Flask(__name__)

# CORS: restringir a origens confiáveis em produção (via variável de ambiente)
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "").split(",") if os.getenv("ALLOWED_ORIGINS") else []
if ALLOWED_ORIGINS:
    CORS(app, origins=ALLOWED_ORIGINS, supports_credentials=True)
else:
    # Modo desenvolvimento: CORS aberto (não usar em produção!)
    CORS(app)
    logger.warning("⚠️  ALLOWED_ORIGINS não configurado – CORS aberto para todos (modo dev)")

# ---------------------------------------------------------------------------
# Variáveis de configuração
# ---------------------------------------------------------------------------
REPLICATE_MODEL = os.getenv(
    "REPLICATE_MODEL",
    "playgroundai/playground-v2.5-1024px-aesthetic:61260cd6b4747eb3b8178875501d51a66275811c75949d21df263300072b7a95",
)
MAX_PROMPT_LENGTH = int(os.getenv("MAX_PROMPT_LENGTH", "1000"))
DEFAULT_WIDTH = int(os.getenv("DEFAULT_WIDTH", "1024"))
DEFAULT_HEIGHT = int(os.getenv("DEFAULT_HEIGHT", "1024"))
DEFAULT_STEPS = int(os.getenv("DEFAULT_STEPS", "25"))
DEFAULT_SCHEDULER = os.getenv("DEFAULT_SCHEDULER", "DPMSolver++")
RATE_LIMIT_REQUESTS = int(os.getenv("RATE_LIMIT_REQUESTS", "10"))
RATE_LIMIT_WINDOW = int(os.getenv("RATE_LIMIT_WINDOW", "60"))  # segundos

logger.info(f"Modelo Replicate: {REPLICATE_MODEL}")
logger.info(f"Rate limit: {RATE_LIMIT_REQUESTS} req / {RATE_LIMIT_WINDOW}s")

# ---------------------------------------------------------------------------
# Rate limiting simples (in-memory – usar Redis em produção)
# ---------------------------------------------------------------------------
rate_limit_store: dict[str, list[float]] = defaultdict(list)
rate_limit_lock = Lock()


def rate_limit(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        ip = request.remote_addr or "unknown"
        now = time.time()

        with rate_limit_lock:
            # Limpar entradas antigas
            rate_limit_store[ip] = [
                t for t in rate_limit_store[ip] if now - t < RATE_LIMIT_WINDOW
            ]
            if len(rate_limit_store[ip]) >= RATE_LIMIT_REQUESTS:
                logger.warning(f"Rate limit excedido para IP: {ip}")
                return (
                    jsonify({
                        "erro": "Muitas requisições. Tente novamente em alguns segundos.",
                        "retry_after": RATE_LIMIT_WINDOW,
                    }),
                    429,
                )
            rate_limit_store[ip].append(now)

        return f(*args, **kwargs)

    return wrapper


# ---------------------------------------------------------------------------
# Validadores
# ---------------------------------------------------------------------------
FORBIDDEN_PATTERNS = [
    r"\b(nude| nudity| sex| porn| naked)\b",
    r"\b(kill| murder| blood| gore| violence)\b",
]  # extensível


def validate_prompt(prompt: str) -> tuple[bool, str]:
    """Valida o prompt do usuário. Retorna (é_valido, mensagem)."""
    if not prompt or not prompt.strip():
        return False, "O prompt não pode estar vazio."

    prompt = prompt.strip()

    if len(prompt) > MAX_PROMPT_LENGTH:
        return (
            False,
            f"O prompt excede o limite de {MAX_PROMPT_LENGTH} caracteres "
            f"(enviado: {len(prompt)}).",
        )

    if len(prompt) < 3:
        return False, "O prompt deve ter pelo menos 3 caracteres."

    # Verificar palavras proibidas (case-insensitive)
    import re
    for pattern in FORBIDDEN_PATTERNS:
        if re.search(pattern, prompt, re.IGNORECASE):
            return False, "O prompt contém conteúdo que viola as diretrizes de segurança."

    return True, ""


# ---------------------------------------------------------------------------
# Rotas
# ---------------------------------------------------------------------------

@app.route("/health", methods=["GET"])
def health():
    """Health check para monitoramento / load balancer."""
    return jsonify({
        "status": "ok",
        "model": REPLICATE_MODEL.split(":")[0],
        "timestamp": time.time(),
    })


@app.route("/gerar", methods=["POST"])
@rate_limit
def gerar_imagem():
    """
    Gera uma imagem a partir do prompt via Replicate.

    Body JSON esperado:
        { "prompt": "string", "width"?: int, "height"?: int, "steps"?: int }
    """
    if not request.is_json:
        return jsonify({"erro": "Content-Type deve ser application/json"}), 415

    dados = request.get_json(silent=True)
    if dados is None:
        return jsonify({"erro": "JSON inválido"}), 400

    prompt_usuario = dados.get("prompt", "").strip()
    valido, msg = validate_prompt(prompt_usuario)
    if not valido:
        return jsonify({"erro": msg}), 400

    # Parâmetros opcionais com defaults
    width = int(dados.get("width", DEFAULT_WIDTH))
    height = int(dados.get("height", DEFAULT_HEIGHT))
    steps = int(dados.get("steps", DEFAULT_STEPS))
    scheduler = dados.get("scheduler", DEFAULT_SCHEDULER)

    # Sanity check nos parâmetros
    for name, val in [("width", width), ("height", height)]:
        if val < 256 or val > 2048:
            return jsonify({"erro": f"{name} deve estar entre 256 e 2048"}), 400

    if steps < 10 or steps > 100:
        return jsonify({"erro": "steps deve estar entre 10 e 100"}), 400

    logger.info(
        f"Gerando imagem | prompt='{prompt_usuario[:80]}...' | "
        f"{width}x{height} | steps={steps} | scheduler={scheduler}"
    )

    try:
        # Verificar se a chave da API está configurada
        token = os.getenv("REPLICATE_API_TOKEN")
        if not token:
            logger.error("REPLICATE_API_TOKEN não configurada!")
            return (
                jsonify({
                    "erro": "Servidor não configurado – contate o administrador.",
                    "detalhe": "REPLICATE_API_TOKEN não está definida.",
                }),
                500,
            )

        output = replicate.run(
            REPLICATE_MODEL,
            input={
                "width": width,
                "height": height,
                "prompt": prompt_usuario,
                "scheduler": scheduler,
                "num_inference_steps": steps,
            },
        )

        url_imagem = output[0] if isinstance(output, list) and output else None

        if not url_imagem:
            logger.error("Replicate retornou output vazio")
            return jsonify({"erro": "A IA não retornou nenhuma imagem. Tente novamente."}), 500

        logger.info(f"Imagem gerada com sucesso: {url_imagem[:80]}...")
        return jsonify({
            "url": url_imagem,
            "prompt": prompt_usuario,
            "parametros": {"width": width, "height": height, "steps": steps, "scheduler": scheduler},
        })

    except replicate.exceptions.ModelError as e:
        logger.error(f"Erro do modelo Replicate: {e}")
        return jsonify({"erro": "Erro no modelo de IA. Tente um prompt diferente."}), 502

    except replicate.exceptions.APIError as e:
        logger.error(f"Erro de API do Replicate: {e}")
        return jsonify({"erro": "Erro na API de IA. Tente novamente em instantes."}), 502

    except Exception as e:
        logger.exception("Erro inesperado na geração de imagem")
        return jsonify({"erro": "Erro interno do servidor."}), 500


# ---------------------------------------------------------------------------
# Inicialização
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    debug = os.getenv("FLASK_DEBUG", "0") == "1"
    logger.info(f"Iniciando servidor na porta {port} (debug={debug})")
    app.run(host="0.0.0.0", port=port, debug=debug)
