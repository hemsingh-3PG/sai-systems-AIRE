// The one way to Azure SQL. A pool rather than a connection per call: each physical connection
// costs a TLS handshake and an Entra login, and the pool pays them once per connection it keeps.
import sql from 'mssql';
import { logger } from './logging.js';
import { settings } from './settings.js';

// ponytail: copied from the reference pattern, unmeasured against a loaded instance; tune from Epic 10's query latency data.
const REQUEST_TIMEOUT_MS = 10_000;

export const SCHEMA_EXISTS_SQL =
  'SELECT COUNT(*) AS tableCount FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = @schema';

const log = logger.child({ module: 'core.database' });

/** One statement issued inside an open transaction, bound to its connection. */
export type TransactionalExecute = (
  statement: string,
  params?: Record<string, unknown>,
) => Promise<Record<string, unknown>[]>;

/**
 * Use the exported `database`. Azure SQL through one pool, reached only by `execute`.
 */
class Database {
  /** The process's pool, built from `settings()` on first read. Building it opens nothing. */
  get pool(): sql.ConnectionPool {
    const { azureSqlServer, azureSqlDatabase, azureClientId, azureSqlUser, azureSqlPassword } = settings();
    const value = new sql.ConnectionPool({
      server: azureSqlServer,
      database: azureSqlDatabase,
      // ponytail: tedious builds a DefaultAzureCredential, with an empty token cache, on every physical login;
      // switch to 'token-credential' with one shared credential if login latency is measured. Bounded by the pool's max of 10.
      authentication: azureSqlUser
        ? { type: 'default', options: { userName: azureSqlUser, password: azureSqlPassword! } }
        : { type: 'azure-active-directory-default', options: azureClientId ? { clientId: azureClientId } : {} },
      options: { encrypt: true },
      requestTimeout: REQUEST_TIMEOUT_MS,
    });
    // An unheard 'error' exits the process, and the pool re-emits connection failures.
    value.on('error', (e: Error & { code?: string }) => log.error({ code: e.code }, 'sql pool error'));
    Object.defineProperty(this, 'pool', { value, configurable: true });
    return value;
  }

  /**
   * The recordset rows, keyed by column name. Each `params` entry binds server-side to its `@name`.
   */
  async execute(statement: string, params: Record<string, unknown> = {}): Promise<Record<string, unknown>[]> {
    const request = (await this.pool.connect()).request();
    for (const [name, value] of Object.entries(params)) request.input(name, value);
    return (await request.query(statement)).recordset;
  }

  /**
   * Nothing. For a statement that returns no rows — DDL, or a write with no OUTPUT clause.
   *
   * Separate from `execute` because the driver returns no recordset for one: mssql builds the
   * result as `recordset: recordsets && recordsets[0]`, and `recordsets` is empty here, so
   * `execute` would hand back `undefined` while its type promises an array.
   */
  async run(statement: string, params: Record<string, unknown> = {}): Promise<void> {
    const request = (await this.pool.connect()).request();
    for (const [name, value] of Object.entries(params)) request.input(name, value);
    await request.query(statement);
  }

  /**
   * `work`'s result, committed; or its error, after a rollback.
   *
   * The callback's `execute` is the only way to issue a statement inside the transaction. A
   * statement sent through `database.execute` during `work` takes a different connection and is
   * not covered by it, which is why the transaction object itself is never handed out.
   */
  async transaction<T>(work: (execute: TransactionalExecute) => Promise<T>): Promise<T> {
    const value = (await this.pool.connect()).transaction();
    await value.begin();
    const execute: TransactionalExecute = async (statement, params = {}) => {
      const request = value.request();
      for (const [name, entry] of Object.entries(params)) request.input(name, entry);
      return (await request.query(statement)).recordset;
    };
    try {
      const result = await work(execute);
      await value.commit();
      return result;
    } catch (error) {
      // A failing rollback must not replace the error that caused it.
      await value.rollback().catch(() => undefined);
      throw error;
    }
  }
}

export const database = new Database();
