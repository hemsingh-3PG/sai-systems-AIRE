// Applies the migration set against the configured Azure SQL database twice, or skips each test with
// the reason it could not. The second run is the one that matters: idempotency here is each script's
// own existence check, not a history table, and nothing else proves it holds.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { database } from '#core/database.js';
import { migrationRunner, readScripts } from '#core/databaseMigrations.js';

const SCHEMA_PRESENT_SQL = 'SELECT COUNT(*) AS schemaCount FROM sys.schemas WHERE name = @name';
const ROLES_PRESENT_SQL =
  'SELECT COUNT(*) AS roleCount FROM sys.database_principals WHERE type = @type AND name IN (@first, @second, @third)';
const ROLES = { type: 'R', first: 'aiServiceRuntime', second: 'aiPromptAdmin', third: 'aiTemplateAdmin' };

/** The one count a `SELECT COUNT(*) AS alias` statement returns. */
function count(rows: Record<string, unknown>[], alias: string): number {
  assert.equal(rows.length, 1);
  return rows[0][alias] as number;
}

// A parent test rather than a top-level await: the reason must exist before the subtests are declared.
test('AI schema migrations, live', async (t) => {
  let skip: string | undefined;
  try {
    await database.execute(SCHEMA_PRESENT_SQL, { name: 'AI' });
    t.after(() => database.pool.close());
  } catch (error) {
    const { name, message } = error as Error;
    skip = `Azure SQL did not answer from this machine (${name}: ${message})`;
  }

  await t.test('applying the set creates the schema and the three roles', { skip }, async () => {
    const applied = await migrationRunner.applyPending();
    assert.equal(applied, readScripts().length);
    assert.equal(count(await database.execute(SCHEMA_PRESENT_SQL, { name: 'AI' }), 'schemaCount'), 1);
    assert.equal(count(await database.execute(ROLES_PRESENT_SQL, ROLES), 'roleCount'), 3);
  });

  await t.test('re-running the set raises nothing and creates nothing', { skip }, async () => {
    // The acceptance criterion the epic states: every existence check short-circuits its CREATE.
    await migrationRunner.applyPending();
    assert.equal(count(await database.execute(SCHEMA_PRESENT_SQL, { name: 'AI' }), 'schemaCount'), 1);
    assert.equal(count(await database.execute(ROLES_PRESENT_SQL, ROLES), 'roleCount'), 3);
  });

  await t.test('a DDL statement returns no rows, so execute yields undefined', { skip }, async () => {
    // ⚠️ execute's signature promises Record<string, unknown>[]; mssql sets `recordset` from an empty
    // `recordsets` for a statement that yields no rows. Asserted here so the day the driver or the
    // signature changes, this fails rather than applyPending quietly starting to read a result.
    const result = await database.execute(readScripts()[0].text);
    assert.equal(result, undefined);
  });
});
