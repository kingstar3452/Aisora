const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = name => fs.readFileSync(path.join(__dirname, '../browser-controller/extension', name), 'utf8');

function worker() {
  const local = {pairing: {key: 'a'.repeat(64), port: 8765}};
  const session = {targetId: 42, targetPath: '/g/aisora/c/fixture'};
  const calls = [], events = {};
  const storage = data => ({
    get: async names => Object.fromEntries((Array.isArray(names) ? names : [names]).map(n => [n, data[n]])),
    set: async values => Object.assign(data, values),
    remove: async names => (Array.isArray(names) ? names : [names]).forEach(n => delete data[n])
  });
  const context = vm.createContext({URL, AbortSignal, Date, console,
    fetch: async (url, options) => { calls.push({url, options}); return {ok: true, json: async () => ({command: null})}; },
    chrome: {
      storage: {local: storage(local), session: storage(session)},
      runtime: {id: 'test-extension', getURL: p => 'chrome-extension://test-extension/' + p,
        onMessage: {addListener: f => events.message = f}, sendMessage: async () => ({ok: true}), getContexts: async () => []},
      tabs: {query: async () => [{id: 42, url: 'https://chatgpt.com/g/aisora/c/fixture'}],
        onRemoved: {addListener: f => events.removed = f}, onUpdated: {addListener: f => events.updated = f}},
      scripting: {executeScript: async value => calls.push({script: value})},
      offscreen: {hasDocument: async () => false, createDocument: async value => calls.push({offscreen: value}), closeDocument: async () => {}},
      tabCapture: {getMediaStreamId: async value => { calls.push({capture: value}); return 'fake-stream'; }},
      commands: {onCommand: {addListener: f => events.command = f}}
    }});
  vm.runInContext(source('background.js'), context);
  const sender = {id: 'test-extension', tab: {id: 42}, url: 'https://chatgpt.com/g/aisora/c/fixture'};
  const popup = {id: 'test-extension', url: 'chrome-extension://test-extension/popup.html'};
  return {context, local, session, calls, events, sender, popup};
}

test('worker targets only the explicitly selected tab and conversation path', async () => {
  const w = worker();
  assert.equal((await w.context.handle({type: 'selected', path: '/g/aisora/c/fixture'}, w.sender)).selected, true);
  assert.equal((await w.context.handle({type: 'selected', path: '/c/other'}, w.sender)).selected, false);
  assert.equal((await w.context.handle({type: 'selected', path: '/g/aisora/c/fixture'}, {...w.sender, tab: {id: 43}})).selected, false);
  await w.context.handle({type: 'tick', path: '/g/aisora/c/fixture', voice: 'inactive', diagnostic: ''}, w.sender);
  assert.equal(w.calls[0].url, 'http://127.0.0.1:8765/v1/poll');
  assert.equal(w.calls[0].options.headers['X-Aisora-Key'], 'a'.repeat(64));
  assert.deepEqual(JSON.parse(w.calls[0].options.body), {voice: 'inactive', diagnostic: ''});
});
test('content script cannot pair, capture output or emit amplitude', async () => {
  const w = worker();
  for (const type of ['pair', 'capture', 'audio']) await assert.rejects(w.context.handle({type}, w.sender));
  assert.equal(w.calls.length, 0);
});
test('pairing rejects arbitrary hosts/keys and stores only local key and port', async () => {
  const w = worker();
  await assert.rejects(w.context.handle({type: 'pair', pairing: {port: 80, key: 'x'}}, w.popup));
  await w.context.handle({type: 'pair', pairing: {port: 8766, key: 'b'.repeat(64), host: 'evil.example'}}, w.popup);
  assert.equal(w.local.pairing.port, 8766);
  assert.equal(w.local.pairing.host, undefined);
  assert.equal(w.calls[0].url, 'http://127.0.0.1:8766/health');
});
test('binding is explicit and script injection never navigates or creates a chat', async () => {
  const w = worker();
  await w.context.handle({type: 'bind'}, w.popup);
  assert.equal(w.session.targetId, 42);
  assert.equal(w.session.targetPath, '/g/aisora/c/fixture');
  assert.ok(w.calls.some(call => call.script?.target.tabId === 42));
});
test('capture uses the selected tab, and only offscreen amplitude is relayed', async () => {
  const w = worker();
  await w.context.handle({type: 'capture'}, w.popup);
  assert.ok(w.calls.some(call => call.capture?.targetTabId === 42));
  await w.context.handle({type: 'audio', rms: 0.2, capturing: true}, {id: 'test-extension', url: 'chrome-extension://test-extension/offscreen.html'});
  assert.equal(JSON.parse(w.calls.at(-1).options.body).rms, 0.2);
  assert.equal(w.calls.at(-1).url, 'http://127.0.0.1:8765/v1/audio');
});
test('navigation away from selected conversation clears selection and output capture', async () => {
  const w = worker();
  await w.events.updated(42, {url: 'https://chatgpt.com/c/other'});
  assert.equal(w.session.targetId, undefined);
  assert.equal(w.session.targetPath, undefined);
  assert.ok(w.calls.some(call => call.url?.endsWith('/v1/audio') && JSON.parse(call.options.body).capturing === false));
});

test('offscreen meter captures tab output, preserves playback, emits RMS only, stops tracks', async () => {
  let constraints, tick, listener, stopped = false, closed = false;
  const connections = [], messages = [];
  const track = {stop: () => stopped = true, addEventListener: () => {}};
  const stream = {active: true, getTracks: () => [track], getAudioTracks: () => [track]};
  const context = vm.createContext({console, setTimeout, clearTimeout,
    setInterval: f => { tick = f; return 1; }, clearInterval: () => {},
    navigator: {mediaDevices: {getUserMedia: async value => { constraints = value; return stream; }}},
    AudioContext: class {
      constructor() { this.destination = {speaker: true}; this.state = 'running'; }
      async resume() {}
      async close() { closed = true; }
      createMediaStreamSource() { return {connect: node => connections.push(node)}; }
      createAnalyser() { return {fftSize: 0, getFloatTimeDomainData: samples => samples.fill(0.2)}; }
    },
    chrome: {runtime: {onMessage: {addListener: f => listener = f}, sendMessage: async message => { messages.push(message); return {ok: true}; }}}
  });
  vm.runInContext(source('offscreen.js'), context);
  const response = await new Promise(resolve => listener({destination: 'offscreen', type: 'capture', streamId: 'fake'}, {}, resolve));
  assert.equal(response.ok, true);
  assert.equal(constraints.audio.mandatory.chromeMediaSource, 'tab');
  assert.equal(constraints.audio.mandatory.chromeMediaSourceId, 'fake');
  assert.equal(constraints.video, false);
  assert.equal(connections.length, 2);
  assert.equal(connections[1].speaker, true);
  await tick();
  assert.equal(messages.length, 1);
  assert.deepEqual(Object.keys(messages[0]).sort(), ['capturing', 'rms', 'type']);
  assert.ok(Math.abs(messages[0].rms - 0.2) < 1e-6);
  await context.stop();
  assert.ok(stopped && closed);
});
