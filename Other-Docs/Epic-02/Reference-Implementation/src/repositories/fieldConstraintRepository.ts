// PEA-206. AI.fieldConstraint read at request time: the numeric bounds for one template's mappings.
// Two bands with different behaviours -- plausible blocks a value, abnormal flags it and keeps it.
import { database } from '#core/database.js';

// One round trip per request, not one per field: a template has tens of mappings and a per-field
// read would be tens of round trips on the request path.
export const SELECT_CONSTRAINTS_BY_TEMPLATE_SQL = `
SELECT [sectionID], [fieldID], [unit],
       [plausibleMin], [plausibleMax], [abnormalMin], [abnormalMax]
  FROM [AI].[fieldConstraint]
 WHERE [templetID] = @templetID
   AND [isActive] = 1`;

/**
 * One mapping's bounds. ⚠️ The four bounds arrive as JavaScript numbers: node-mssql surfaces
 * DECIMAL(6,2) as a binary double, so a comparison at the boundary can flip. Compare in SQL, or
 * with an explicit documented tolerance -- never with bare `>` on a value a clinician typed.
 */
export type FieldConstraint = {
  sectionID: number;
  fieldID: number;
  unit: string | null;
  plausibleMin: number | null;
  plausibleMax: number | null;
  abnormalMin: number | null;
  abnormalMax: number | null;
};

/**
 * Use the exported `fieldConstraintRepository`.
 */
class FieldConstraintRepository {
  /**
   * The template's active bounds, keyed `sectionID:fieldID`.
   *
   * No cache. The read is one indexed range seek, and a cached bound is a bound that disagrees
   * with what an author just changed -- in a direction that silently blocks a clinical value.
   */
  async forTemplate(templetID: number): Promise<Map<string, FieldConstraint>> {
    const rows = await database.execute(SELECT_CONSTRAINTS_BY_TEMPLATE_SQL, { templetID });
    return new Map(rows.map((row) => [`${row.sectionID}:${row.fieldID}`, row as FieldConstraint]));
  }
}

export const fieldConstraintRepository = new FieldConstraintRepository();
