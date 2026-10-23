/* Fixed diagnostics only; never render pairing objects, keys or raw HTTP bodies. */
globalThis.AisoraPairingUI = {
  connecting() { document.querySelector('#connection').textContent = 'Connecting · Authenticating localhost…'; },
  render(s) {
    const labels = {unpaired: 'Unpaired', connecting: 'Connecting', connected: 'Connected',
      authentication_failed: 'Authentication failed', bridge_unavailable: 'Bridge unavailable',
      incompatible: 'Incompatible bridge', invalid_config: 'Invalid pairing configuration'};
    document.querySelector('#connection').textContent = `${labels[s.pairingStatus] || 'Bridge unavailable'} · ${s.bridgeMessage || 'Reconnect to check the local bridge.'}`;
    document.querySelector('#versions').textContent = `Extension ${s.extensionVersion || chrome.runtime.getManifest().version} · Bridge ${s.bridgeVersion || 'not authenticated'}${s.protocol ? ' · Protocol ' + s.protocol : ''}${s.endpoint ? ' · ' + s.endpoint : ''}`;
  },
  async send(type, extra = {}) {
    let reply;
    try { reply = await chrome.runtime.sendMessage({type, ...extra}); }
    catch { throw new Error('Extension worker unavailable. Reload this extension/page, then Reconnect.'); }
    if (reply?.error) throw new Error(reply.error);
    if (!reply) throw new Error('Extension worker did not respond. Reload the extension/page.');
    return reply;
  }
};
