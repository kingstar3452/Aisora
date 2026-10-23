const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = name => fs.readFileSync(path.join(__dirname, '../browser-controller/extension', name), 'utf8');

function worker(overrides = {}) {
  const local = overrides.local || {pairing: {key: 'a'.repeat(64), port: 8765}};
  const session = overrides.session || {targetId: 42, targetPath: '/g/aisora/c/fixture'};
  const calls = [], events = {};
  const storage = data => ({
    get: async names => Object.fromEntries((Array.isArray(names) ? names : [names]).map(n => [n, data[n]])),
    set: async values => Object.assign(data, values),
    remove: async names => (Array.isArray(names) ? names : [names]).forEach(n => delete data[n])
  });
  const context = vm.createContext({URL, AbortSignal, Date, console, crypto:require('node:crypto').webcrypto,
    fetch: overrides.fetch || (async (url, options) => { calls.push({url, options}); return {ok: true, json: async () => url.endsWith('/health') ? {service: 'aisora', version: 1} : (url.endsWith('/v1/state') ? {connected: false, voice: 'unknown'} : {command: null})}; }),
    chrome: {
      storage: {local: storage(local), session: storage(session)},
      runtime: {id: 'test-extension', getURL: p => 'chrome-extension://test-extension/' + p,
        getManifest: () => ({version: '0.3.1'}), onMessage: {addListener: f => events.message = f}, sendMessage: async () => ({ok: true}), getContexts: async () => []},
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

module.exports = {worker};
