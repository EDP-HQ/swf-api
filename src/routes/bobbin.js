/**
 * Bobbin monitoring — add routes here as you wire SQL Server stored procedures.
 * Public URL prefix: /bobbin (mounted in app.js)
 *
 * Default paths use localdb. Parallel paths under /bobbin/sfcwr/* use sfcwrdb (real server).
 */
const express = require('express');
const localdbConfig = require('../config/localdb');
const sfcwrdbConfig = require('../config/sfcwrdb');
const bobbinApi = require('../config/bobbinApi');
const database = require('../db/database');
const sql = database.sql;

const router = express.Router();

function bobbincycleHandler(dbConfig, logTag) {
  return async (req, res) => {
    try {
      const q = req.query || {};
      const lcCd = q.lc_cd ?? q.LC_CD;

      if (!lcCd) {
        return res.status(400).json({
          error: 'Missing query parameters',
          required: ['lc_cd'],
          example: `${logTag === 'sfcwr' ? '/bobbin/sfcwr/bobbincycle' : '/bobbin/bobbincycle'}?lc_cd=4977`
        });
      }

      const parameters = [
        { name: 'COMPANY', value: bobbinApi.company },
        { name: 'FACTORY', value: bobbinApi.factory },
        { name: 'LC_CD', value: lcCd },
        { name: 'LANG', value: bobbinApi.lang }
      ];
      await database.executeStoredProcedure(res, dbConfig, 'sp_Bobbin_Cycle', parameters);
    } catch (error) {
      console.error(`bobbincycle${logTag ? ` (${logTag})` : ''}:`, error);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Internal Server Error' });
      }
    }
  };
}

function limitwarningGetHandler(dbConfig, logTag) {
  return async (req, res) => {
    try {
      await database.executeStoredProcedure(res, dbConfig, 'sp_Bobbin_Limit_Warning_Select', []);
    } catch (error) {
      console.error(`limitwarning GET${logTag ? ` (${logTag})` : ''}:`, error);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Internal Server Error' });
      }
    }
  };
}

function limitwarningPostHandler(dbConfig, logTag) {
  return async (req, res) => {
    try {
      const b = req.body || {};
      const toInt = (v) => {
        const n = parseInt(String(v), 10);
        return Number.isInteger(n) ? n : NaN;
      };
      const bobbinCycleLimit = toInt(b.bobbinCycleLimit);
      const bobbinLifeSpanLimit = toInt(b.bobbinLifeSpanLimit);
      const bobbinCycleWarning = toInt(b.bobbinCycleWarning);
      const bobbinLifespanWarning = toInt(b.bobbinLifespanWarning);

      const nums = [bobbinCycleLimit, bobbinLifeSpanLimit, bobbinCycleWarning, bobbinLifespanWarning];
      if (nums.some((n) => !Number.isInteger(n) || n < 1)) {
        return res.status(400).json({ error: 'All fields must be integers ≥ 1.' });
      }
      if (bobbinCycleWarning > 100 || bobbinLifespanWarning > 100) {
        return res.status(400).json({ error: 'Warning fields must be 1–100 (percent).' });
      }

      await database.executeStoredProcedure(
        null,
        dbConfig,
        'sp_Bobbin_Limit_Warning_Update',
        [
          { name: 'DateTime', type: sql.DateTime, value: new Date() },
          { name: 'BobbinCycleLimit', type: sql.Int, value: bobbinCycleLimit },
          { name: 'BobbinLifeSpanLimit', type: sql.Int, value: bobbinLifeSpanLimit },
          { name: 'BobbinCycleWarning', type: sql.Int, value: bobbinCycleWarning },
          { name: 'BobbinLifespanWarning', type: sql.Int, value: bobbinLifespanWarning }
        ]
      );
      res.json({ ok: true });
    } catch (error) {
      console.error(`limitwarning POST${logTag ? ` (${logTag})` : ''}:`, error);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Internal Server Error' });
      }
    }
  };
}

/** Bobbin tracker login — dbo.sp_Bobbin_Tracker_Login_Check (company/factory/lang from bobbinApi). */
function pdaLoginHandler(dbConfig, logTag) {
  return async (req, res) => {
    try {
      const b = req.body || {};
      const empCd = String(b.emp_cd ?? b.EMP_CD ?? '').trim();
      const lang = String(b.lang ?? b.LANG ?? bobbinApi.lang ?? 'ENG').trim() || 'ENG';

      if (!empCd) {
        return res.status(400).json({
          error: 'Missing body fields',
          required: ['emp_cd'],
          example: { emp_cd: 'E12345' }
        });
      }

      const parameters = [
        { name: 'COMPANY', value: bobbinApi.company },
        { name: 'FACTORY', value: bobbinApi.factory },
        { name: 'EMP_CD', value: empCd },
        { name: 'LANG', value: lang }
      ];

      const rows = await database.executeStoredProcedure(
        null,
        dbConfig,
        'sp_Bobbin_Tracker_Login_Check',
        parameters
      );

      const list = Array.isArray(rows) ? rows : [];
      if (!list.length) {
        return res.status(401).json({ error: 'Login failed: no matching employee for company/factory.' });
      }

      const row = list[0];
      res.json({
        ok: true,
        empCd: row.EMP_CD ?? row.emp_cd ?? empCd,
        empName: row.EMP_NAME ?? row.emp_name ?? null,
        permId: row.PERM_ID ?? row.perm_id ?? null
      });
    } catch (error) {
      const msg = error?.message || String(error);
      const isLoginDenied =
        /usr|user|exist|login|ng|invalid|not exist|해당|denied|failed/i.test(msg) ||
        error?.number === 50000 ||
        error?.originalError?.info?.number === 50000;
      const status = isLoginDenied ? 401 : 500;
      console.error(`pdalogin${logTag ? ` (${logTag})` : ''}:`, error);
      if (!res.headersSent) {
        res.status(status).json({ error: msg });
      }
    }
  };
}

/** PDA scrap / inventory move — dbo.USP_SFC_PDA_SCRAP_I10 (COMPANY/FACTORY same constants as bobbincycle; LANG fixed ENG). */
function pdaScrapHandler(dbConfig, logTag) {
  return async (req, res) => {
    try {
      const b = req.body || {};
      const lcCd = String(b.lc_cd ?? b.LC_CD ?? '').trim();
      const user = String(b.user ?? b.USER ?? b.emp_cd ?? b.EMP_CD ?? '').trim();
      const lang = 'ENG';

      if (!lcCd) {
        return res.status(400).json({
          error: 'Missing body fields',
          required: ['lc_cd'],
          example: { lc_cd: 'PB18_3668', emp_cd: '040403' }
        });
      }
      if (!user) {
        return res.status(400).json({
          error: 'Missing user',
          required: ['emp_cd or user'],
          example: { lc_cd: 'PB18_3668', emp_cd: '040403' }
        });
      }

      const parameters = [
        { name: 'COMPANY', value: bobbinApi.company },
        { name: 'FACTORY', value: bobbinApi.factory },
        { name: 'LC_CD', value: lcCd },
        { name: 'USER', value: user },
        { name: 'LANG', value: lang, type: sql.VarChar(5) }
      ];

      await database.executeStoredProcedure(null, dbConfig, 'USP_SFC_PDA_SCRAP_I10', parameters);
      res.json({ ok: true });
    } catch (error) {
      const msg = error?.message || String(error);
      const isBizRule =
        /E900|PDA031|E90032|E90033|scrap|inventory|공급|없습니다|처리|임시|보빈|LoginUsr|error info/i.test(
          msg
        ) ||
        error?.number === 50000 ||
        error?.originalError?.info?.number === 50000;
      const status = isBizRule ? 422 : 500;
      console.error(`pdascrap${logTag ? ` (${logTag})` : ''}:`, error);
      if (!res.headersSent) {
        res.status(status).json({ error: msg });
      }
    }
  };
}

function bobbinlifespanHandler(dbConfig, logTag) {
  return async (req, res) => {
    try {
      const q = req.query || {};
      const lcCd = q.lc_cd ?? q.LC_CD;

      if (!lcCd) {
        return res.status(400).json({
          error: 'Missing query parameters',
          required: ['lc_cd'],
          example:
            logTag === 'sfcwr'
              ? '/bobbin/sfcwr/bobbinlifespan?lc_cd=4977'
              : '/bobbin/bobbinlifespan?lc_cd=4977'
        });
      }

      const parameters = [{ name: 'LC_CD', value: lcCd }];
      await database.executeStoredProcedure(res, dbConfig, 'sp_BobbinStartDate', parameters);
    } catch (error) {
      console.error(`bobbinlifespan${logTag ? ` (${logTag})` : ''}:`, error);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Internal Server Error' });
      }
    }
  };
}

/** Overview for clients and operators */
router.get('/', (req, res) => {
  res.json({
    module: 'bobbin-monitoring',
    service: 'swf-api',
    prefix: '/bobbin',
    databases: {
      local:
        'localdb — … bobbincycle, bobbinlifespan, limitwarning, POST pdalogin, POST pdascrap',
      sfcwr:
        'sfcwrdb (remote) — … sfcwr/* same + POST /bobbin/sfcwr/pdalogin, POST /bobbin/sfcwr/pdascrap'
    },
    endpoints: [
      { method: 'GET', path: '/bobbin', description: 'This summary' },
      {
        method: 'GET',
        path: '/bobbin/bobbincycle',
        description:
          'localdb — USP_SFC_KPRD010_R10 — query: lc_cd; company/factory/lang from bobbinApi config'
      },
      {
        method: 'GET',
        path: '/bobbin/sfcwr/bobbincycle',
        description: 'sfcwrdb — same SP and parameters as /bobbin/bobbincycle'
      },
      {
        method: 'GET',
        path: '/bobbin/bobbinlifespan',
        description: 'localdb — BobbinStartDate — query: lc_cd (first cycle date)'
      },
      {
        method: 'GET',
        path: '/bobbin/sfcwr/bobbinlifespan',
        description: 'sfcwrdb — same as /bobbin/bobbinlifespan'
      },
      {
        method: 'GET',
        path: '/bobbin/limitwarning',
        description: 'localdb — sp_Bobbin_Limit_Warning_Select — latest TB_BOBBIN_LIMIT row'
      },
      {
        method: 'GET',
        path: '/bobbin/sfcwr/limitwarning',
        description: 'sfcwrdb — same as /bobbin/limitwarning'
      },
      {
        method: 'POST',
        path: '/bobbin/limitwarning',
        body: '{ bobbinCycleLimit, bobbinLifeSpanLimit, bobbinCycleWarning, bobbinLifespanWarning }',
        description: 'localdb — sp_Bobbin_Limit_Warning_Update — insert TB_BOBBIN_LIMIT'
      },
      {
        method: 'POST',
        path: '/bobbin/sfcwr/limitwarning',
        body: '{ bobbinCycleLimit, bobbinLifeSpanLimit, bobbinCycleWarning, bobbinLifespanWarning }',
        description: 'sfcwrdb — same as POST /bobbin/limitwarning'
      },
      {
        method: 'POST',
        path: '/bobbin/pdalogin',
        body: '{ emp_cd } optional lang — company/factory from bobbinApi config',
        description: 'localdb — sp_Bobbin_Tracker_Login_Check → TB_CD_EMP'
      },
      {
        method: 'POST',
        path: '/bobbin/sfcwr/pdalogin',
        body: 'same as POST /bobbin/pdalogin',
        description: 'sfcwrdb — same stored procedure as /bobbin/pdalogin'
      },
      {
        method: 'POST',
        path: '/bobbin/pdascrap',
        body: '{ lc_cd: full bobbin code, emp_cd } — COMPANY/FACTORY same as bobbincycle (bobbinApi); USER=emp_cd; LANG always ENG (lc_cd is not last-4-only)',
        description: 'localdb — USP_SFC_PDA_SCRAP_I10 (scrap / TB_INVENTORY_SCRAP + delete inventory)'
      },
      {
        method: 'POST',
        path: '/bobbin/sfcwr/pdascrap',
        body: 'same as POST /bobbin/pdascrap',
        description: 'sfcwrdb — same as /bobbin/pdascrap'
      }
    ]
  });
});

router.get('/bobbincycle', bobbincycleHandler(localdbConfig));
router.get('/sfcwr/bobbincycle', bobbincycleHandler(sfcwrdbConfig, 'sfcwr'));

router.get('/limitwarning', limitwarningGetHandler(localdbConfig));
router.get('/sfcwr/limitwarning', limitwarningGetHandler(sfcwrdbConfig, 'sfcwr'));

router.post('/limitwarning', limitwarningPostHandler(localdbConfig));
router.post('/sfcwr/limitwarning', limitwarningPostHandler(sfcwrdbConfig, 'sfcwr'));

router.get('/bobbinlifespan', bobbinlifespanHandler(localdbConfig));
router.get('/sfcwr/bobbinlifespan', bobbinlifespanHandler(sfcwrdbConfig, 'sfcwr'));

router.post('/pdalogin', pdaLoginHandler(localdbConfig));
router.post('/sfcwr/pdalogin', pdaLoginHandler(sfcwrdbConfig, 'sfcwr'));

router.post('/pdascrap', pdaScrapHandler(localdbConfig));
router.post('/sfcwr/pdascrap', pdaScrapHandler(sfcwrdbConfig, 'sfcwr'));

module.exports = router;
