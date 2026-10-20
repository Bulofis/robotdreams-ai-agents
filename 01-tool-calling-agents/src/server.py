"""Tiny web server (stdlib only): serves index.html and a JSON API for the chat."""

import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import openai

from agent import HINT, client, run_agent

INDEX = Path(__file__).with_name("index.html").read_bytes()
MAX_HISTORY = 20  # messages sent to the LLM - keeps long chats cheap

# Readable messages for the chat; the raw error goes to the container log (make logs).
ERRORS = [
    (openai.RateLimitError, "Model „{model}“ je práve preťažený. Skús to o chvíľu znova alebo vyber iný model."),
    (openai.AuthenticationError, "Model „{model}“ nemá platný API kľúč. Doplň ho do .env a spusti make restart."),
    (openai.NotFoundError, "Model „{model}“ neexistuje alebo ho poskytovateľ vypol. Skontroluj jeho názov v .env."),
    (openai.APIConnectionError, "LiteLLM proxy nie je dostupná. Skontroluj, či beží Docker (make logs)."),
]


def friendly_error(e: Exception, model: str) -> str:
    for cls, message in ERRORS:
        if isinstance(e, cls):
            return message.format(model=model)
    if "missing" in str(e).lower() and "api key" in str(e).lower():  # some providers (Gemini) report it as 500
        return ERRORS[1][1].format(model=model)
    return "Pri volaní modelu nastala neočakávaná chyba. Podrobnosti sú v logoch (make logs)."


class Handler(BaseHTTPRequestHandler):
    def send(self, code: int, body, content_type="application/json; charset=utf-8"):
        data = body if isinstance(body, bytes) else json.dumps(body, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/":
            return self.send(200, INDEX, "text/html; charset=utf-8")
        if self.path == "/api/config":
            try:
                models = [m.id for m in client.models.list()]
            except Exception as e:
                return self.send(502, {"error": f"LiteLLM nedostupný: {e}"})
            return self.send(200, {"hint": HINT, "models": models})
        self.send(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/api/chat":
            return self.send(404, {"error": "not found"})
        try:
            req = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
            model = req["model"]
            # Trust boundary: accept only user/assistant text, so the browser can't inject a system prompt.
            history = [
                {"role": m["role"], "content": str(m["content"])}
                for m in req["messages"]
                if m.get("role") in ("user", "assistant")
            ][-MAX_HISTORY:]
            if not isinstance(model, str) or not history:
                raise ValueError
        except Exception:
            return self.send(400, {"error": "neplatná požiadavka"})

        try:
            reply, trace = run_agent(model, history)
        except Exception as e:  # provider/LiteLLM error, e.g. missing API key
            print(f"LLM error ({model}): {e!r}", file=sys.stderr, flush=True)
            return self.send(502, {"error": friendly_error(e, model)})
        self.send(200, {"reply": reply, "tools": trace})


if __name__ == "__main__":
    print("App running on http://0.0.0.0:8000")
    ThreadingHTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
