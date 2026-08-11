"""Gerador de imagens por IA — backend Flask + Replicate.

Serve o frontend estático em /static e expõe a API POST /gerar.
"""

import os
import time
from collections import defaultdict

import replicate
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS

app = Flask(__name__, static_folder="static", static_url_path="")
CORS(app)

# ---------------------------------------------------------------------------
# Configuração
# ---------------------------------------------------------------------------
REPLICATE_MODEL = os.environ.get(
    "REPLICATE_MODEL",
    "playgroundai/playground-v2.5-1024px-aesthetic:"
    "61260cd6b4747eb3b8178875501d51a66275811c75949d21df263300072b7a95",
)
REQUEST_LIMIT = int(os.environ.get("RATE_LIMIT", 5))       # requisições por janela
WINDOW_SECONDS = int(os.environ.get("RATE_LIMIT_WINDOW", 60))

# Rate limiting simples por IP (em memória; troque por Redis em produção)
_request_log = defaultdict(list)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _is_rate_limited(client_ip: str) -> bool:
    now = time.time()
    _request_log[client_ip] = [t for t in _request_log[client_ip]
                               if now - t < WINDOW_SECONDS]
    if len(_request_log[client_ip]) >= REQUEST_LIMIT:
        return True
    _request_log[client_ip].append(now)
    return False


# ---------------------------------------------------------------------------
# Rotas
# ---------------------------------------------------------------------------
@app.get("/")
def index():
    return send_from_directory(app.static_folder, "index.html")


@app.get("/health")
def health():
    return jsonify({
        "status": "ok",
        "model": REPLICATE_MODEL.split(":")[0],
    })


@app.post("/gerar")
def gerar_imagem():
    dados = request.get_json(silent=True) or {}
    prompt = (dados.get("prompt") or "").strip()

    if not prompt:
        return jsonify({"erro": "O campo 'prompt' é obrigatório."}), 400
    if len(prompt) > 2000:
        return jsonify({"erro": "Prompt muito longo (máx. 2000 caracteres)."}), 400
    if _is_rate_limited(request.remote_addr):
        return jsonify({"erro": "Limite de requisições atingido. Aguarde um momento."}), 429

    try:
        output = replicate.run(
            REPLICATE_MODEL,
            input={
                "width": int(dados.get("width", 1024)),
                "height": int(dados.get("height", 1024)),
                "prompt": prompt,
                "scheduler": dados.get("scheduler", "DPMSolver++"),
                "num_inference_steps": int(dados.get("steps", 25)),
            },
        )
        url = output[0] if isinstance(output, (list, tuple)) else output
        return jsonify({"url": url})
    except Exception as exc:  # noqa: BLE001 — erro genérico vai ao cliente
        return jsonify({"erro": str(exc)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))