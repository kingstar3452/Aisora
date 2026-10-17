/* Isolated extension world: no cookies, network interception, React internals, or transcripts. */
(() => {
  if (globalThis.__aisoraInstalled) return;
  globalThis.__aisoraInstalled = true;
  let busy = false;
  let options = {};
  let polling = false;

  function collect() {
    const buttons = [...document.querySelectorAll('button, [role="button"]')];
    for (const selector of [options.startSelector, options.endSelector]) {
      if (!selector) continue;
      try { for (const node of document.querySelectorAll(selector)) if (!buttons.includes(node)) buttons.push(node); }
      catch { /* Invalid overrides yield no match, never execute code. */ }
    }
    return buttons.map(node => {
      const style = getComputedStyle(node);
      const visible = node.getClientRects().length > 0 && style.display !== 'none' && style.visibility !== 'hidden' && style.opacity !== '0';
      let custom;
      try {
        if (options.startSelector && node.matches(options.startSelector)) custom = 'start';
        if (options.endSelector && node.matches(options.endSelector)) custom = custom === 'start' ? 'both' : 'end';
      } catch { /* Invalid CSS override. */ }
      return {node, visible, enabled: !node.disabled && node.getAttribute('aria-disabled') !== 'true',
        label: node.getAttribute('aria-label') || node.getAttribute('title') || node.innerText,
        testId: node.getAttribute('data-testid'), custom};
    });
  }
  const inspect = () => AisoraVoiceDOM.inspect(collect());
  const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

  async function execute(command) {
    busy = true;
    let ok = false;
    try {
      const plan = AisoraVoiceDOM.plan(command.action, inspect());
      if (plan.button) plan.button.node.click();
      const deadline = Date.now() + 9500;
      do {
        if (inspect().voice === plan.desired) { ok = true; break; }
        await delay(250);
      } while (Date.now() < deadline);
    } catch { /* Browser permissions/UI changes require the user, never bypass them. */ }
    finally {
      await chrome.runtime.sendMessage({type: 'result', path: location.pathname, id: command.id, ok}).catch(() => {});
      busy = false;
    }
  }

  async function tick() {
    if (polling) return;
    polling = true;
    try {
      const selected = await chrome.runtime.sendMessage({type: 'selected', path: location.pathname});
      if (!selected?.selected) return;
      options = selected.options || {};
      const status = inspect();
      const reply = await chrome.runtime.sendMessage({type: 'tick', path: location.pathname, voice: status.voice, diagnostic: status.diagnostic});
      if (reply?.command && !busy) void execute(reply.command);
    } catch { /* Bridge/browser restarts recover on the next heartbeat. */ }
    finally { polling = false; }
  }
  setInterval(tick, 1000);
  void tick();
})();
