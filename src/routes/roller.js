/**
 * Roller monitoring — SQL Server stored procedures (SFC_WR_DB).
 * Public URL prefix: /roller (mounted in app.js)
 */
const express = require('express');
const localdbConfig = require('../config/localdb');
const database = require('../db/database');

const router = express.Router();

router.get('/onoff', async (req, res) => {
  try {
    await database.executeStoredProcedure(res, localdbConfig, 'sp_Roller_Run_ONOFF', []);
  } catch (error) {
    console.error('Error processing the request:', error);
    if (!res.headersSent) {
      res.status(500).json({ error: 'Internal Server Error' });
    }
  }
});

router.get('/list', async (req, res) => {
  try {
    await database.executeStoredProcedure(res, localdbConfig, 'sp_RollerTracker_SelectRoller', []);
  } catch (error) {
    console.error('Error processing the request:', error);
    if (!res.headersSent) {
      res.status(500).json({ error: 'Internal Server Error' });
    }
  }
});

router.get('/activelist', async (req, res) => {
  try {
    await database.executeStoredProcedure(res, localdbConfig, 'sp_RollerTracker_ActiveRoller', []);
  } catch (error) {
    console.error('Error processing the request:', error);
    if (!res.headersSent) {
      res.status(500).json({ error: 'Internal Server Error' });
    }
  }
});

router.get('/currentruntime', async (req, res) => {
  try {
    await database.executeStoredProcedure(res, localdbConfig, 'sp_Roller_Curr_Runtime', []);
  } catch (error) {
    console.error('Error processing the request:', error);
    if (!res.headersSent) {
      res.status(500).json({ error: 'Internal Server Error' });
    }
  }
});

router.get('/history', async (req, res) => {
  try {
    await database.executeStoredProcedure(res, localdbConfig, 'sp_RollerTracker_SelectRollerInfoHistory', []);
  } catch (error) {
    console.error('Error processing the request:', error);
    if (!res.headersSent) {
      res.status(500).json({ error: 'Internal Server Error' });
    }
  }
});

router.post('/updateruntimelimit', async (req, res) => {
  try {
    const parameters = [
      { name: 'RollerId', value: req.body.params.RollerID },
      { name: 'RuntimeLimit', value: req.body.params.RuntimeLimit }
    ];
    await database.executeStoredProcedure(res, localdbConfig, 'sp_Roller_Runtime_Limit_Update', parameters);
  } catch (error) {
    if (!res.headersSent) {
      res.status(500).json({ error: 'Internal Server Error' });
    }
  }
});

router.post('/batchupdateruntimelimit', async (req, res) => {
  try {
    const { params = {} } = req.body || {};
    const { RollerID, RollerIDs, RuntimeLimit } = params;

    if (RuntimeLimit == null) {
      return res.status(400).json({ error: 'RuntimeLimit is required' });
    }

    if (Array.isArray(RollerIDs) ? RollerIDs.length : typeof RollerIDs === 'string') {
      const idsCsv = Array.isArray(RollerIDs)
        ? RollerIDs.map(s => String(s).trim()).filter(Boolean).join(',')
        : String(RollerIDs).split(',').map(s => s.trim()).filter(Boolean).join(',');

      if (!idsCsv) {
        return res.status(400).json({ error: 'RollerIDs cannot be empty' });
      }

      const parameters = [
        { name: 'RollerIds', value: idsCsv },
        { name: 'RuntimeLimit', value: RuntimeLimit }
      ];
      return database.executeStoredProcedure(res, localdbConfig, 'sp_Roller_Runtime_Limit_BatchUpdate', parameters);
    }

    if (!RollerID) {
      return res.status(400).json({ error: 'RollerID or RollerIDs is required' });
    }

    const parameters = [
      { name: 'RollerId', value: RollerID },
      { name: 'RuntimeLimit', value: RuntimeLimit }
    ];
    return database.executeStoredProcedure(res, localdbConfig, 'sp_Roller_Runtime_Limit_Update', parameters);
  } catch (error) {
    if (!res.headersSent) {
      res.status(500).json({ error: 'Internal Server Error' });
    }
  }
});

router.post('/replace', async (req, res) => {
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

    await database.executeStoredProcedure(res, localdbConfig, 'sp_RollerTracker_InsertReplacement', parameters);
  } catch (error) {
    if (!res.headersSent) {
      res.status(500).json({ error: 'Internal Server Error' });
    }
  }
});

module.exports = router;
