/**
 * Parts Monitoring — fixed components (gearbox, skipper SF/SB).
 * Public URL prefix: /components (mounted in app.js)
 *
 * Default paths use localdb. Parallel paths under /components/sfcwr/* use sfcwrdb.
 */
const express = require('express');
const localdbConfig = require('../config/localdb');
const sfcwrdbConfig = require('../config/sfcwrdb');
const database = require('../db/database');
const sql = database.sql;

const router = express.Router();

const PART_KEY_TO_SEQ = {
  gearbox: 1,
  skipperFront: 2,
  skipperBack: 3,
  skipper_bearing_sf: 2,
  skipper_bearing_sb: 3
};

function selectHandler(dbConfig, logTag) {
  return async (req, res) => {
    try {
      const q = req.query || {};
      const company = q.company ?? q.Company ?? q.COMPANY ?? null;
      const factory = q.factory ?? q.Factory ?? q.FACTORY ?? null;
      const machineNm = q.machine_nm ?? q.machineNm ?? q.MachineNm ?? q.MACHINE_NM ?? null;

      const parameters = [
        { name: 'Company', value: company || null },
        { name: 'Factory', value: factory || null },
        { name: 'MachineNm', value: machineNm || null }
      ];

      await database.executeStoredProcedure(res, dbConfig, 'sp_Components_Select', parameters);
    } catch (error) {
      console.error(`components/select${logTag ? ` (${logTag})` : ''}:`, error);
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
      const partId = params.PartId ?? params.PartID ?? params.partId ?? null;
      const machineNm = params.MachineNm ?? params.MachineName ?? params.machineNm ?? null;
      let partSeq = params.PartSeq ?? params.partSeq ?? null;
      const partKey = params.PartKey ?? params.partKey ?? null;
      const runtimeSec = params.RuntimeSec ?? params.runtimeSec ?? params.RUNTIME_SEC ?? null;

      if (partSeq == null && partKey != null) {
        partSeq = PART_KEY_TO_SEQ[partKey] ?? null;
      }

      if (runtimeSec == null || Number(runtimeSec) < 0) {
        return res.status(400).json({ error: 'RuntimeSec is required and must be >= 0' });
      }

      if (!partId && (!machineNm || partSeq == null)) {
        return res.status(400).json({
          error: 'PartId or both MachineName and PartKey/PartSeq are required'
        });
      }

      const parameters = [
        { name: 'PartId', value: partId || null },
        { name: 'MachineNm', value: machineNm || null },
        { name: 'PartSeq', value: partSeq, type: sql.Int },
        { name: 'RuntimeSec', value: runtimeSec, type: sql.BigInt }
      ];

      await database.executeStoredProcedure(res, dbConfig, 'sp_Components_UpdateRuntime', parameters);
    } catch (error) {
      console.error(`components/updateruntime${logTag ? ` (${logTag})` : ''}:`, error);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Internal Server Error' });
      }
    }
  };
}

function updateRuntimeLimitHandler(dbConfig, logTag) {
  return async (req, res) => {
    try {
      const { params = {} } = req.body || {};
      const partId = params.PartId ?? params.PartID ?? params.partId ?? null;
      const machineNm = params.MachineNm ?? params.MachineName ?? params.machineNm ?? null;
      let partSeq = params.PartSeq ?? params.partSeq ?? null;
      const partKey = params.PartKey ?? params.partKey ?? null;
      const runtimeLimit =
        params.RuntimeLimit ?? params.RuntimeLimitHour ?? params.runtimeLimit ?? null;

      if (partSeq == null && partKey != null) {
        partSeq = PART_KEY_TO_SEQ[partKey] ?? null;
      }

      if (runtimeLimit == null || Number(runtimeLimit) <= 0) {
        return res.status(400).json({ error: 'RuntimeLimit is required and must be > 0' });
      }

      if (!partId && (!machineNm || partSeq == null)) {
        return res.status(400).json({
          error: 'PartId or both MachineName and PartKey/PartSeq are required'
        });
      }

      const parameters = [
        { name: 'PartId', value: partId || null },
        { name: 'MachineNm', value: machineNm || null },
        { name: 'PartSeq', value: partSeq, type: sql.Int },
        { name: 'RuntimeLimitHour', value: runtimeLimit, type: sql.Decimal(12, 2) }
      ];

      await database.executeStoredProcedure(res, dbConfig, 'sp_Components_UpdateRuntimeLimit', parameters);
    } catch (error) {
      console.error(`components/updateruntimelimit${logTag ? ` (${logTag})` : ''}:`, error);
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
      const partId = params.PartId ?? params.PartID ?? params.partId ?? null;
      const machineNm = params.MachineNm ?? params.MachineName ?? params.machineNm ?? null;
      let partSeq = params.PartSeq ?? params.partSeq ?? null;
      const partKey = params.PartKey ?? params.partKey ?? null;
      const runtimeLimit = params.RuntimeLimit ?? params.RuntimeLimitHour ?? params.runtimeLimit ?? null;

      if (partSeq == null && partKey != null) {
        partSeq = PART_KEY_TO_SEQ[partKey] ?? null;
      }

      if (!partId && (!machineNm || partSeq == null)) {
        return res.status(400).json({
          error: 'PartId or both MachineName and PartKey/PartSeq are required'
        });
      }

      const parameters = [
        { name: 'PartId', value: partId || null },
        { name: 'MachineNm', value: machineNm || null },
        { name: 'PartSeq', value: partSeq, type: sql.Int },
        {
          name: 'RuntimeLimitHour',
          value: runtimeLimit == null ? null : runtimeLimit,
          type: sql.Decimal(12, 2)
        }
      ];

      await database.executeStoredProcedure(res, dbConfig, 'sp_Components_Replace', parameters);
    } catch (error) {
      console.error(`components/replace${logTag ? ` (${logTag})` : ''}:`, error);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Internal Server Error' });
      }
    }
  };
}

router.get('/select', selectHandler(localdbConfig));
router.post('/replace', replaceHandler(localdbConfig));
router.post('/updateruntime', updateRuntimeHandler(localdbConfig));
router.post('/updateruntimelimit', updateRuntimeLimitHandler(localdbConfig));
router.get('/sfcwr/select', selectHandler(sfcwrdbConfig, 'sfcwr'));
router.post('/sfcwr/replace', replaceHandler(sfcwrdbConfig, 'sfcwr'));
router.post('/sfcwr/updateruntime', updateRuntimeHandler(sfcwrdbConfig, 'sfcwr'));
router.post('/sfcwr/updateruntimelimit', updateRuntimeLimitHandler(sfcwrdbConfig, 'sfcwr'));

module.exports = router;
