// agentRunWriter against a seeded pool. What matters here is not that an INSERT happens but that
// the two shapes the table's CHECK constraints allow are the two shapes this writer can produce:
// a completed run always carries its prompt hash, a blocked run always carries its reason.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { database } from '#core/database.js';
import { INSERT_AGENT_RUN_SQL, agentRunWriter } from '#repositories/agentRunWriter.js';
import { useTestEnv } from '../env.js';

type Seen = { statement?: string; inputs: Record<string, unknown> };

function seedPool(t: { after: (fn: () => void) => void }, recordset: Record<string, unknown>[]): Seen {
  const seen: Seen = { inputs: {} };
  const request = {
    input(name: string, value: unknown) { seen.inputs[name] = value; return request; },
    async query(statement: string) { seen.statement = statement; return { recordset }; },
  };
  const stub = { connect: async () => stub, request: () => request };
  Object.defineProperty(database, 'pool', { value: stub, configurable: true });
  t.after(() => Reflect.deleteProperty(database, 'pool'));
  return seen;
}

const COMPLETED = {
  encounterID: 41, templetID: 7, promptHash: 'a'.repeat(64), modelDeployment: 'gpt-4-1',
  configVersion: 'v3', inputTokens: 900, outputTokens: 120, latencyMs: 1840,
  outcome: 'COMMITTED',
} as const;

test('a completed run writes its hash and deployment, and returns the new runID', async (t) => {
  useTestEnv();
  const seen = seedPool(t, [{ runID: 12345 }]);
  const runID = await agentRunWriter.record({ ...COMPLETED });
  assert.equal(runID, 12345);
  assert.equal(seen.statement, INSERT_AGENT_RUN_SQL);
  assert.equal(seen.inputs.promptHash, 'a'.repeat(64));
  assert.equal(seen.inputs.modelDeployment, 'gpt-4-1');
  assert.equal(seen.inputs.outcome, 'COMMITTED');
  // CK_agentRun_blockedHasReason permits a null reason only when the outcome is not BLOCKED.
  assert.equal(seen.inputs.reasonCode, null);
});

test('a blocked run writes its reason and no model columns', async (t) => {
  useTestEnv();
  const seen = seedPool(t, [{ runID: 7 }]);
  await agentRunWriter.record({ encounterID: 41, templetID: null, outcome: 'BLOCKED', reasonCode: 'PHI_GUARD' });
  assert.equal(seen.inputs.reasonCode, 'PHI_GUARD');
  // CK_agentRun_reachedModel permits these to be null only on the BLOCKED path.
  assert.equal(seen.inputs.promptHash, null);
  assert.equal(seen.inputs.modelDeployment, null);
});

test('every column the statement names is bound, so none is silently dropped', async (t) => {
  useTestEnv();
  const seen = seedPool(t, [{ runID: 1 }]);
  await agentRunWriter.record({ ...COMPLETED });
  const named = [...INSERT_AGENT_RUN_SQL.matchAll(/@(\w+)/g)].map((m) => m[1]);
  assert.deepEqual([...new Set(named)].sort(), Object.keys(seen.inputs).sort());
});

test('the run is written through a caller-supplied execute, so it can join a transaction', async (t) => {
  useTestEnv();
  seedPool(t, [{ runID: 1 }]);
  const calls: string[] = [];
  const execute = async (statement: string) => { calls.push(statement); return [{ runID: 99 }]; };
  const runID = await agentRunWriter.record({ ...COMPLETED }, execute);
  // The point of the seam: PEA-203's outcomes and this row are one fact and must commit together.
  assert.equal(runID, 99);
  assert.deepEqual(calls, [INSERT_AGENT_RUN_SQL]);
});
