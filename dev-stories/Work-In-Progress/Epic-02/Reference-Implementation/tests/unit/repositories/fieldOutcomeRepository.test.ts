// fieldOutcomeRepository against a seeded pool. The behaviour worth pinning is the decision guard:
// a second decision on an already-decided row must change nothing and say so, because a clinician
// acting on a stale screen silently overwriting the first decision is a clinical-record defect,
// not a race to retry.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { database } from '#core/database.js';
import {
  INSERT_FIELD_OUTCOME_SQL,
  SET_FIELD_OUTCOME_DECISION_SQL,
  fieldOutcomeRepository,
} from '#repositories/fieldOutcomeRepository.js';
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

const PROPOSAL = {
  runID: 5, encounterID: 41, templetID: 7, sectionID: 2, fieldID: 88,
  proposedValue: '120/80', proposedUnit: 'mmHg', proposedStatus: 'FOUND',
  proposedConfidence: 'HIGH', foundIn: 'BP was 120/80 on exam.', verdict: 'REVIEW',
  reasonCode: null,
} as const;

test('a proposal is written and its outcomeID returned', async (t) => {
  useTestEnv();
  const seen = seedPool(t, [{ outcomeID: 900 }]);
  assert.equal(await fieldOutcomeRepository.recordProposal({ ...PROPOSAL }), 900);
  assert.equal(seen.statement, INSERT_FIELD_OUTCOME_SQL);
  assert.equal(seen.inputs.proposedStatus, 'FOUND');
});

test('the proposal write names no decision column', () => {
  // The two write paths never touch each other's columns: the proposal is written once by the
  // run, the decision once by a human, and neither may overwrite the other.
  for (const column of ['acceptedValue', 'acceptedUnit', 'acceptedStatus', 'decidedByProviderID', 'decidedAtUtc']) {
    assert.doesNotMatch(INSERT_FIELD_OUTCOME_SQL, new RegExp(`\\[${column}\\]`), column);
  }
});

test('the decision write names no proposal column', () => {
  for (const column of ['proposedValue', 'proposedUnit', 'proposedStatus', 'proposedConfidence', 'verdict', 'foundIn']) {
    assert.doesNotMatch(SET_FIELD_OUTCOME_DECISION_SQL, new RegExp(`\\[${column}\\]`), column);
  }
});

test('a first decision is recorded and reported as recorded', async (t) => {
  useTestEnv();
  const seen = seedPool(t, [{ changed: 1 }]);
  const recorded = await fieldOutcomeRepository.recordDecision({
    outcomeID: 900, acceptedValue: '120/80', acceptedUnit: 'mmHg', acceptedStatus: 'FOUND', decidedByProviderID: 33,
  });
  assert.equal(recorded, true);
  assert.equal(seen.inputs.decidedByProviderID, 33);
});

test('a second decision on a decided row changes nothing and reports false', async (t) => {
  useTestEnv();
  seedPool(t, [{ changed: 0 }]);
  const recorded = await fieldOutcomeRepository.recordDecision({
    outcomeID: 900, acceptedValue: 'other', acceptedUnit: null, acceptedStatus: 'FOUND', decidedByProviderID: 44,
  });
  // Not an error and not a retry: another decision arrived first, so the caller re-reads.
  assert.equal(recorded, false);
});

test('a system commit carries a null provider, which the statement permits', async (t) => {
  useTestEnv();
  const seen = seedPool(t, [{ changed: 1 }]);
  await fieldOutcomeRepository.recordDecision({
    outcomeID: 901, acceptedValue: '98.6', acceptedUnit: 'F', acceptedStatus: 'FOUND', decidedByProviderID: null,
  });
  // An auto-accepted field acquires a final value with no human in it. A constraint pairing
  // decidedAtUtc with decidedByProviderID would forbid exactly this row -- do not add one.
  assert.equal(seen.inputs.decidedByProviderID, null);
});

test('the decision statement is guarded on an undecided row', () => {
  assert.match(SET_FIELD_OUTCOME_DECISION_SQL, /AND \[decidedAtUtc\] IS NULL/);
});
