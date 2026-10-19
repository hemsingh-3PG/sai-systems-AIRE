// The migration set's own rules, asserted without a database: every script touches only the AI
// schema, nothing undoes anything, and the naming that makes filename order numeric order holds.
// This is the check the epic requires in CI and the only thing standing between a merged script and
// production, since there is no down-migration.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { batches, readScripts, validate } from '#core/databaseMigrations.js';

/** The script's text with `--` line comments and `/* *\/` blocks removed. */
function statements(text: string): string {
  return text.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/--[^\n]*/g, ' ');
}

// Every schema-qualified name a script may mention. sys and INFORMATION_SCHEMA are the existence
// checks; AI is the only schema this epic may create in or write to.
const ALLOWED_SCHEMAS = new Set(['ai', 'sys', 'information_schema']);
const QUALIFIED_NAME = /\[?([A-Za-z_][A-Za-z0-9_]*)\]?\s*\.\s*\[?[A-Za-z_][A-Za-z0-9_]*\]?/g;

// A migration that removes or rewrites data is how this epic reaches a clinical table by accident.
const FORBIDDEN = /\b(DROP|TRUNCATE|DELETE|UPDATE|INSERT|MERGE|ALTER\s+TABLE)\b/i;

const scripts = readScripts();
const allBatches = scripts.flatMap(({ name, text }) => batches(text).map((batch) => ({ name, batch })));

test('the migration set is not empty and reads in numeric order', () => {
  assert.ok(scripts.length > 0, 'no scripts found under migrations/sql/');
  assert.deepEqual([...scripts].sort((a, b) => a.name.localeCompare(b.name)), scripts);
});

test('no script names an object outside the AI schema', () => {
  for (const { name, text } of scripts) {
    const schemas = [...statements(text).matchAll(QUALIFIED_NAME)].map((m) => m[1].toLowerCase());
    const foreign = [...new Set(schemas)].filter((schema) => !ALLOWED_SCHEMAS.has(schema));
    assert.deepEqual(foreign, [], `${name} references ${foreign.join(', ')}`);
  }
});

test('no script drops, truncates or writes rows anywhere', () => {
  for (const { name, text } of scripts) {
    const hit = FORBIDDEN.exec(statements(text));
    assert.equal(hit, null, `${name} contains ${hit?.[0]}`);
  }
});

test('every CREATE is guarded by an existence check, so a second run creates nothing', () => {
  for (const { name, text } of scripts) {
    const body = statements(text);
    const creates = (body.match(/\bCREATE\s+(SCHEMA|ROLE|TABLE|INDEX)\b/gi) ?? []).length;
    const guards = (body.match(/\bIF\s+NOT\s+EXISTS\b/gi) ?? []).length;
    assert.ok(guards >= creates, `${name}: ${creates} CREATE statements, ${guards} guards`);
  }
});

test('no script is a down-migration', () => {
  // Restated as its own case because it is the rule a reviewer is most likely to relax under
  // pressure: undoing a bad migration is a new forward script, never an edit or a reversal.
  for (const { name, text } of scripts) {
    assert.doesNotMatch(statements(text), /\bDROP\b/i, `${name} reverses a prior script`);
  }
});

test('the shipped set passes every rule', () => {
  assert.deepEqual(validate(scripts), []);
});

test('GO splits a script into batches, in each form a script might carry it', () => {
  // GO is a client separator the driver never sees. Splitting here is what lets one script hold a
  // statement that must be first in its batch next to one that references what an earlier batch made.
  for (const text of ['CREATE TABLE a;\nGO\nCREATE INDEX b;\n', 'CREATE TABLE a;\n  go  \nCREATE INDEX b;\n', 'CREATE TABLE a;\nGO;\nCREATE INDEX b;\n']) {
    assert.deepEqual(batches(text), ['CREATE TABLE a;', 'CREATE INDEX b;'], text);
  }
});

test('GO inside an identifier or mid-line is not a separator', () => {
  assert.deepEqual(batches('CREATE ROLE [gogo];\n'), ['CREATE ROLE [gogo];']);
  assert.deepEqual(batches('SELECT 1 GO 2;\n'), ['SELECT 1 GO 2;']);
});

test('trailing and repeated separators produce no empty batch', () => {
  assert.deepEqual(batches('CREATE TABLE a;\nGO\nGO\n\n'), ['CREATE TABLE a;']);
});

test('a script with no statements is rejected', () => {
  assert.deepEqual(validate([{ name: '0001_x.sql', text: '\nGO\n   \n' }]), ['0001_x.sql: no statements']);
});

test('a filename that would break numeric ordering is rejected', () => {
  for (const name of ['10_late.sql', '0001-dashed.sql', '0001_Mixed_Case.sql', 'create_ai_schema.sql']) {
    assert.deepEqual(validate([{ name, text: 'SELECT 1;' }]), [`${name}: not NNNN_lower_snake.sql`], name);
  }
});

test('two scripts sharing a number are rejected', () => {
  const set = [{ name: '0002_a.sql', text: 'SELECT 1;' }, { name: '0002_b.sql', text: 'SELECT 1;' }];
  assert.deepEqual(validate(set), ['0002: duplicate script number']);
});

test('every problem in a set is reported, not just the first', () => {
  const set = [{ name: 'bad.sql', text: '' }, { name: '0001_x.sql', text: 'SELECT 1;' }];
  assert.deepEqual(validate(set), [
    'bad.sql: not NNNN_lower_snake.sql',
    'bad.sql: no statements',
  ]);
});
