"use strict";

const form = document.getElementById("form-gerar");
const promptInput = document.getElementById("prompt");
const widthInput = document.getElementById("width");
const heightInput = document.getElementById("height");
const stepsInput = document.getElementById("steps");
const backendInput = document.getElementById("backend");
const btn = document.getElementById("btn-gerar");
const statusEl = document.getElementById("status");
const resultadoEl = document.getElementById("resultado");
const imagemEl = document.getElementById("imagem");
const downloadEl = document.getElementById("download");
const historicoEl = document.getElementById("historico");

const STORAGE_KEY = "openrouter.historico";
const DEFAULT_BACKEND =
  window.location.origin.startsWith("http://localhost") ||
  window.location.origin.startsWith("https://localhost")
    ? "http://localhost:5000/gerar"
    : "https://localhost:5000/gerar";

function carregarHistorico() {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]");
  } catch {
    return [];
  }
}

function salvarHistorico(url) {
  const items = [url, ...carregarHistorico().filter((u) => u !== url)].slice(0, 12);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(items));
  renderizarHistorico();
}

function renderizarHistorico() {
  const items = carregarHistorico();
  historicoEl.innerHTML = "";
  for (const url of items) {
    const img = document.createElement("img");
    img.src = url;
    img.alt = "Imagem anterior";
    img.addEventListener("click", () => mostrarImagem(url));
    historicoEl.appendChild(img);
  }
}

function mostrarImagem(url) {
  imagemEl.src = url;
  downloadEl.href = url;
  resultadoEl.hidden = false;
  resultadoEl.scrollIntoView({ behavior: "smooth" });
}

function setStatus(msg, tipo) {
  statusEl.textContent = msg;
  statusEl.className = "status" + (tipo ? " " + tipo : "");
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();

  const prompt = promptInput.value.trim();
  const backend = backendInput.value.trim() || DEFAULT_BACKEND;

  if (!prompt) {
    setStatus("Digite um prompt primeiro.", "erro");
    return;
  }
  if (!/^https?:\/\//.test(backend)) {
    setStatus("URL do backend inválida (comece com http:// ou https://).", "erro");
    return;
  }

  btn.disabled = true;
  setStatus("A IA está desenhando… (aguarde alguns segundos)");
  resultadoEl.hidden = true;

  try {
    const response = await fetch(backend, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        prompt,
        width: Number(widthInput.value),
        height: Number(heightInput.value),
        steps: Number(stepsInput.value),
      }),
    });

    const data = await response.json();

    if (response.ok && data.url) {
      mostrarImagem(data.url);
      salvarHistorico(data.url);
      setStatus("Imagem gerada com sucesso!", "sucesso");
    } else {
      setStatus("Erro: " + (data.erro || "Resposta inválida"), "erro");
    }
  } catch (err) {
    console.error(err);
    setStatus(
      "Falha de conexão. O backend está rodando e a URL está correta?",
      "erro"
    );
  } finally {
    btn.disabled = false;
  }
});

if (window.localStorage) {
  renderizarHistorico();
}