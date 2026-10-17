/* This worker never sees ChatGPT authentication or conversation text. */
let captureRms = 0;
let captureAt = 0;
let captureTarget = null;

async function config() {
  const data = await chrome.storage.local.get(['pairing', 'startSelector', 'endSelector']);
  const session = await chrome.storage.session.get(['targetId', 'targetPath']);
  return {...data, targetId: session.targetId, targetPath: session.targetPath};
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
  if (await chrome.offscreen.hasDocument()) await chrome.runtime.sendMessage({destination: 'offscreen', type: 'stop'});
  captureRms = 0; captureAt = 0; captureTarget = null;
  await bridge('/v1/audio', {capturing: false, rms: 0}).catch(() => {});
  if (await chrome.offscreen.hasDocument()) await chrome.offscreen.closeDocument();
}
async function capture(tabId) {
  await stopCapture();
  const contexts = await chrome.runtime.getContexts({contextTypes: ['OFFSCREEN_DOCUMENT']});
  if (!contexts.length) await chrome.offscreen.createDocument({url: 'offscreen.html', reasons: ['USER_MEDIA'],
    justification: 'Analyze selected ChatGPT tab output amplitude locally for mouth animation; never microphone input.'});
  try {
    const streamId = await chrome.tabCapture.getMediaStreamId({targetTabId: tabId});
    captureTarget = tabId;
    const response = await chrome.runtime.sendMessage({destination: 'offscreen', type: 'capture', streamId});
    if (!response?.ok) throw new Error('Audio capture failed. Re-select ChatGPT and approve capture.');
  } catch (error) { await stopCapture(); throw error; }
}
async function handle(message, sender) {
  if (message.destination === 'offscreen') return undefined;
  if (sender.id !== chrome.runtime.id) throw new Error('Invalid sender');
  const cfg = await config();
  const trustedPopup = sender.url === chrome.runtime.getURL('popup.html');
  const trustedOffscreen = sender.url === chrome.runtime.getURL('offscreen.html');
  const selected = sender.tab?.id === cfg.targetId && sender.url?.startsWith('https://chatgpt.com/') && message.path === cfg.targetPath;
  if (message.type === 'selected') return {selected, options: {startSelector: cfg.startSelector, endSelector: cfg.endSelector}};
  if (message.type === 'audio' && trustedOffscreen) {
    captureRms = Number.isFinite(message.rms) ? Math.min(1, Math.max(0, message.rms)) : 0;
    captureAt = Date.now();
    const current = await config();
    if (captureTarget !== current.targetId) return {ok: false};
    await bridge('/v1/audio', {capturing: message.capturing === true, rms: captureRms});
    return {ok: true};
  }
  if (message.type === 'tick' && selected) return bridge('/v1/poll', {voice: message.voice, diagnostic: message.diagnostic});
  if (message.type === 'result' && selected) return bridge('/v1/result', {id: message.id, ok: message.ok === true});
  if (!trustedPopup) throw new Error('Select this tab in the Aisora extension first.');
  if (message.type === 'pair') {
    const p = message.pairing;
    if (!p || !Number.isInteger(p.port) || p.port < 1024 || p.port > 65535 || !/^[a-f0-9]{64}$/.test(p.key))
      throw new Error('Invalid bridge pairing file');
    await chrome.storage.local.set({pairing: {port: p.port, key: p.key}});
    return bridge('/health');
  }
  if (message.type === 'bind') {
    const [tab] = await chrome.tabs.query({active: true, currentWindow: true});
    if (!tab?.url?.startsWith('https://chatgpt.com/')) throw new Error('Open your existing Aisora Project conversation in this tab first.');
    await stopCapture();
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
  if (message.type === 'toggle') return bridge('/v1/command', {action: 'toggle'});
  if (message.type === 'status') {
    const state = await bridge('/v1/state');
    return {...state, captureFresh: Date.now() - captureAt < 500};
  }
  if (message.type === 'selectors') {
    await chrome.storage.local.set({startSelector: String(message.start || '').slice(0, 256), endSelector: String(message.end || '').slice(0, 256)});
    return {ok: true};
  }
  throw new Error('Unsupported operation');
}
chrome.runtime.onMessage.addListener((message, sender, respond) => {
  if (message.destination === 'offscreen') return false;
  handle(message, sender).then(respond).catch(error => respond({error: error.message}));
  return true;
});
chrome.commands.onCommand.addListener(command => {
  if (command === 'toggle-voice') bridge('/v1/command', {action: 'toggle'}).catch(() => {});
});
chrome.tabs.onRemoved.addListener(async tabId => {
  const {targetId} = await config();
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
