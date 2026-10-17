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
async function refresh() {
  const s = await send('status');
  status.textContent = `${s.connected ? 'Tab connected' : 'Tab disconnected'} · Voice ${s.voice} · Output ${s.capturing ? 'capturing' : 'off'}${s.error ? '\n' + s.error : ''}`;
}
document.querySelector('#pair').addEventListener('change', event => run(async () => {
  const file = event.target.files[0];
  if (!file || file.size > 2048) throw new Error('Choose the small .local/bridge.json pairing file.');
  await send('pair', {pairing: JSON.parse(await file.text())});
  status.textContent = 'Bridge paired. Now select this existing ChatGPT tab.';
}));
for (const [id, type, message] of [
  ['bind', 'bind', 'Tab selected. Wait a second, then refresh status.'],
  ['capture', 'capture', 'Output capture started. Start native Voice normally.'],
  ['stopCapture', 'stopCapture', 'Output capture stopped.'],
  ['toggle', 'toggle', 'Command sent. Confirm the Voice interface in ChatGPT.']
]) document.querySelector('#' + id).addEventListener('click', () => run(async () => {
  await send(type); status.textContent = message;
}));
document.querySelector('#refresh').addEventListener('click', () => run(refresh));
document.querySelector('#selectors').addEventListener('click', () => run(async () => {
  await send('selectors', {start: document.querySelector('#start').value.trim(), end: document.querySelector('#end').value.trim()});
  status.textContent = 'Selectors saved. Confirm they target only Voice controls.';
}));
chrome.storage.local.get(['startSelector', 'endSelector']).then(data => {
  document.querySelector('#start').value = data.startSelector || '';
  document.querySelector('#end').value = data.endSelector || '';
});
void run(refresh);
