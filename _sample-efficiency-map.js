/**
 * READ-ONLY sample of efficiency SPs. Does not ALTER anything.
 */
const fs = require('fs');
const sql = require('mssql');
const cfg = require('./src/config/sfcwrdb');

function summarize(rows, label) {
  console.log(`\n=== ${label}: ${rows.length} rows ===`);
  if (!rows.length) {
    console.log('(empty)');
    return;
  }
  console.log('COLUMNS:', Object.keys(rows[0]).join(' | '));
  console.log('SAMPLE[0]:', JSON.stringify(rows[0], null, 2));
  if (rows.length > 1) console.log('SAMPLE[1]:', JSON.stringify(rows[1], null, 2));
}

(async () => {
  const pool = await sql.connect(cfg);
  console.log('READ-ONLY connected', cfg.server, cfg.database);

  // Discover process ids used recently
  const procIds = await pool.request().query(`
    SELECT TOP 30 WO_PROCESS_ID, COUNT(*) AS cnt
    FROM (
      SELECT WO_PROCESS_ID FROM TB_WO_DRAWING_PROD_CLOSE WITH (NOLOCK)
      WHERE WR_YYMMDD >= '20260801' AND FINISH_YN = 'Y'
      UNION ALL
      SELECT WO_PROCESS_ID FROM TB_WO_STRANDING_PROD_CLOSE WITH (NOLOCK)
      WHERE WR_YYMMDD >= '20260801' AND FINISH_YN = 'Y'
    ) X
    GROUP BY WO_PROCESS_ID
    ORDER BY cnt DESC
  `);
  console.log('\n=== PROCESS IDS (Aug 2026 closes) ===');
  console.log(procIds.recordset);

  // Try a few date windows / process prefixes
  const attempts = [
    { company: 'KSB', factory: 'F002', s: '20260819', e: '20260819', proc: 'DW', machine: '', lang: 'ENG' },
    { company: 'KSB', factory: 'F002', s: '20260819', e: '20260819', proc: 'ST', machine: '', lang: 'ENG' },
    { company: 'KSB', factory: 'F002', s: '20260819', e: '20260819', proc: '', machine: '', lang: 'ENG' },
    { company: 'KSB', factory: 'F002', s: '20260801', e: '20260821', proc: 'DW', machine: '', lang: 'MA' }
  ];

  for (const a of attempts) {
    const req = pool.request();
    req.input('COMPANY', sql.VarChar(20), a.company);
    req.input('FACTORY', sql.VarChar(20), a.factory);
    req.input('SDATE', sql.NVarChar(10), a.s);
    req.input('EDATE', sql.NVarChar(10), a.e);
    req.input('WO_PROCESS_ID', sql.NVarChar(20), a.proc);
    req.input('MACHINE_CD', sql.NVarChar(20), a.machine);
    req.input('LANG', sql.VarChar(5), a.lang);
    try {
      const r = await req.execute('USP_SFC_KPRD060_R10');
      const rows = r.recordset || [];
      summarize(rows, `KPRD060 ${a.s}-${a.e} proc='${a.proc}' lang=${a.lang}`);
      if (rows.length) {
        const machines = [...new Set(rows.map((x) => x.MACHINE_DESC).filter(Boolean))].slice(0, 15);
        const processes = [...new Set(rows.map((x) => x.WO_PROCESS_ID).filter(Boolean))];
        console.log('machines:', machines.join(', '));
        console.log('processes:', processes.join(', '));
        fs.writeFileSync(
          './_map_sample_kprd060.json',
          JSON.stringify({ params: a, columns: Object.keys(rows[0]), sample: rows.slice(0, 5), count: rows.length }, null, 2)
        );
        break;
      }
    } catch (e) {
      console.log('KPRD060 fail', a, e.message);
    }
  }

  // CALL031
  const callAttempts = [
    { company: 'KSB', factory: 'F002', div: '', machine: '', s: '20260819', e: '20260819', tp: '', settle: '', lang: 'ENG' },
    { company: 'KSB', factory: 'F002', div: '', machine: '', s: '20260801', e: '20260821', tp: '', settle: '', lang: 'ENG' }
  ];
  for (const a of callAttempts) {
    const req = pool.request();
    req.input('COMPANY', sql.NVarChar(20), a.company);
    req.input('FACTORY', sql.NVarChar(20), a.factory);
    req.input('CALL_DIV', sql.NVarChar(20), a.div);
    req.input('MACHINE_CD', sql.NVarChar(20), a.machine);
    req.input('SDATE', sql.NVarChar(8), a.s);
    req.input('EDATE', sql.NVarChar(8), a.e);
    req.input('CALL_TP', sql.NVarChar(10), a.tp);
    req.input('CALL_SETTLE_YN', sql.NVarChar(1), a.settle);
    req.input('LANG', sql.VarChar(5), a.lang);
    try {
      const r = await req.execute('USP_SFC_CALL031_R10');
      const rows = r.recordset || [];
      summarize(rows, `CALL031_R10 ${a.s}-${a.e}`);
      if (rows.length) {
        fs.writeFileSync(
          './_map_sample_call031.json',
          JSON.stringify({ params: a, columns: Object.keys(rows[0]), sample: rows.slice(0, 5), count: rows.length }, null, 2)
        );
        break;
      }
    } catch (e) {
      console.log('CALL031 fail', a, e.message);
    }
  }

  await pool.close();
  console.log('\nDONE (read-only)');
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
