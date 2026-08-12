/**
 * Background component install-time ticker.
 * While swf-api is running, polls plant Run/Stop for all process boards and
 * writes TB_COMPONENTS_TRACKER.RUNTIME_SEC — independent of which UI tab is open.
 */
const database = require('../db/database');
const sql = database.sql;
const sfcwrdbConfig = require('../config/sfcwrdb');

const DEFAULT_INTERVAL_MS = 10_000;

const SCOPES = [
  { processCd: 'INLINE', lineCd: null },
  { processCd: 'DRAWING', lineCd: null },
  { processCd: 'CLOSING', lineCd: null },
  { processCd: 'REWINDER', lineCd: null },
  { processCd: 'STRANDING', lineCd: 'BUNCHER' },
  { processCd: 'STRANDING', lineCd: 'TUBULAR' }
];

/** @type {Map<string, { partId: string, machineNm: string, runtimeSec: number, running: boolean, lastTickMs: number, processCd: string, lineCd: string|null }>} */
const partState = new Map();

let timer = null;
let runningTick = false;
let startedAt = null;
let lastTickAt = null;
let lastTickOk = true;
let lastError = null;
let tickCount = 0;
let lastWrites = 0;
let intervalMs = DEFAULT_INTERVAL_MS;

function rowStr(row, ...keys) {
  for (const key of keys) {
    if (row[key] != null && row[key] !== '') return String(row[key]).trim();
    const u = key.toUpperCase();
    if (row[u] != null && row[u] !== '') return String(row[u]).trim();
    const l = key.toLowerCase();
    if (row[l] != null && row[l] !== '') return String(row[l]).trim();
  }
  return '';
}

function rowNum(row, ...keys) {
  const v = rowStr(row, ...keys);
  if (v === '') return 0;
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
}

function scopeKey(processCd, lineCd) {
  return `${processCd}:${lineCd || '_'}`;
}

async function execSp(procedureName, parameters = []) {
  return database.executeStoredProcedure(null, sfcwrdbConfig, procedureName, parameters);
}

async function loadMachines(processCd, lineCd) {
  const rows = await execSp('sp_CmMachine_Select', [
    { name: 'ProcessCd', value: processCd, type: sql.VarChar(20) },
    { name: 'LineCd', value: lineCd, type: sql.VarChar(20) },
    { name: 'UseYn', value: 'Y', type: sql.Char(1) },
    { name: 'IncludeHidden', value: 0, type: sql.Bit }
  ]);
  return Array.isArray(rows) ? rows : [];
}

async function loadComponents(processCd, lineCd) {
  const rows = await execSp('sp_Components_Select', [
    { name: 'Company', value: null, type: sql.VarChar(10) },
    { name: 'Factory', value: null, type: sql.VarChar(20) },
    { name: 'MachineNm', value: null, type: sql.NVarChar(100) },
    { name: 'ProcessCd', value: processCd, type: sql.VarChar(20) },
    { name: 'LineCd', value: lineCd, type: sql.VarChar(20) }
  ]);
  return Array.isArray(rows) ? rows : [];
}

async function loadBuncherOnoff() {
  const rows = await execSp('sp_Roller_Run_ONOFF', []);
  return Array.isArray(rows) ? rows : [];
}

function buildRunningMap(machineRows, buncherOnoffRows, processCd, lineCd) {
  /** @type {Map<string, boolean>} */
  const map = new Map();

  if (processCd === 'STRANDING' && lineCd === 'BUNCHER' && buncherOnoffRows) {
    for (const row of buncherOnoffRows) {
      const name = rowStr(row, 'MachineName', 'MACHINE_NAME', 'MACHINE_NM');
      if (!name) continue;
      map.set(name, rowStr(row, 'RUN_DN_TYPE') === '01');
    }
    // ensure registry machines appear even if missing from HQ list
    for (const row of machineRows) {
      const name = rowStr(row, 'MACHINE_NM', 'MACHINE_NAME');
      if (name && !map.has(name)) map.set(name, false);
    }
    return map;
  }

  for (const row of machineRows) {
    const name = rowStr(row, 'MACHINE_NM', 'MACHINE_NAME');
    if (!name) continue;
    const machineNo = rowStr(row, 'MACHINE_NO', 'MACHINE_CD');
    // No plant match → do not accumulate (same as UI "Not found")
    map.set(name, !!machineNo && rowStr(row, 'RUN_DN_TYPE') === '01');
  }
  return map;
}

async function updateRuntimeSec(partId, runtimeSec) {
  await execSp('sp_Components_UpdateRuntime', [
    { name: 'PartId', value: partId, type: sql.VarChar(20) },
    { name: 'MachineNm', value: null, type: sql.NVarChar(100) },
    { name: 'PartSeq', value: null, type: sql.Int },
    { name: 'RuntimeSec', value: runtimeSec, type: sql.BigInt }
  ]);
}

async function tickScope(scope, nowMs, buncherOnoffRows) {
  const { processCd, lineCd } = scope;
  const machines = await loadMachines(processCd, lineCd);
  const components = await loadComponents(processCd, lineCd);
  if (!components.length) return 0;

  const runningMap = buildRunningMap(machines, buncherOnoffRows, processCd, lineCd);
  let writes = 0;

  for (const row of components) {
    const partId = rowStr(row, 'PART_ID');
    const machineNm = rowStr(row, 'MACHINE_NM', 'MACHINE_NAME');
    if (!partId || !machineNm) continue;

    const dbSec = Math.max(0, Math.round(rowNum(row, 'RUNTIME_SEC')));
    const isRunning = runningMap.get(machineNm) === true;
    const key = `${scopeKey(processCd, lineCd)}:${partId}`;
    let st = partState.get(key);

    if (!st) {
      st = {
        partId,
        machineNm,
        runtimeSec: dbSec,
        running: false,
        lastTickMs: nowMs,
        processCd,
        lineCd
      };
      partState.set(key, st);
    }

    // Prefer higher of memory vs DB (another writer / replace)
    if (dbSec > st.runtimeSec) st.runtimeSec = dbSec;
    st.machineNm = machineNm;

    if (isRunning) {
      if (st.running) {
        const elapsedSec = Math.max(0, Math.floor((nowMs - st.lastTickMs) / 1000));
        if (elapsedSec > 0) {
          st.runtimeSec += elapsedSec;
          await updateRuntimeSec(partId, st.runtimeSec);
          writes += 1;
        }
      } else {
        // Stop → Run: start from DB baseline, no backfill gap
        st.runtimeSec = Math.max(st.runtimeSec, dbSec);
      }
      st.running = true;
      st.lastTickMs = nowMs;
    } else if (st.running) {
      // Run → Stop: flush remaining seconds
      const elapsedSec = Math.max(0, Math.floor((nowMs - st.lastTickMs) / 1000));
      if (elapsedSec > 0) st.runtimeSec += elapsedSec;
      await updateRuntimeSec(partId, st.runtimeSec);
      writes += 1;
      st.running = false;
      st.lastTickMs = nowMs;
    } else {
      st.runtimeSec = dbSec;
      st.lastTickMs = nowMs;
    }
  }

  return writes;
}

async function tickOnce() {
  if (runningTick) return;
  runningTick = true;
  const nowMs = Date.now();
  let writes = 0;
  try {
    let buncherOnoff = null;
    try {
      buncherOnoff = await loadBuncherOnoff();
    } catch (e) {
      console.warn('[component-runtime] buncher onoff failed:', e?.message || e);
      buncherOnoff = [];
    }

    for (const scope of SCOPES) {
      try {
        writes += await tickScope(scope, nowMs, buncherOnoff);
      } catch (e) {
        console.warn(
          `[component-runtime] scope ${scope.processCd}/${scope.lineCd || '-'} failed:`,
          e?.message || e
        );
      }
    }

    lastTickAt = new Date().toISOString();
    lastTickOk = true;
    lastError = null;
    lastWrites = writes;
    tickCount += 1;
  } catch (e) {
    lastTickAt = new Date().toISOString();
    lastTickOk = false;
    lastError = e?.message || String(e);
    console.error('[component-runtime] tick failed:', lastError);
  } finally {
    runningTick = false;
  }
}

function getStatus() {
  return {
    enabled: timer != null,
    intervalMs,
    startedAt,
    lastTickAt,
    lastTickOk,
    lastError,
    tickCount,
    lastWrites,
    trackedParts: partState.size,
    scopes: SCOPES
  };
}

function start(options = {}) {
  if (timer) return getStatus();

  const disabled =
    String(process.env.COMPONENT_RUNTIME_WORKER || '1').trim() === '0' ||
    options.disabled === true;
  if (disabled) {
    console.log('[component-runtime] worker disabled (COMPONENT_RUNTIME_WORKER=0)');
    return getStatus();
  }

  intervalMs = Math.max(
    5_000,
    Number(options.intervalMs || process.env.COMPONENT_RUNTIME_TICK_MS || DEFAULT_INTERVAL_MS) ||
      DEFAULT_INTERVAL_MS
  );
  startedAt = new Date().toISOString();
  console.log(`[component-runtime] worker starting (every ${intervalMs}ms)`);

  // First tick shortly after boot so DB pools are ready
  setTimeout(() => {
    void tickOnce();
  }, 2_000);

  timer = setInterval(() => {
    void tickOnce();
  }, intervalMs);
  if (typeof timer.unref === 'function') timer.unref();

  return getStatus();
}

function stop() {
  if (timer) {
    clearInterval(timer);
    timer = null;
  }
  return getStatus();
}

module.exports = {
  start,
  stop,
  tickOnce,
  getStatus,
  SCOPES
};
