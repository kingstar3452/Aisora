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
    fetch: async (url, options) => { calls.push({url, options}); return {ok: true, json: async () => url.endsWith('/health') ? {service: 'aisora', version: 1} : (url.endsWith('/v1/state') ? {connected: false, voice: 'unknown'} : {command: null})}; },
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
  assert.equal(w.calls[1].url, 'http://127.0.0.1:8766/v1/state');
  assert.equal(w.calls[1].options.headers['X-Aisora-Key'], 'b'.repeat(64));
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
  const response = await new Promise(resolve => listener({destination: 'offscreen', type: 'capture', streamId: 'fake', tabId: 42}, {}, resolve));
  assert.equal(response.ok, true);
  assert.equal(constraints.audio.mandatory.chromeMediaSource, 'tab');
  assert.equal(constraints.audio.mandatory.chromeMediaSourceId, 'fake');
  assert.equal(constraints.video, false);
  assert.equal(connections.length, 2);
  assert.equal(connections[1].speaker, true);
  await tick();
  assert.equal(messages.length, 1);
  assert.deepEqual(Object.keys(messages[0]).sort(), ['capturing', 'rms', 'tabId', 'type']);
  assert.equal(messages[0].tabId, 42);
  assert.ok(Math.abs(messages[0].rms - 0.2) < 1e-6);
  await context.stop();
  assert.ok(stopped && closed);
});


test('failed pairing keeps a working binding, and never trusts health alone', async () => {
  const w = worker();
  w.context.fetch = async url => ({ok: !url.endsWith('/v1/state'), json: async () => url.endsWith('/health') ? {service: 'aisora', version: 1} : {error: 'Unauthorized'}});
  await assert.rejects(w.context.handle({type: 'pair', pairing: {port: 9999, key: 'b'.repeat(64)}}, w.popup), /Pairing rejected/);
  assert.equal(w.local.pairing.port,8765);
  assert.equal(w.local.pairing.key,'a'.repeat(64));
});
test('worker restart re-adopts only the selected tab meter, not another tab', async () => {
  const w=worker();const sender={id:'test-extension',url:'chrome-extension://test-extension/offscreen.html'};
  assert.equal((await w.context.handle({type:'audio',tabId:43,rms:.5,capturing:true},sender)).ok,false);
  assert.equal(w.calls.length,0);
  assert.equal((await w.context.handle({type:'audio',tabId:42,rms:.3,capturing:true},sender)).ok,true);
  assert.equal(JSON.parse(w.calls[0].options.body).rms,.3);
});
test('capture attempts serialize and explicit start/end preserve intent', async () => {
  const w=worker();
  await Promise.all([w.context.handle({type:'capture'},w.popup),w.context.handle({type:'capture'},w.popup)]);
  assert.equal(w.calls.filter(c=>c.capture).length,1);
  for (const [type,action] of [['startVoice','start'],['endVoice','end']]) {
    await w.context.handle({type},w.popup);
    assert.equal(JSON.parse(w.calls.at(-1).options.body).action,action);
  }
});
test('an observed active session blocks switching to a second conversation', async () => {
  const w=worker();
  await w.context.handle({type:'tick',path:'/g/aisora/c/fixture',voice:'active'},w.sender);
  w.context.chrome.tabs.query=async()=>[{id:43,url:'https://chatgpt.com/c/other'}];
  await assert.rejects(w.context.handle({type:'bind'},w.popup),/End Voice/);
  assert.equal(w.session.targetId,42);
  await w.context.handle({type:'tick',path:'/g/aisora/c/fixture',voice:'inactive'},w.sender);
  await w.context.handle({type:'bind'},w.popup);
  assert.equal(w.session.targetId,43);
});
test('unknown detection retains the guard until explicit manual release or tab closure', async () => {
  const w=worker();
  await w.context.handle({type:'tick',path:'/g/aisora/c/fixture',voice:'active'},w.sender);
  await w.context.handle({type:'tick',path:'/g/aisora/c/fixture',voice:'unknown'},w.sender);
  assert.equal(w.session.voiceOwner.tabId,42);
  await w.context.handle({type:'releaseGuard'},w.popup);
  assert.equal(w.session.voiceOwner,undefined);
});


test('output-capture permission failure returns only a fixed diagnostic', async () => {
 let listener;
 const context=vm.createContext({setTimeout,clearTimeout,clearInterval:()=>{},
   navigator:{mediaDevices:{getUserMedia:async()=>{const error=new Error('private device detail');error.name='NotAllowedError';throw error;}}},
   chrome:{runtime:{onMessage:{addListener:f=>listener=f}}}});
 vm.runInContext(source('offscreen.js'),context);
 const result=await new Promise(resolve=>listener({destination:'offscreen',type:'capture',streamId:'test',tabId:42},{},resolve));
 assert.equal(result.ok,false);assert.equal(result.diagnostic,'capture_denied');
 assert.equal(JSON.stringify(result).includes('private device detail'),false);
});
