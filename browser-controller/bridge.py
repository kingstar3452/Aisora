#!/usr/bin/env python3
"""Local metadata-only bridge. No ChatGPT API, credentials, transcripts, or audio files."""
from __future__ import annotations
import argparse
import hmac
import json
import math
import os
import re
from pathlib import Path
import secrets
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = Path(__file__).resolve().parents[1]


class BridgeState:
    def __init__(self, clock=time.monotonic):
        self.clock = clock
        self.lock = threading.RLock()
        self.last_browser = -math.inf
        self.last_audio = -math.inf
        self.voice = "unknown"
        self.activity = "unknown"
        self.audio_error = ""
        self.rms = 0.0
        self.capturing = False
        self.pending = None
        self.command_error = ""
        self.error = "Open the extension on your existing ChatGPT conversation."

    def expire(self):
        if self.pending and self.clock() - self.pending["created"] > 15:
            self.pending = None
            self.error = "Voice command timed out. Check the browser; use its Voice button manually."
            self.command_error = self.error

    def snapshot(self):
        with self.lock:
            self.expire()
            connected = self.clock() - self.last_browser < 4
            audio_fresh = self.clock() - self.last_audio < 0.4
            return {"connected": connected, "voice": self.voice if connected else "unknown",
                    "capturing": connected and self.capturing and audio_fresh,
                    "rms": self.rms if connected and self.capturing and audio_fresh else 0.0,
                    "pending": self.pending is not None,
                    "activity": self.activity if connected and self.voice == "active" else "unknown",
                    "error": " ".join(filter(None, [self.error, self.audio_error])) if connected else "Browser disconnected. Open ChatGPT and pair the extension."}

    def poll(self, data):
        with self.lock:
            self.expire()
            voice = data.get("voice")
            if voice not in ("unknown", "active", "inactive"):
                raise ValueError("Invalid Voice state")
            self.last_browser = self.clock()
            self.voice = voice
            activity = data.get("activity", "unknown")
            self.activity = activity if voice == "active" and activity in ("thinking", "unknown") else "unknown"
            if not self.pending:
                # Only fixed, non-content diagnostic codes are accepted from the extension.
                self.error = self.command_error or {"ambiguous": "Voice controls are ambiguous; use manual Voice.",
                              "permission": "Microphone permission is blocked. Allow ChatGPT microphone access in the browser/macOS, then use Voice manually.",
                              "missing": "Voice controls not found; sign in or use manual Voice.",
                              "": ""}.get(data.get("diagnostic", ""), "Voice detection unavailable.")
            if data.get("diagnostic") == "permission":
                self.error = "Microphone permission is blocked. Allow ChatGPT microphone access in the browser/macOS, then use Voice manually."
            if self.pending and not self.pending["dispatched"] and data.get("busy") is not True:
                self.pending["dispatched"] = True
                return {k: self.pending[k] for k in ("id", "action")}
            return None

    def command(self, action):
        with self.lock:
            self.expire()
            if action not in ("toggle", "start", "end"):
                raise ValueError("Invalid action")
            if self.clock() - self.last_browser >= 4:
                raise RuntimeError("Browser disconnected; use ChatGPT Voice manually.")
            if self.pending:
                raise RuntimeError("A Voice command is already pending.")
            self.pending = {"id": secrets.token_hex(8), "action": action,
                            "created": self.clock(), "dispatched": False}
            self.error = ""
            self.command_error = ""
            return self.pending["id"]

    def result(self, data):
        with self.lock:
            self.expire()
            if not self.pending or data.get("id") != self.pending["id"]:
                return False
            self.pending = None
            # A click is not success. The extension must observe the resulting control.
            self.error = "" if data.get("ok") is True else "Voice did not confirm the requested state. Use the browser's Voice controls."
            self.command_error = self.error
            return True

    def audio(self, data):
        with self.lock:
            rms = data.get("rms", 0.0)
            if isinstance(rms, bool) or not isinstance(rms, (float, int)) or not math.isfinite(rms):
                raise ValueError("Invalid amplitude")
            if not isinstance(data.get("capturing"), bool):
                raise ValueError("Invalid capture state")
            diagnostic = data.get("diagnostic", "")
            if diagnostic not in ("", "capture_denied", "capture_ended", "capture_failed"):
                raise ValueError("Invalid capture diagnostic")
            if diagnostic:
                self.audio_error = {"capture_denied": "Tab output permission was denied. Retry capture from the selected tab; manual Voice still works.",
                                    "capture_ended": "Tab output capture ended. Retry capture for lip sync; Voice may still be active.",
                                    "capture_failed": "Tab output capture could not start. Check browser permissions; use manual Voice."}[diagnostic]
            elif data["capturing"]:
                self.audio_error = ""
            self.rms = max(0.0, min(1.0, rms))
            self.capturing = data["capturing"]
            self.last_audio = self.clock()


def make_server(port, key, state=None):
    state = state or BridgeState()

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass  # Never log requests, pairing keys, tab information, or browser content.

        def origin_allowed(self):
            origin = self.headers.get("Origin", "")
            return not origin or re.fullmatch(r"chrome-extension://[a-p]{32}", origin) is not None

        def respond(self, status, data):
            body = json.dumps(data, allow_nan=False).encode()
            self.send_response(status)
            origin = self.headers.get("Origin", "")
            if origin and self.origin_allowed():
                self.send_header("Access-Control-Allow-Origin", origin)
                self.send_header("Vary", "Origin")
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def allowed(self, auth=True):
            allowed_hosts = {f"127.0.0.1:{self.server.server_port}"}
            if self.headers.get("Host") not in allowed_hosts or not self.origin_allowed():
                self.respond(403, {"error": "Forbidden origin or host"})
                return False
            if auth and not hmac.compare_digest(self.headers.get("X-Aisora-Key", "").encode("utf-8"), key.encode("utf-8")):
                self.respond(401, {"error": "Pair the local bridge"})
                return False
            return True

        def do_OPTIONS(self):
            if not self.allowed(auth=False):
                return
            self.send_response(204)
            self.send_header("Access-Control-Allow-Origin", self.headers.get("Origin", ""))
            self.send_header("Access-Control-Allow-Headers", "Content-Type, X-Aisora-Key")
            self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            self.send_header("Access-Control-Allow-Private-Network", "true")
            self.end_headers()

        def do_GET(self):
            if not self.allowed(auth=self.path != "/health"):
                return
            if self.path == "/health":
                self.respond(200, {"service": "aisora", "version": 1})
            elif self.path == "/v1/state":
                self.respond(200, state.snapshot())
            else:
                self.respond(404, {"error": "Not found"})

        def do_POST(self):
            if not self.allowed():
                return
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if not 0 < length <= 2048:
                    raise ValueError("Invalid body length")
                data = json.loads(self.rfile.read(length))
                if not isinstance(data, dict):
                    raise ValueError("Expected object")
                if self.path == "/v1/poll":
                    result = {"command": state.poll(data)}
                elif self.path == "/v1/command":
                    result = {"id": state.command(data.get("action"))}
                elif self.path == "/v1/result":
                    result = {"accepted": state.result(data)}
                elif self.path == "/v1/audio":
                    state.audio(data)
                    result = {"ok": True}
                else:
                    self.respond(404, {"error": "Not found"})
                    return
                self.respond(200, result)
            except (ValueError, TypeError, OverflowError):
                self.respond(400, {"error": "Invalid request"})
            except RuntimeError as exc:
                self.respond(409, {"error": str(exc)})

    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    server.daemon_threads = True
    return server


def pairing_config(path: Path, port: int):
    path.parent.mkdir(parents=True, exist_ok=True)
    (path.parent / ".gdignore").touch()
    if path.exists():
        data = json.loads(path.read_text())
        if not isinstance(data.get("key"), str) or not re.fullmatch(r"[a-f0-9]{64}", data["key"]):
            raise ValueError("Invalid pairing file; remove it and re-pair")
        key = data["key"]
    else:
        key = secrets.token_hex(32)
    # Atomic replacement, restrictive permissions even with a permissive umask.
    temporary = path.with_suffix(".tmp")
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as handle:
        json.dump({"port": port, "key": key}, handle)
    os.chmod(temporary, 0o600)
    temporary.replace(path)
    return key


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--config", type=Path, default=ROOT / ".local" / "bridge.json")
    args = parser.parse_args()
    if not 1024 <= args.port <= 65535:
        parser.error("Use a port from 1024 to 65535")
    key = pairing_config(args.config, args.port)
    server = make_server(args.port, key)
    print(f"Aisora bridge listening on 127.0.0.1:{args.port}", flush=True)
    print(f"In the extension, choose this pairing file: {args.config}", flush=True)
    try:
        server.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
