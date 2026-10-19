// database.transaction and database.run, against a seeded pool: no settings, no server, no network.
// Transaction correctness is the one thing an integration test proves late and expensively — a
// rollback that silently did not happen looks identical to a commit until the data is wrong.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { database } from '#core/database.js';
import { useTestEnv } from '../env.js';

type Seen = { statements: string[]; inputs: Record<string, unknown>; calls: string[] };

/** A pool whose transaction records what was asked of it, seeded onto `database`. */
function seedPool(t: { after: (fn: () => void) => void }, failOn?: 'rollback'): Seen {
  const seen: Seen = { statements: [], inputs: {}, calls: [] };
  const request = {
    input(name: string, value: unknown) { seen.inputs[name] = value; return request; },
    async query(statement: string) { seen.statements.push(statement); return { recordset: [{ ok: 1 }] }; },
  };
  const transaction = {
    async begin() { seen.calls.push('begin'); return transaction; },
    async commit() { seen.calls.push('commit'); },
    async rollback() {
      seen.calls.push('rollback');
      if (failOn === 'rollback') throw new Error('rollback failed');
    },
    request: () => request,
  };
  const stub = { connect: async () => stub, request: () => request, transaction: () => transaction };
  Object.defineProperty(database, 'pool', { value: stub, configurable: true });
  t.after(() => Reflect.deleteProperty(database, 'pool'));
  return seen;
}

test('work that returns commits, and its value is returned', async (t) => {
  useTestEnv();
  const seen = seedPool(t);
  const result = await database.transaction(async (execute) => {
    await execute('INSERT_AGENT_RUN_SQL', { runId: 7 });
    return 'committed';
  });
  assert.equal(result, 'committed');
  assert.deepEqual(seen.calls, ['begin', 'commit']);
  assert.deepEqual(seen.statements, ['INSERT_AGENT_RUN_SQL']);
  assert.deepEqual(seen.inputs, { runId: 7 });
});

test('work that throws rolls back and never commits, and the error reaches the caller', async (t) => {
  useTestEnv();
  const seen = seedPool(t);
  await assert.rejects(
    database.transaction(async (execute) => {
      await execute('INSERT_AGENT_RUN_SQL');
      throw new Error('field outcome rejected');
    }),
    /field outcome rejected/,
  );
  assert.deepEqual(seen.calls, ['begin', 'rollback']);
});

test('a failing rollback does not replace the error that caused it', async (t) => {
  useTestEnv();
  const seen = seedPool(t, 'rollback');
  // The original cause is what an operator needs; the rollback failure is noise on top of it.
  await assert.rejects(
    database.transaction(async () => { throw new Error('field outcome rejected'); }),
    /field outcome rejected/,
  );
  assert.deepEqual(seen.calls, ['begin', 'rollback']);
});

test('run issues the statement, binds its parameters, and returns nothing', async (t) => {
  useTestEnv();
  const seen = seedPool(t);
  const result = await database.run('CREATE_SCHEMA_SQL', { name: "AI'; DROP TABLE x;--" });
  assert.equal(result, undefined);
  assert.deepEqual(seen.statements, ['CREATE_SCHEMA_SQL']);
  // Bound server-side, so the injection attempt is a value and never statement text.
  assert.deepEqual(seen.inputs, { name: "AI'; DROP TABLE x;--" });
});
