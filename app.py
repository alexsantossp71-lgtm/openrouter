import os
import replicate
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
# Permite que seu GitHub Pages acesse este servidor
CORS(app) 

# Configure sua chave aqui ou nas variáveis de ambiente do sistema
# No terminal: export REPLICATE_API_TOKEN=sua_chave_aqui
# Ou hardcoded para teste rápido (não suba pro GitHub público assim!):
# os.environ["REPLICATE_API_TOKEN"] = "sua_chave_r8_..."

@app.route('/gerar', methods=['POST'])
def gerar_imagem():
    dados = request.json
    prompt_usuario = dados.get('prompt')
    
    if not prompt_usuario:
        return jsonify({"erro": "Faltou o prompt!"}), 400

    try:
        print(f"Gerando imagem para: {prompt_usuario}")
        
        # Chamando o modelo Playground v2.5 via Replicate
        output = replicate.run(
            "playgroundai/playground-v2.5-1024px-aesthetic:61260cd6b4747eb3b8178875501d51a66275811c75949d21df263300072b7a95",
            input={
                "width": 1024,
                "height": 1024,
                "prompt": prompt_usuario,
                "scheduler": "DPMSolver++",
                "num_inference_steps": 25
            }
        )
        
        # O output geralmente é uma lista de URLs
        url_imagem = output[0]
        return jsonify({"url": url_imagem})

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
