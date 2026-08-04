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

const PART_KEY_TO_TYPE = {
  gearbox: 'GEARBOX',
  skipperFront: 'SF',
  skipperBack: 'SB',
  skipper_bearing_sf: 'SF',
  skipper_bearing_sb: 'SB'
};

function historyHandler(dbConfig, logTag) {
  return async (req, res) => {
    try {
      const rows = await database.executeStoredProcedure(
        null,
        dbConfig,
        'sp_Components_SelectComponetsInfoHistory',
        []
      );

      const list = Array.isArray(rows) ? rows : [];
      if (list.length === 0) {
        return res.json([]);
      }

      const partIds = [...new Set(list.map((row) => row.PART_ID).filter(Boolean))];
      if (partIds.length === 0) {
        return res.json(list);
      }

      const idList = partIds.map((id) => `'${String(id).replace(/'/g, "''")}'`).join(',');
      const typeRows = await database.executeQuery(
        null,
        dbConfig,
        `SELECT PART_ID, PART_TYPE FROM dbo.TB_COMPONENTS_TRACKER WHERE PART_ID IN (${idList})`
      );
      const typeById = new Map(
        (typeRows || []).map((row) => [String(row.PART_ID), row.PART_TYPE])
      );

      const enriched = list.map((row) => ({
        ...row,
        PART_TYPE: typeById.get(String(row.PART_ID)) ?? null
      }));

      res.json(enriched);
    } catch (error) {
      console.error(`components/history${logTag ? ` (${logTag})` : ''}:`, error);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Internal Server Error' });
      }
    }
  };
}

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

function insertHandler(dbConfig, logTag) {
  return async (req, res) => {
    try {
      const { params = {} } = req.body || {};
      const company = params.Company ?? params.company ?? 'KSB';
      const factory = params.Factory ?? params.factory ?? 'F002';
      const machineNm = params.MachineNm ?? params.MachineName ?? params.machineNm ?? null;
      const partKey = params.PartKey ?? params.partKey ?? null;
      let partType = params.PartType ?? params.partType ?? null;
      const runtimeLimit =
        params.RuntimeLimit ?? params.RuntimeLimitHour ?? params.runtimeLimit ?? null;

      if (!partType && partKey != null) {
        partType = PART_KEY_TO_TYPE[partKey] ?? null;
      }

      if (!machineNm) {
        return res.status(400).json({ error: 'MachineName is required' });
      }

      if (!partType) {
        return res.status(400).json({ error: 'PartType or PartKey is required' });
      }

      if (runtimeLimit == null || Number(runtimeLimit) <= 0) {
        return res.status(400).json({ error: 'RuntimeLimit is required and must be > 0' });
      }

      const parameters = [
        { name: 'Company', value: company },
        { name: 'Factory', value: factory },
        { name: 'MachineNm', value: machineNm },
        { name: 'PartType', value: partType },
        { name: 'RuntimeLimitHour', value: runtimeLimit, type: sql.Decimal(12, 2) }
      ];

      await database.executeStoredProcedure(res, dbConfig, 'sp_Components_Insert', parameters);
    } catch (error) {
      console.error(`components/insert${logTag ? ` (${logTag})` : ''}:`, error);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Internal Server Error' });
      }
    }
  };
}

function machinesSelectHandler(dbConfig, logTag) {
  return async (req, res) => {
    try {
      const q = req.query || {};
      const processCd = q.process_cd ?? q.processCd ?? q.ProcessCd ?? null;
      const lineCd = q.line_cd ?? q.lineCd ?? q.LineCd ?? null;
      const useYn = q.use_yn ?? q.useYn ?? q.UseYn ?? 'Y';

      const parameters = [
        { name: 'ProcessCd', value: processCd || null },
        { name: 'LineCd', value: lineCd || null },
        { name: 'UseYn', value: useYn || null }
      ];

      await database.executeStoredProcedure(res, dbConfig, 'sp_CmMachine_Select', parameters);
    } catch (error) {
      console.error(`components/machines${logTag ? ` (${logTag})` : ''}:`, error);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Internal Server Error' });
      }
    }
  };
}

function machinesInsertHandler(dbConfig, logTag) {
  return async (req, res) => {
    try {
      const { params = {} } = req.body || {};
      const company = params.Company ?? params.company ?? 'KSB';
      const factory = params.Factory ?? params.factory ?? 'F002';
      const processCd = params.ProcessCd ?? params.processCd ?? params.process_cd ?? null;
      const lineCd = params.LineCd ?? params.lineCd ?? params.line_cd ?? null;
      const machineNm = params.MachineNm ?? params.MachineName ?? params.machineNm ?? null;

      if (!processCd) {
        return res.status(400).json({ error: 'ProcessCd is required' });
      }
      if (!machineNm) {
        return res.status(400).json({ error: 'MachineName is required' });
      }

      const parameters = [
        { name: 'Company', value: String(company), type: sql.VarChar(10) },
        { name: 'Factory', value: String(factory), type: sql.VarChar(20) },
        { name: 'ProcessCd', value: String(processCd), type: sql.VarChar(20) },
        { name: 'LineCd', value: lineCd ? String(lineCd) : null, type: sql.VarChar(20) },
        { name: 'MachineNm', value: String(machineNm), type: sql.NVarChar(100) }
      ];

      await database.executeStoredProcedure(res, dbConfig, 'sp_CmMachine_Insert', parameters);
    } catch (error) {
      console.error(`components/machines/insert${logTag ? ` (${logTag})` : ''}:`, error);
      if (!res.headersSent) {
        res.status(500).json({
          error: 'Stored procedure failed: sp_CmMachine_Insert',
          detail: error?.message || String(error)
        });
      }
    }
  };
}

router.get('/select', selectHandler(localdbConfig));
router.get('/history', historyHandler(localdbConfig));
router.get('/machines', machinesSelectHandler(localdbConfig));
router.post('/machines', machinesInsertHandler(localdbConfig));
router.post('/replace', replaceHandler(localdbConfig));
router.post('/updateruntime', updateRuntimeHandler(localdbConfig));
router.post('/updateruntimelimit', updateRuntimeLimitHandler(localdbConfig));
router.post('/insert', insertHandler(localdbConfig));
router.get('/sfcwr/select', selectHandler(sfcwrdbConfig, 'sfcwr'));
router.get('/sfcwr/history', historyHandler(sfcwrdbConfig, 'sfcwr'));
router.get('/sfcwr/machines', machinesSelectHandler(sfcwrdbConfig, 'sfcwr'));
router.post('/sfcwr/machines', machinesInsertHandler(sfcwrdbConfig, 'sfcwr'));
router.post('/sfcwr/replace', replaceHandler(sfcwrdbConfig, 'sfcwr'));
router.post('/sfcwr/updateruntime', updateRuntimeHandler(sfcwrdbConfig, 'sfcwr'));
router.post('/sfcwr/updateruntimelimit', updateRuntimeLimitHandler(sfcwrdbConfig, 'sfcwr'));
router.post('/sfcwr/insert', insertHandler(sfcwrdbConfig, 'sfcwr'));

module.exports = router;
