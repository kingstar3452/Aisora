/* Exact accessible labels only. Unknown/localized/changed UI fails to manual control. */
(() => {
  const labels = {
    start: new Set(['start voice', 'start voice mode', 'use voice', 'voice mode', 'start a voice conversation']),
    end: new Set(['end voice', 'end voice mode', 'end conversation', 'stop voice', 'exit voice mode'])
  };
  const ids = {
    start: new Set(['voice-mode-button', 'start-voice-button']),
    end: new Set(['end-voice-button', 'end-voice-mode-button'])
  };
  const normalize = value => String(value || '').toLowerCase().replace(/\s+/g, ' ').trim();
  function inspect(buttons, markers = {}) {
    if (markers.permission === true) return {voice: 'unknown', activity: 'unknown', diagnostic: 'permission', start: null, end: null};
    const start = buttons.filter(b => b.visible && (['start', 'both'].includes(b.custom) || labels.start.has(normalize(b.label)) || ids.start.has(b.testId)));
    const end = buttons.filter(b => b.visible && (['end', 'both'].includes(b.custom) || labels.end.has(normalize(b.label)) || ids.end.has(b.testId)));
    if (start.length > 1 || end.length > 1 || (start.length && end.length))
      return {voice: 'unknown', diagnostic: 'ambiguous', start: null, end: null};
    if (end.length === 1) return {voice: 'active', activity: markers.thinking === true ? 'thinking' : 'unknown', diagnostic: '', start: null, end: end[0]};
    if (start.length === 1) return {voice: 'inactive', diagnostic: '', start: start[0], end: null};
    return {voice: 'unknown', diagnostic: 'missing', start: null, end: null};
  }
  function plan(action, status) {
    if (!['toggle', 'start', 'end'].includes(action)) throw new Error('Unsupported command');
    if (status.voice === 'unknown') throw new Error('Voice controls unavailable or ambiguous');
    const desired = action === 'toggle' ? (status.voice === 'active' ? 'inactive' : 'active') : (action === 'start' ? 'active' : 'inactive');
    if (status.voice === desired) return {desired, button: null};
    const button = desired === 'active' ? status.start : status.end;
    if (!button || !button.enabled) throw new Error('Voice control is disabled');
    return {desired, button};
  }
  const api = {normalize, inspect, plan};
  if (typeof module !== 'undefined') module.exports = api;
  else globalThis.AisoraVoiceDOM = api;
})();
