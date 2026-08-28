/** READ-ONLY follow-up sampling. No ALTER. */
const sql = require('mssql');
const cfg = require('./src/config/sfcwrdb');

(async () => {
  const pool = await sql.connect(cfg);

  // Distinct PROD_TP for DW/ST on sample day
  for (const proc of ['DW', 'ST']) {
    const req = pool.request();
    req.input('COMPANY', sql.VarChar(20), 'KSB');
    req.input('FACTORY', sql.VarChar(20), 'F002');
    req.input('SDATE', sql.NVarChar(10), '20260819');
    req.input('EDATE', sql.NVarChar(10), '20260819');
    req.input('WO_PROCESS_ID', sql.NVarChar(20), proc);
    req.input('MACHINE_CD', sql.NVarChar(20), '');
    req.input('LANG', sql.VarChar(5), 'ENG');
    const r = await req.execute('USP_SFC_KPRD060_R10');
    const rows = r.recordset || [];
    const tps = {};
    for (const row of rows) tps[row.PROD_TP] = (tps[row.PROD_TP] || 0) + 1;
    const pitchNz = rows.filter((x) => Number(x.PITCH) > 0).length;
    const speeds = [...new Set(rows.map((x) => x.WO_SPEED))].slice(0, 12);
    console.log(`\n${proc}: rows=${rows.length} PROD_TP=`, tps, 'pitch>0=', pitchNz, 'speeds=', speeds);
    if (proc === 'ST' && rows[0]) {
      console.log('ST sample', {
        MACHINE_DESC: rows[0].MACHINE_DESC,
        WO_SPEED: rows[0].WO_SPEED,
        PITCH: rows[0].PITCH,
        PROD_LENGTH: rows[0].PROD_LENGTH,
        PROD_TIME: rows[0].PROD_TIME,
        PROD_TP: rows[0].PROD_TP
      });
    }
  }

  // CALL type names with MA / KO
  for (const lang of ['MA', 'KO', 'ENG']) {
    const req = pool.request();
    req.input('COMPANY', sql.NVarChar(20), 'KSB');
    req.input('FACTORY', sql.NVarChar(20), 'F002');
    req.input('CALL_DIV', sql.NVarChar(20), '');
    req.input('MACHINE_CD', sql.NVarChar(20), '');
    req.input('SDATE', sql.NVarChar(8), '20260819');
    req.input('EDATE', sql.NVarChar(8), '20260819');
    req.input('CALL_TP', sql.NVarChar(10), '');
    req.input('CALL_SETTLE_YN', sql.NVarChar(1), '');
    req.input('LANG', sql.VarChar(5), lang);
    const r = await req.execute('USP_SFC_CALL031_R10');
    const rows = r.recordset || [];
    const named = rows.filter((x) => x.CALL_TP_NM).slice(0, 5);
    console.log(`\nCALL lang=${lang} named=${named.length}/${rows.length}`);
    named.forEach((x) => console.log(' ', x.CALL_TP, x.CALL_TP_NM, x.MACHINE_DESC));
  }

  // common code table MES016 sample
  const codes = await pool.request().query(`
    SELECT TOP 20 CD_ID, CD_NM, CD_NM_ENGLISH, CD_NM_MALAY
    FROM TB_CD_COMMON WITH (NOLOCK)
    WHERE CD_TP = 'MES016'
    ORDER BY CD_ID
  `);
  console.log('\nMES016 call types:', codes.recordset);

  await pool.close();
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
