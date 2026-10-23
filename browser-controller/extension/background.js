/* This worker never sees ChatGPT authentication or conversation text. */
let bindingTask = null;
let captureRms = 0;
let captureAt = 0;
let captureTarget = null;
let captureTask = null;
let captureGeneration = 0;
let pairingTask = null;
let connection = {pairingStatus: 'unpaired', bridgeMessage: 'Import the running bridge\'s pairing file. Importing alone is not authentication.'};

function pairingError(code, message) {
  const error = new Error(message); error.pairingStatus = code; return error;
}
function validPairing(p) {
  return p && Number.isInteger(p.port) && p.port >= 1024 && p.port <= 65535 && typeof p.key === 'string' && /^[a-f0-9]{64}$/.test(p.key)
    && (p.protocol === undefined || p.protocol === 1) && (p.service === undefined || p.service === 'aisora');
}
function rememberConnection(error, extra = {}) {
  connection = error ? {pairingStatus: error.pairingStatus || 'bridge_unavailable', bridgeMessage: error.pairingStatus ? error.message : 'Bridge unavailable. Start one bridge, check its port and Chrome local-network access, then Reconnect.'}
    : {...connection, pairingStatus: 'connected', bridgeMessage: 'Bridge authenticated. Selected-conversation connection is separate.', ...extra};
}
async function requestBridge(p, path, data) {
  if (!validPairing(p)) throw pairingError(p ? 'invalid_config' : 'unpaired', p ? 'Saved/file configuration is invalid or incompatible. Import the current bridge.json; requests were not sent.' : 'No pairing saved. Open Pair / troubleshoot bridge.');
  let response;
  try {
    response = await fetch(`http://127.0.0.1:${p.port}${path}`, {
      method: data === undefined ? 'GET' : 'POST',
      headers: {'Content-Type': 'application/json', ...(path === '/health' ? {} : {'X-Aisora-Key': p.key})},
      body: data === undefined ? undefined : JSON.stringify(data),
      signal: AbortSignal.timeout(1500), cache: 'no-store', redirect: 'error'
    });
  } catch { throw pairingError('bridge_unavailable', 'Bridge unavailable. Start one bridge on this port, check Chrome local-network permission, then Reconnect.'); }
  if (!response.ok) {
    if (response.status === 401) throw pairingError('authentication_failed', 'Authentication failed (HTTP 401). This running bridge rejected the saved key. Use the exact file printed by its Terminal; check for another source copy on the port.');
    if (response.status === 403) throw pairingError('bridge_unavailable', 'Bridge refused the localhost request (HTTP 403). Check extension origin/permissions; do not disable security checks.');
    throw pairingError('bridge_unavailable', `Local bridge request failed (HTTP ${Number(response.status) || 'unknown'}). Check its version/process; manual Voice remains available.`);
  }
  let result;
  try { result = await response.json(); }
  catch { throw pairingError('incompatible', 'Incompatible response on the saved port. Start the matching Aisora bridge.'); }
  if (!result || typeof result !== 'object' || Array.isArray(result)) throw pairingError('incompatible', 'Incompatible bridge response.');
  return result;
}
async function authenticate(p) {
  const identity = await requestBridge(p, '/health');
  if (identity.service !== 'aisora' || identity.version !== 1) throw pairingError('incompatible', 'This port is not an Aisora protocol 1 bridge. Start the matching bridge; existing pairing kept.');
  const state = await requestBridge(p, '/v1/state');
  if (typeof state.connected !== 'boolean' || !['active', 'inactive', 'unknown'].includes(state.voice)) throw pairingError('incompatible', 'Incompatible bridge state; existing pairing kept.');
  const version = typeof identity.bridge_version === 'string' && /^\d+\.\d+\.\d+$/.test(identity.bridge_version) ? identity.bridge_version : 'legacy protocol 1';
  rememberConnection(null, {bridgeVersion: version, protocol: 1, endpoint: `127.0.0.1:${p.port}`});
  return state;
}
function pairingOperation(task) {
  const result = (pairingTask || Promise.resolve()).catch(() => {}).then(task);
  pairingTask = result;
  return result.finally(() => { if (pairingTask === result) pairingTask = null; });
}

async function config() {
  const data = await chrome.storage.local.get(['pairing', 'startSelector', 'endSelector', 'thinkingSelector', 'listeningSelector']);
  const session = await chrome.storage.session.get(['targetId', 'targetPath', 'voiceOwner', 'bindingId', 'projectLabel']);
  return {...data, targetId: session.targetId, targetPath: session.targetPath, voiceOwner: session.voiceOwner, bindingId: session.bindingId, projectLabel: session.projectLabel};
}
async function bridge(path, data) {
  const {pairing} = await config();
  try { const result = await requestBridge(pairing, path, data); rememberConnection(null); return result; }
  catch (error) { rememberConnection(error); throw error; }
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
    const response = await chrome.runtime.sendMessage({destination: 'offscreen', type: 'capture', streamId, tabId, bindingId: (await config()).bindingId});
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
  const trustedSetup = sender.url === chrome.runtime.getURL('pairing.html');
  const trustedOffscreen = sender.url === chrome.runtime.getURL('offscreen.html');
  const selected = sender.tab?.id === cfg.targetId && sender.url?.startsWith('https://chatgpt.com/') && message.path === cfg.targetPath;
  if (message.type === 'selected') return {selected, options: {startSelector: cfg.startSelector, endSelector: cfg.endSelector, thinkingSelector: cfg.thinkingSelector, listeningSelector: cfg.listeningSelector}};
  if (message.type === 'audio' && trustedOffscreen) {
    const tabId = message.tabId ?? captureTarget;
    if (!Number.isInteger(cfg.targetId) || tabId !== cfg.targetId || (cfg.bindingId && message.bindingId !== cfg.bindingId)) return {ok: false};
    // Re-adopt a valid running offscreen meter after service-worker suspension.
    captureTarget = tabId;
    captureRms = Number.isFinite(message.rms) ? Math.min(1, Math.max(0, message.rms)) : 0;
    captureAt = Date.now();
    const diagnostic = ['capture_denied', 'capture_ended', 'capture_failed'].includes(message.diagnostic) ? message.diagnostic : '';
    await bridge('/v1/audio', {capturing: message.capturing === true, rms: captureRms, ...(cfg.bindingId ? {binding_id: cfg.bindingId} : {}), ...(diagnostic ? {diagnostic} : {})});
    return {ok: true};
  }
  if (message.type === 'tick' && selected) {
    if (message.voice === 'active') await chrome.storage.session.set({voiceOwner: {tabId: cfg.targetId, path: cfg.targetPath}});
    else if (message.voice === 'inactive' && !message.busy && cfg.voiceOwner?.tabId === cfg.targetId && cfg.voiceOwner?.path === cfg.targetPath) await chrome.storage.session.remove('voiceOwner');
    const reply = await bridge('/v1/poll', {voice: message.voice, activity: message.activity, busy: message.busy, diagnostic: message.diagnostic, ...(cfg.bindingId ? {binding_id: cfg.bindingId, project_label: cfg.projectLabel || "Aisora"} : {})});
    if (reply.command && (reply.command.action === 'start' || reply.command.action === 'toggle'))
      await chrome.storage.session.set({voiceOwner: {tabId: cfg.targetId, path: cfg.targetPath}});
    return reply;
  }
  if (message.type === 'result' && selected) {
    if (message.ok && message.observedVoice === 'active') await chrome.storage.session.set({voiceOwner: {tabId: cfg.targetId, path: cfg.targetPath}});
    if (message.ok && message.observedVoice === 'inactive') await chrome.storage.session.remove('voiceOwner');
    return bridge('/v1/result', {id: message.id, ok: message.ok === true, ...(message.observedVoice ? {observed_voice: message.observedVoice} : {})});
  }
  if (!trustedPopup && !(trustedSetup && ['pair','status','reconnect','resetPairing'].includes(message.type))) throw new Error('Select this tab in the Aisora extension first.');
  if (message.type === 'pair') {
    return pairingOperation(async () => {
      const p = message.pairing;
      const current = await config();
      if (!validPairing(p)) throw pairingError('invalid_config', 'Invalid bridge pairing file or incompatible protocol. Saved pairing was not replaced.');
      if (current.voiceOwner && (current.pairing?.port !== p.port || current.pairing?.key !== p.key)) throw new Error('End Voice and clear its stale guard before switching bridges.');
      connection = {pairingStatus: 'connecting', bridgeMessage: 'Authenticating imported file; it has not been saved yet.'};
      try {
        await authenticate(p);
        await chrome.storage.local.set({pairing: {port: p.port, key: p.key}});
        return {ok: true, ...connection};
      } catch (error) {
        rememberConnection(error);
        throw pairingError(error.pairingStatus || 'bridge_unavailable', 'Pairing rejected. ' + connection.bridgeMessage + ' Existing saved pairing kept.');
      }
    });
  }
  if (message.type === 'resetPairing') {
    return pairingOperation(async () => {
      const current = await config();
      if (message.confirmedNoVoice !== true || current.voiceOwner) throw new Error('End Voice first. If it ended manually, clear the stale Voice guard in the popup, then confirm Reset.');
      let observed;
      try { observed = await authenticate(current.pairing); } catch { /* Unobservable state requires the explicit confirmation above. */ }
      if (observed?.voice === 'active' || observed?.pending) throw new Error('Voice or a command is active; pairing was not reset.');
      await stopCapture();
      await chrome.storage.local.remove('pairing');
      await chrome.storage.session.remove(['targetId', 'targetPath', 'bindingId', 'projectLabel']);
      connection = {pairingStatus: 'unpaired', bridgeMessage: 'Pairing reset. Bridge files, browser sign-in and other preferences were not changed.'};
      return {ok: true, ...connection};
    });
  }
  if (message.type === 'bind') {
    if (bindingTask) return bindingTask;
    bindingTask = bindConversation(message).finally(() => { bindingTask = null; });
    return bindingTask;
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
  if (message.type === 'status' || message.type === 'reconnect') {
    let state = {connected: false, voice: 'unknown', capturing: false};
    // Status is always renderable, even before pairing or during failure. A
    // saved configuration is not reported as authenticated without a probe.
    try { state = await authenticate(cfg.pairing); } catch (error) { rememberConnection(error); }
    const warning = state.error ? (String(state.error).includes('Microphone permission') ? 'Microphone permission is blocked; check ChatGPT/browser permissions.' : 'Conversation or audio capture reports a warning; check the selected tab and use manual Voice if needed.') : '';
    return {connected: state.connected === true, voice: state.voice, capturing: state.capturing === true,
      pending: state.pending === true, error: warning, ...connection, extensionVersion: chrome.runtime.getManifest?.().version || '0.3.1',
      guarded: !!cfg.voiceOwner, captureFresh: Date.now() - captureAt < 500,
      selected: Number.isInteger(cfg.targetId), projectLabel: cfg.projectLabel || '', selectionRequired: !Number.isInteger(cfg.targetId)};
  }
  if (message.type === 'selectors') {
    await chrome.storage.local.set({startSelector: String(message.start || '').slice(0, 256), endSelector: String(message.end || '').slice(0, 256), thinkingSelector: String(message.thinking || '').slice(0,256), listeningSelector: String(message.listening || '').slice(0,256)});
    return {ok: true};
  }
  throw new Error('Unsupported operation');
}
async function bindConversation(message) {
  const cfg = await config();
  const [tab] = await chrome.tabs.query({active: true, currentWindow: true});
  const url = new URL(tab?.url || 'about:blank');
  if (url.origin !== 'https://chatgpt.com' || !/^\/(?:g\/[^/]+\/)?c\/[^/]+\/?$/.test(url.pathname))
    throw new Error('Open an existing conversation inside your Aisora Project first. Project/home pages cannot be paired.');
  const label = String(message.projectLabel || 'Aisora').trim();
  if (!label || label.length > 64 || /[\x00-\x1f\x7f]/.test(label)) throw new Error('Use a short Project label without control characters.');
  const changed = cfg.targetId !== tab.id || cfg.targetPath !== url.pathname;
  if (cfg.voiceOwner && (cfg.voiceOwner.tabId !== tab.id || cfg.voiceOwner.path !== url.pathname))
    throw new Error('End Voice in the previously selected tab before changing conversations. If it ended manually, clear the stale Voice guard.');
  if (changed && Number.isInteger(cfg.targetId)) {
    const state = await bridge('/v1/state');
    if (state.pending || state.voice === 'active') throw new Error('End Voice and wait for pending commands before changing conversations.');
  }
  if (changed) await stopCapture();
  await chrome.storage.session.set({targetId: tab.id, targetPath: url.pathname, projectLabel: label,
    bindingId: changed || !cfg.bindingId ? crypto.randomUUID() : cfg.bindingId});
  await chrome.scripting.executeScript({target: {tabId: tab.id}, files: ['voice_dom.js', 'content.js']});
  return {ok: true, projectLabel: label};
}
async function sendVoiceCommand(action, cfg) {
  if (!Number.isInteger(cfg.targetId)) throw new Error('Select your existing ChatGPT tab first.');
  if (cfg.voiceOwner && (cfg.voiceOwner.tabId !== cfg.targetId || cfg.voiceOwner.path !== cfg.targetPath)) throw new Error('A previous Voice session may be active. End it manually before starting another.');
  if (action !== 'end') await chrome.storage.session.set({voiceOwner: {tabId: cfg.targetId, path: cfg.targetPath}});
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
    await chrome.storage.session.remove(['targetId', 'targetPath', 'bindingId', 'projectLabel']);
  }
});
chrome.tabs.onUpdated.addListener(async (tabId, change) => {
  if (!change.url) return;
  const {targetId, targetPath} = await config();
  const url = new URL(change.url);
  if (tabId === targetId && (url.origin !== 'https://chatgpt.com' || url.pathname !== targetPath)) {
    await stopCapture();
    await chrome.storage.session.remove(['targetId', 'targetPath', 'bindingId', 'projectLabel']);
  }
});
