const status = document.querySelector('#status');
async function send(type, extra = {}) {
  const reply = await chrome.runtime.sendMessage({type, ...extra});
  if (reply?.error) throw new Error(reply.error);
  return reply;
}
async function run(task) {
  try { await task(); }
  catch (error) { status.textContent = error.message; }
}
async function refresh(type = 'status') {
  const s = await send(type);
  AisoraPairingUI.render(s);
  status.textContent = `${s.selected ? 'Selected: ' + (s.projectLabel || 'conversation') : 'Select the Project conversation'} · ${s.connected ? 'Tab connected' : 'Tab disconnected'} · Voice ${s.voice} · Output ${s.capturing ? 'capturing' : 'off'}${s.error ? '\n' + s.error : ''}`;
}
document.querySelector('#pairSetup').addEventListener('click', () => run(() => chrome.runtime.openOptionsPage()));
document.querySelector('#reconnect').addEventListener('click', () => run(async () => { AisoraPairingUI.connecting(); await refresh('reconnect'); }));
for (const [id, type, message] of [
  ['bind', 'bind', 'Tab selected. Wait a second, then refresh status.'],
  ['capture', 'capture', 'Output capture started. Start native Voice normally.'],
  ['stopCapture', 'stopCapture', 'Output capture stopped.'],
  ['startVoice', 'startVoice', 'Start requested. Confirm native Voice in ChatGPT.'],
  ['endVoice', 'endVoice', 'End requested. Confirm native Voice ended.'],
  ['releaseGuard', 'releaseGuard', 'Stale guard cleared. Use this only after ending Voice manually.'],
  ['toggle', 'toggle', 'Command sent. Confirm the Voice interface in ChatGPT.']
]) document.querySelector('#' + id).addEventListener('click', () => run(async () => {
  await send(type, type === 'bind' ? {projectLabel: document.querySelector('#project').value} : {}); status.textContent = message;
}));
document.querySelector('#refresh').addEventListener('click', () => run(refresh));
document.querySelector('#selectors').addEventListener('click', () => run(async () => {
  await send('selectors', {start: document.querySelector('#start').value.trim(), end: document.querySelector('#end').value.trim(), thinking: document.querySelector('#thinking').value.trim(), listening: document.querySelector('#listening').value.trim()});
  status.textContent = 'Selectors saved. Confirm they target only Voice controls.';
}));
chrome.storage.local.get(['startSelector', 'endSelector', 'thinkingSelector', 'listeningSelector']).then(data => {
  document.querySelector('#start').value = data.startSelector || '';
  document.querySelector('#end').value = data.endSelector || '';
  document.querySelector('#thinking').value = data.thinkingSelector || '';
  document.querySelector('#listening').value = data.listeningSelector || '';
});
void run(refresh);
