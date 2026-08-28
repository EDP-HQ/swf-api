/**
 * Machine efficiency — live read of USP_SFC_KPRD060_R10 + USP_SFC_CALL031_R10.
 * Does NOT alter any stored procedure.
 *
 * GET /efficiency              — module summary
 * GET /efficiency/sfcwr/runs   — production runs (mapped)
 * GET /efficiency/sfcwr/calls  — machine calls (mapped)
 * GET /efficiency/sfcwr/bundle — runs + calls with calls attached to runs
 *
 * Query: dateFrom, dateTo (YYYY-MM-DD), process (DRAWING|STRANDING|DW|ST),
 *        machine (optional MACHINE_CD prefix), company, factory, lang
 */
const express = require('express');
const sfcwrdbConfig = require('../config/sfcwrdb');
const bobbinApi = require('../config/bobbinApi');
const database = require('../db/database');
const sql = database.sql;
const {
  ymdToSpDate,
  processToWoId,
  mapProductionRow,
  mapCallRow,
  attachCallsToRuns
} = require('../services/efficiencyMap');

const router = express.Router();

function parseQuery(q) {
  const dateFrom = q.dateFrom || q.date_from || q.sdate;
  const dateTo = q.dateTo || q.date_to || q.edate;
  if (!dateFrom || !dateTo) {
    return {
      error: 'Missing dateFrom/dateTo (YYYY-MM-DD)',
      example: '/efficiency/sfcwr/bundle?dateFrom=2026-08-19&dateTo=2026-08-19&process=DRAWING'
    };
  }
  return {
    company: String(q.company || bobbinApi.company || 'KSB'),
    factory: String(q.factory || bobbinApi.factory || 'F002'),
    dateFrom: ymdToSpDate(dateFrom),
    dateTo: ymdToSpDate(dateTo),
    process: processToWoId(q.process || 'DW'),
    machine: String(q.machine || q.machineCd || ''),
    // KPRD works with ENG; CALL type names need MA/KO (ENG returns null labels)
    prodLang: String(q.prodLang || q.lang || bobbinApi.lang || 'ENG'),
    callLang: String(q.callLang || 'MA')
  };
}

async function fetchProdRows(params) {
  return database.executeStoredProcedure(null, sfcwrdbConfig, 'USP_SFC_KPRD060_R10', [
    { name: 'COMPANY', type: sql.VarChar(20), value: params.company },
    { name: 'FACTORY', type: sql.VarChar(20), value: params.factory },
    { name: 'SDATE', type: sql.NVarChar(10), value: params.dateFrom },
    { name: 'EDATE', type: sql.NVarChar(10), value: params.dateTo },
    { name: 'WO_PROCESS_ID', type: sql.NVarChar(20), value: params.process },
    { name: 'MACHINE_CD', type: sql.NVarChar(20), value: params.machine },
    { name: 'LANG', type: sql.VarChar(5), value: params.prodLang }
  ]);
}

async function fetchCallRows(params) {
  return database.executeStoredProcedure(null, sfcwrdbConfig, 'USP_SFC_CALL031_R10', [
    { name: 'COMPANY', type: sql.NVarChar(20), value: params.company },
    { name: 'FACTORY', type: sql.NVarChar(20), value: params.factory },
    { name: 'CALL_DIV', type: sql.NVarChar(20), value: '' },
    { name: 'MACHINE_CD', type: sql.NVarChar(20), value: params.machine },
    { name: 'SDATE', type: sql.NVarChar(8), value: params.dateFrom },
    { name: 'EDATE', type: sql.NVarChar(8), value: params.dateTo },
    { name: 'CALL_TP', type: sql.NVarChar(10), value: '' },
    { name: 'CALL_SETTLE_YN', type: sql.NVarChar(1), value: '' },
    { name: 'LANG', type: sql.VarChar(5), value: params.callLang }
  ]);
}

router.get('/', (req, res) => {
  res.json({
    module: 'machine-efficiency',
    note: 'Read-only SP access — USP_SFC_KPRD060_R10 + USP_SFC_CALL031_R10 (no SP changes)',
    endpoints: [
      'GET /efficiency/sfcwr/runs?dateFrom=&dateTo=&process=DRAWING|STRANDING',
      'GET /efficiency/sfcwr/calls?dateFrom=&dateTo=',
      'GET /efficiency/sfcwr/bundle?dateFrom=&dateTo=&process=DRAWING|STRANDING'
    ],
    defaults: {
      company: bobbinApi.company,
      factory: bobbinApi.factory
    }
  });
});

router.get('/sfcwr/runs', async (req, res) => {
  try {
    const params = parseQuery(req.query || {});
    if (params.error) return res.status(400).json(params);
    const raw = (await fetchProdRows(params)) || [];
    const runs = raw.map(mapProductionRow).filter((r) => r.start && r.end);
    res.json({
      source: 'USP_SFC_KPRD060_R10',
      params,
      count: runs.length,
      runs
    });
  } catch (error) {
    console.error('efficiency runs:', error);
    if (!res.headersSent) {
      res.status(500).json({ error: error?.message || 'Failed to load production runs' });
    }
  }
});

router.get('/sfcwr/calls', async (req, res) => {
  try {
    const params = parseQuery(req.query || {});
    if (params.error) return res.status(400).json(params);
    const raw = (await fetchCallRows(params)) || [];
    const calls = raw.map(mapCallRow).filter((c) => c.callTime);
    res.json({
      source: 'USP_SFC_CALL031_R10',
      params,
      count: calls.length,
      calls
    });
  } catch (error) {
    console.error('efficiency calls:', error);
    if (!res.headersSent) {
      res.status(500).json({ error: error?.message || 'Failed to load machine calls' });
    }
  }
});

router.get('/sfcwr/bundle', async (req, res) => {
  try {
    const params = parseQuery(req.query || {});
    if (params.error) return res.status(400).json(params);

    const [prodRaw, callRaw] = await Promise.all([fetchProdRows(params), fetchCallRows(params)]);
    const runsBase = (prodRaw || []).map(mapProductionRow).filter((r) => r.start && r.end);
    const calls = (callRaw || []).map(mapCallRow).filter((c) => c.callTime);

    // Keep calls relevant to this process when WO_PROCESS_ID is present on the call
    const processCalls = calls.filter(
      (c) => !c.woProcessId || String(c.woProcessId).toUpperCase() === params.process
    );

    const runs = attachCallsToRuns(runsBase, processCalls);

    res.json({
      sources: {
        production: 'USP_SFC_KPRD060_R10',
        calls: 'USP_SFC_CALL031_R10'
      },
      params,
      count: { runs: runs.length, calls: processCalls.length },
      runs,
      calls: processCalls
    });
  } catch (error) {
    console.error('efficiency bundle:', error);
    if (!res.headersSent) {
      res.status(500).json({ error: error?.message || 'Failed to load efficiency bundle' });
    }
  }
});

module.exports = router;
