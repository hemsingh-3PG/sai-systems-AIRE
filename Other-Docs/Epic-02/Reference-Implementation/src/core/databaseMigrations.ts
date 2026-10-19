// Applies the forward-only AI-schema scripts. This is the only path by which an AI.* object reaches
// a database, so the whole set is validated before any of it runs: a half-applied set is worse than
// an unapplied one, and there is no down-migration to undo it with.
import { readFileSync, readdirSync } from 'node:fs';
import { database } from './database.js';
import { logger } from './logging.js';

// Scripts sit at the repository root, outside src/, so the same relative path resolves from
// src/core/ and from dist/core/. tsc emits only .js, so the deployed package must ship the folder.
const SCRIPT_DIRECTORY = new URL('../../migrations/sql/', import.meta.url);

// Four zero-padded digits so filename order is numeric order: an unpadded 10_ sorts before 2_.
const SCRIPT_NAME = /^\d{4}_[a-z0-9_]+\.sql$/;

// GO is a client-side separator, not T-SQL: the driver never sees it. A script is split on it and
// each part sent as its own batch, which is what lets a script hold statements that must be first
// in a batch (CREATE SCHEMA) alongside ones that reference objects an earlier batch created.
// Line-anchored, so `GO` inside an identifier or mid-line is untouched.
const BATCH_SEPARATOR = /^[ \t]*GO[ \t]*;?[ \t]*$/gim;

const log = logger.child({ module: 'core.databaseMigrations' });

/** One script's filename and full text. */
export type Script = { name: string; text: string };

/**
 * The script's batches, in order, with empty ones dropped.
 *
 * Exported because the batch boundary is the unit the database actually receives: a test that
 * asserts on whole-file text is asserting on something no server ever sees.
 */
export function batches(text: string): string[] {
  return text.split(BATCH_SEPARATOR).map((batch) => batch.trim()).filter((batch) => batch.length > 0);
}

/**
 * Every rule the set breaks, one message each, or an empty array.
 *
 * Takes the scripts rather than reading them so tests/unit can assert each rejection against a
 * synthetic set, with no filesystem and no database.
 */
export function validate(scripts: Script[]): string[] {
  const problems = [
    ...scripts.filter(({ name }) => !SCRIPT_NAME.test(name)).map(({ name }) => `${name}: not NNNN_lower_snake.sql`),
    ...scripts.filter(({ text }) => batches(text).length === 0).map(({ name }) => `${name}: no statements`),
  ];
  const numbers = scripts.filter(({ name }) => SCRIPT_NAME.test(name)).map(({ name }) => name.slice(0, 4));
  for (const [index, number] of numbers.entries()) {
    if (numbers.indexOf(number) !== index) problems.push(`${number}: duplicate script number`);
  }
  return problems;
}

/**
 * Every script in numeric order, or an `Error` naming every file that fails a rule.
 *
 * Reads the filesystem and validates; does nothing else.
 */
export function readScripts(): Script[] {
  const names = readdirSync(SCRIPT_DIRECTORY).filter((name) => name.endsWith('.sql')).sort();
  const scripts = names.map((name) => ({ name, text: readFileSync(new URL(name, SCRIPT_DIRECTORY), 'utf8') }));
  const problems = validate(scripts);
  if (problems.length) throw new Error(`migrations: ${problems.join('; ')}`);
  return scripts;
}

/**
 * Use the exported `migrationRunner`.
 *
 * Forward-only: a merged script is never edited, and a correction is a new script. Idempotency is
 * each script's own existence check rather than a history table, so a second run is a no-op.
 */
class MigrationRunner {
  /**
   * The number of scripts applied.
   *
   * Scripts run in order, one batch each, outside a transaction: the set is forward-only and every
   * script guards its own objects, so a failure leaves the earlier scripts applied and re-running
   * resumes from there. A failure names the script and never its text.
   */
  async applyPending(): Promise<number> {
    const scripts = readScripts();
    for (const { name, text } of scripts) {
      const parts = batches(text);
      log.info({ script: name, batches: parts.length }, 'applying migration');
      for (const [index, batch] of parts.entries()) {
        try {
          // `run`, not `execute`: a migration yields no rows, and execute's type would promise an
          // array the driver never builds.
          await database.run(batch);
        } catch (cause) {
          // The batch ordinal, never its text: a script body can be long and is not a log line.
          throw new Error(`migrations: ${name} batch ${index + 1} failed`, { cause });
        }
      }
    }
    log.info({ count: scripts.length }, 'migrations applied');
    return scripts.length;
  }
}

export const migrationRunner = new MigrationRunner();
