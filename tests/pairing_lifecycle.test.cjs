const {test} = require('node:test');
const assert = require('node:assert/strict');
const {spawn} = require('node:child_process');
const {once} = require('node:events');
const path = require('node:path');
const {worker} = require('./extension_harness.cjs');
const response = (data, status = 200) => ({ok: status === 200, status, json: async () => data});

test('unpaired status renders explicitly instead of throwing a generic pairing prompt', async () => {
  const w = worker({local: {}});
  const s = await w.context.handle({type: 'status'}, w.popup);
  assert.equal(s.pairingStatus, 'unpaired'); assert.equal(s.extensionVersion, '0.3.1');
  assert.equal(w.calls.length, 0);
});

test('invalid legacy storage cannot inject a port, host or request path', async () => {
  for (const port of ['8765/path', '8765@evil.example', true, 80, 70000]) {
    const w = worker({local: {pairing: {port, key: 'a'.repeat(64)}}});
    assert.equal((await w.context.handle({type: 'status'}, w.popup)).pairingStatus, 'invalid_config');
    assert.equal(w.calls.length, 0);
  }
});

test('HTTP 401 is explicit, does not expose a reflected key, and preserves saved pairing', async () => {
  const w = worker({fetch: async url => url.endsWith('/health') ? response({service: 'aisora', version: 1}) : response({error: 'a'.repeat(64)}, 401)});
  const old = w.local.pairing;
  await assert.rejects(w.context.handle({type: 'pair', pairing: {port: 8766, key: 'b'.repeat(64)}}, w.popup), /Authentication failed/);
  assert.equal(w.local.pairing, old);
  const s = await w.context.handle({type: 'status'}, w.popup);
  assert.equal(s.pairingStatus, 'authentication_failed');
  assert.equal(JSON.stringify(s).includes('a'.repeat(64)), false);
});

test('service identity and protocol are validated before saving/authenticated state', async () => {
  for (const identity of [{service: 'other', version: 1}, {service: 'aisora', version: 2}]) {
    const w = worker({fetch: async () => response(identity)});
    const previous = w.local.pairing;
    await assert.rejects(w.context.handle({type: 'pair', pairing: {port: 9999, key: 'b'.repeat(64)}}, w.popup), /protocol 1/);
    assert.equal(w.local.pairing, previous);
    assert.equal((await w.context.handle({type: 'status'}, w.popup)).pairingStatus, 'incompatible');
  }
});

test('future pairing-file protocols are refused without any network request', async () => {
  const w = worker();
  await assert.rejects(w.context.handle({type: 'pair', pairing: {port: 8765, key: 'a'.repeat(64), protocol: 2}}, w.popup), /incompatible/);
  assert.equal(w.calls.length, 0);
});

test('a different localhost service does not receive the pairing key in its health probe', async () => {
  const calls = [];
  const w = worker({fetch: async (url, options) => {calls.push({url, options}); return response({service: 'other', version: 1});}});
  await assert.rejects(w.context.handle({type: 'pair', pairing: {port: 8765, key: 'a'.repeat(64)}}, w.popup), /protocol 1/);
  assert.equal(calls.length, 1); assert.equal(calls[0].options.headers['X-Aisora-Key'], undefined);
});

test('network/JSON failure is actionable and never displays raw exception/response text', async () => {
  for (const fetch of [async () => {throw new Error('private ' + 'a'.repeat(64));}, async () => ({ok: true, json: async () => {throw new Error('secret body');}}), async () => response({error: 'secret'}, 403)]) {
    const w = worker({fetch}); const s = await w.context.handle({type: 'reconnect'}, w.popup);
    assert.ok(['bridge_unavailable', 'incompatible'].includes(s.pairingStatus));
    assert.equal(JSON.stringify(s).includes('secret'), false);
    assert.equal(JSON.stringify(s).includes('a'.repeat(64)), false);
  }
});

test('a connected authenticated bridge is distinct from a disconnected conversation', async () => {
  const w = worker(); const s = await w.context.handle({type: 'status'}, w.popup);
  assert.equal(s.pairingStatus, 'connected'); assert.equal(s.connected, false);
  assert.equal(s.selected, true); assert.equal(s.bridgeVersion, 'legacy protocol 1');
  assert.equal(s.key, undefined); assert.equal(s.pairing, undefined);
  assert.ok(w.calls.every(c => c.options.redirect === 'error' && c.url.startsWith('http://127.0.0.1:')));
});

test('pair/reconnect from persistent setup is privileged but cannot control Voice or select tabs', async () => {
  const w = worker(); const setup = {id: w.popup.id, url: w.context.chrome.runtime.getURL('pairing.html')};
  await w.context.handle({type: 'pair', pairing: {port: 8765, key: 'a'.repeat(64)}}, setup);
  assert.equal((await w.context.handle({type: 'reconnect'}, setup)).pairingStatus, 'connected');
  for (const type of ['startVoice','bind','capture']) await assert.rejects(w.context.handle({type}, setup));
  assert.ok(w.calls.every(c => !c.url.endsWith('/v1/command')));
});

test('reset requires confirmation, refuses known active/pending Voice and preserves guard', async () => {
  const w = worker();
  await assert.rejects(w.context.handle({type: 'resetPairing'}, w.popup), /End Voice/);
  w.session.voiceOwner = {tabId: 42, path: w.session.targetPath};
  await assert.rejects(w.context.handle({type: 'resetPairing', confirmedNoVoice: true}, w.popup), /stale Voice guard/);
  assert.equal(w.session.voiceOwner.tabId, 42);
  delete w.session.voiceOwner;
  w.context.fetch = async url => response(url.endsWith('/health') ? {service: 'aisora', version: 1} : {connected: true, voice: 'inactive', pending: true});
  await assert.rejects(w.context.handle({type: 'resetPairing', confirmedNoVoice: true}, w.popup), /command is active/);
  assert.ok(w.local.pairing);
});

test('confirmed reset while bridge unavailable clears only extension pairing/selection', async () => {
  const w = worker({fetch: async () => {throw new Error('offline');}});
  w.local.startSelector = '#my-visible-button';
  const result = await w.context.handle({type: 'resetPairing', confirmedNoVoice: true}, w.popup);
  assert.equal(result.pairingStatus, 'unpaired'); assert.equal(w.local.pairing, undefined);
  assert.equal(w.session.targetId, undefined); assert.equal(w.local.startSelector, '#my-visible-button');
});

test('a known active Voice guard prevents switching bridge credentials', async () => {
  const w = worker(); w.session.voiceOwner = {tabId: 42, path: w.session.targetPath};
  await assert.rejects(w.context.handle({type: 'pair', pairing: {port: 8766, key: 'b'.repeat(64)}}, w.popup), /End Voice/);
  assert.equal(w.local.pairing.port, 8765);
});

async function startBridge(port = 0, key = 'a'.repeat(64)) {
  const script = `import importlib.util,sys\ns=importlib.util.spec_from_file_location('bridge',sys.argv[1]);b=importlib.util.module_from_spec(s);s.loader.exec_module(b)\nserver=b.make_server(int(sys.argv[2]),sys.argv[3]);print(server.server_port,flush=True);server.serve_forever()`;
  const child = spawn('python3', ['-u', '-c', script, path.join(__dirname, '../browser-controller/bridge.py'), String(port), key]);
  const ready = await new Promise((resolve, reject) => {
    child.once('error', reject); child.once('exit', () => reject(new Error('Fixture bridge did not start')));
    child.stdout.once('data', data => resolve(Number(String(data).trim())));
  });
  return {child, port: ready, stop: async () => { if (child.exitCode === null) {const exited = once(child, 'exit'); child.kill(); await exited;} }};
}

test('real Python HTTP lifecycle: import/auth, storage reload, outage, restart, stale key repair and selected routing', {timeout: 20000}, async t => {
  let server = await startBridge(); t.after(async () => server.stop());
  const local = {}; const session = {targetId: 42, targetPath: '/g/aisora/c/fixture', bindingId: 'selected-fixture'};
  let w = worker({local, session, fetch});
  await w.context.handle({type: 'pair', pairing: {port: server.port, key: 'a'.repeat(64), service: 'aisora', protocol: 1}}, w.popup);
  let status = await w.context.handle({type: 'status'}, w.popup);
  assert.equal(status.pairingStatus, 'connected'); assert.equal(status.connected, false); assert.equal(status.bridgeVersion, '0.3.1');
  // Closing a popup or reloading the worker does not erase chrome.storage.local.
  w = worker({local, session, fetch});
  assert.equal((await w.context.handle({type: 'reconnect'}, w.popup)).pairingStatus, 'connected');
  await w.context.handle({type: 'tick', path: session.targetPath, voice: 'inactive'}, w.sender);
  await w.context.handle({type: 'startVoice'}, w.popup);
  await assert.rejects(w.context.handle({type: 'tick', path: session.targetPath, voice: 'inactive'}, {...w.sender, tab: {id: 99}}));
  const pending = await w.context.handle({type: 'tick', path: session.targetPath, voice: 'inactive'}, w.sender);
  assert.equal(pending.command.action, 'start');
  await w.context.handle({type: 'result', path: session.targetPath, id: pending.command.id, ok: true, observedVoice: 'inactive'}, w.sender);
  const port = server.port;
  await server.stop();
  assert.equal((await w.context.handle({type: 'reconnect'}, w.popup)).pairingStatus, 'bridge_unavailable');
  server = await startBridge(port);
  assert.equal((await w.context.handle({type: 'reconnect'}, w.popup)).pairingStatus, 'connected');
  await server.stop(); server = await startBridge(port, 'b'.repeat(64));
  assert.equal((await w.context.handle({type: 'reconnect'}, w.popup)).pairingStatus, 'authentication_failed');
  await w.context.handle({type: 'pair', pairing: {port, key: 'b'.repeat(64)}}, w.popup);
  assert.equal((await w.context.handle({type: 'status'}, w.popup)).pairingStatus, 'connected');
  // Extension reload retains pairing, but browser/session selection must be explicit again.
  w = worker({local, session: {}, fetch});
  assert.equal((await w.context.handle({type: 'reconnect'}, w.popup)).selected, false);
  await assert.rejects(w.context.handle({type: 'startVoice'}, w.popup), /Select your existing/);
});
