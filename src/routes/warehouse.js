/**
 * Warehouse — material verification M2B (material → bin), separate from legacy KBAS090 rack API.
 *
 * GET /warehouse/sfcwr/material-verification-m2b
 *   → dbo.sp_MaterialVerification_M2B_Select
 */
const express = require('express');
const sfcwrdbConfig = require('../config/sfcwrdb');
const database = require('../db/database');

const router = express.Router();

router.get('/', (req, res) => {
  res.json({
    area: 'warehouse',
    endpoints: [
      {
        method: 'GET',
        path: '/warehouse/sfcwr/material-verification-m2b',
        query: 'lang=EN (optional)',
        description: 'Material → bin verification grid (sp_MaterialVerification_M2B_Select)'
      }
    ]
  });
});

router.get('/sfcwr/material-verification-m2b', async (req, res) => {
  try {
    const q = req.query || {};
    const lang = String(q.lang ?? q.LANG ?? 'EN').trim() || 'EN';
    await database.executeStoredProcedure(
      res,
      sfcwrdbConfig,
      'sp_MaterialVerification_M2B_Select',
      [{ name: 'LANG', value: lang }],
      { timeoutMs: 120000 }
    );
  } catch (error) {
    console.error('material-verification-m2b:', error);
    if (!res.headersSent) {
      res.status(500).json({ error: 'Internal Server Error' });
    }
  }
});

module.exports = router;
