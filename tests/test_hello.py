from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_hello_status_code() -> None:
    response = client.get("/hello")
    assert response.status_code == 200


def test_hello_message() -> None:
    response = client.get("/hello")
    assert response.text == "Hello World"


def test_v1_hello() -> None:
    response = client.get("/v1/hello")
    assert response.status_code == 200
    assert response.text == "Hello World"


def test_health() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_ready() -> None:
    response = client.get("/ready")
    assert response.status_code == 200
    assert response.json() == {"status": "ready"}


def test_openapi_lists_versioned_hello() -> None:
    response = client.get("/openapi.json")
    assert response.status_code == 200
    paths = response.json()["paths"]
    assert "/v1/hello" in paths
    assert paths["/v1/hello"]["get"]["tags"] == ["v1"]
