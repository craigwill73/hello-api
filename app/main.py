from fastapi import FastAPI
from fastapi.responses import PlainTextResponse

app = FastAPI(title="hello-api")


@app.get("/hello")
def hello() -> PlainTextResponse:
    return PlainTextResponse("Hello World")
