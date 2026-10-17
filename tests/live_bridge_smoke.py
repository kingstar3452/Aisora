#!/usr/bin/env python3
"""Exercise Godot's actual HTTP client against the bridge; browser/audio are simulated."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('bridge', ROOT / 'browser-controller/bridge.py')
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)


def main():
    key = '1' * 64  # Test-only local pairing, never a ChatGPT credential.
    state = bridge.BridgeState()
    server = bridge.make_server(0, key, state)
    http_thread = threading.Thread(target=server.serve_forever, daemon=True)
    http_thread.start()
    stopped = threading.Event()

    def simulated_browser():
        voice = 'inactive'
        while not stopped.is_set():
            command = state.poll({'voice': voice})
            if command:
                voice = 'active' if voice == 'inactive' else 'inactive'
                state.poll({'voice': voice})
                state.result({'id': command['id'], 'ok': True})
            state.audio({'rms': 0.12 if voice == 'active' else 0.0, 'capturing': True})
            stopped.wait(0.1)

    browser_thread = threading.Thread(target=simulated_browser, daemon=True)
    browser_thread.start()
    try:
        with tempfile.TemporaryDirectory(prefix='aisora-godot-bridge-') as temporary:
            path = Path(temporary) / 'pairing.json'
            path.write_text(json.dumps({'port': server.server_port, 'key': key}))
            result = subprocess.run([str(ROOT / 'tools/run_godot.sh'), '--headless', '--script', 'res://tests/test_live_bridge.gd'],
                                    cwd=ROOT, env={**os.environ, 'AISORA_BRIDGE_CONFIG': str(path)},
                                    capture_output=True, text=True, timeout=25)
            print(result.stdout, end='')
            print(result.stderr, end='')
            if result.returncode or '5 checks; 0 failures' not in result.stdout or 'SCRIPT ERROR' in result.stderr:
                raise SystemExit(result.returncode or 1)
    finally:
        stopped.set()
        browser_thread.join()
        server.shutdown()
        server.server_close()
        http_thread.join()


if __name__ == '__main__': main()
