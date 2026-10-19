// Deploy-time entrypoint: applies the AI-schema migrations and exits. Kept out of src/core/ because
// every file there is imported by tests/unit/repo.test.ts, which proves the tree imports with no
// environment and no network — an entrypoint that runs on import would fail it.
import { database } from '#core/database.js';
import { migrationRunner } from '#core/databaseMigrations.js';
import { logger } from '#core/logging.js';
import { settings } from '#core/settings.js';

const { logLevel } = settings();
logger.level = logLevel;
const log = logger.child({ module: 'migrate' });

// Exit codes: 0 applied, 1 refused or failed. A pipeline step reads the code, not the log.
migrationRunner
  .applyPending()
  .then(
    () => 0,
    (error: unknown) => {
      // The message names the script; the cause carries the driver's own error.
      log.error({ err: error }, 'migrations failed');
      return 1;
    },
  )
  .then(async (code: number) => {
    // Only a pool that was built has connections to close.
    if (Object.hasOwn(database, 'pool')) await database.pool.close();
    process.exit(code);
  });
