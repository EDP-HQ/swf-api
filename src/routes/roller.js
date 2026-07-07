/**
 * Roller monitoring — SQL Server stored procedures (SFC_WR_DB).
 * Public URL prefix: /roller (mounted in app.js)
 *
 * All paths use sfcwrdb (SFC_WR_DB on 194.1.31.3).
 */
const express = require('express');
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

function listHandler(dbConfig, logTag) {
  return async (req, res) => {
    try {
      await database.executeStoredProcedure(res, dbConfig, 'sp_RollerTracker_SelectRoller', []);
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
      await database.executeStoredProcedure(res, dbConfig, 'sp_RollerTracker_ActiveRoller', []);
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
      await database.executeStoredProcedure(res, dbConfig, 'sp_Roller_Curr_Runtime', []);
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
      const parameters = [
        { name: 'RollerId', value: req.body.params.RollerID },
        { name: 'RuntimeLimit', value: req.body.params.RuntimeLimit }
      ];
      await database.executeStoredProcedure(res, dbConfig, 'sp_Roller_Runtime_Limit_Update', parameters);
    } catch (error) {
      console.error(`roller/updateruntimelimit${logTag ? ` (${logTag})` : ''}:`, error);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Internal Server Error' });
      }
    }
  };
}

function batchupdateruntimelimitHandler(dbConfig, logTag) {
  return async (req, res) => {
    try {
      const { params = {} } = req.body || {};
      const { RollerID, RollerIDs, RuntimeLimit } = params;

      if (RuntimeLimit == null) {
        return res.status(400).json({ error: 'RuntimeLimit is required' });
      }

      if (Array.isArray(RollerIDs) ? RollerIDs.length : typeof RollerIDs === 'string') {
        const idsCsv = Array.isArray(RollerIDs)
          ? RollerIDs.map((s) => String(s).trim()).filter(Boolean).join(',')
          : String(RollerIDs).split(',').map((s) => s.trim()).filter(Boolean).join(',');

        if (!idsCsv) {
          return res.status(400).json({ error: 'RollerIDs cannot be empty' });
        }

        const parameters = [
          { name: 'RollerIds', value: idsCsv },
          { name: 'RuntimeLimit', value: RuntimeLimit }
        ];
        return database.executeStoredProcedure(res, dbConfig, 'sp_Roller_Runtime_Limit_BatchUpdate', parameters);
      }

      if (!RollerID) {
        return res.status(400).json({ error: 'RollerID or RollerIDs is required' });
      }

      const parameters = [
        { name: 'RollerId', value: RollerID },
        { name: 'RuntimeLimit', value: RuntimeLimit }
      ];
      return database.executeStoredProcedure(res, dbConfig, 'sp_Roller_Runtime_Limit_Update', parameters);
    } catch (error) {
      console.error(`roller/batchupdateruntimelimit${logTag ? ` (${logTag})` : ''}:`, error);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Internal Server Error' });
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
