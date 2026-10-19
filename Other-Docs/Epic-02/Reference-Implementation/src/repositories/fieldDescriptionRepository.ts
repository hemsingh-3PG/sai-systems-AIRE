// PEA-207. AI.fieldDescription read at request time: the per-mapping semantics the schema builder
// puts in front of the model. Not on Template.fields, because no clinical table is altered here.
import { database } from '#core/database.js';

// Bulk by template, never per field: the schema builder needs every description for one template
// at once, and a per-field read would be one round trip per field on the request path.
export const SELECT_DESCRIPTIONS_BY_TEMPLATE_SQL = `
SELECT [sectionID], [fieldID], [description]
  FROM [AI].[fieldDescription]
 WHERE [templetID] = @templetID`;

/**
 * Use the exported `fieldDescriptionRepository`.
 */
class FieldDescriptionRepository {
  /**
   * The template's descriptions, keyed `sectionID:fieldID`.
   *
   * ⚠️ No cache, and in Node that rule is easy to break without writing anything that looks like
   * a cache: a module-scope Map and an Azure Functions warm instance both persist across
   * invocations. A cached description also makes the per-call prompt hash stop matching what was
   * actually sent, which is the record an audit reads.
   */
  async forTemplate(templetID: number): Promise<Map<string, string>> {
    const rows = await database.execute(SELECT_DESCRIPTIONS_BY_TEMPLATE_SQL, { templetID });
    return new Map(rows.map((row) => [`${row.sectionID}:${row.fieldID}`, row.description as string]));
  }
}

export const fieldDescriptionRepository = new FieldDescriptionRepository();
