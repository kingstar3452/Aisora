import importlib.util
import json
from pathlib import Path
import tempfile
import threading
import unittest
import urllib.error
import urllib.request

SPEC = importlib.util.spec_from_file_location('bridge', Path(__file__).resolve().parents[1] / 'browser-controller/bridge.py')
bridge = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bridge)


class StateTests(unittest.TestCase):
    def setUp(self):
        self.now = 100.0
        self.state = bridge.BridgeState(lambda: self.now)

    def test_offline_refuses_commands(self):
        with self.assertRaises(RuntimeError): self.state.command('toggle')
        self.assertEqual(self.state.snapshot()['voice'], 'unknown')

    def test_command_delivered_once_and_acknowledged_by_id(self):
        self.state.poll({'voice': 'inactive'})
        command_id = self.state.command('toggle')
        with self.assertRaises(RuntimeError): self.state.command('toggle')
        command = self.state.poll({'voice': 'inactive'})
        self.assertEqual(command, {'id': command_id, 'action': 'toggle'})
        self.assertIsNone(self.state.poll({'voice': 'active'}))
        self.assertFalse(self.state.result({'id': 'old', 'ok': True}))
        self.assertTrue(self.state.snapshot()['pending'])
        self.assertTrue(self.state.result({'id': command_id, 'ok': True}))
        self.assertFalse(self.state.snapshot()['pending'])

    def test_timeout_never_replays_command(self):
        self.state.poll({'voice': 'inactive'})
        self.state.command('start')
        self.now += 16
        self.assertFalse(self.state.snapshot()['pending'])
        self.assertIsNone(self.state.poll({'voice': 'inactive'}))

    def test_failed_command_diagnostic_survives_heartbeats(self):
        self.state.poll({'voice': 'inactive'})
        command_id = self.state.command('start')
        self.state.result({'id': command_id, 'ok': False})
        self.state.poll({'voice': 'inactive'})
        self.assertIn('did not confirm', self.state.snapshot()['error'])
        self.state.command('start')
        self.assertEqual(self.state.snapshot()['error'], '')

    def test_audio_and_disconnect_freshness(self):
        self.state.poll({'voice': 'active'})
        self.state.audio({'rms': 0.2, 'capturing': True})
        self.assertEqual(self.state.snapshot()['rms'], 0.2)
        self.now += 0.41
        self.assertEqual(self.state.snapshot()['rms'], 0)
        self.assertFalse(self.state.snapshot()['capturing'])
        self.state.audio({'rms': 0.2, 'capturing': True})
        self.now += 4
        self.assertEqual(self.state.snapshot()['voice'], 'unknown')
        self.assertEqual(self.state.snapshot()['rms'], 0)

    def test_invalid_and_clamped_audio(self):
        for value in [float('nan'), float('inf'), 'text', True]:
            with self.assertRaises(ValueError): self.state.audio({'rms': value, 'capturing': True})
        self.state.poll({'voice': 'active'})
        self.state.audio({'rms': 4, 'capturing': True})
        self.assertEqual(self.state.snapshot()['rms'], 1)
        self.state.audio({'rms': -4, 'capturing': True})
        self.assertEqual(self.state.snapshot()['rms'], 0)

    def test_pairing_reuses_key_and_is_private(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'bridge.json'
            key = bridge.pairing_config(path, 8765)
            self.assertEqual(key, bridge.pairing_config(path, 8766))
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertTrue((path.parent / '.gdignore').exists())
            self.assertEqual(json.loads(path.read_text())['port'], 8766)

    def test_busy_browser_retains_an_undispatched_command(self):
        self.state.poll({'voice': 'inactive'})
        token = self.state.command('start')
        self.assertIsNone(self.state.poll({'voice': 'inactive', 'busy': True}))
        self.assertEqual(self.state.poll({'voice': 'inactive', 'busy': False})['id'], token)
        self.assertIsNone(self.state.poll({'voice': 'inactive'}))

    def test_thinking_is_explicit_fresh_and_only_for_active_voice(self):
        self.state.poll({'voice': 'active', 'activity': 'thinking'})
        self.assertEqual(self.state.snapshot()['activity'], 'thinking')
        self.state.poll({'voice': 'active'})
        self.assertEqual(self.state.snapshot()['activity'], 'unknown')
        self.state.poll({'voice': 'inactive', 'activity': 'thinking'})
        self.assertEqual(self.state.snapshot()['activity'], 'unknown')
        self.state.poll({'voice': 'active', 'activity': 'thinking'})
        self.now += 4.1
        self.assertEqual(self.state.snapshot()['activity'], 'unknown')

    def test_permission_and_capture_failures_do_not_end_or_invent_voice(self):
        self.state.poll({'voice': 'active', 'diagnostic': 'permission'})
        self.assertIn('Microphone permission', self.state.snapshot()['error'])
        self.state.audio({'capturing': False, 'rms': 0, 'diagnostic': 'capture_denied'})
        self.state.poll({'voice': 'active'})
        self.assertEqual(self.state.snapshot()['voice'], 'active')
        self.assertIn('permission was denied', self.state.snapshot()['error'])
        self.assertEqual(self.state.snapshot()['rms'], 0)
        self.state.audio({'capturing': True, 'rms': .1})
        self.assertEqual(self.state.snapshot()['error'], '')
        with self.assertRaises(ValueError):
            self.state.audio({'capturing': False, 'rms': 0, 'diagnostic': 'private free text'})


class HTTPTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = bridge.make_server(0, 'test-local-key')
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base = f'http://127.0.0.1:{cls.server.server_port}'
        cls.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def request(self, path, data=None, **headers):
        headers.setdefault('X-Aisora-Key', 'test-local-key')
        req = urllib.request.Request(self.base + path, headers=headers,
                                     data=json.dumps(data).encode() if data is not None else None)
        try:
            with self.opener.open(req, timeout=2) as response:
                return response.status, json.load(response)
        except urllib.error.HTTPError as error:
            return error.code, json.load(error)

    def test_health_and_authentication(self):
        self.assertEqual(self.request('/health', **{'X-Aisora-Key': ''})[0], 200)
        self.assertEqual(self.request('/v1/state', **{'X-Aisora-Key': ''})[0], 401)
        self.assertEqual(self.request('/v1/state')[0], 200)

    def test_web_origins_and_rebinding_rejected(self):
        self.assertEqual(self.request('/v1/command', {'action': 'toggle'}, Origin='https://evil.example')[0], 403)
        self.assertEqual(self.request('/v1/state', Host='evil.example')[0], 403)
        self.assertEqual(self.request('/v1/state', Origin='chrome-extension://' + 'a' * 32)[0], 200)
        self.assertEqual(self.request('/v1/state', Origin='chrome-extension://')[0], 403)

    def test_http_workflow_and_invalid_payload(self):
        self.assertEqual(self.request('/v1/poll', {'voice': 'inactive'})[0], 200)
        status, data = self.request('/v1/command', {'action': 'toggle'})
        self.assertEqual(status, 200)
        command_id = data['id']
        _, poll = self.request('/v1/poll', {'voice': 'inactive'})
        self.assertEqual(poll['command']['id'], command_id)
        self.assertEqual(self.request('/v1/result', {'id': command_id, 'ok': False})[0], 200)
        self.assertIn('did not confirm', self.request('/v1/state')[1]['error'])
        self.assertEqual(self.request('/v1/audio', {'rms': 'bad', 'capturing': True})[0], 400)
        self.assertEqual(self.request('/v1/poll', {'voice': 'made-up'})[0], 400)
        self.assertEqual(self.request('/missing')[0], 404)


if __name__ == '__main__': unittest.main()
