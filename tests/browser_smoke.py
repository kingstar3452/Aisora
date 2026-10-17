#!/usr/bin/env python3
"""Optional simulated DOM/bridge integration. Requires playwright + local Chromium.
Run: python3 tests/browser_smoke.py [--chromium /path/to/chromium]
Never opens real ChatGPT or loads an authenticated profile. Extension API transport is
simulated because cloud browser administrator policy blocks unpacked extensions.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import threading
import time
import urllib.request
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('bridge', ROOT / 'browser-controller/bridge.py')
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)

HTML = '''<!doctype html><title>Aisora simulated Voice controls</title>
<button aria-label="Start voice mode" id="voice">Voice</button>
<button aria-label="Dictate" id="dictate">Dictation</button>
<script>
window.clicks = 0; window.dictationClicks = 0;
document.querySelector('#voice').onclick = event => {
 window.clicks++;
 const active = event.target.getAttribute('aria-label') === 'Start voice mode';
 event.target.setAttribute('aria-label', active ? 'End voice' : 'Start voice mode');
};
document.querySelector('#dictate').onclick = () => window.dictationClicks++;
</script>'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--chromium', default='/usr/bin/chromium')
    args = parser.parse_args()
    state = bridge.BridgeState()
    server = bridge.make_server(0, 'simulated-local-key', state)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    base = f'http://127.0.0.1:{server.server_port}'
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

    def api(path, data=None):
        req = urllib.request.Request(base + path, headers={'X-Aisora-Key': 'simulated-local-key'},
                                     data=json.dumps(data).encode() if data is not None else None)
        with opener.open(req, timeout=2) as response: return json.load(response)

    def message(_source, msg):
        if msg['type'] == 'selected': return {'selected': msg['path'] == '/g/aisora/c/fixture', 'options': {}}
        if msg['type'] == 'tick': return api('/v1/poll', {'voice': msg['voice'], 'diagnostic': msg['diagnostic']})
        if msg['type'] == 'result': return api('/v1/result', {'id': msg['id'], 'ok': msg['ok']})
        raise AssertionError('Unexpected extension message')

    try:
        with tempfile.TemporaryDirectory(prefix='aisora-smoke-') as temporary, sync_playwright() as p:
            env = dict(os.environ)
            for name, child in [('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache'), ('XDG_DATA_HOME', 'data')]:
                directory = Path(temporary) / child
                directory.mkdir()
                env[name] = str(directory)
            with p.chromium.launch_persistent_context(str(Path(temporary) / 'profile'), executable_path=args.chromium,
                                                      headless=True, timeout=20000, env=env,
                                                      args=['--no-sandbox']) as context:
                context.route('https://chatgpt.com/**', lambda route: route.fulfill(status=200, content_type='text/html', body=HTML))
                page = context.new_page()
                page.expose_binding('sendToAisora', message)
                page.add_init_script('globalThis.chrome = {runtime: {sendMessage: message => sendToAisora(message)}};')
                page.goto('https://chatgpt.com/g/aisora/c/fixture')
                for filename in ['voice_dom.js', 'content.js']:
                    page.add_script_tag(path=str(ROOT / 'browser-controller/extension' / filename))
                def wait_state(predicate, timeout=6):
                    deadline = time.monotonic() + timeout
                    while time.monotonic() < deadline:
                        snapshot = api('/v1/state')
                        if predicate(snapshot):
                            return snapshot
                        # Pump browser/binding callbacks instead of sleeping across the one-second heartbeat.
                        page.wait_for_timeout(50)
                    raise AssertionError(f'Bridge did not reach expected state: {api("/v1/state")}')

                wait_state(lambda s: s['voice'] == 'inactive' and not s['pending'])
                for _ in range(2):
                    api('/v1/command', {'action': 'toggle'})
                    page.wait_for_function("document.querySelector('#voice').getAttribute('aria-label') === 'End voice'")
                    wait_state(lambda s: s['voice'] == 'active' and not s['pending'])
                    api('/v1/command', {'action': 'toggle'})
                    page.wait_for_function("document.querySelector('#voice').getAttribute('aria-label') === 'Start voice mode'")
                    wait_state(lambda s: s['voice'] == 'inactive' and not s['pending'])
                assert page.url == 'https://chatgpt.com/g/aisora/c/fixture'
                assert page.evaluate('window.clicks') == 4
                assert page.evaluate('window.dictationClicks') == 0
                # Actual DOM ambiguity: no activation and an explicit failed command result.
                page.evaluate("document.body.insertAdjacentHTML('beforeend','<button aria-label=\"Use voice\">Duplicate</button>')")
                wait_state(lambda s: s['connected'] and s['voice'] == 'unknown')
                api('/v1/command', {'action': 'toggle'})
                wait_state(lambda s: not s['pending'])
                assert page.evaluate('window.clicks') == 4
                # No keep-alive when the selected conversation changes inside the same tab.
                page.evaluate("history.pushState({}, '', '/c/other-conversation')")
                wait_state(lambda s: not s['connected'])
                assert api('/v1/state')['voice'] == 'unknown'
                print('BROWSER SMOKE: two start/end cycles, unchanged conversation, no dictation, ambiguous-control refusal, navigation disconnect: PASS')
    finally:
        server.shutdown()
        server.server_close()
        thread.join()


if __name__ == '__main__': main()
