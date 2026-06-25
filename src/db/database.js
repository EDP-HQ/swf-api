// database.js
const sql = require('mssql');

// cache one pool per distinct dbConfig (by JSON string key)
const pools = new Map();
/** @type {Map<string, Promise<import('mssql').ConnectionPool>>} */
const connecting = new Map();

function keyOf(cfg) {
  // only include relevant props
  const { user, server, database, port } = cfg || {};
  return JSON.stringify({ user, server, database, port });
}

function dropPool(k) {
  const pool = pools.get(k);
  if (pool) {
    try { pool.close(); } catch (_) {}
  }
  pools.delete(k);
  connecting.delete(k);
}

// build a safe config with keepalive/timeouts
function buildConfig(cfg) {
  return {
    user: cfg.user,
    password: cfg.password,
    server: cfg.server,
    database: cfg.database,
    ...(cfg.port != null ? { port: cfg.port } : {}),
    options: {
      encrypt: false,
      trustServerCertificate: true,
      enableArithAbort: true,
      enableTcpKeepAlive: true,
      keepAliveInitialDelayMillis: 300000, // 5 min
      connectionTimeout: 30000,
      requestTimeout: 60000,
      appName: 'swf-api'
    },
    pool: {
      max: 10,
      min: 0,
      idleTimeoutMillis: 30000
    }
  };
}

async function getPool(dbConfig) {
  const k = keyOf(dbConfig);
  const cached = pools.get(k);

  if (cached?.connected) return cached;

  const inFlight = connecting.get(k);
  if (inFlight) return inFlight;

  const promise = (async () => {
    const pool = new sql.ConnectionPool(buildConfig(dbConfig));

    pool.on('error', (err) => {
      console.error('[DB] pool error:', err?.message || err);
      dropPool(k);
    });

    await pool.connect();
    pools.set(k, pool);
    connecting.delete(k);
    return pool;
  })();

  connecting.set(k, promise);

  try {
    return await promise;
  } catch (err) {
    dropPool(k);
    throw err;
  }
}

// periodic ping to keep sockets alive & detect silent drops
function startHealthPing(dbConfig, intervalMs = 300000) {
  setInterval(async () => {
    try {
      const pool = await getPool(dbConfig);
      await pool.request().query('SELECT 1');
    } catch (e) {
      console.warn('[DB] ping failed, will reconnect on next request:', e.message);
      dropPool(keyOf(dbConfig));
    }
  }, intervalMs);
}

/** Ping DB; does not send HTTP response. Never throws — returns { ok, latencyMs, error? }. */
async function testConnection(dbConfig) {
  const started = Date.now();
  try {
    const pool = await getPool(dbConfig);
    await pool.request().query('SELECT 1 AS health');
    return { ok: true, latencyMs: Date.now() - started };
  } catch (err) {
    return {
      ok: false,
      latencyMs: Date.now() - started,
      error: err?.message || String(err)
    };
  }
}

/** Execute raw query, returns result.recordset (and sends via res if provided) */
async function executeQuery(response, dbConfig, strQuery) {
  try {
    const pool = await getPool(dbConfig);
    const result = await pool.request().query(strQuery);
    if (response && !response.headersSent) response.json(result.recordset);
    return result.recordset;
  } catch (error) {
    console.error('DB query error:', error);
    if (response && !response.headersSent) {
      response.status(500).json({ error: 'Database query failed' });
    }
    throw error;
  }
}

/** Execute stored procedure with params: [{ name, value, type? }] */
async function executeStoredProcedure(response, dbConfig, procedureName, parameters = []) {
  try {
    const pool = await getPool(dbConfig);
    const req = pool.request();
    for (const p of parameters) {
      // default to NVARCHAR when no explicit type is provided
      const t = p.type || sql.NVarChar;
      req.input(p.name, t, p.value);
    }
    const result = await req.execute(procedureName);
    if (response && !response.headersSent) response.json(result.recordset ?? result);
    return result.recordset ?? result;
  } catch (error) {
    console.error('DB SP error:', error);
    if (response && !response.headersSent) {
      response.status(500).json({ error: `Stored procedure failed: ${procedureName}` });
    }
    throw error;
  }
}

/** For commands where you want full Result object back */
async function statementQuery(response, dbConfig, strQuery) {
  try {
    const pool = await getPool(dbConfig);
    const result = await pool.request().query(strQuery);
    if (response && !response.headersSent) response.json(result);
    return result;
  } catch (error) {
    console.error('DB statement error:', error);
    if (response && !response.headersSent) {
      response.status(500).json({ error: 'Database statement failed' });
    }
    throw error;
  }
}

module.exports = {
  executeQuery,
  executeStoredProcedure,
  statementQuery,
  startHealthPing,
  testConnection,
  sql // export mssql in case you want to pass explicit types
};
