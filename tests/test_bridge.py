import importlib.util
import json
from pathlib import Path
import tempfile
import threading
import subprocess
import sys
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

    def test_selection_nonce_cancels_pending_commands_and_stale_results(self):
        self.state.poll({'voice': 'inactive', 'binding_id': 'first', 'project_label': 'Aisora'})
        command_id = self.state.command('start')
        self.assertIsNone(self.state.poll({'voice': 'inactive', 'binding_id': 'second', 'project_label': 'Aisora'}))
        self.assertFalse(self.state.snapshot()['pending'])
        self.assertIn('cancelled', self.state.snapshot()['error'])
        self.assertFalse(self.state.result({'id': command_id, 'ok': True, 'observed_voice': 'active'}))
        self.assertEqual(self.state.snapshot()['voice'], 'inactive')

    def test_old_binding_audio_cannot_animate_new_conversation(self):
        self.state.poll({'voice': 'active', 'binding_id': 'new'})
        self.state.audio({'binding_id': 'old', 'capturing': True, 'rms': 1.0})
        self.assertEqual(self.state.snapshot()['rms'], 0)
        self.state.audio({'binding_id': 'new', 'capturing': True, 'rms': .3})
        self.assertAlmostEqual(self.state.snapshot()['rms'], .3)
        self.state.poll({'voice': 'active', 'binding_id': 'next'})
        self.assertFalse(self.state.snapshot()['capturing'])

    def test_confirmed_result_updates_state_before_next_heartbeat(self):
        self.state.poll({'voice': 'inactive'})
        command_id = self.state.command('start')
        self.state.result({'id': command_id, 'ok': True, 'observed_voice': 'active'})
        self.assertEqual(self.state.snapshot()['voice'], 'active')
        self.now += 5
        self.assertEqual(self.state.snapshot()['voice'], 'unknown')
        restarted = bridge.BridgeState(lambda: self.now)
        self.assertFalse(restarted.result({'id': command_id, 'ok': True}))
        self.assertIsNone(restarted.poll({'voice': 'active', 'binding_id': 'return'}))

    def test_project_metadata_is_bounded_user_selection_not_credential_data(self):
        self.state.poll({'voice': 'inactive', 'binding_id': 'local-id', 'project_label': 'Aisora'})
        self.assertEqual(self.state.snapshot()['project_label'], 'Aisora')
        self.assertTrue(self.state.snapshot()['conversation_selected'])
        for value in ['x'*65, 'bad\nlabel', {'secret': 'unaccepted'}]:
            with self.assertRaises(ValueError): self.state.poll({'voice': 'inactive', 'project_label': value})
        with self.assertRaises(ValueError): self.state.poll({'voice': 'inactive', 'binding_id': '../wrong'})
        self.now += 5
        self.assertEqual(self.state.snapshot()['project_label'], '')

    def test_listening_requires_explicit_active_fresh_metadata(self):
        self.state.poll({'voice': 'active', 'activity': 'listening'})
        self.assertEqual(self.state.snapshot()['activity'], 'listening')
        self.state.poll({'voice': 'inactive', 'activity': 'listening'})
        self.assertEqual(self.state.snapshot()['activity'], 'unknown')


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


class StartupTests(unittest.TestCase):
    def test_occupied_port_does_not_create_a_misleading_pairing_file(self):
        server = bridge.make_server(0, 'a' * 64)
        self.addCleanup(server.server_close)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'another-source-copy/.local/bridge.json'
            result = subprocess.run([sys.executable, str(Path(bridge.__file__)), '--port', str(server.server_port), '--config', str(path)], capture_output=True, text=True, timeout=5)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(path.exists(), 'A failed second bridge must not generate a valid-looking key for the first bridge port')

    def test_occupied_port_preserves_existing_pairing_bytes(self):
        server = bridge.make_server(0, 'a' * 64)
        self.addCleanup(server.server_close)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'bridge.json'
            original = json.dumps({'port': 8766, 'key': 'b' * 64}, indent=2).encode()
            path.write_bytes(original)
            result = subprocess.run([sys.executable, str(Path(bridge.__file__)), '--port', str(server.server_port), '--config', str(path)], capture_output=True, text=True, timeout=5)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(path.read_bytes(), original)


class DiagnosticTests(unittest.TestCase):
    def setUp(self):
        self.server = bridge.make_server(0, 'a' * 64)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.stop)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'bridge.json'
        bridge.pairing_config(self.path, self.server.server_port, 'a' * 64)

    def stop(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def test_authenticated_bridge_is_distinct_from_selected_browser(self):
        before = self.path.read_bytes()
        result = bridge.diagnose(self.path)
        self.assertEqual(result['status'], 'Connected')
        self.assertEqual(result['protocol'], 1)
        self.assertEqual(result['bridge_version'], '0.3.1')
        self.assertFalse(result['conversation_connected'])
        self.assertEqual(self.path.read_bytes(), before)
        self.assertNotIn('a' * 64, json.dumps(result))

    def test_stale_key_reports_authentication_failure_without_secrets(self):
        bridge.pairing_config(self.path, self.server.server_port, 'b' * 64)
        result = bridge.diagnose(self.path)
        self.assertEqual(result['status'], 'Authentication failed')
        self.assertEqual(result['http_status'], 401)
        self.assertNotIn('a' * 64, json.dumps(result))
        self.assertNotIn('b' * 64, json.dumps(result))

    def test_diagnose_cli_authenticates_and_never_rewrites_key(self):
        before = self.path.read_bytes()
        result = subprocess.run([sys.executable, str(Path(bridge.__file__)), '--diagnose', '--config', str(self.path)], capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(json.loads(result.stdout)['status'], 'Connected')
        self.assertEqual(self.path.read_bytes(), before)
        self.assertNotIn('a' * 64, result.stdout + result.stderr)

    def test_missing_or_future_config_is_read_only(self):
        missing = self.path.parent / 'missing/bridge.json'
        self.assertEqual(bridge.diagnose(missing)['status'], 'Unpaired')
        self.assertFalse(missing.parent.exists())
        config = json.loads(self.path.read_text())
        config['protocol'] = 2
        self.path.write_text(json.dumps(config))
        self.assertEqual(bridge.diagnose(self.path)['status'], 'Incompatible')

    def test_legacy_file_remains_compatible(self):
        self.path.write_text(json.dumps({'port': self.server.server_port, 'key': 'a' * 64}))
        self.assertEqual(bridge.diagnose(self.path)['status'], 'Connected')


if __name__ == '__main__': unittest.main()
