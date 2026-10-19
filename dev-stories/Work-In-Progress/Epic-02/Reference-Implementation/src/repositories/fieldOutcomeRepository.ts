// PEA-203. AI.fieldOutcome: the model's proposal, and later the clinician's decision, one row per
// field per run. Two write paths that never touch each other's columns -- the proposal is written
// once by the extraction run, the decision once by a human, and neither may overwrite the other.
import { database } from '#core/database.js';

export const INSERT_FIELD_OUTCOME_SQL = `
INSERT INTO [AI].[fieldOutcome]
    ([runID], [encounterID], [templetID], [sectionID], [fieldID],
     [proposedValue], [proposedUnit], [proposedStatus], [proposedConfidence],
     [foundIn], [verdict], [reasonCode])
OUTPUT INSERTED.[outcomeID] AS [outcomeID]
VALUES
    (@runID, @encounterID, @templetID, @sectionID, @fieldID,
     @proposedValue, @proposedUnit, @proposedStatus, @proposedConfidence,
     @foundIn, @verdict, @reasonCode)`;

// Guarded on decidedAtUtc IS NULL so a second decision on the same row changes nothing and the
// caller can tell: a clinician acting on a stale screen must not silently overwrite the first
// decision. The statement touches no proposal column.
export const SET_FIELD_OUTCOME_DECISION_SQL = `
UPDATE [AI].[fieldOutcome]
   SET [acceptedValue]       = @acceptedValue,
       [acceptedUnit]        = @acceptedUnit,
       [acceptedStatus]      = @acceptedStatus,
       [decidedByProviderID] = @decidedByProviderID,
       [decidedAtUtc]        = getutcdate()
 WHERE [outcomeID] = @outcomeID
   AND [decidedAtUtc] IS NULL;
SELECT @@ROWCOUNT AS [changed]`;

export const SELECT_PENDING_BY_ENCOUNTER_SQL = `
SELECT [outcomeID], [runID], [templetID], [sectionID], [fieldID],
       [proposedValue], [proposedUnit], [proposedStatus], [proposedConfidence],
       [foundIn], [verdict], [reasonCode], [createdUtc]
  FROM [AI].[fieldOutcome]
 WHERE [encounterID] = @encounterID
   AND [decidedAtUtc] IS NULL
 ORDER BY [createdUtc] ASC, [outcomeID] ASC`;

/** FOUND is a value the model extracted; ABSENT is a successful extraction finding nothing;
 *  ABSTAINED is the model declining to answer. Collapsing the last two is the defect this
 *  table exists to fix, so they are distinct here and in the CHECK constraint. */
export type ProposedStatus = 'FOUND' | 'ABSENT' | 'ABSTAINED';

/** A band, never a float: nothing in the runtime produces a calibrated probability. */
export type Confidence = 'HIGH' | 'MEDIUM' | 'LOW';

export type Verdict = 'ACCEPT' | 'REVIEW' | 'BLOCK';

export type Proposal = {
  runID: number;
  encounterID: number;
  templetID: number;
  sectionID: number;
  fieldID: number;
  proposedValue: string | null;
  proposedUnit: string | null;
  proposedStatus: ProposedStatus;
  proposedConfidence: Confidence;
  foundIn: string | null;
  verdict: Verdict;
  reasonCode: string | null;
};

export type Decision = {
  outcomeID: number;
  acceptedValue: string | null;
  acceptedUnit: string | null;
  acceptedStatus: ProposedStatus;
  /** Null for a system commit of an auto-accepted field: a decision with no human in it. */
  decidedByProviderID: number | null;
};

/**
 * Use the exported `fieldOutcomeRepository`.
 */
class FieldOutcomeRepository {
  /**
   * The new row's `outcomeID`.
   *
   * The caller passes `execute` from `database.transaction` so a run's outcomes land with the
   * `AI.agentRun` row that produced them.
   */
  async recordProposal(proposal: Proposal, execute = database.execute.bind(database)): Promise<number> {
    const rows = await execute(INSERT_FIELD_OUTCOME_SQL, { ...proposal });
    return rows[0].outcomeID as number;
  }

  /**
   * True if this call recorded the decision, false if the row already had one.
   *
   * False is not an error and not a retry: it means another decision arrived first, and the
   * caller should re-read rather than overwrite.
   */
  async recordDecision(decision: Decision): Promise<boolean> {
    const rows = await database.execute(SET_FIELD_OUTCOME_DECISION_SQL, { ...decision });
    return (rows[0].changed as number) === 1;
  }

  /** The encounter's undecided proposals, oldest first. Serves the review queue. */
  async pendingForEncounter(encounterID: number): Promise<Record<string, unknown>[]> {
    return database.execute(SELECT_PENDING_BY_ENCOUNTER_SQL, { encounterID });
  }
}

export const fieldOutcomeRepository = new FieldOutcomeRepository();
