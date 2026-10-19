// PEA-202. The one writer of AI.agentRun: one append-only row per invocation, including the runs a
// guard blocked before the model was reached. Separate from the repositories that read, because
// this table is never read on the request path and never updated at all.
import { database } from '#core/database.js';

// OUTPUT rather than SCOPE_IDENTITY(): the insert and the id come back in one round trip, and
// OUTPUT is unaffected by a trigger adding rows to another table.
export const INSERT_AGENT_RUN_SQL = `
INSERT INTO [AI].[agentRun]
    ([encounterID], [templetID], [promptHash], [modelDeployment], [configVersion],
     [inputTokens], [outputTokens], [latencyMs], [outcome], [reasonCode])
OUTPUT INSERTED.[runID] AS [runID]
VALUES
    (@encounterID, @templetID, @promptHash, @modelDeployment, @configVersion,
     @inputTokens, @outputTokens, @latencyMs, @outcome, @reasonCode)`;

/** A run that reached the model. `promptHash` and `modelDeployment` are required by CK_agentRun_reachedModel. */
export type CompletedRun = {
  encounterID: number;
  templetID: number | null;
  promptHash: string;
  modelDeployment: string;
  configVersion: string | null;
  inputTokens: number | null;
  outputTokens: number | null;
  latencyMs: number | null;
  outcome: 'COMMITTED' | 'AWAITING_REVIEW';
  reasonCode?: null;
};

/** A run a guard stopped before any model call. `reasonCode` is required by CK_agentRun_blockedHasReason. */
export type BlockedRun = {
  encounterID: number;
  templetID: number | null;
  outcome: 'BLOCKED';
  reasonCode: string;
  latencyMs?: number | null;
};

export type AgentRun = CompletedRun | BlockedRun;

/**
 * Use the exported `agentRunWriter`.
 *
 * The union is the table's two CHECK constraints expressed in the type system: a completed run
 * cannot omit its prompt hash, a blocked run cannot omit its reason. The database enforces both
 * regardless — this only moves the failure from a deployed INSERT to a compile.
 */
class AgentRunWriter {
  /**
   * The new row's `runID`.
   *
   * `execute` and not `run`: the OUTPUT clause returns a row. The caller passes `execute` from
   * `database.transaction` when the run's field outcomes must land with it — PEA-203's rows and
   * this row are one fact, and a run row without them reads as a completed run that extracted
   * nothing.
   */
  async record(run: AgentRun, execute = database.execute.bind(database)): Promise<number> {
    const rows = await execute(INSERT_AGENT_RUN_SQL, {
      encounterID: run.encounterID,
      templetID: run.templetID,
      promptHash: 'promptHash' in run ? run.promptHash : null,
      modelDeployment: 'modelDeployment' in run ? run.modelDeployment : null,
      configVersion: 'configVersion' in run ? run.configVersion : null,
      inputTokens: 'inputTokens' in run ? run.inputTokens : null,
      outputTokens: 'outputTokens' in run ? run.outputTokens : null,
      latencyMs: run.latencyMs ?? null,
      outcome: run.outcome,
      reasonCode: 'reasonCode' in run ? (run.reasonCode ?? null) : null,
    });
    return rows[0].runID as number;
  }
}

export const agentRunWriter = new AgentRunWriter();
