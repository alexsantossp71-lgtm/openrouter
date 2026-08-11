import pytest
from app import app


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setenv("REPLICATE_API_TOKEN", "dummy")
    app.config["TESTING"] = True
    return app.test_client()


def test_health(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["status"] == "ok"


def test_index(client):
    resp = client.get("/")
    assert resp.status_code == 200
    assert b"Gerador" in resp.data


def test_gerar_missing_prompt(client):
    resp = client.post("/gerar", json={})
    assert resp.status_code == 400
    body = resp.get_json()
    assert "obrigatório" in body["erro"]


def test_gerar_long_prompt(client):
    resp = client.post("/gerar", json={"prompt": "x" * 2100})
    assert resp.status_code == 400
    body = resp.get_json()
    assert "muito longo" in body["erro"]


def test_gerar_mock_replicate(client, monkeypatch):
    def fake_run(*args, **kwargs):
        return ["https://fake-image.com/test.png"]

    monkeypatch.setattr("replicate.run", fake_run)
    resp = client.post(
        "/gerar",
        json={"prompt": "beautiful sunset", "width": 512, "height": 512},
    )
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["url"] == "https://fake-image.com/test.png"
