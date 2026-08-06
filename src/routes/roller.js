/**
 * Roller monitoring — SQL Server stored procedures (SFC_WR_DB).
 * Public URL prefix: /roller (mounted in app.js)
 *
 * Default paths use localdb. Parallel paths under /roller/sfcwr/* use sfcwrdb (remote server).
 */
const express = require('express');
const localdbConfig = require('../config/localdb');
const sfcwrdbConfig = require('../config/sfcwrdb');
const database = require('../db/database');
const sql = database.sql;

const router = express.Router();

function onoffHandler(dbConfig, logTag) {
  return async (req, res) => {
    try {
      await database.executeStoredProcedure(res, dbConfig, 'sp_Roller_Run_ONOFF', []);
    } catch (error) {
      console.error(`roller/onoff${logTag ? ` (${logTag})` : ''}:`, error);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Internal Server Error' });
      }
    }
  };
}

function processQueryParams(q) {
  const processCd = q.process_cd ?? q.processCd ?? q.ProcessCd ?? null;
  const lineCd = q.line_cd ?? q.lineCd ?? q.LineCd ?? null;
  return {
    processCd: processCd ? String(processCd).trim().toUpperCase() : null,
    lineCd: lineCd ? String(lineCd).trim().toUpperCase() : null
  };
}

function listHandler(dbConfig, logTag) {
  return async (req, res) => {
    try {
      const { processCd, lineCd } = processQueryParams(req.query || {});
      const parameters = [
        { name: 'ProcessCd', value: processCd || 'STRANDING', type: sql.VarChar(20) },
        { name: 'LineCd', value: lineCd || null, type: sql.VarChar(20) }
      ];
      await database.executeStoredProcedure(res, dbConfig, 'sp_RollerTracker_SelectRoller', parameters);
    } catch (error) {
      console.error(`roller/list${logTag ? ` (${logTag})` : ''}:`, error);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Internal Server Error' });
      }
    }
  };
}

function activelistHandler(dbConfig, logTag) {
  return async (req, res) => {
    try {
      const { processCd, lineCd } = processQueryParams(req.query || {});
      const parameters = [
        { name: 'ProcessCd', value: processCd || 'STRANDING', type: sql.VarChar(20) },
        { name: 'LineCd', value: lineCd || null, type: sql.VarChar(20) }
      ];
      await database.executeStoredProcedure(res, dbConfig, 'sp_RollerTracker_ActiveRoller', parameters);
    } catch (error) {
      console.error(`roller/activelist${logTag ? ` (${logTag})` : ''}:`, error);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Internal Server Error' });
      }
    }
  };
}

function currentruntimeHandler(dbConfig, logTag) {
  return async (req, res) => {
    try {
      const { processCd, lineCd } = processQueryParams(req.query || {});
      const parameters = [
        { name: 'RollerId', value: null, type: sql.VarChar(30) },
        { name: 'OnlyActive', value: 1, type: sql.Bit },
        { name: 'ProcessCd', value: processCd || null, type: sql.VarChar(20) },
        { name: 'LineCd', value: lineCd || null, type: sql.VarChar(20) }
      ];
      await database.executeStoredProcedure(res, dbConfig, 'sp_Roller_Curr_Runtime', parameters);
    } catch (error) {
      console.error(`roller/currentruntime${logTag ? ` (${logTag})` : ''}:`, error);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Internal Server Error' });
      }
    }
  };
}

function historyHandler(dbConfig, logTag) {
  return async (req, res) => {
    try {
      await database.executeStoredProcedure(res, dbConfig, 'sp_RollerTracker_SelectRollerInfoHistory', []);
    } catch (error) {
      console.error(`roller/history${logTag ? ` (${logTag})` : ''}:`, error);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Internal Server Error' });
      }
    }
  };
}

function updateruntimelimitHandler(dbConfig, logTag) {
  return async (req, res) => {
    try {
      const { params = {} } = req.body || {};
      const rollerId = params.RollerID ?? params.RollerId ?? params.rollerId ?? null;
      const runtimeLimit = params.RuntimeLimit ?? params.runtimeLimit ?? null;

      if (!rollerId) {
        return res.status(400).json({ error: 'RollerID is required' });
      }
      if (runtimeLimit == null || Number(runtimeLimit) <= 0) {
        return res.status(400).json({ error: 'RuntimeLimit is required and must be > 0' });
      }

      const parameters = [
        { name: 'RollerId', value: String(rollerId), type: sql.VarChar(30) },
        { name: 'RuntimeLimit', value: Number(runtimeLimit), type: sql.Decimal(18, 2) }
      ];
      await database.executeStoredProcedure(res, dbConfig, 'sp_Roller_Runtime_Limit_Update', parameters);
    } catch (error) {
      console.error(`roller/updateruntimelimit${logTag ? ` (${logTag})` : ''}:`, error);
      if (!res.headersSent) {
        res.status(500).json({
          error: 'Stored procedure failed: sp_Roller_Runtime_Limit_Update',
          detail: error?.message || String(error)
        });
      }
    }
  };
}

function batchupdateruntimelimitHandler(dbConfig, logTag) {
  return async (req, res) => {
    try {
      const { params = {} } = req.body || {};
      const { RollerID, RollerIDs, RuntimeLimit } = params;

      if (RuntimeLimit == null || Number(RuntimeLimit) <= 0) {
        return res.status(400).json({ error: 'RuntimeLimit is required and must be > 0' });
      }

      if (Array.isArray(RollerIDs) ? RollerIDs.length : typeof RollerIDs === 'string') {
        const idsCsv = Array.isArray(RollerIDs)
          ? RollerIDs.map((s) => String(s).trim()).filter(Boolean).join(',')
          : String(RollerIDs).split(',').map((s) => s.trim()).filter(Boolean).join(',');

        if (!idsCsv) {
          return res.status(400).json({ error: 'RollerIDs cannot be empty' });
        }

        const parameters = [
          { name: 'RollerIds', value: idsCsv, type: sql.NVarChar(sql.MAX) },
          { name: 'RuntimeLimit', value: Number(RuntimeLimit), type: sql.Decimal(10, 2) }
        ];
        await database.executeStoredProcedure(res, dbConfig, 'sp_Roller_Runtime_Limit_BatchUpdate', parameters);
        return;
      }

      if (!RollerID) {
        return res.status(400).json({ error: 'RollerID or RollerIDs is required' });
      }

      const parameters = [
        { name: 'RollerId', value: String(RollerID), type: sql.VarChar(30) },
        { name: 'RuntimeLimit', value: Number(RuntimeLimit), type: sql.Decimal(18, 2) }
      ];
      await database.executeStoredProcedure(res, dbConfig, 'sp_Roller_Runtime_Limit_Update', parameters);
    } catch (error) {
      console.error(`roller/batchupdateruntimelimit${logTag ? ` (${logTag})` : ''}:`, error);
      if (!res.headersSent) {
        res.status(500).json({
          error: 'Stored procedure failed: sp_Roller_Runtime_Limit_BatchUpdate',
          detail: error?.message || String(error)
        });
      }
    }
  };
}

function replaceHandler(dbConfig, logTag) {
  return async (req, res) => {
    try {
      const { params = {} } = req.body || {};
      const { BinLocation, Company, Factory, RuntimeLimitDefault } = params;

      if (!BinLocation) {
        return res.status(400).json({ error: "BinLocation is required (e.g. 'ST0009_0001')" });
      }

      const parameters = [
        { name: 'BinLocationCd', value: BinLocation },
        { name: 'Company', value: Company ?? null },
        { name: 'Factory', value: Factory ?? null },
        { name: 'RuntimeLimitDefault', value: RuntimeLimitDefault ?? null }
      ];

      await database.executeStoredProcedure(res, dbConfig, 'sp_RollerTracker_InsertReplacement', parameters);
    } catch (error) {
      console.error(`roller/replace${logTag ? ` (${logTag})` : ''}:`, error);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Internal Server Error' });
      }
    }
  };
}

function updateRuntimeHandler(dbConfig, logTag) {
  return async (req, res) => {
    try {
      const { params = {} } = req.body || {};
      const rollerId = params.RollerId ?? params.RollerID ?? params.rollerId ?? null;
      const binLocation =
        params.BinLocation ?? params.BinLocationCd ?? params.binLocation ?? null;
      const runtimeSec = params.RuntimeSec ?? params.runtimeSec ?? params.RUNTIME_SEC ?? null;

      if (runtimeSec == null || Number(runtimeSec) < 0) {
        return res.status(400).json({ error: 'RuntimeSec is required and must be >= 0' });
      }

      if (!rollerId && !binLocation) {
        return res.status(400).json({ error: 'RollerId or BinLocation is required' });
      }

      const parameters = [
        { name: 'RollerId', value: rollerId || null },
        { name: 'BinLocationCd', value: binLocation || null },
        { name: 'RuntimeSec', value: runtimeSec, type: sql.BigInt }
      ];

      await database.executeStoredProcedure(res, dbConfig, 'sp_Roller_UpdateRuntime', parameters);
    } catch (error) {
      console.error(`roller/updateruntime${logTag ? ` (${logTag})` : ''}:`, error);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Internal Server Error' });
      }
    }
  };
}

// localdb (127.0.0.1)
router.get('/onoff', onoffHandler(localdbConfig));
router.get('/list', listHandler(localdbConfig));
router.get('/activelist', activelistHandler(localdbConfig));
router.get('/currentruntime', currentruntimeHandler(localdbConfig));
router.get('/history', historyHandler(localdbConfig));
router.post('/updateruntimelimit', updateruntimelimitHandler(localdbConfig));
router.post('/batchupdateruntimelimit', batchupdateruntimelimitHandler(localdbConfig));
router.post('/updateruntime', updateRuntimeHandler(localdbConfig));
router.post('/replace', replaceHandler(localdbConfig));

// sfcwrdb (194.1.31.3)
router.get('/sfcwr/onoff', onoffHandler(sfcwrdbConfig, 'sfcwr'));
router.get('/sfcwr/list', listHandler(sfcwrdbConfig, 'sfcwr'));
router.get('/sfcwr/activelist', activelistHandler(sfcwrdbConfig, 'sfcwr'));
router.get('/sfcwr/currentruntime', currentruntimeHandler(sfcwrdbConfig, 'sfcwr'));
router.get('/sfcwr/history', historyHandler(sfcwrdbConfig, 'sfcwr'));
router.post('/sfcwr/updateruntimelimit', updateruntimelimitHandler(sfcwrdbConfig, 'sfcwr'));
router.post('/sfcwr/batchupdateruntimelimit', batchupdateruntimelimitHandler(sfcwrdbConfig, 'sfcwr'));
router.post('/sfcwr/updateruntime', updateRuntimeHandler(sfcwrdbConfig, 'sfcwr'));
router.post('/sfcwr/replace', replaceHandler(sfcwrdbConfig, 'sfcwr'));

module.exports = router;
