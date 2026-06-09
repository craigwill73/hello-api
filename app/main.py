from fastapi import APIRouter, FastAPI
from fastapi.responses import PlainTextResponse

app = FastAPI(
    title="hello-api",
    version="1.0.0",
    description="Minimal REST API for the hello-api assessment.",
)

v1 = APIRouter(prefix="/v1", tags=["v1"])


def hello_response() -> PlainTextResponse:
    return PlainTextResponse("Hello World")


@app.get("/health", tags=["ops"])
def health() -> dict[str, str]:
    """Liveness: process is running."""
    return {"status": "ok"}


@app.get("/ready", tags=["ops"])
def ready() -> dict[str, str]:
    """Readiness: pod can accept traffic (extend with dependency checks later)."""
    return {"status": "ready"}


@v1.get("/hello")
def hello_v1() -> PlainTextResponse:
    return hello_response()


@app.get("/hello", tags=["legacy"])
def hello_legacy() -> PlainTextResponse:
    """Unversioned alias kept for assignment compatibility."""
    return hello_response()


app.include_router(v1)
