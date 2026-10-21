import { test } from 'node:test';
import assert from 'node:assert/strict';
import { matchCommand } from '../js/voice.js';

test('recognizes short awake phrases', () => {
  for (const said of ["I'm awake", 'awake', 'still here', 'Keep going.', 'I’m listening', 'im awake']) {
    assert.equal(matchCommand(said), 'awake', said);
  }
});

test('recognizes stop phrases, and stop wins over awake', () => {
  assert.equal(matchCommand('Good night'), 'stop');
  assert.equal(matchCommand('goodnight'), 'stop');
  assert.equal(matchCommand('stop playing'), 'stop');
  assert.equal(matchCommand("I'm awake good night"), 'stop');
});

test('ignores narration and look-alike words', () => {
  assert.equal(matchCommand('She lay awake for hours listening to the rain on the roof'), null);
  assert.equal(matchCommand('"Yes," she said.'), null);
  assert.equal(matchCommand('Stop!'), null);
  assert.equal(matchCommand('awakened'), null);
  assert.equal(matchCommand(''), null);
});
