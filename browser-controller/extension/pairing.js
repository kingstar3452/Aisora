const ui = AisoraPairingUI;
const message = document.querySelector('#status');
let working = false;
async function refresh() { ui.render(await ui.send('status')); }
async function operation(task) {
  if (working) return;
  working = true;
  for (const id of ['pair', 'reset', 'reconnect']) document.querySelector('#' + id).disabled = true;
  try { await task(); }
  catch (error) { message.textContent = error.message; }
  finally {
    document.querySelector('#pair').value = ''; // Same file must be selectable again after failure/restart.
    for (const id of ['pair', 'reset', 'reconnect']) document.querySelector('#' + id).disabled = false;
    working = false;
  }
}
document.querySelector('#pair').addEventListener('change', event => {
  const file = event.target.files[0];
  void operation(async () => {
    if (!file || file.size > 2048) throw new Error('Choose the small bridge.json created by the running bridge.');
    let pairing;
    try { pairing = JSON.parse(await file.text()); }
    catch { throw new Error('The selected file is unreadable or invalid JSON. Choose bridge.json; its contents are not displayed.'); }
    ui.connecting(); message.textContent = 'File read; checking service identity and pairing-key authentication before saving…';
    try {
      ui.render(await ui.send('pair', {pairing}));
      message.textContent = 'Authentication succeeded and pairing saved. Return to the ChatGPT conversation and select that tab in the popup.';
    } catch (error) { await refresh(); throw error; }
  });
});
document.querySelector('#reconnect').addEventListener('click', () => void operation(async () => {
  ui.connecting(); ui.render(await ui.send('reconnect'));
  message.textContent = 'Saved pairing checked. Read the bridge status above; no Voice session was started.';
}));
document.querySelector('#reset').addEventListener('click', () => void operation(async () => {
  if (!confirm('End native Voice in ChatGPT first. Reset the extension pairing/selection and stop its output meter? Bridge files and browser sign-in stay unchanged.')) return;
  ui.render(await ui.send('resetPairing', {confirmedNoVoice: true}));
  message.textContent = 'Extension pairing reset. Import the running bridge configuration to authenticate again.';
}));
void operation(refresh);
let refreshing = false;
const timer = setInterval(async () => {
  if (working || refreshing || document.visibilityState !== 'visible') return;
  refreshing = true;
  try { await refresh(); } catch (error) { message.textContent = error.message; }
  finally { refreshing = false; }
}, 3000);
addEventListener('pagehide', () => clearInterval(timer));
