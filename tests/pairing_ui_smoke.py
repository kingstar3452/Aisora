#!/usr/bin/env python3
"""Real Chromium DOM/file chooser with mocked extension transport, no account.

Unpacked extensions are blocked by cloud browser policy; do not bypass it.
The worker/real HTTP path is tested separately by pairing_lifecycle.test.cjs.
"""
from pathlib import Path
import json
import tempfile
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
EXT = ROOT / 'browser-controller/extension'


def main():
    with tempfile.TemporaryDirectory(prefix='aisora-pair-ui-') as tmp, sync_playwright() as p:
        browser = p.chromium.launch(executable_path='/usr/bin/chromium', headless=True, args=['--no-sandbox'])
        try:
            page = browser.new_page()
            def serve(route):
                name = route.request.url.rsplit('/', 1)[-1]
                allowed = {'pairing.html', 'pairing_status.js', 'pairing.js', 'popup.css', 'popup.html', 'popup.js'}
                if name not in allowed: return route.abort()
                route.fulfill(path=str(EXT / name))
            page.route('https://aisora-test.invalid/**', serve)
            page.add_init_script('''
              window.mode = 'fail'; window.operations = []; window.openedSetup = 0;
              window.connection = {pairingStatus:'unpaired',bridgeMessage:'Import current bridge file.',extensionVersion:'0.3.1',connected:false,voice:'unknown'};
              window.chrome = {storage:{local:{get:async()=>({})}},runtime:{getManifest:()=>({version:'0.3.1'}),openOptionsPage:async()=>{window.openedSetup++},sendMessage:async msg=>{
                window.operations.push(msg.type);
                if(msg.type==='pair'){
                  if(window.mode==='fail') return {error:'Authentication failed (HTTP 401). Existing pairing kept.'};
                  window.connection={...window.connection,pairingStatus:'connected',bridgeVersion:'0.3.1',protocol:1,bridgeMessage:'Bridge authenticated; conversation separate.'};
                }
                if(msg.type==='resetPairing') window.connection={...window.connection,pairingStatus:'unpaired',bridgeMessage:'Pairing reset.'};
                return {...window.connection,ok:true};
              }}};
            ''')
            page.goto('https://aisora-test.invalid/pairing.html')
            page.wait_for_function("!document.querySelector('#pair').disabled")
            payload = json.dumps({'port': 8765, 'key': 'a' * 64}).encode()
            for success in [False, True]:
                if success: page.evaluate("window.mode='ok'")
                with page.expect_file_chooser() as selected:
                    page.locator('#pair').click()
                selected.value.set_files({'name': 'bridge.json', 'mimeType': 'application/json', 'buffer': payload})
                page.wait_for_function("document.querySelector('#status').textContent.includes(" + json.dumps('Authentication succeeded' if success else 'Authentication failed') + ")")
                assert page.locator('#pair').input_value() == ''
                assert page.url.endswith('/pairing.html')
            assert 'Connected' in page.locator('#connection').inner_text()
            assert 'a' * 64 not in page.locator('body').inner_text()
            page.locator('#pair').set_input_files({'name': 'bad.json', 'mimeType': 'application/json', 'buffer': ('{"key":"' + 'b' * 64).encode()})
            page.wait_for_function("document.querySelector('#status').textContent.includes('invalid JSON')")
            assert 'b' * 64 not in page.locator('body').inner_text()
            assert page.locator('#pair').input_value() == ''
            page.on('dialog', lambda dialog: dialog.accept())
            page.locator('#reset').click()
            page.wait_for_function("document.querySelector('#connection').textContent.startsWith('Unpaired')")
            assert not any(x in ['startVoice', 'bind', 'capture'] for x in page.evaluate('window.operations'))
            page.goto('https://aisora-test.invalid/popup.html')
            page.locator('#pairSetup').click()
            page.wait_for_function('window.openedSetup===1')
            assert page.locator('input[type=file]').count() == 0
            print('PAIRING UI SMOKE: persistent setup/file chooser, failed-auth and same-file retry, JSON redaction, confirmed reset and popup setup handoff: PASS (extension transport mocked)')
        finally:
            browser.close()


if __name__ == '__main__':
    main()
