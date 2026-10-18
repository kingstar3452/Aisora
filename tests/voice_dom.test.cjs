const {test} = require('node:test');
const assert = require('node:assert/strict');
const {inspect, plan} = require('../browser-controller/extension/voice_dom.js');
const button = (label, extra = {}) => ({label, visible: true, enabled: true, ...extra});

test('start/end commands preserve intent and toggle correctly', () => {
  const start = button('Start voice mode');
  const end = button('End voice');
  const inactive = inspect([start]);
  const active = inspect([end]);
  assert.equal(inactive.voice, 'inactive');
  assert.equal(active.voice, 'active');
  assert.equal(plan('toggle', inactive).button, start);
  assert.equal(plan('toggle', active).button, end);
  assert.equal(plan('start', active).button, null);
  assert.equal(plan('end', inactive).button, null);
});
test('dictation, transcript, unrelated and hidden controls never activate Voice', () => {
  const s = inspect([button('Dictate'), button('End'), button('Send message'), button('Start voice', {visible: false})]);
  assert.equal(s.voice, 'unknown');
  assert.throws(() => plan('toggle', s));
});
test('ambiguous controls refuse a click', () => {
  assert.equal(inspect([button('', {custom: 'both'})]).voice, 'unknown');
  for (const buttons of [[button('Use voice'), button('Start voice')], [button('Use voice'), button('End voice')]]) {
    const s = inspect(buttons);
    assert.equal(s.diagnostic, 'ambiguous');
    assert.throws(() => plan('toggle', s));
  }
});
test('disabled controls refuse a click', () => {
  assert.throws(() => plan('start', inspect([button('Use voice', {enabled: false})])));
});
test('explicit localized CSS bindings and stable test ids', () => {
  assert.equal(inspect([button('音声', {custom: 'start'})]).voice, 'inactive');
  assert.equal(inspect([button('', {testId: 'end-voice-button'})]).voice, 'active');
});
test('case/space normalization, never substring matching', () => {
  assert.equal(inspect([button('  START  VOICE  ')]).voice, 'inactive');
  assert.equal(inspect([button('Do not start voice now')]).voice, 'unknown');
});

test('permission errors refuse automation and thinking requires active Voice', () => {
  const blocked=inspect([button('Start voice')],{permission:true});
  assert.equal(blocked.diagnostic,'permission');
  assert.throws(()=>plan('start',blocked));
  assert.equal(inspect([button('End voice')],{thinking:true}).activity,'thinking');
  assert.notEqual(inspect([button('Start voice')],{thinking:true}).activity,'thinking');
  assert.equal(inspect([button('End voice')]).activity,'unknown');
});
