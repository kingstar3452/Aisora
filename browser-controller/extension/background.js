/* This worker never sees ChatGPT authentication or conversation text. */
let captureRms = 0;
let captureAt = 0;
let captureTarget = null;
let captureTask = null;
let captureGeneration = 0;

async function config() {
  const data = await chrome.storage.local.get(['pairing', 'startSelector', 'endSelector', 'thinkingSelector']);
  const session = await chrome.storage.session.get(['targetId', 'targetPath', 'voiceOwner']);
  return {...data, targetId: session.targetId, targetPath: session.targetPath, voiceOwner: session.voiceOwner};
}
async function bridge(path, data) {
  const {pairing} = await config();
  if (!pairing) throw new Error('Choose the bridge pairing file first.');
  const response = await fetch(`http://127.0.0.1:${pairing.port}${path}`, {
    method: data === undefined ? 'GET' : 'POST',
    headers: {'Content-Type': 'application/json', 'X-Aisora-Key': pairing.key},
    body: data === undefined ? undefined : JSON.stringify(data),
    signal: AbortSignal.timeout(1500), cache: 'no-store'
  });
  const result = await response.json();
  if (!response.ok) throw new Error(result.error || 'Local bridge unavailable.');
  return result;
}
async function stopCapture() {
  captureGeneration++;
  if (await chrome.offscreen.hasDocument()) await chrome.runtime.sendMessage({destination: 'offscreen', type: 'stop'});
  captureRms = 0; captureAt = 0; captureTarget = null;
  await bridge('/v1/audio', {capturing: false, rms: 0}).catch(() => {});
  if (await chrome.offscreen.hasDocument()) await chrome.offscreen.closeDocument();
}
function capture(tabId) {
  if (captureTask) return captureTask;
  captureTask = startCapture(tabId).finally(() => { captureTask = null; });
  return captureTask;
}
async function startCapture(tabId) {
  if (captureTarget === tabId && Date.now()-captureAt < 500 && await chrome.offscreen.hasDocument()) return;

  await stopCapture();
  const generation = captureGeneration;
  const contexts = await chrome.runtime.getContexts({contextTypes: ['OFFSCREEN_DOCUMENT']});
  if (!contexts.length) await chrome.offscreen.createDocument({url: 'offscreen.html', reasons: ['USER_MEDIA'],
    justification: 'Analyze selected ChatGPT tab output amplitude locally for mouth animation; never microphone input.'});
  try {
    const streamId = await chrome.tabCapture.getMediaStreamId({targetTabId: tabId});
    captureTarget = tabId;
    const response = await chrome.runtime.sendMessage({destination: 'offscreen', type: 'capture', streamId, tabId});
    if (!response?.ok) { const e = new Error('Audio capture failed. Return to the selected tab and approve output capture.'); e.code = response?.diagnostic || 'capture_failed'; throw e; }
    if (generation !== captureGeneration) throw new Error('Capture was stopped.');
  } catch (error) {
    await stopCapture();
    await bridge('/v1/audio', {capturing: false, rms: 0, diagnostic: error.code === 'capture_denied' ? 'capture_denied' : 'capture_failed'}).catch(() => {});
    throw error;
  }
}
async function handle(message, sender) {
  if (message.destination === 'offscreen') return undefined;
  if (sender.id !== chrome.runtime.id) throw new Error('Invalid sender');
  const cfg = await config();
  const trustedPopup = sender.url === chrome.runtime.getURL('popup.html');
  const trustedOffscreen = sender.url === chrome.runtime.getURL('offscreen.html');
  const selected = sender.tab?.id === cfg.targetId && sender.url?.startsWith('https://chatgpt.com/') && message.path === cfg.targetPath;
  if (message.type === 'selected') return {selected, options: {startSelector: cfg.startSelector, endSelector: cfg.endSelector, thinkingSelector: cfg.thinkingSelector}};
  if (message.type === 'audio' && trustedOffscreen) {
    const tabId = message.tabId ?? captureTarget;
    if (!Number.isInteger(cfg.targetId) || tabId !== cfg.targetId) return {ok: false};
    // Re-adopt a valid running offscreen meter after service-worker suspension.
    captureTarget = tabId;
    captureRms = Number.isFinite(message.rms) ? Math.min(1, Math.max(0, message.rms)) : 0;
    captureAt = Date.now();
    const diagnostic = ['capture_denied', 'capture_ended', 'capture_failed'].includes(message.diagnostic) ? message.diagnostic : '';
    await bridge('/v1/audio', {capturing: message.capturing === true, rms: captureRms, ...(diagnostic ? {diagnostic} : {})});
    return {ok: true};
  }
  if (message.type === 'tick' && selected) {
    if (message.voice === 'active') await chrome.storage.session.set({voiceOwner: {tabId: cfg.targetId, path: cfg.targetPath}});
    else if (message.voice === 'inactive' && cfg.voiceOwner?.tabId === cfg.targetId && cfg.voiceOwner?.path === cfg.targetPath) await chrome.storage.session.remove('voiceOwner');
    return bridge('/v1/poll', {voice: message.voice, activity: message.activity, busy: message.busy, diagnostic: message.diagnostic});
  }
  if (message.type === 'result' && selected) return bridge('/v1/result', {id: message.id, ok: message.ok === true});
  if (!trustedPopup) throw new Error('Select this tab in the Aisora extension first.');
  if (message.type === 'pair') {
    const p = message.pairing;
    if (!p || !Number.isInteger(p.port) || p.port < 1024 || p.port > 65535 || !/^[a-f0-9]{64}$/.test(p.key))
      throw new Error('Invalid bridge pairing file');
    const base = `http://127.0.0.1:${p.port}`;
    const request = path => fetch(base+path, {headers: {'X-Aisora-Key': p.key}, signal: AbortSignal.timeout(1500), cache: 'no-store'});
    const health = await request('/health');
    const identity = await health.json();
    if (!health.ok || identity.service !== 'aisora' || identity.version !== 1) throw new Error('This is not the Aisora bridge. Existing pairing kept.');
    const response = await request('/v1/state');
    const state = await response.json();
    if (!response.ok || typeof state.connected !== 'boolean' || !['active','inactive','unknown'].includes(state.voice))
      throw new Error('Pairing rejected. Choose the current bridge.json; existing pairing kept.');
    await chrome.storage.local.set({pairing: {port: p.port, key: p.key}});
    return {ok: true};
  }
  if (message.type === 'bind') {
    const [tab] = await chrome.tabs.query({active: true, currentWindow: true});
    if (!tab?.url?.startsWith('https://chatgpt.com/')) throw new Error('Open your existing Aisora Project conversation in this tab first.');
    const path = new URL(tab.url).pathname;
    if (cfg.voiceOwner && (cfg.voiceOwner.tabId !== tab.id || cfg.voiceOwner.path !== path))
      throw new Error('End Voice in the previously selected tab before changing conversations. If it ended manually, clear the stale Voice guard.');
    if (cfg.targetId !== tab.id || cfg.targetPath !== path) await stopCapture();
    await chrome.storage.session.set({targetId: tab.id, targetPath: new URL(tab.url).pathname});
    await chrome.scripting.executeScript({target: {tabId: tab.id}, files: ['voice_dom.js', 'content.js']});
    return {ok: true};
  }
  if (message.type === 'capture') {
    const [tab] = await chrome.tabs.query({active: true, currentWindow: true});
    if (tab?.id !== cfg.targetId) throw new Error('Return to the selected ChatGPT tab before starting output capture.');
    await capture(cfg.targetId);
    return {ok: true};
  }
  if (message.type === 'stopCapture') { await stopCapture(); return {ok: true}; }
  if (message.type === 'releaseGuard') { await chrome.storage.session.remove('voiceOwner'); return {ok: true}; }
  if (['toggle','startVoice','endVoice'].includes(message.type)) {
    return sendVoiceCommand({toggle:'toggle',startVoice:'start',endVoice:'end'}[message.type],cfg);
  }
  if (message.type === 'status') {
    const state = await bridge('/v1/state');
    return {...state, guarded: !!cfg.voiceOwner, captureFresh: Date.now() - captureAt < 500};
  }
  if (message.type === 'selectors') {
    await chrome.storage.local.set({startSelector: String(message.start || '').slice(0, 256), endSelector: String(message.end || '').slice(0, 256), thinkingSelector: String(message.thinking || '').slice(0,256)});
    return {ok: true};
  }
  throw new Error('Unsupported operation');
}
async function sendVoiceCommand(action, cfg) {
  if (!Number.isInteger(cfg.targetId)) throw new Error('Select your existing ChatGPT tab first.');
  if (cfg.voiceOwner && (cfg.voiceOwner.tabId !== cfg.targetId || cfg.voiceOwner.path !== cfg.targetPath)) throw new Error('A previous Voice session may be active. End it manually before starting another.');
  return bridge('/v1/command', {action});
}
chrome.runtime.onMessage.addListener((message, sender, respond) => {
  if (message.destination === 'offscreen') return false;
  handle(message, sender).then(respond).catch(error => respond({error: error.message}));
  return true;
});
chrome.commands.onCommand.addListener(command => {
  if (command === 'toggle-voice') config().then(cfg => sendVoiceCommand('toggle',cfg)).catch(() => {});
});
chrome.tabs.onRemoved.addListener(async tabId => {
  const {targetId} = await config();
  const {voiceOwner} = await config();
  if (voiceOwner?.tabId === tabId) await chrome.storage.session.remove("voiceOwner");
  if (tabId === targetId) {
    await stopCapture();
    await chrome.storage.session.remove(['targetId', 'targetPath']);
  }
});
chrome.tabs.onUpdated.addListener(async (tabId, change) => {
  if (!change.url) return;
  const {targetId, targetPath} = await config();
  const url = new URL(change.url);
  if (tabId === targetId && (url.origin !== 'https://chatgpt.com' || url.pathname !== targetPath)) {
    await stopCapture();
    await chrome.storage.session.remove(['targetId', 'targetPath']);
  }
});
