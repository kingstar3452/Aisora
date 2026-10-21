/* Isolated extension world: no cookies, network interception, React internals, or transcripts. */
(() => {
  const version = '0.3.0';
  if (globalThis.__aisoraInstalled === version) return;
  globalThis.__aisoraStop?.();
  globalThis.__aisoraInstalled = version;
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
  function markers() {
    const visible = selector => {
      try { return [...document.querySelectorAll(selector)].some(node => {
        const s = getComputedStyle(node);
        return node.getClientRects().length && s.display !== 'none' && s.visibility !== 'hidden' && s.opacity !== '0';
      }); } catch { return false; }
    };
    return {
      permission: visible('[data-testid="voice-microphone-error"], [aria-label="Microphone permission denied"], [aria-label="Microphone access blocked"]'),
      thinking: visible(options.thinkingSelector || '[data-testid="voice-thinking-indicator"]'),
      listening: visible(options.listeningSelector || '[data-testid="voice-listening-indicator"], [data-testid="voice-user-speaking-indicator"]')
    };
  }
  const inspect = () => AisoraVoiceDOM.inspect(collect(), markers());
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
      await chrome.runtime.sendMessage({type: 'result', path: location.pathname, id: command.id, ok, observedVoice: ok ? inspect().voice : 'unknown'}).catch(() => {});
      busy = false;
    }
  }

  async function tick() {
    if (globalThis.__aisoraInstalled !== version) return;
    if (polling) return;
    polling = true;
    try {
      const selected = await chrome.runtime.sendMessage({type: 'selected', path: location.pathname});
      if (!selected?.selected) return;
      options = selected.options || {};
      const status = inspect();
      const reply = await chrome.runtime.sendMessage({type: 'tick', path: location.pathname, voice: status.voice, activity: status.activity, busy, diagnostic: status.diagnostic});
      if (reply?.command && !busy) void execute(reply.command);
    } catch { /* Bridge/browser restarts recover on the next heartbeat. */ }
    finally { polling = false; }
  }
  const timer = setInterval(tick, 1000);
  globalThis.__aisoraStop = () => clearInterval(timer);
  void tick();
})();
