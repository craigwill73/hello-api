from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_hello_status_code() -> None:
    response = client.get("/hello")
    assert response.status_code == 200


def test_hello_message() -> None:
    response = client.get("/hello")
    assert response.text == "Hello World"
