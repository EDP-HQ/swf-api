// database.js
const sql = require('mssql');

// cache one pool per distinct dbConfig (by JSON string key)
const pools = new Map();

function keyOf(cfg) {
  // only include relevant props
  const { user, server, database } = cfg || {};
  return JSON.stringify({ user, server, database });
}

// build a safe config with keepalive/timeouts
function buildConfig(cfg) {
  return {
    user: cfg.user,
    password: cfg.password,
    server: cfg.server,
    database: cfg.database,
    options: {
      encrypt: false,
      trustServerCertificate: true,
      enableArithAbort: true,
      enableTcpKeepAlive: true,
      keepAliveInitialDelayMillis: 300000, // 5 min
      connectionTimeout: 30000,
      requestTimeout: 60000,
      appName: 'roller-api'
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
  if (cached?.connecting) return cached.connecting; // a promise

  const pool = new sql.ConnectionPool(buildConfig(dbConfig));
  const connecting = pool.connect()
    .then(() => {
      pool.connecting = null;
      return pool;
    })
    .catch(err => {
      // if connect fails, clear so next call retries
      pools.delete(k);
      throw err;
    });

  pool.connecting = connecting;

  // pool-level error handler: drop from cache so next call reconnects
  pool.on('error', (err) => {
    console.error('[DB] pool error:', err?.message || err);
    try { pool.close(); } catch (_) {}
    pools.delete(k);
  });

  pools.set(k, pool);
  return connecting;
}

// periodic ping to keep sockets alive & detect silent drops
function startHealthPing(dbConfig, intervalMs = 300000) {
  setInterval(async () => {
    try {
      const pool = await getPool(dbConfig);
      await pool.request().query('SELECT 1');
    } catch (e) {
      console.warn('[DB] ping failed, will reconnect on next request:', e.message);
      const k = keyOf(dbConfig);
      const p = pools.get(k);
      if (p) {
        try { p.close(); } catch (_) {}
        pools.delete(k);
      }
    }
  }, intervalMs);
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
  sql // export mssql in case you want to pass explicit types
};
