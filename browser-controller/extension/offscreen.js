/* Only tab OUTPUT. Raw samples remain in this document and are never stored/sent. */
let stream, context, timer;
let selectedTabId;
async function stop() {
  clearInterval(timer);
  stream?.getTracks().forEach(track => track.stop());
  stream = null;
  if (context) await context.close();
  context = null;
}
async function capture(streamId, tabId, bindingId) {
  selectedTabId = tabId;
  await stop();
  stream = await navigator.mediaDevices.getUserMedia({audio: {mandatory: {
    chromeMediaSource: 'tab', chromeMediaSourceId: streamId
  }}, video: false});
  context = new AudioContext();
  let resumeTimer;
  try {
    await Promise.race([context.resume(), new Promise((_, reject) => {
      resumeTimer = setTimeout(() => reject(new Error('Audio permission required')), 3000);
    })]);
  } finally { clearTimeout(resumeTimer); }
  if (context.state !== 'running') throw new Error('Audio context did not start');
  const source = context.createMediaStreamSource(stream);
  const analyser = context.createAnalyser();
  analyser.fftSize = 2048;
  source.connect(analyser);
  // Tab capture otherwise suppresses the original playback. Keep it audible once.
  source.connect(context.destination);
  const samples = new Float32Array(analyser.fftSize);
  let sending = false;
  timer = setInterval(async () => {
    if (sending) return;
    sending = true;
    try {
      analyser.getFloatTimeDomainData(samples);
      let sum = 0;
      for (const sample of samples) sum += sample * sample;
      await chrome.runtime.sendMessage({type: 'audio', tabId: selectedTabId, ...(bindingId ? {bindingId} : {}), rms: Math.sqrt(sum / samples.length), capturing: stream?.active === true});
    } catch { /* Godot/bridge can restart; the freshness timeout closes the mouth. */ }
    finally { sending = false; }
  }, 100);
  stream.getAudioTracks()[0].addEventListener('ended', async () => {
    await chrome.runtime.sendMessage({type: 'audio', tabId: selectedTabId, ...(bindingId ? {bindingId} : {}), rms: 0, capturing: false, diagnostic: 'capture_ended'}).catch(() => {});
    await stop();
  });
}
chrome.runtime.onMessage.addListener((message, _sender, respond) => {
  if (message.destination !== 'offscreen') return false;
  const operation = message.type === 'capture' ? capture(message.streamId, message.tabId, message.bindingId) : stop();
  operation.then(() => respond({ok: true})).catch(async error => { await stop(); respond({ok: false, diagnostic: error?.name === 'NotAllowedError' ? 'capture_denied' : 'capture_failed'}); });
  return true;
});
